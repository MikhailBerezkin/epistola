import {
  after,
  afterEach,
  before,
  beforeEach,
  describe,
  test,
} from 'node:test';

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-push-device-rules-test';

const userA = {
  uid: 'user-a',
  email: 'user-a@example.com',
};

const userB = {
  uid: 'user-b',
  email: 'user-b@example.com',
};

const deviceId = '0123456789abcdef0123456789abcdef';

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

beforeEach(async () => {
  await seedBaseline();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Push device rules', () => {
  test('allows user to read own device', async () => {
    const db = authenticatedFirestore(userA);

    await assertSucceeds(
      getDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          deviceId,
        ),
      ),
    );
  });

  test('allows user to list own devices', async () => {
    const db = authenticatedFirestore(userA);

    await assertSucceeds(
      getDocs(
        collection(
          db,
          'users',
          userA.uid,
          'devices',
        ),
      ),
    );
  });

  test('rejects user reading another users device', async () => {
    const db = authenticatedFirestore(userB);

    await assertFails(
      getDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          deviceId,
        ),
      ),
    );
  });

  test('rejects direct device create', async () => {
    const db = authenticatedFirestore(userA);

    await assertFails(
      setDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          'fedcba9876543210fedcba9876543210',
        ),
        {
          token: 'client-token',
          platform: 'android',
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects direct device update', async () => {
    const db = authenticatedFirestore(userA);

    await assertFails(
      updateDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          deviceId,
        ),
        {
          token: 'changed-token',
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects direct device delete', async () => {
    const db = authenticatedFirestore(userA);

    await assertFails(
      deleteDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          deviceId,
        ),
      ),
    );
  });
});

function authenticatedFirestore(user) {
  return testEnvironment
      .authenticatedContext(
        user.uid,
        {
          email: user.email,
        },
      )
      .firestore();
}

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(db, 'users', userA.uid),
        {
          uid: userA.uid,
          email: userA.email,
          name: 'User A',
          phone: '',
          about: '',
          avatarUrl: '',
        },
      );

      await setDoc(
        doc(db, 'users', userB.uid),
        {
          uid: userB.uid,
          email: userB.email,
          name: 'User B',
          phone: '',
          about: '',
          avatarUrl: '',
        },
      );

      await setDoc(
        doc(
          db,
          'users',
          userA.uid,
          'devices',
          deviceId,
        ),
        {
          token: 'server-created-token',
          platform: 'android',
          updatedAt: new Date(),
        },
      );
    },
  );
}