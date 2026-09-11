const CLAIM_FIELDS = [
  "installationId",
  "token",
  "platform",
] as const;

const RELEASE_FIELDS = [
  "installationId",
] as const;

const INSTALLATION_ID_PATTERN = /^[a-f0-9]{32}$/;
const MAX_PUSH_TOKEN_LENGTH = 4096;
const ANDROID_PLATFORM = "android";

export interface PushInstallationClaimRequest {
  installationId: string;
  token: string;
  platform: "android";
}

export interface PushInstallationReleaseRequest {
  installationId: string;
}

export interface PushInstallationOwnershipPaths {
  registryDocumentPath: string;
  currentDeviceDocumentPath: string;
  previousDeviceDocumentPath: string | null;
}

/**
 * Checks whether a value is a plain callable request object.
 *
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value can be treated as a record.
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
 * Checks whether a record contains exactly the expected fields.
 *
 * @param {Record<string, unknown>} record Candidate record.
  * @param {string[]} fields Expected fields.
 * @return {boolean} Whether fields match exactly.
 */
function hasExactFields(
  record: Record<string, unknown>,
  fields: readonly string[],
): boolean {
  const keys = Object.keys(record);

  return (
    keys.length === fields.length &&
    fields.every((field) =>
      Object.prototype.hasOwnProperty.call(
        record,
        field,
      ),
    )
  );
}

/**
 * Checks the locally persisted installation identifier format.
 *
 * @param {unknown} value Candidate installation identifier.
 * @return {boolean} Whether the identifier is valid.
 */
function isValidInstallationId(
  value: unknown,
): value is string {
  return (
    typeof value === "string" &&
    INSTALLATION_ID_PATTERN.test(value)
  );
}

/**
 * Checks a Firebase Authentication user id before path construction.
 *
 * @param {string} value Candidate user id.
 * @return {boolean} Whether the user id is safe for a document path.
 */
function isValidUserId(value: string): boolean {
  return (
    value.length > 0 &&
    value === value.trim() &&
    !value.includes("/")
  );
}

/**
 * Checks a Firebase Cloud Messaging registration token.
 *
 * @param {unknown} value Candidate token.
 * @return {boolean} Whether the token has an acceptable shape.
 */
function isValidPushToken(
  value: unknown,
): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_PUSH_TOKEN_LENGTH &&
    value === value.trim()
  );
}

/**
 * Parses a strict installation ownership claim request.
 *
 * Only Android is accepted because Web push is not currently supported.
 *
 * @param {unknown} data Callable request data.
 * @return {PushInstallationClaimRequest|null} Parsed request or null.
 */
export function parsePushInstallationClaimRequest(
  data: unknown,
): PushInstallationClaimRequest | null {
  if (!isRecord(data)) {
    return null;
  }

  if (!hasExactFields(data, CLAIM_FIELDS)) {
    return null;
  }

  const installationId = data.installationId;
  const token = data.token;
  const platform = data.platform;

  if (
    !isValidInstallationId(installationId) ||
    !isValidPushToken(token) ||
    platform !== ANDROID_PLATFORM
  ) {
    return null;
  }

  return {
    installationId,
    token,
    platform: ANDROID_PLATFORM,
  };
}

/**
 * Parses a strict installation ownership release request.
 *
 * @param {unknown} data Callable request data.
 * @return {PushInstallationReleaseRequest|null} Parsed request or null.
 */
export function parsePushInstallationReleaseRequest(
  data: unknown,
): PushInstallationReleaseRequest | null {
  if (!isRecord(data)) {
    return null;
  }

  if (!hasExactFields(data, RELEASE_FIELDS)) {
    return null;
  }

  const installationId = data.installationId;

  if (!isValidInstallationId(installationId)) {
    return null;
  }

  return {
    installationId,
  };
}

/**
 * Builds canonical Firestore paths for one installation ownership claim.
 *
 * The canonical registry belongs to the trusted backend. The user device
 * document remains the source consumed by existing push delivery.
 *
 * @param {string} installationId Stable local installation identifier.
 * @param {string} currentUserId Authenticated current user id.
 * @param {string|null} previousOwnerUserId Previous canonical owner.
 * @return {PushInstallationOwnershipPaths|null} Safe paths or null.
 */
export function buildPushInstallationOwnershipPaths(
  installationId: string,
  currentUserId: string,
  previousOwnerUserId: string | null,
): PushInstallationOwnershipPaths | null {
  if (
    !isValidInstallationId(installationId) ||
    !isValidUserId(currentUserId)
  ) {
    return null;
  }

  if (
    previousOwnerUserId !== null &&
    !isValidUserId(previousOwnerUserId)
  ) {
    return null;
  }

  const previousDeviceDocumentPath =
    previousOwnerUserId !== null &&
    previousOwnerUserId !== currentUserId ?
      `users/${previousOwnerUserId}/devices/${installationId}` :
      null;

  return {
    registryDocumentPath:
      `pushInstallations/${installationId}`,
    currentDeviceDocumentPath:
      `users/${currentUserId}/devices/${installationId}`,
    previousDeviceDocumentPath,
  };
}
