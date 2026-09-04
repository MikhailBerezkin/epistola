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
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const projectId =
    'epistola-substitution-finalize-rules-test';

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
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Substitution confirmed-call finalize rules', () => {
  test(
    'allows brigadier to finalize expired pending call',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        calledAt,
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      addFirstFinalizeWrites({
        batch,
        db,
        calledAt,
      });

      await assertSucceeds(batch.commit());

      const statisticsSnapshot = await assertSucceeds(
        getDoc(
          statisticsDoc(db, 2026),
        ),
      );

      assert.equal(statisticsSnapshot.exists(), true);

      const statistics = statisticsSnapshot.data();

      assert.equal(statistics.year, 2026);

      assert.equal(
        statistics.monthCallCounts['8'][member.uid],
        1,
      );

      assert.deepEqual(
        statistics.monthShifts['8'][member.uid],
        ['night'],
      );

      assert.equal(
        statistics.yearCallCounts[member.uid],
        1,
      );

      assert.equal(
        statistics.lastFinalizedCallId,
        '1',
      );

      const memberDb = authenticatedFirestore(member);

const confirmedSnapshot = await assertSucceeds(
  getDoc(
    confirmedCallDoc(memberDb, '1'),
  ),
);

      assert.equal(
        confirmedSnapshot.exists(),
        true,
      );

      const confirmed = confirmedSnapshot.data();

      assert.equal(confirmed.schemaVersion, 1);
      assert.equal(confirmed.callId, '1');
      assert.equal(confirmed.userId, member.uid);
      assert.equal(confirmed.revision, 1);

      assert.equal(
        confirmed.calledByUserId,
        brigadier.uid,
      );

      assert.equal(
        confirmed.calledAt.toMillis(),
        calledAt.getTime(),
      );

      assert.equal(confirmed.shiftYear, 2026);
      assert.equal(confirmed.shiftMonth, 8);
      assert.equal(confirmed.shiftDay, 31);
      assert.equal(confirmed.shiftKind, 'night');

      const pendingSnapshot = await assertSucceeds(
        getDoc(
          pendingCallDoc(db, '1'),
        ),
      );

      assert.equal(pendingSnapshot.exists(), false);
    },
  );

  test(
    'rejects finalize before six second window expires',
    async () => {
      const calledAt =
          new Date(Date.now() - 1_000);

      await seedPendingCall({
        calledAt,
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      addFirstFinalizeWrites({
        batch,
        db,
        calledAt,
      });

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects statistics and confirmed call without deleting pending call',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        calledAt,
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.set(
        statisticsDoc(db, 2026),
        firstStatisticsData(),
      );

      batch.set(
        confirmedCallDoc(db, '1'),
        confirmedCallData({
          calledAt,
        }),
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects deleting expired pending call without statistics write',
    async () => {
      await seedPendingCall({
        calledAt:
            new Date(Date.now() - 10_000),
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.delete(
        pendingCallDoc(db, '1'),
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects ordinary member finalizing pending call',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        calledAt,
      });

      const db = authenticatedFirestore(member);
      const batch = writeBatch(db);

      addFirstFinalizeWrites({
        batch,
        db,
        calledAt,
      });

      await assertFails(batch.commit());
    },
  );

  test(
    'allows existing yearly statistics to increment exactly once',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        callId: '2',
        revision: 2,
        calledAt,
        shiftKind: 'day',
      });

      await seedStatistics({
        year: 2026,
        data: {
          year: 2026,
          monthCallCounts: {
            '8': {
              [member.uid]: 1,
            },
          },
          monthShifts: {
            '8': {
              [member.uid]: ['night'],
            },
          },
          yearCallCounts: {
            [member.uid]: 1,
          },
          lastFinalizedCallId: '1',
          updatedAt:
              new Date(Date.now() - 20_000),
        },
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.set(
        statisticsDoc(db, 2026),
        {
          year: 2026,
          monthCallCounts: {
            '8': {
              [member.uid]: 2,
            },
          },
          monthShifts: {
            '8': {
              [member.uid]: [
                'night',
                'day',
              ],
            },
          },
          yearCallCounts: {
            [member.uid]: 2,
          },
          lastFinalizedCallId: '2',
          updatedAt: serverTimestamp(),
        },
      );

      batch.set(
        confirmedCallDoc(db, '2'),
        confirmedCallData({
          callId: '2',
          revision: 2,
          calledAt,
          shiftKind: 'day',
        }),
      );

      batch.delete(
        pendingCallDoc(db, '2'),
      );

      await assertSucceeds(batch.commit());

      const snapshot = await assertSucceeds(
        getDoc(
          statisticsDoc(db, 2026),
        ),
      );

      const statistics = snapshot.data();

      assert.equal(
        statistics.monthCallCounts['8'][member.uid],
        2,
      );

      assert.deepEqual(
        statistics.monthShifts['8'][member.uid],
        [
          'night',
          'day',
        ],
      );

      assert.equal(
        statistics.yearCallCounts[member.uid],
        2,
      );
    },
  );

  test(
    'rejects changing another participant statistics during finalize',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        callId: '2',
        revision: 2,
        calledAt,
        shiftKind: 'day',
      });

      await seedStatistics({
        year: 2026,
        data: {
          year: 2026,
          monthCallCounts: {
            '8': {
              [member.uid]: 1,
              [secondMember.uid]: 1,
            },
          },
          monthShifts: {
            '8': {
              [member.uid]: ['night'],
              [secondMember.uid]: ['day'],
            },
          },
          yearCallCounts: {
            [member.uid]: 1,
            [secondMember.uid]: 1,
          },
          lastFinalizedCallId: '1',
          updatedAt:
              new Date(Date.now() - 20_000),
        },
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.set(
        statisticsDoc(db, 2026),
        {
          year: 2026,
          monthCallCounts: {
            '8': {
              [member.uid]: 2,
              [secondMember.uid]: 2,
            },
          },
          monthShifts: {
            '8': {
              [member.uid]: [
                'night',
                'day',
              ],
              [secondMember.uid]: [
                'day',
                'night',
              ],
            },
          },
          yearCallCounts: {
            [member.uid]: 2,
            [secondMember.uid]: 2,
          },
          lastFinalizedCallId: '2',
          updatedAt: serverTimestamp(),
        },
      );

      batch.set(
        confirmedCallDoc(db, '2'),
        confirmedCallData({
          callId: '2',
          revision: 2,
          calledAt,
          shiftKind: 'day',
        }),
      );

      batch.delete(
        pendingCallDoc(db, '2'),
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects second finalize attempt for same call',
    async () => {
      const calledAt =
          new Date(Date.now() - 10_000);

      await seedPendingCall({
        calledAt,
      });

      const db = authenticatedFirestore(brigadier);

      const firstBatch = writeBatch(db);

      addFirstFinalizeWrites({
        batch: firstBatch,
        db,
        calledAt,
      });

      await assertSucceeds(firstBatch.commit());

      const secondBatch = writeBatch(db);

      secondBatch.set(
        statisticsDoc(db, 2026),
        {
          year: 2026,
          monthCallCounts: {
            '8': {
              [member.uid]: 2,
            },
          },
          monthShifts: {
            '8': {
              [member.uid]: [
                'night',
                'night',
              ],
            },
          },
          yearCallCounts: {
            [member.uid]: 2,
          },
          lastFinalizedCallId: '1',
          updatedAt: serverTimestamp(),
        },
      );

      secondBatch.delete(
        pendingCallDoc(db, '1'),
      );

      await assertFails(secondBatch.commit());
    },
  );

  test(
    'rejects writing statistics into wrong yearly document',
    async () => {
      await seedPendingCall({
        calledAt:
            new Date(Date.now() - 10_000),
      });

      const db = authenticatedFirestore(owner);
      const batch = writeBatch(db);

      batch.set(
        statisticsDoc(db, 2027),
        {
          ...firstStatisticsData(),
          year: 2027,
        },
      );

      batch.delete(
        pendingCallDoc(db, '1'),
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'allows brigadier to list pending calls',
    async () => {
      await seedPendingCall({
        calledAt:
            new Date(Date.now() - 10_000),
      });

      const db = authenticatedFirestore(brigadier);

      const snapshot = await assertSucceeds(
        getDocs(
          collection(
            db,
            'spaces',
            'substitution',
            'pendingCalls',
          ),
        ),
      );

      assert.equal(snapshot.size, 1);
    },
  );

  test(
    'rejects ordinary member listing pending calls',
    async () => {
      await seedPendingCall({
        calledAt:
            new Date(Date.now() - 10_000),
      });

      const db = authenticatedFirestore(member);

      await assertFails(
        getDocs(
          collection(
            db,
            'spaces',
            'substitution',
            'pendingCalls',
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

function pendingCallDoc(db, callId) {
  return doc(
    db,
    'spaces',
    'substitution',
    'pendingCalls',
    callId,
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

function statisticsDoc(db, year) {
  return doc(
    db,
    'spaces',
    'substitution',
    'statistics',
    `year_${year}`,
  );
}

function firstStatisticsData() {
  return {
    year: 2026,
    monthCallCounts: {
      '8': {
        [member.uid]: 1,
      },
    },
    monthShifts: {
      '8': {
        [member.uid]: ['night'],
      },
    },
    yearCallCounts: {
      [member.uid]: 1,
    },
    lastFinalizedCallId: '1',
    updatedAt: serverTimestamp(),
  };
}

function confirmedCallData({
  callId = '1',
  revision = 1,
  calledAt,
  userId = member.uid,
  calledByUserId = brigadier.uid,
  shiftYear = 2026,
  shiftMonth = 8,
  shiftDay = 31,
  shiftKind = 'night',
}) {
  return {
    schemaVersion: 1,
    callId,
    userId,
    revision,
    calledByUserId,
    calledAt,
    finalizedAt: serverTimestamp(),
    shiftYear,
    shiftMonth,
    shiftDay,
    shiftKind,
  };
}

function addFirstFinalizeWrites({
  batch,
  db,
  calledAt,
}) {
  batch.set(
    statisticsDoc(db, 2026),
    firstStatisticsData(),
  );

  batch.set(
    confirmedCallDoc(db, '1'),
    confirmedCallData({
      calledAt,
    }),
  );

  batch.delete(
    pendingCallDoc(db, '1'),
  );
}

async function seedPendingCall({
  callId = '1',
  revision = 1,
  calledAt,
  userId = member.uid,
  calledByUserId = brigadier.uid,
  shiftYear = 2026,
  shiftMonth = 8,
  shiftDay = 31,
  shiftKind = 'night',
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        pendingCallDoc(
          context.firestore(),
          callId,
        ),
        {
          callId,
          userId,
          revision,
          calledByUserId,
          calledAt,
          shiftYear,
          shiftMonth,
          shiftDay,
          shiftKind,
        },
      );
    },
  );
}

async function seedStatistics({
  year,
  data,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        statisticsDoc(
          context.firestore(),
          year,
        ),
        data,
      );
    },
  );
}

async function seedAccess() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(db, 'spaces_access', owner.uid),
        {
          role: 'owner',
        },
      );

      await setDoc(
        doc(db, 'spaces_access', brigadier.uid),
        {
          role: 'brigadier',
        },
      );
    },
  );
}