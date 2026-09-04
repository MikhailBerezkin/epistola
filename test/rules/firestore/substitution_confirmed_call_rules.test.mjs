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
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const projectId =
    'epistola-substitution-confirmed-call-rules-test';

const owner = {
  uid: 'owner-1',
  email: 'owner@example.com',
};

const brigadier = {
  uid: 'brigadier-1',
  email: 'brigadier@example.com',
};

const member = {
  uid: 'member-1',
  email: 'member@example.com',
};

const secondMember = {
  uid: 'member-2',
  email: 'member2@example.com',
};

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(projectRoot, 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await seedAccess();

  await seedConfirmedCall({
    callId: '1',
    revision: 1,
    userId: member.uid,
  });

  await seedConfirmedCall({
    callId: '2',
    revision: 2,
    userId: secondMember.uid,
  });
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Substitution confirmed-call rules', () => {
  test(
    'allows called member to read own confirmed call',
    async () => {
      const db = authenticatedFirestore(member);

      const snapshot = await assertSucceeds(
        getDoc(
          confirmedCallDoc(db, '1'),
        ),
      );

      assert.equal(snapshot.exists(), true);
      assert.equal(
        snapshot.data().userId,
        member.uid,
      );
    },
  );

  test(
    'rejects another member reading confirmed call',
    async () => {
      const db = authenticatedFirestore(secondMember);

      await assertFails(
        getDoc(
          confirmedCallDoc(db, '1'),
        ),
      );
    },
  );

  test(
    'rejects brigadier reading member confirmed call',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        getDoc(
          confirmedCallDoc(db, '1'),
        ),
      );
    },
  );

  test(
    'rejects unauthenticated confirmed call read',
    async () => {
      const db = testEnvironment
          .unauthenticatedContext()
          .firestore();

      await assertFails(
        getDoc(
          confirmedCallDoc(db, '1'),
        ),
      );
    },
  );

  test(
    'allows member to list only own confirmed calls',
    async () => {
      const db = authenticatedFirestore(member);

      const snapshot = await assertSucceeds(
        getDocs(
          query(
            confirmedCallsCollection(db),
            where(
              'userId',
              '==',
              member.uid,
            ),
          ),
        ),
      );

      assert.equal(snapshot.size, 1);

      const confirmed = snapshot.docs[0].data();

      assert.equal(
        confirmed.userId,
        member.uid,
      );

      assert.equal(
        confirmed.callId,
        '1',
      );
    },
  );

  test(
    'rejects unfiltered confirmed call list',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        getDocs(
          confirmedCallsCollection(db),
        ),
      );
    },
  );

  test(
    'rejects standalone confirmed call creation',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        setDoc(
          confirmedCallDoc(db, '3'),
          confirmedCallData({
            callId: '3',
            revision: 3,
            userId: member.uid,
            calledByUserId: brigadier.uid,
            calledAt:
                new Date(Date.now() - 10_000),
            finalizedAt: serverTimestamp(),
          }),
        ),
      );
    },
  );

  test(
    'rejects called member updating confirmed call',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          confirmedCallDoc(db, '1'),
          {
            shiftKind: 'day',
          },
        ),
      );
    },
  );

  test(
    'rejects called member deleting confirmed call',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        deleteDoc(
          confirmedCallDoc(db, '1'),
        ),
      );
    },
  );

  test(
    'rejects brigadier deleting confirmed call',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        deleteDoc(
          confirmedCallDoc(db, '1'),
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

function confirmedCallsCollection(db) {
  return collection(
    db,
    'spaces',
    'substitution',
    'confirmedCalls',
  );
}

function confirmedCallDoc(db, callId) {
  return doc(
    db,
    'spaces',
    'substitution',
    'confirmedCalls',
    callId,
  );
}

function confirmedCallData({
  callId,
  revision,
  userId,
  calledByUserId,
  calledAt,
  finalizedAt,
  shiftYear = 2026,
  shiftMonth = 9,
  shiftDay = 4,
  shiftKind = 'night',
}) {
  return {
    schemaVersion: 1,
    callId,
    userId,
    revision,
    calledByUserId,
    calledAt,
    finalizedAt,
    shiftYear,
    shiftMonth,
    shiftDay,
    shiftKind,
  };
}

async function seedConfirmedCall({
  callId,
  revision,
  userId,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      const calledAt =
          new Date(Date.now() - 20_000);

      const finalizedAt =
          new Date(Date.now() - 10_000);

      await setDoc(
        confirmedCallDoc(
          db,
          callId,
        ),
        confirmedCallData({
          callId,
          revision,
          userId,
          calledByUserId: brigadier.uid,
          calledAt,
          finalizedAt,
        }),
      );
    },
  );
}

async function seedAccess() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(
          db,
          'spaces_access',
          owner.uid,
        ),
        {
          role: 'owner',
        },
      );

      await setDoc(
        doc(
          db,
          'spaces_access',
          brigadier.uid,
        ),
        {
          role: 'brigadier',
        },
      );
    },
  );
}