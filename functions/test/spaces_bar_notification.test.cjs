const test = require("node:test");
const assert = require("node:assert/strict");

const {
  detectSpacesBarPublication,
} = require("../lib/spaces_bar_notification.js");

function message({
  text = "Важное объявление",
  createdByUserId = "manager-1",
} = {}) {
  return {
    text,
    lifetime: "oneHour",
    createdByUserId,
    createdAt: {},
  };
}

function board(messages) {
  return {
    schemaVersion: 1,
    revision: 1,
    messages,
    updatedAt: {},
  };
}

test("detects the first SpacesBar publication", () => {
  const publication = detectSpacesBarPublication(
    undefined,
    board({
      "1": message(),
    }),
  );

  assert.deepEqual(publication, {
    messageId: "1",
    text: "Важное объявление",
    createdByUserId: "manager-1",
  });
});

test("detects one added message", () => {
  const publication = detectSpacesBarPublication(
    board({
      "1": message({text: "Первое"}),
      "2": message({text: "Второе"}),
    }),
    board({
      "1": message({text: "Первое"}),
      "2": message({text: "Второе"}),
      "3": message({
        text: "Третье",
        createdByUserId: "manager-2",
      }),
    }),
  );

  assert.deepEqual(publication, {
    messageId: "3",
    text: "Третье",
    createdByUserId: "manager-2",
  });
});

test("detects publication while expired messages disappear", () => {
  const publication = detectSpacesBarPublication(
    board({
      "1": message({text: "Expired"}),
      "2": message({text: "Active"}),
    }),
    board({
      "2": message({text: "Active"}),
      "3": message({text: "Новое"}),
    }),
  );

  assert.equal(publication?.messageId, "3");
});

test("ignores delete-only writes", () => {
  const publication = detectSpacesBarPublication(
    board({
      "1": message(),
      "2": message(),
    }),
    board({
      "1": message(),
    }),
  );

  assert.equal(publication, null);
});

test("ignores updates of an existing message", () => {
  const publication = detectSpacesBarPublication(
    board({
      "1": message({text: "До"}),
    }),
    board({
      "1": message({text: "После"}),
    }),
  );

  assert.equal(publication, null);
});

test("rejects multiple added messages", () => {
  const publication = detectSpacesBarPublication(
    board({}),
    board({
      "1": message(),
      "2": message(),
    }),
  );

  assert.equal(publication, null);
});

test("rejects malformed added messages", () => {
  const publication = detectSpacesBarPublication(
    board({}),
    board({
      "1": {
        text: "",
        createdByUserId: "manager-1",
      },
    }),
  );

  assert.equal(publication, null);
});