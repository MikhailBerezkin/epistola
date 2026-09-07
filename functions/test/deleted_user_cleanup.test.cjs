const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildDeletedUserCleanupPlan,
} = require("../lib/deleted_user_cleanup.js");

test("builds deleted user cleanup plan", () => {
  const result = buildDeletedUserCleanupPlan(
    "user-123",
  );

  assert.deepEqual(result, {
    userId: "user-123",
    userDocumentPath:
      "users/user-123",
    devicesCollectionPath:
      "users/user-123/devices",
    substitutionParticipantDocumentPath:
      "spaces/substitution/participants/user-123",
    spacesAccessDocumentPath:
      "spaces_access/user-123",
  });
});

test("trims user id", () => {
  const result = buildDeletedUserCleanupPlan(
    "  user-123  ",
  );

  assert.equal(
    result?.userId,
    "user-123",
  );
});

test("rejects empty user id", () => {
  assert.equal(
    buildDeletedUserCleanupPlan("   "),
    null,
  );
});

test("rejects user id containing slash", () => {
  assert.equal(
    buildDeletedUserCleanupPlan("bad/user"),
    null,
  );
});