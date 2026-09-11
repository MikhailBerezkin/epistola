import {
  FieldValue,
  Firestore,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  buildPushInstallationOwnershipPaths,
  parsePushInstallationClaimRequest,
  parsePushInstallationReleaseRequest,
} from "./push_installation_ownership";

const REGISTRY_SCHEMA_VERSION = 2;

/**
 * Checks a registry user id.
 * @param {unknown} value Candidate user id.
 * @return {boolean} Whether the user id is valid.
 */
function isValidRegistryUserId(
  value: unknown,
): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value === value.trim() &&
    !value.includes("/")
  );
}

/**
 * Reads the current canonical installation user.
 *
 * Legacy schema version 1 used ownerUserId. New documents use userId.
 *
 * @param {FirebaseFirestore.DocumentData|undefined} data Registry data.
 * @return {string} Validated current user id.
 */
function readRegistryUserId(
  data: FirebaseFirestore.DocumentData | undefined,
): string {
  const userId = data?.userId;
  const legacyOwnerUserId = data?.ownerUserId;

  if (
    userId != null &&
    legacyOwnerUserId != null &&
    userId !== legacyOwnerUserId
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Push installation ownership data is inconsistent.",
    );
  }

  const resolvedUserId =
    userId ?? legacyOwnerUserId;

  if (!isValidRegistryUserId(resolvedUserId)) {
    throw new HttpsError(
      "failed-precondition",
      "Push installation ownership data is invalid.",
    );
  }

  return resolvedUserId;
}

/**
 * Claims one application installation for the authenticated user.
 *
 * If another user currently owns the installation, that user's device
 * document is removed in the same Firestore transaction.
 *
 * @param {Firestore} firestore Firestore Admin instance.
 * @param {string} authenticatedUserId Authenticated Firebase user id.
 * @param {unknown} data Callable request data.
 * @return {Promise<{claimed: boolean}>} Claim result.
 */
export async function claimPushInstallationOwnership(
  firestore: Firestore,
  authenticatedUserId: string,
  data: unknown,
): Promise<{claimed: boolean}> {
  const request =
    parsePushInstallationClaimRequest(data);

  if (request == null) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid push installation claim request.",
    );
  }

  const registryRef = firestore
    .collection("pushInstallations")
    .doc(request.installationId);

  await firestore.runTransaction(async (transaction) => {
    const registrySnapshot =
      await transaction.get(registryRef);

    const previousUserId =
      registrySnapshot.exists ?
        readRegistryUserId(
          registrySnapshot.data(),
        ) :
        null;

    const paths =
      buildPushInstallationOwnershipPaths(
        request.installationId,
        authenticatedUserId,
        previousUserId,
      );

    if (paths == null) {
      throw new HttpsError(
        "failed-precondition",
        "Unable to build push installation ownership paths.",
      );
    }

    if (paths.previousDeviceDocumentPath != null) {
      transaction.delete(
        firestore.doc(
          paths.previousDeviceDocumentPath,
        ),
      );
    }

    transaction.set(
      firestore.doc(
        paths.currentDeviceDocumentPath,
      ),
      {
        token: request.token,
        platform: request.platform,
        updatedAt: FieldValue.serverTimestamp(),
      },
    );

    transaction.set(
      registryRef,
      {
        schemaVersion: REGISTRY_SCHEMA_VERSION,
        userId: authenticatedUserId,
        token: request.token,
        platform: request.platform,
        updatedAt: FieldValue.serverTimestamp(),
      },
    );
  });

  return {claimed: true};
}

/**
 * Releases one installation from the authenticated user.
 *
 * A stale release can remove only the caller's own device document.
 * It never removes another user's canonical ownership.
 *
 * @param {Firestore} firestore Firestore Admin instance.
 * @param {string} authenticatedUserId Authenticated Firebase user id.
 * @param {unknown} data Callable request data.
 * @return {Promise<{released: boolean}>} Release result.
 */
export async function releasePushInstallationOwnership(
  firestore: Firestore,
  authenticatedUserId: string,
  data: unknown,
): Promise<{released: boolean}> {
  const request =
    parsePushInstallationReleaseRequest(data);

  if (request == null) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid push installation release request.",
    );
  }

  const registryRef = firestore
    .collection("pushInstallations")
    .doc(request.installationId);

  const currentDeviceRef = firestore.doc(
    `users/${authenticatedUserId}/devices/${request.installationId}`,
  );

  await firestore.runTransaction(async (transaction) => {
    const registrySnapshot =
      await transaction.get(registryRef);

    if (!registrySnapshot.exists) {
      transaction.delete(currentDeviceRef);
      return;
    }

    const userId =
      readRegistryUserId(
        registrySnapshot.data(),
      );

    if (userId === authenticatedUserId) {
      transaction.delete(registryRef);
      transaction.delete(currentDeviceRef);
      return;
    }

    transaction.delete(currentDeviceRef);
  });

  return {released: true};
}
