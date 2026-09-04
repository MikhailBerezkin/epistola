export interface SpacesBarPublication {
  messageId: string;
  text: string;
  createdByUserId: string;
}

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
 * Reads the messages map from a SpacesBar board.
 * @param {unknown} data Board data.
 * @param {boolean} allowMissing Whether missing board means empty messages.
 * @return {Record<string, unknown>|null} Messages map.
 */
function readMessages(
  data: unknown,
  allowMissing: boolean,
): Record<string, unknown> | null {
  if (data === undefined || data === null) {
    return allowMissing ? {} : null;
  }

  if (!isRecord(data) || !isRecord(data.messages)) {
    return null;
  }

  return data.messages;
}

/**
 * Detects one newly published SpacesBar message from a board write.
 *
 * Deletions, updates of existing messages and malformed multi-add writes
 * do not produce a publication.
 *
 * @param {unknown} beforeData Board state before write.
 * @param {unknown} afterData Board state after write.
 * @return {SpacesBarPublication|null} Newly published message.
 */
export function detectSpacesBarPublication(
  beforeData: unknown,
  afterData: unknown,
): SpacesBarPublication | null {
  const beforeMessages = readMessages(beforeData, true);
  const afterMessages = readMessages(afterData, false);

  if (beforeMessages === null || afterMessages === null) {
    return null;
  }

  const addedMessageIds = Object.keys(afterMessages).filter(
    (messageId) =>
      !Object.prototype.hasOwnProperty.call(
        beforeMessages,
        messageId,
      ),
  );

  if (addedMessageIds.length !== 1) {
    return null;
  }

  const messageId = addedMessageIds[0];

  if (
    !/^[1-9][0-9]*$/.test(messageId) ||
    messageId.includes("/")
  ) {
    return null;
  }

  const message = afterMessages[messageId];

  if (!isRecord(message)) {
    return null;
  }

  const rawText = message.text;
  const rawCreatedByUserId = message.createdByUserId;

  if (
    typeof rawText !== "string" ||
    typeof rawCreatedByUserId !== "string"
  ) {
    return null;
  }

  const text = rawText.trim();
  const createdByUserId = rawCreatedByUserId.trim();

  if (
    text.length === 0 ||
    createdByUserId.length === 0 ||
    createdByUserId.includes("/")
  ) {
    return null;
  }

  return {
    messageId,
    text,
    createdByUserId,
  };
}
