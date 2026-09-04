import {getApps, initializeApp} from "firebase-admin/app";
import {getDatabase} from "firebase-admin/database";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {setGlobalOptions} from "firebase-functions/v2";
import {
  detectSpacesBarPublication,
} from "./spaces_bar_notification";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

if (getApps().length === 0) {
  initializeApp();
}

const PUSH_PREVIEW_MAX_CHARACTERS = 180;
const FIRST_PRIVATE_IMAGE_GRANT_TYPE = "first_private_image";
const IMAGE_GRANTS_COLLECTION = "imageMessageUploadGrants";
const GRANT_DURATION_MILLISECONDS = 5 * 60 * 1000;
const MAX_GRANT_DURATION_MILLISECONDS = 10 * 60 * 1000;
const GRANT_REQUEST_FIELDS = [
  "peerId",
  "chatId",
  "messageId",
  "version",
] as const;
const GRANT_DOCUMENT_FIELDS = [
  "grantType",
  "uploaderId",
  "peerId",
  "chatId",
  "messageId",
  "version",
  "createdAt",
  "expiresAt",
] as const;

interface FirstPrivateImageGrantRequest {
  peerId: string;
  chatId: string;
  messageId: string;
  version: string;
}

/**
 * Builds a shortened push notification preview.
 * @param {string} text Full message text.
 * @return {string} Shortened preview text.
 */
function buildPushPreview(text: string): string {
  const characters = Array.from(text);

  if (characters.length <= PUSH_PREVIEW_MAX_CHARACTERS) {
    return text;
  }

  return [
    ...characters.slice(0, PUSH_PREVIEW_MAX_CHARACTERS - 1),
    "…",
  ].join("");
}

/**
 * Reads a strict non-empty callable string field.
 * @param {Record<string, unknown>} data Callable request data.
 * @param {string} field Field name.
 * @return {string} Validated value.
 */
