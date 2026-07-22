import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

if (getApps().length === 0) {
  initializeApp();
}
const PUSH_PREVIEW_MAX_CHARACTERS = 180;

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

    const senderId = messageData.senderId as string | undefined;
    const senderName = messageData.senderName as string | undefined;
    const text = messageData.text as string | undefined;

    if (!senderId || !text) {
      logger.warn("Message data is incomplete", {
        chatId,
        messageId: event.params.messageId,
      });
      return;
    }
    const notificationBody = buildPushPreview(text);

    const firestore = getFirestore();
    const chatSnapshot = await firestore.collection("chats").doc(chatId).get();

    if (!chatSnapshot.exists) {
      logger.warn("Chat does not exist", {chatId});
      return;
    }

    const chatData = chatSnapshot.data();
    const memberIds = chatData?.memberIds;

    if (!Array.isArray(memberIds)) {
      logger.warn("Chat memberIds are invalid", {chatId});
      return;
    }

    const recipientIds = memberIds.filter(
      (memberId): memberId is string =>
        typeof memberId === "string" && memberId !== senderId,
    );

    if (recipientIds.length === 0) {
      return;
    }

    const deviceSnapshots = await Promise.all(
      recipientIds.map((recipientId) =>
        firestore
          .collection("users")
          .doc(recipientId)
          .collection("devices")
          .get(),
      ),
    );

    const tokenDocuments = deviceSnapshots.flatMap((snapshot) =>
      snapshot.docs
        .map((document) => ({
          reference: document.ref,
          token: document.data().token,
        }))
        .filter(
          (
            device,
          ): device is {
            reference: FirebaseFirestore.DocumentReference;
            token: string;
          } => typeof device.token === "string" && device.token.length > 0,
        ),
    );

    if (tokenDocuments.length === 0) {
      logger.info("No recipient tokens found", {chatId});
      return;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: tokenDocuments.map((device) => device.token),
      notification: {
        title: senderName?.trim() || "Epistola",
        body: notificationBody,
      },
      data: {
        chatId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "epistola_messages",
        },
      },
    });

    const invalidTokenCodes = new Set([
      "messaging/invalid-registration-token",
      "messaging/registration-token-not-registered",
    ]);

    const invalidTokenDeletes = response.responses.flatMap(
      (sendResponse, index) => {
        const errorCode = sendResponse.error?.code;

        if (!errorCode || !invalidTokenCodes.has(errorCode)) {
          return [];
        }

        return [tokenDocuments[index].reference.delete()];
      },
    );

    await Promise.all(invalidTokenDeletes);

    logger.info("Push notification processed", {
      chatId,
      recipients: recipientIds.length,
      tokens: tokenDocuments.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      removedInvalidTokens: invalidTokenDeletes.length,
    });
  },
);
