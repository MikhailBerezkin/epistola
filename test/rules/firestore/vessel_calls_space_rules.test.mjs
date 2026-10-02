import {
  after,
  afterEach,
  before,
  beforeEach,
  describe,
  test,
} from 'node:test';
import assert from 'node:assert/strict';

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
  'epistola-vessel-calls-space-rules-test';

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
  await seedVesselCallsDocuments();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Vessel calls space rules', () => {
  test(
    'allows signed-in user to read month metadata',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthMeta',
            '2026-10',
          ),
        ),
      );
    },
  );

  test(
    'allows signed-in user to read current month snapshot',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthSnapshots',
            '2026-10',
          ),
        ),
      );
    },
  );

  test(
    'allows signed-in user to read archived month snapshot',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthArchives',
            '2026-09',
          ),
        ),
      );
    },
  );

  test(
    'rejects unauthenticated month metadata read',
    async () => {
      const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

      await assertFails(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthMeta',
            '2026-10',
          ),
        ),
      );
    },
  );

  test(
    'rejects unauthenticated current month snapshot read',
    async () => {
      const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

      await assertFails(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthSnapshots',
            '2026-10',
          ),
        ),
      );
    },
  );

  test(
    'rejects unauthenticated archived month read',
    async () => {
      const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

      await assertFails(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthArchives',
            '2026-09',
          ),
        ),
      );
    },
  );

  test(
    'rejects signed-in user creating month metadata',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        setDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthMeta',
            '2026-11',
          ),
          {
            revision: 1,
          },
        ),
      );
    },
  );

  test(
    'rejects signed-in user updating current month snapshot',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthSnapshots',
            '2026-10',
          ),
          {
            revision: 99,
          },
        ),
      );
    },
  );

  test(
    'rejects signed-in user deleting archived month',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        deleteDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
            'monthArchives',
            '2026-09',
          ),
        ),
      );
    },
  );

  test(
    'rejects signed-in user reading vessel calls module document',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        getDoc(
          doc(
            db,
            'spaces',
            'vesselCalls',
          ),
        ),
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

async function seedVesselCallsDocuments() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'monthMeta',
          '2026-10',
        ),
        {
          revision: 1,
        },
      );

      await setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'monthSnapshots',
          '2026-10',
        ),
        {
          year: 2026,
          month: 10,
          revision: 1,
          calls: [],
          isArchived: false,
        },
      );

      await setDoc(
        doc(
          db,
          'spaces',
          'vesselCalls',
          'monthArchives',
          '2026-09',
        ),
        {
          year: 2026,
          month: 9,
          revision: 1,
          calls: [],
          isArchived: true,
        },
      );
    },
  );
}