function readGrantString(
  data: Record<string, unknown>,
  field: keyof FirstPrivateImageGrantRequest,
): string {
  const value = data[field];

  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value !== value.trim()
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Field ${field} must be a non-empty string.`,
    );
  }

  return value;
}

/**
 * Parses and validates callable grant request data.
 * @param {unknown} data Callable request data.
 * @return {FirstPrivateImageGrantRequest} Validated request.
 */
function parseGrantRequest(data: unknown): FirstPrivateImageGrantRequest {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new HttpsError(
      "invalid-argument",
      "Request data must be an object.",
    );
  }

  const record = data as Record<string, unknown>;
  const keys = Object.keys(record);
  const hasExactFields =
    keys.length === GRANT_REQUEST_FIELDS.length &&
    GRANT_REQUEST_FIELDS.every((field) =>
      Object.prototype.hasOwnProperty.call(record, field),
    );

  if (!hasExactFields) {
    throw new HttpsError(
      "invalid-argument",
      "Request data contains missing or unknown fields.",
    );
  }

  const request = {
    peerId: readGrantString(record, "peerId"),
    chatId: readGrantString(record, "chatId"),
    messageId: readGrantString(record, "messageId"),
    version: readGrantString(record, "version"),
  };

  if (
    request.peerId.includes("/") ||
    request.chatId.includes("/") ||
    request.messageId.includes("/")
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Firestore identifiers must not contain a slash.",
    );
  }

  if (!/^v[1-9][0-9]*$/.test(request.version)) {
    throw new HttpsError(
      "invalid-argument",
      "Field version must match v[1-9][0-9]*.",
    );
  }

  return request;
}

/**
 * Checks whether an existing grant can be reused safely.
 * @param {FirebaseFirestore.DocumentData|undefined} data Existing grant data.
 * @param {FirstPrivateImageGrantRequest} request Validated request.
 * @param {string} uploaderId Authenticated uploader ID.
 * @param {Timestamp} now Current server time.
 * @return {boolean} Whether the grant is reusable.
 */
function isReusableGrant(
  data: FirebaseFirestore.DocumentData | undefined,
  request: FirstPrivateImageGrantRequest,
  uploaderId: string,
  now: Timestamp,
): boolean {
  if (data == null) {
    return false;
  }

  const keys = Object.keys(data);
  const hasExactFields =
    keys.length === GRANT_DOCUMENT_FIELDS.length &&
    GRANT_DOCUMENT_FIELDS.every((field) =>
      Object.prototype.hasOwnProperty.call(data, field),
    );
  const createdAt = data.createdAt;
  const expiresAt = data.expiresAt;

  if (
    !hasExactFields ||
    !(createdAt instanceof Timestamp) ||
    !(expiresAt instanceof Timestamp)
  ) {
    return false;
  }

  const createdAtMilliseconds = createdAt.toMillis();
  const expiresAtMilliseconds = expiresAt.toMillis();
  const nowMilliseconds = now.toMillis();
  const durationMilliseconds =
    expiresAtMilliseconds - createdAtMilliseconds;

  return (
    data.grantType === FIRST_PRIVATE_IMAGE_GRANT_TYPE &&
    data.uploaderId === uploaderId &&
    data.peerId === request.peerId &&
    data.chatId === request.chatId &&
    data.messageId === request.messageId &&
    data.version === request.version &&
    createdAtMilliseconds <= nowMilliseconds &&
    expiresAtMilliseconds > nowMilliseconds &&
    durationMilliseconds > 0 &&
    durationMilliseconds <= MAX_GRANT_DURATION_MILLISECONDS
  );
}
const PRIVATE_TYPING_ACCESS_ROOT = "privateChatAccess";
const ENSURE_PRIVATE_TYPING_ACCESS_FIELDS = [
  "chatId",
] as const;

interface EnsurePrivateTypingAccessRequest {
  chatId: string;
}

/**
 * Checks whether a value contains a character forbidden in an RTDB key.
 * @param {string} value Candidate key.
 * @return {boolean} Whether the key contains a forbidden character.
 */
function containsInvalidRealtimeDatabaseKeyCharacter(
  value: string,
): boolean {
  return [
    ".",
    "#",
    "$",
    "[",
    "]",
    "/",
  ].some(
    (character) => value.includes(character),
  );
}

/**
 * Parses a strict typing access callable request.
 * @param {unknown} data Callable request data.
 * @return {EnsurePrivateTypingAccessRequest} Validated request.
 */
function parseEnsurePrivateTypingAccessRequest(
  data: unknown,
): EnsurePrivateTypingAccessRequest {
  if (
    typeof data !== "object" ||
    data === null ||
    Array.isArray(data)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Request data must be an object.",
    );
  }

  const record = data as Record<string, unknown>;
  const keys = Object.keys(record);
  const hasExactFields =
    keys.length ===
        ENSURE_PRIVATE_TYPING_ACCESS_FIELDS.length &&
    ENSURE_PRIVATE_TYPING_ACCESS_FIELDS.every(
      (field) =>
        Object.prototype.hasOwnProperty.call(
          record,
          field,
        ),
    );

  if (!hasExactFields) {
    throw new HttpsError(
      "invalid-argument",
      "Request data contains missing or unknown fields.",
    );
  }

  const chatId = record.chatId;

  if (
    typeof chatId !== "string" ||
    chatId.length === 0 ||
    chatId !== chatId.trim() ||
    containsInvalidRealtimeDatabaseKeyCharacter(chatId)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Field chatId must be a valid non-empty RTDB key.",
    );
  }

  return {chatId};
}

/**
 * Reads and validates private chat member IDs.
 * @param {FirebaseFirestore.DocumentData|undefined} data Chat data.
 * @param {string} authenticatedUserId Authenticated caller ID.
 * @return {string[]} Two validated private chat member IDs.
 */
function readPrivateTypingMemberIds(
  data: FirebaseFirestore.DocumentData | undefined,
  authenticatedUserId: string,
): string[] {
  if (
    data == null ||
    data.type !== "private" ||
    data.isDissolved !== false
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Typing access is available only for an active private chat.",
    );
  }

  const memberIds: unknown = data.memberIds;

  if (
    !Array.isArray(memberIds) ||
    memberIds.length !== 2 ||
    !memberIds.every(
      (memberId) =>
        typeof memberId === "string" &&
        memberId.length > 0 &&
        memberId === memberId.trim() &&
        !containsInvalidRealtimeDatabaseKeyCharacter(
          memberId,
        ),
    )
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Private chat members are invalid.",
    );
  }

  const validatedMemberIds = memberIds as string[];

  if (
    new Set(validatedMemberIds).size !==
    validatedMemberIds.length
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Private chat members must be unique.",
    );
  }

  if (!validatedMemberIds.includes(authenticatedUserId)) {
    throw new HttpsError(
      "permission-denied",
      "The authenticated user is not a chat member.",
    );
  }

  return validatedMemberIds;
}

export const ensurePrivateTypingAccess = onCall<unknown>(
  async (callableRequest) => {
    const authenticatedUser = callableRequest.auth;

    if (authenticatedUser == null) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    const request =
      parseEnsurePrivateTypingAccessRequest(
        callableRequest.data,
      );
    const authenticatedUserId = authenticatedUser.uid;

    try {
      const chatSnapshot = await getFirestore()
        .collection("chats")
        .doc(request.chatId)
        .get();

      if (!chatSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "The private chat does not exist.",
        );
      }

      const memberIds = readPrivateTypingMemberIds(
        chatSnapshot.data(),
        authenticatedUserId,
      );
      const accessData: Record<string, boolean> = {};

      for (const memberId of memberIds) {
        accessData[memberId] = true;
      }

      await getDatabase()
        .ref(
          `${PRIVATE_TYPING_ACCESS_ROOT}/${request.chatId}`,
        )
        .set(accessData);

      logger.info("Private typing access is ready", {
        chatId: request.chatId,
        requestedBy: authenticatedUserId,
        memberIds,
      });

      return {granted: true};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error(
        "Failed to ensure private typing access",
        {
          error,
          chatId: request.chatId,
          requestedBy: authenticatedUserId,
        },
      );

      throw new HttpsError(
        "internal",
        "Unable to prepare private typing access.",
      );
    }
  },
);

export const createFirstPrivateImageUploadGrant = onCall<unknown>(
  async (callableRequest) => {
    const authenticatedUser = callableRequest.auth;

    if (authenticatedUser == null) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }

    const request = parseGrantRequest(callableRequest.data);
    const uploaderId = authenticatedUser.uid;

    if (request.peerId === uploaderId) {
      throw new HttpsError(
        "invalid-argument",
        "The peer user must differ from the uploader.",
      );
    }

    const hasExpectedChatId =
      request.chatId === `${uploaderId}_${request.peerId}` ||
      request.chatId === `${request.peerId}_${uploaderId}`;

    if (!hasExpectedChatId) {
      throw new HttpsError(
        "invalid-argument",
        "The chat ID does not match the private chat participants.",
      );
    }

    const firestore = getFirestore();
    const peerReference = firestore
      .collection("users")
      .doc(request.peerId);
    const chatReference = firestore
      .collection("chats")
      .doc(request.chatId);
    const grantReference = firestore
      .collection(IMAGE_GRANTS_COLLECTION)
      .doc(request.messageId);

    try {
      const status = await firestore.runTransaction(async (transaction) => {
        const peerSnapshot = await transaction.get(peerReference);
        const chatSnapshot = await transaction.get(chatReference);
        const grantSnapshot = await transaction.get(grantReference);

        if (!peerSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "The peer user does not exist.",
          );
        }

        if (chatSnapshot.exists) {
          throw new HttpsError(
            "failed-precondition",
            "The private chat already exists.",
          );
        }

        const now = Timestamp.now();

        if (
          isReusableGrant(
            grantSnapshot.data(),
            request,
            uploaderId,
            now,
          )
        ) {
          return "reused";
        }

        if (grantSnapshot.exists) {
          throw new HttpsError(
            "already-exists",
            "A grant for this message ID already exists.",
          );
        }

        const expiresAt = Timestamp.fromMillis(
          now.toMillis() + GRANT_DURATION_MILLISECONDS,
        );

        transaction.create(grantReference, {
          grantType: FIRST_PRIVATE_IMAGE_GRANT_TYPE,
          uploaderId,
          peerId: request.peerId,
          chatId: request.chatId,
          messageId: request.messageId,
          version: request.version,
          createdAt: now,
          expiresAt,
        });

        return "created";
      });

      logger.info("First private image upload grant is ready", {
        status,
        uploaderId,
        peerId: request.peerId,
        chatId: request.chatId,
        messageId: request.messageId,
        version: request.version,
      });

      return {granted: true};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error("Failed to create first private image upload grant", {
        error,
        uploaderId,
        peerId: request.peerId,
        chatId: request.chatId,
        messageId: request.messageId,
        version: request.version,
      });

      throw new HttpsError(
        "internal",
        "Unable to create an image upload grant.",
      );
    }
  },
);

type NotificationDeliveryMode =
  "sound" |
  "silent" |
  "disabled";

type EnabledNotificationDeliveryMode =
  Exclude<NotificationDeliveryMode, "disabled">;

interface NotificationRecipient {
  recipientId: string;
  mode: EnabledNotificationDeliveryMode;
}

interface NotificationTokenDocument {
  reference: FirebaseFirestore.DocumentReference;
  token: string;
  mode: EnabledNotificationDeliveryMode;
}

const MESSAGE_NOTIFICATION_CHANNEL_ID =
  "epistola_messages_seagull_v3";

const SILENT_MESSAGE_NOTIFICATION_CHANNEL_ID =
  "epistola_messages_silent";

const SPACES_BAR_NOTIFICATION_CHANNEL_ID =
  "epistola_spaces_bar_v1";

const FCM_MULTICAST_TOKEN_LIMIT = 500;

const INVALID_FCM_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

/**
 * Checks whether a value is a plain record.
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

/**
 * Resolves notification delivery mode for one chat member.
 * Missing, malformed, or expired settings fall back to sound.
 * @param {FirebaseFirestore.DocumentData|undefined} chatData Chat data.
 * @param {string} recipientId Recipient user ID.
 * @param {Timestamp} now Current server time.
 * @return {NotificationDeliveryMode} Effective delivery mode.
 */
function resolveNotificationDeliveryMode(
  chatData: FirebaseFirestore.DocumentData | undefined,
  recipientId: string,
  now: Timestamp,
): NotificationDeliveryMode {
  const rawSettingsByUser: unknown =
    chatData?.notificationSettingsByUser;

  if (!isRecord(rawSettingsByUser)) {
    return "sound";
  }

  const rawSettings = rawSettingsByUser[recipientId];

  if (!isRecord(rawSettings)) {
    return "sound";
  }

  const mode = rawSettings.mode;

  if (mode === "disabled") {
    return "disabled";
  }

  if (mode !== "silent") {
    return "sound";
  }

  if (rawSettings.permanent === true) {
    return "silent";
  }

  const expiresAt = rawSettings.expiresAt;

  if (
    expiresAt instanceof Timestamp &&
    expiresAt.toMillis() > now.toMillis()
  ) {
    return "silent";
  }

  return "sound";
}

export const sendMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const messageSnapshot = event.data;

    if (!messageSnapshot) {
      logger.warn("Message snapshot is missing");
      return;
    }

    const {chatId} = event.params;
    const messageData = messageSnapshot.data();

    const senderId =
      messageData.senderId as string | undefined;

    const senderName =
      messageData.senderName as string | undefined;

    const messageType =
  messageData.messageType as string | undefined;

    const text =
  messageData.text as string | undefined;

    if (!senderId) {
      logger.warn("Message data is incomplete", {
        chatId,
        messageId: event.params.messageId,
      });

      return;
    }

    let notificationBody: string;

    if (messageType === "image") {
      notificationBody = "Фотография";
    } else if (
      (messageType === "text" || messageType === undefined) &&
  typeof text === "string" &&
  text.length > 0
    ) {
      notificationBody = buildPushPreview(text);
    } else {
      logger.warn("Message content is unsupported or incomplete", {
        chatId,
        messageId: event.params.messageId,
        messageType,
      });

      return;
    }

    const firestore = getFirestore();

    const chatSnapshot = await firestore
      .collection("chats")
      .doc(chatId)
      .get();

    if (!chatSnapshot.exists) {
      logger.warn("Chat does not exist", {
        chatId,
      });

      return;
    }

    const chatData = chatSnapshot.data();
    const memberIds = chatData?.memberIds;

    if (!Array.isArray(memberIds)) {
      logger.warn("Chat memberIds are invalid", {
        chatId,
      });

      return;
    }

    const recipientIds = memberIds.filter(
      (memberId): memberId is string =>
        typeof memberId === "string" &&
        memberId !== senderId,
    );

    if (recipientIds.length === 0) {
      return;
    }

    const now = Timestamp.now();

    const enabledRecipients:
      NotificationRecipient[] = [];

    let disabledRecipientCount = 0;

    for (const recipientId of recipientIds) {
      const mode = resolveNotificationDeliveryMode(
        chatData,
        recipientId,
        now,
      );

      if (mode === "disabled") {
        disabledRecipientCount += 1;
        continue;
      }

      enabledRecipients.push({
        recipientId,
        mode,
      });
    }

    if (enabledRecipients.length === 0) {
      logger.info(
        "Push notification skipped for all recipients",
        {
          chatId,
          recipients: recipientIds.length,
          disabledRecipients:
            disabledRecipientCount,
        },
      );

      return;
    }

    const deviceResults = await Promise.all(
      enabledRecipients.map(
        async (recipient) => {
          const snapshot = await firestore
            .collection("users")
            .doc(recipient.recipientId)
            .collection("devices")
            .get();

          return {
            recipient,
            snapshot,
          };
        },
      ),
    );

    const tokenDocuments:
      NotificationTokenDocument[] = [];

    for (const result of deviceResults) {
      for (const document of result.snapshot.docs) {
        const token = document.data().token;

        if (
          typeof token !== "string" ||
          token.length === 0
        ) {
          continue;
        }

        tokenDocuments.push({
          reference: document.ref,
          token,
          mode: result.recipient.mode,
        });
      }
    }

    if (tokenDocuments.length === 0) {
      logger.info("No recipient tokens found", {
        chatId,
      });

      return;
    }

    const invalidTokenReferences:
      FirebaseFirestore.DocumentReference[] = [];

    let successCount = 0;
    let failureCount = 0;

    const deliveryModes:
      EnabledNotificationDeliveryMode[] = [
        "sound",
        "silent",
      ];

    for (const mode of deliveryModes) {
      const modeTokenDocuments =
        tokenDocuments.filter(
          (device) => device.mode === mode,
        );

      for (
        let start = 0;
        start < modeTokenDocuments.length;
        start += FCM_MULTICAST_TOKEN_LIMIT
      ) {
        const batch = modeTokenDocuments.slice(
          start,
          start + FCM_MULTICAST_TOKEN_LIMIT,
        );

        const channelId =
          mode === "silent" ?
            SILENT_MESSAGE_NOTIFICATION_CHANNEL_ID :
            MESSAGE_NOTIFICATION_CHANNEL_ID;

        const response =
          await getMessaging().sendEachForMulticast({
            tokens: batch.map(
              (device) => device.token,
            ),
            notification: {
              title:
                senderName?.trim() || "Epistola",
              body: notificationBody,
            },
            data: {
              chatId,
              notificationMode: mode,
            },
            android: {
              priority: "high",
              notification: {
                channelId,
                ...(mode === "sound" ?
                  {
                    sound: "seagull_notification",
                    vibrateTimingsMillis: [0, 250, 100, 250],
                  } :
                  {}),
              },
            },
          });

        successCount += response.successCount;
        failureCount += response.failureCount;

        response.responses.forEach(
          (sendResponse, index) => {
            const errorCode =
              sendResponse.error?.code;

            if (
              !errorCode ||
              !INVALID_FCM_TOKEN_CODES.has(
                errorCode,
              )
            ) {
              return;
            }

            invalidTokenReferences.push(
              batch[index].reference,
            );
          },
        );
      }
    }

    await Promise.all(
      invalidTokenReferences.map(
        (reference) => reference.delete(),
      ),
    );

    const soundRecipientCount =
      enabledRecipients.filter(
        (recipient) =>
          recipient.mode === "sound",
      ).length;

    const silentRecipientCount =
      enabledRecipients.filter(
        (recipient) =>
          recipient.mode === "silent",
      ).length;

    logger.info("Push notification processed", {
      chatId,
      recipients: recipientIds.length,
      soundRecipients: soundRecipientCount,
      silentRecipients: silentRecipientCount,
      disabledRecipients: disabledRecipientCount,
      tokens: tokenDocuments.length,
      successCount,
      failureCount,
      removedInvalidTokens:
        invalidTokenReferences.length,
    });
  },
);
export const sendSpacesBarNotification = onDocumentWritten(
  "spaces/spacesBar",
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    const publication = detectSpacesBarPublication(
      beforeData,
      afterData,
    );

    if (publication === null) {
      return;
    }

    const firestore = getFirestore();

    const devicesSnapshot = await firestore
      .collectionGroup("devices")
      .get();

    const referencesByToken = new Map<
      string,
      FirebaseFirestore.DocumentReference[]
    >();

    const publisherTokens = new Set<string>();

    for (const document of devicesSnapshot.docs) {
      const userReference = document.ref.parent.parent;

      if (
        userReference === null ||
        userReference.parent.id !== "users"
      ) {
        continue;
      }

      const token = document.data().token;

      if (
        typeof token !== "string" ||
        token.length === 0
      ) {
        continue;
      }

      if (userReference.id === publication.createdByUserId) {
        publisherTokens.add(token);
        continue;
      }

      const existingReferences =
        referencesByToken.get(token);

      if (existingReferences !== undefined) {
        existingReferences.push(document.ref);
      } else {
        referencesByToken.set(
          token,
          [document.ref],
        );
      }
    }

    for (const publisherToken of publisherTokens) {
      referencesByToken.delete(publisherToken);
    }

    const tokenEntries = Array.from(
      referencesByToken.entries(),
    );

    if (tokenEntries.length === 0) {
      logger.info(
        "SpacesBar push skipped: no recipient tokens",
        {
          messageId: publication.messageId,
          createdByUserId: publication.createdByUserId,
        },
      );

      return;
    }

    const invalidTokenReferences:
      FirebaseFirestore.DocumentReference[] = [];

    let successCount = 0;
    let failureCount = 0;

    for (
      let start = 0;
      start < tokenEntries.length;
      start += FCM_MULTICAST_TOKEN_LIMIT
    ) {
      const batch = tokenEntries.slice(
        start,
        start + FCM_MULTICAST_TOKEN_LIMIT,
      );

      const response =
        await getMessaging().sendEachForMulticast({
          tokens: batch.map(
            ([token]) => token,
          ),
          notification: {
            title: "Epistola — Пространства",
            body: buildPushPreview(publication.text),
          },
          data: {
            deepLinkType: "spacesBar",
            spacesBarMessageId: publication.messageId,
            notificationMode: "sound",
          },
          android: {
            priority: "high",
            notification: {
              channelId: SPACES_BAR_NOTIFICATION_CHANNEL_ID,
              sound: "seagull_notification",
              vibrateTimingsMillis: [0, 250, 100, 250],
            },
          },
        });

      successCount += response.successCount;
      failureCount += response.failureCount;

      response.responses.forEach(
        (sendResponse, index) => {
          const errorCode =
            sendResponse.error?.code;

          if (
            !errorCode ||
            !INVALID_FCM_TOKEN_CODES.has(errorCode)
          ) {
            return;
          }

          const [, references] = batch[index];

          invalidTokenReferences.push(
            ...references,
          );
        },
      );
    }

    await Promise.all(
      invalidTokenReferences.map(
        (reference) => reference.delete(),
      ),
    );

    logger.info(
      "SpacesBar push notification processed",
      {
        messageId: publication.messageId,
        createdByUserId: publication.createdByUserId,
        registeredDeviceDocuments:
          devicesSnapshot.size,
        recipientTokens: tokenEntries.length,
        successCount,
        failureCount,
        removedInvalidTokens:
          invalidTokenReferences.length,
      },
    );
  },
);
