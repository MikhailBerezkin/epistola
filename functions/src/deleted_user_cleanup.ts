export interface DeletedUserCleanupPlan {
  userId: string;
  userDocumentPath: string;
  devicesCollectionPath: string;
  substitutionParticipantDocumentPath: string;
  spacesAccessDocumentPath: string;
}

/**
 * Builds Firestore paths that belong to an active deleted user.
 *
 * Historical chats, messages, confirmed calls and statistics
 * are intentionally excluded from this plan.
 *
 * @param {string} rawUserId Authentication user id.
 * @return {DeletedUserCleanupPlan|null} Cleanup plan or null.
 */
export function buildDeletedUserCleanupPlan(
  rawUserId: string,
): DeletedUserCleanupPlan | null {
  const userId = rawUserId.trim();

  if (
    userId.length === 0 ||
    userId.includes("/")
  ) {
    return null;
  }

  return {
    userId,
    userDocumentPath: `users/${userId}`,
    devicesCollectionPath: `users/${userId}/devices`,
    substitutionParticipantDocumentPath:
      `spaces/substitution/participants/${userId}`,
    spacesAccessDocumentPath:
      `spaces_access/${userId}`,
  };
}
