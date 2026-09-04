export interface SubstitutionCallNotification {
  callId: string;
  recipientUserId: string;
  presentationId: string;
  body: string;
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
 * Checks a Firestore-style identifier.
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value is valid.
 */
function isValidId(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value === value.trim() &&
    !value.includes("/")
  );
}

/**
 * Reads an integer.
 * @param {unknown} value Candidate value.
 * @return {number|null} Integer or null.
 */
function readInteger(value: unknown): number | null {
  return typeof value === "number" &&
    Number.isInteger(value) ?
    value :
    null;
}

/**
 * Checks a calendar date.
 * @param {number} year Year.
 * @param {number} month Month.
 * @param {number} day Day.
 * @return {boolean} Whether the date is valid.
 */
function isValidDate(
  year: number,
  month: number,
  day: number,
): boolean {
  if (
    year < 1 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31
  ) {
    return false;
  }

  const date = new Date(
    Date.UTC(year, month - 1, day),
  );

  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

/**
 * Formats a number using two digits.
 * @param {number} value Number.
 * @return {string} Two-digit value.
 */
function twoDigits(value: number): string {
  return value.toString().padStart(2, "0");
}

/**
 * Builds a notification from one confirmed substitution call.
 * @param {string} documentCallId Firestore document ID.
 * @param {unknown} data Confirmed call data.
 * @return {SubstitutionCallNotification|null} Notification metadata.
 */
export function buildSubstitutionCallNotification(
  documentCallId: string,
  data: unknown,
): SubstitutionCallNotification | null {
  if (
    !isValidId(documentCallId) ||
    !isRecord(data)
  ) {
    return null;
  }

  const callId = data.callId;
  const userId = data.userId;
  const shiftYear = readInteger(data.shiftYear);
  const shiftMonth = readInteger(data.shiftMonth);
  const shiftDay = readInteger(data.shiftDay);
  const shiftKind = data.shiftKind;

  if (
    !isValidId(callId) ||
    callId !== documentCallId ||
    !isValidId(userId) ||
    shiftYear === null ||
    shiftMonth === null ||
    shiftDay === null ||
    (shiftKind !== "day" &&
      shiftKind !== "night")
  ) {
    return null;
  }

  if (
    !isValidDate(
      shiftYear,
      shiftMonth,
      shiftDay,
    )
  ) {
    return null;
  }

  const startHour =
    shiftKind === "day" ? 8 : 20;

  const shiftLabel =
    shiftKind === "day" ?
      "дневную" :
      "ночную";

  const date =
    `${twoDigits(shiftDay)}.` +
    `${twoDigits(shiftMonth)}.` +
    `${shiftYear}`;

  const time = `${twoDigits(startHour)}:00`;

  return {
    callId,
    recipientUserId: userId,
    presentationId: `substitution:${callId}`,
    body:
      `Вы вызваны на ${shiftLabel} смену ` +
      `${date} в ${time}`,
  };
}
