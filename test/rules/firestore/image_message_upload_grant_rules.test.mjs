import {
  after,
  afterEach,
  before,
  describe,
  test,
} from 'node:test';

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-434b7';
const grantDocumentId = 'grant-message-1';

const sender = {
  uid: 'user-1',
  email: 'sender@example.com',
};

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: testProjectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(projectRoot, 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Image message upload grant Firestore security', () => {
  test(
    'rejects an authenticated client creating a grant',
    async () => {
      const database = authenticatedDatabase();

      const result = setDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
        validGrantData(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an unauthenticated client creating a grant',
    async () => {
      const database =
          testEnvironment.unauthenticatedContext().firestore();

      const result = setDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
        validGrantData(),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an authenticated client reading a grant',
    async () => {
      await seedGrant();

      const database = authenticatedDatabase();

      const result = getDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an authenticated client listing grants',
    async () => {
      await seedGrant();

      const database = authenticatedDatabase();

      const result = getDocs(
        collection(
          database,
          'imageMessageUploadGrants',
        ),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an authenticated client updating a grant',
    async () => {
      await seedGrant();

      const database = authenticatedDatabase();

      const result = updateDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
        {
          expiresAt:
              new Date(Date.now() + (10 * 60 * 1000)),
        },
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an authenticated client deleting a grant',
    async () => {
      await seedGrant();

      const database = authenticatedDatabase();

      const result = deleteDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
      );

      await assertFails(result);
    },
  );
});

async function seedGrant() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'imageMessageUploadGrants',
          grantDocumentId,
        ),
        validGrantData(),
      );
    },
  );
}

function authenticatedDatabase() {
  return testEnvironment.authenticatedContext(
    sender.uid,
    {
      email: sender.email,
    },
  ).firestore();
}

function validGrantData() {
  const createdAt = new Date(Date.now() - 1000);

  return {
    grantType: 'first_private_image',
    uploaderId: sender.uid,
    peerId: 'user-2',
    chatId: 'user-1_user-2',
    messageId: grantDocumentId,
    version: 'v1',
    createdAt,
    expiresAt:
        new Date(createdAt.getTime() + (5 * 60 * 1000)),
  };
}