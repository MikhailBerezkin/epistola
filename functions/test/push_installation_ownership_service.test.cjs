const test = require("node:test");
const assert = require("node:assert/strict");

const {
  claimPushInstallationOwnership,
  releasePushInstallationOwnership,
} = require(
  "../lib/push_installation_ownership_service.js",
);

const installationId =
  "ba4a84ff3faf57cadce0db0e9f8ba269";

class FakeDocumentReference {
  constructor(path) {
    this.path = path;
  }
}

class FakeDocumentSnapshot {
  constructor(data) {
    this._data = data;
    this.exists = data !== undefined;
  }

  data() {
    return this._data;
  }
}

class FakeCollectionReference {
  constructor(firestore, path) {
    this._firestore = firestore;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(
      `${this.path}/${id}`,
    );
  }
}

class FakeTransaction {
  constructor(documents) {
    this._documents = documents;
  }

  async get(reference) {
    return new FakeDocumentSnapshot(
      this._documents.get(reference.path),
    );
  }

  set(reference, data) {
    this._documents.set(
      reference.path,
      data,
    );
  }

  delete(reference) {
    this._documents.delete(reference.path);
  }
}

class FakeFirestore {
  constructor(initialDocuments = {}) {
    this._documents = new Map(
      Object.entries(initialDocuments),
    );
  }

  collection(path) {
    return new FakeCollectionReference(
      this,
      path,
    );
  }

  doc(path) {
    return new FakeDocumentReference(path);
  }

  async runTransaction(handler) {
    const transaction =
      new FakeTransaction(this._documents);

    return handler(transaction);
  }

  read(path) {
    return this._documents.get(path);
  }

  has(path) {
    return this._documents.has(path);
  }
}

test("first claim creates registry and device", async () => {
  const firestore = new FakeFirestore();

  const result =
    await claimPushInstallationOwnership(
      firestore,
      "user-a",
      {
        installationId,
        token: "token-a",
        platform: "android",
      },
    );

  assert.deepEqual(result, {
    claimed: true,
  });

  assert.equal(
    firestore.read(
      `pushInstallations/${installationId}`,
    ).userId,
    "user-a",
  );

  assert.equal(
    firestore.read(
      `users/user-a/devices/${installationId}`,
    ).token,
    "token-a",
  );
});

test("claim moves installation to new owner", async () => {
  const firestore = new FakeFirestore({
    [`pushInstallations/${installationId}`]: {
      schemaVersion: 2,
      userId: "user-a",
      token: "token-a",
      platform: "android",
    },
    [`users/user-a/devices/${installationId}`]: {
      token: "token-a",
      platform: "android",
    },
  });

  await claimPushInstallationOwnership(
    firestore,
    "user-b",
    {
      installationId,
      token: "token-b",
      platform: "android",
    },
  );

  assert.equal(
    firestore.has(
      `users/user-a/devices/${installationId}`,
    ),
    false,
  );

  assert.equal(
    firestore.read(
      `users/user-b/devices/${installationId}`,
    ).token,
    "token-b",
  );

  assert.equal(
    firestore.read(
      `pushInstallations/${installationId}`,
    ).userId,
    "user-b",
  );
});

test("same owner refresh updates token", async () => {
  const firestore = new FakeFirestore({
    [`pushInstallations/${installationId}`]: {
      schemaVersion: 2,
      userId: "user-a",
      token: "old-token",
      platform: "android",
    },
    [`users/user-a/devices/${installationId}`]: {
      token: "old-token",
      platform: "android",
    },
  });

  await claimPushInstallationOwnership(
    firestore,
    "user-a",
    {
      installationId,
      token: "new-token",
      platform: "android",
    },
  );

  assert.equal(
    firestore.read(
      `users/user-a/devices/${installationId}`,
    ).token,
    "new-token",
  );

  assert.equal(
    firestore.read(
      `pushInstallations/${installationId}`,
    ).token,
    "new-token",
  );
});

test("current owner release removes registry and device", async () => {
  const firestore = new FakeFirestore({
    [`pushInstallations/${installationId}`]: {
      schemaVersion: 2,
      userId: "user-a",
      token: "token-a",
      platform: "android",
    },
    [`users/user-a/devices/${installationId}`]: {
      token: "token-a",
      platform: "android",
    },
  });

  const result =
    await releasePushInstallationOwnership(
      firestore,
      "user-a",
      {
        installationId,
      },
    );

  assert.deepEqual(result, {
    released: true,
  });

  assert.equal(
    firestore.has(
      `pushInstallations/${installationId}`,
    ),
    false,
  );

  assert.equal(
    firestore.has(
      `users/user-a/devices/${installationId}`,
    ),
    false,
  );
});

test("stale release cannot remove new owner", async () => {
  const firestore = new FakeFirestore({
    [`pushInstallations/${installationId}`]: {
      schemaVersion: 2,
      userId: "user-b",
      token: "token-b",
      platform: "android",
    },
    [`users/user-a/devices/${installationId}`]: {
      token: "stale-token-a",
      platform: "android",
    },
    [`users/user-b/devices/${installationId}`]: {
      token: "token-b",
      platform: "android",
    },
  });

  await releasePushInstallationOwnership(
    firestore,
    "user-a",
    {
      installationId,
    },
  );

  assert.equal(
    firestore.has(
      `users/user-a/devices/${installationId}`,
    ),
    false,
  );

  assert.equal(
    firestore.has(
      `users/user-b/devices/${installationId}`,
    ),
    true,
  );

  assert.equal(
    firestore.read(
      `pushInstallations/${installationId}`,
    ).userId,
    "user-b",
  );
});

test("release without registry cleans caller stale device", async () => {
  const firestore = new FakeFirestore({
    [`users/user-a/devices/${installationId}`]: {
      token: "stale-token-a",
      platform: "android",
    },
  });

  await releasePushInstallationOwnership(
    firestore,
    "user-a",
    {
      installationId,
    },
  );

  assert.equal(
    firestore.has(
      `users/user-a/devices/${installationId}`,
    ),
    false,
  );
});

test("legacy ownerUserId registry migrates to userId", async () => {
  const firestore = new FakeFirestore({
    [`pushInstallations/${installationId}`]: {
      schemaVersion: 1,
      ownerUserId: "user-a",
      token: "old-token",
      platform: "android",
    },
    [`users/user-a/devices/${installationId}`]: {
      token: "old-token",
      platform: "android",
    },
  });

  await claimPushInstallationOwnership(
    firestore,
    "user-a",
    {
      installationId,
      token: "new-token",
      platform: "android",
    },
  );

  const registry = firestore.read(
    `pushInstallations/${installationId}`,
  );

  assert.equal(
    registry.schemaVersion,
    2,
  );

  assert.equal(
    registry.userId,
    "user-a",
  );

  assert.equal(
    Object.prototype.hasOwnProperty.call(
      registry,
      "ownerUserId",
    ),
    false,
  );

  assert.equal(
    registry.token,
    "new-token",
  );
});