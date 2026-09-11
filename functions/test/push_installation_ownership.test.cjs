const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildPushInstallationOwnershipPaths,
  parsePushInstallationClaimRequest,
  parsePushInstallationReleaseRequest,
} = require("../lib/push_installation_ownership.js");

const installationId =
  "ba4a84ff3faf57cadce0db0e9f8ba269";

test("parses valid installation claim", () => {
  const result = parsePushInstallationClaimRequest({
    installationId,
    token: "valid-fcm-token",
    platform: "android",
  });

  assert.deepEqual(result, {
    installationId,
    token: "valid-fcm-token",
    platform: "android",
  });
});

test("rejects claim with missing fields", () => {
  const result = parsePushInstallationClaimRequest({
    installationId,
    platform: "android",
  });

  assert.equal(result, null);
});

test("rejects claim with unknown fields", () => {
  const result = parsePushInstallationClaimRequest({
    installationId,
    token: "valid-fcm-token",
    platform: "android",
    userId: "must-not-come-from-client",
  });

  assert.equal(result, null);
});

test("rejects invalid installation id", () => {
  const result = parsePushInstallationClaimRequest({
    installationId: "not-an-installation-id",
    token: "valid-fcm-token",
    platform: "android",
  });

  assert.equal(result, null);
});

test("rejects unsupported push platform", () => {
  const result = parsePushInstallationClaimRequest({
    installationId,
    token: "valid-fcm-token",
    platform: "web",
  });

  assert.equal(result, null);
});

test("rejects token with surrounding whitespace", () => {
  const result = parsePushInstallationClaimRequest({
    installationId,
    token: "  valid-fcm-token  ",
    platform: "android",
  });

  assert.equal(result, null);
});

test("parses valid installation release", () => {
  const result = parsePushInstallationReleaseRequest({
    installationId,
  });

  assert.deepEqual(result, {
    installationId,
  });
});

test("rejects release with unknown fields", () => {
  const result = parsePushInstallationReleaseRequest({
    installationId,
    userId: "must-not-come-from-client",
  });

  assert.equal(result, null);
});

test("builds paths when installation changes owner", () => {
  const result = buildPushInstallationOwnershipPaths(
    installationId,
    "new-user",
    "old-user",
  );

  assert.deepEqual(result, {
    registryDocumentPath:
      `pushInstallations/${installationId}`,
    currentDeviceDocumentPath:
      `users/new-user/devices/${installationId}`,
    previousDeviceDocumentPath:
      `users/old-user/devices/${installationId}`,
  });
});

test("does not delete device when owner is unchanged", () => {
  const result = buildPushInstallationOwnershipPaths(
    installationId,
    "same-user",
    "same-user",
  );

  assert.deepEqual(result, {
    registryDocumentPath:
      `pushInstallations/${installationId}`,
    currentDeviceDocumentPath:
      `users/same-user/devices/${installationId}`,
    previousDeviceDocumentPath: null,
  });
});

test("builds first ownership paths without previous owner", () => {
  const result = buildPushInstallationOwnershipPaths(
    installationId,
    "first-user",
    null,
  );

  assert.deepEqual(result, {
    registryDocumentPath:
      `pushInstallations/${installationId}`,
    currentDeviceDocumentPath:
      `users/first-user/devices/${installationId}`,
    previousDeviceDocumentPath: null,
  });
});

test("rejects unsafe user id", () => {
  const result = buildPushInstallationOwnershipPaths(
    installationId,
    "bad/user",
    null,
  );

  assert.equal(result, null);
});