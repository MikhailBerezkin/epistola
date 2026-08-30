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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'epistola-substitution-test-statistics-rules-test';

const owner = {
  uid: 'owner-1',
  email: 'owner@example.com',
};

const member = {
  uid: 'member-1',
  email: 'member@example.com',
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

beforeEach(async () => {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        statisticsDoc(context.firestore()),
        {
          callCounts: {
            [member.uid]: 3,
          },
        },
      );
    },
  );
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Substitution TEST statistics rules', () => {
  test(
    'allows signed-in member to read test statistics',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        getDoc(statisticsDoc(db)),
      );
    },
  );

  test(
    'rejects unauthenticated test statistics read',
    async () => {
      const db = testEnvironment
          .unauthenticatedContext()
          .firestore();

      await assertFails(
        getDoc(statisticsDoc(db)),
      );
    },
  );

  test(
    'rejects statistics collection list',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        getDocs(
          collection(
            db,
            'spaces',
            'substitution',
            'statistics',
          ),
        ),
      );
    },
  );

  test(
    'rejects direct statistics update even for owner',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertFails(
        updateDoc(
          statisticsDoc(db),
          {
            callCounts: {
              [member.uid]: 4,
            },
          },
        ),
      );
    },
  );

  test(
    'rejects statistics delete even for owner',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertFails(
        deleteDoc(statisticsDoc(db)),
      );
    },
  );
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

function statisticsDoc(db) {
  return doc(
    db,
    'spaces',
    'substitution',
    'statistics',
    'test',
  );
}