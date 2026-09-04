const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildSubstitutionCallNotification,
} = require("../lib/substitution_call_notification.js");

test("builds day shift notification", () => {
  const result = buildSubstitutionCallNotification(
    "7",
    {
      callId: "7",
      userId: "member-1",
      shiftYear: 2026,
      shiftMonth: 9,
      shiftDay: 5,
      shiftKind: "day",
    },
  );

  assert.deepEqual(result, {
    callId: "7",
    recipientUserId: "member-1",
    presentationId: "substitution:7",
    body:
      "Вы вызваны на дневную смену " +
      "05.09.2026 в 08:00",
  });
});

test("builds night shift notification", () => {
  const result = buildSubstitutionCallNotification(
    "8",
    {
      callId: "8",
      userId: "member-2",
      shiftYear: 2026,
      shiftMonth: 10,
      shiftDay: 11,
      shiftKind: "night",
    },
  );

  assert.equal(
    result?.body,
    "Вы вызваны на ночную смену " +
      "11.10.2026 в 20:00",
  );

  assert.equal(
    result?.presentationId,
    "substitution:8",
  );
});

test("rejects mismatched call id", () => {
  const result = buildSubstitutionCallNotification(
    "7",
    {
      callId: "8",
      userId: "member-1",
      shiftYear: 2026,
      shiftMonth: 9,
      shiftDay: 5,
      shiftKind: "day",
    },
  );

  assert.equal(result, null);
});

test("rejects invalid recipient", () => {
  const result = buildSubstitutionCallNotification(
    "7",
    {
      callId: "7",
      userId: "bad/user",
      shiftYear: 2026,
      shiftMonth: 9,
      shiftDay: 5,
      shiftKind: "day",
    },
  );

  assert.equal(result, null);
});

test("rejects invalid shift kind", () => {
  const result = buildSubstitutionCallNotification(
    "7",
    {
      callId: "7",
      userId: "member-1",
      shiftYear: 2026,
      shiftMonth: 9,
      shiftDay: 5,
      shiftKind: "unknown",
    },
  );

  assert.equal(result, null);
});

test("rejects invalid calendar date", () => {
  const result = buildSubstitutionCallNotification(
    "7",
    {
      callId: "7",
      userId: "member-1",
      shiftYear: 2026,
      shiftMonth: 2,
      shiftDay: 30,
      shiftKind: "day",
    },
  );

  assert.equal(result, null);
});