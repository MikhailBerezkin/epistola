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
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-vacation-period-rules-test';

const member = {
  uid: 'member-1',
  email: 'member1@example.com',
};

const secondMember = {
  uid: 'member-2',
  email: 'member2@example.com',
};

const brigadier = {
  uid: 'brigadier-1',
  email: 'brigadier1@example.com',
};

const owner = {
  uid: 'owner-1',
  email: 'owner1@example.com',
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
  await seedBaseline();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Vacation period rules', () => {
  test('allows signed-in member to read another user vacation', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDoc(
        vacationPeriodDoc(
          db,
          secondMember.uid,
          1,
        ),
      ),
    );
  });

  test('rejects unauthenticated vacation read', async () => {
    const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

    await assertFails(
      getDoc(
        vacationPeriodDoc(
          db,
          secondMember.uid,
          1,
        ),
      ),
    );
  });

  test('allows signed-in member to list vacation periods', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDocs(
        collection(
          db,
          'spaces',
          'calendar',
          'vacationPeriods',
        ),
      ),
    );
  });

  test('allows member to create own vacation period', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      setDoc(
        vacationPeriodDoc(db, member.uid, 6),
        vacationPeriodData({
          userId: member.uid,
          slot: 6,
          startDay: 20261005,
          endDay: 20261018,
        }),
      ),
    );
  });

  test('allows member to update own vacation period', async () => {
    await seedVacationPeriod({
      userId: member.uid,
      slot: 1,
      startDay: 20261005,
      endDay: 20261018,
    });

    const db = authenticatedFirestore(member);

    await assertSucceeds(
      updateDoc(
        vacationPeriodDoc(db, member.uid, 1),
        {
          startDay: 20261006,
          endDay: 20261019,
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('allows member to delete own vacation period', async () => {
    await seedVacationPeriod({
      userId: member.uid,
      slot: 1,
      startDay: 20261005,
      endDay: 20261018,
    });

    const db = authenticatedFirestore(member);

    await assertSucceeds(
      deleteDoc(
        vacationPeriodDoc(db, member.uid, 1),
      ),
    );
  });

  test('rejects member creating vacation for another user', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        vacationPeriodDoc(db, secondMember.uid, 2),
        vacationPeriodData({
          userId: secondMember.uid,
          slot: 2,
          startDay: 20261101,
          endDay: 20261110,
        }),
      ),
    );
  });

  test('rejects mismatched vacation document id', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        vacationPeriodDoc(db, member.uid, 1),
        vacationPeriodData({
          userId: member.uid,
          slot: 2,
          startDay: 20261005,
          endDay: 20261018,
        }),
      ),
    );
  });

  test('rejects seventh vacation slot', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        vacationPeriodDoc(db, member.uid, 7),
        vacationPeriodData({
          userId: member.uid,
          slot: 7,
          startDay: 20261005,
          endDay: 20261018,
        }),
      ),
    );
  });

  test('rejects reversed vacation range', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        vacationPeriodDoc(db, member.uid, 1),
        vacationPeriodData({
          userId: member.uid,
          slot: 1,
          startDay: 20261018,
          endDay: 20261005,
        }),
      ),
    );
  });

  test('rejects member updating another user vacation', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      updateDoc(
        vacationPeriodDoc(
          db,
          secondMember.uid,
          1,
        ),
        {
          endDay: 20261020,
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects member deleting another user vacation', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      deleteDoc(
        vacationPeriodDoc(
          db,
          secondMember.uid,
          1,
        ),
      ),
    );
  });

  test('allows brigadier to create vacation for substitution participant', async () => {
  const db = authenticatedFirestore(brigadier);

  await assertSucceeds(
    setDoc(
      vacationPeriodDoc(db, secondMember.uid, 2),
      vacationPeriodData({
        userId: secondMember.uid,
        slot: 2,
        startDay: 20261101,
        endDay: 20261110,
      }),
    ),
  );
});

test('allows brigadier to update and delete participant vacation', async () => {
  const db = authenticatedFirestore(brigadier);

  await assertSucceeds(
    updateDoc(
      vacationPeriodDoc(
        db,
        secondMember.uid,
        1,
      ),
      {
        startDay: 20261006,
        endDay: 20261020,
        updatedAt: serverTimestamp(),
      },
    ),
  );

  await assertSucceeds(
    deleteDoc(
      vacationPeriodDoc(
        db,
        secondMember.uid,
        1,
      ),
    ),
  );
});

test('allows owner to create vacation for substitution participant', async () => {
  const db = authenticatedFirestore(owner);

  await assertSucceeds(
    setDoc(
      vacationPeriodDoc(db, secondMember.uid, 3),
      vacationPeriodData({
        userId: secondMember.uid,
        slot: 3,
        startDay: 20261201,
        endDay: 20261214,
      }),
    ),
  );
});

test('rejects brigadier creating vacation for user outside substitution', async () => {
  const db = authenticatedFirestore(brigadier);

  await assertFails(
    setDoc(
      vacationPeriodDoc(db, member.uid, 2),
      vacationPeriodData({
        userId: member.uid,
        slot: 2,
        startDay: 20261101,
        endDay: 20261110,
      }),
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

function vacationPeriodDoc(db, userId, slot) {
  return doc(
    db,
    'spaces',
    'calendar',
    'vacationPeriods',
    `${userId}__${slot}`,
  );
}

function vacationPeriodData({
  userId,
  slot,
  startDay,
  endDay,
}) {
  return {
    schemaVersion: 1,
    userId,
    slot,
    startDay,
    endDay,
    updatedAt: serverTimestamp(),
  };
}

async function seedBaseline() {
  await seedVacationPeriod({
    userId: secondMember.uid,
    slot: 1,
    startDay: 20261005,
    endDay: 20261018,
  });

  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

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
          'spaces',
          'substitution',
          'participants',
          secondMember.uid,
        ),
        {
          rotationOrder: 1,
          availability: 'green',
          status: 'active',
        },
      );
    },
  );
}

async function seedVacationPeriod({
  userId,
  slot,
  startDay,
  endDay,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        vacationPeriodDoc(
          context.firestore(),
          userId,
          slot,
        ),
        {
          schemaVersion: 1,
          userId,
          slot,
          startDay,
          endDay,
          updatedAt: Timestamp.fromDate(
  new Date('2026-09-17T12:00:00.000Z'),
),
        },
      );
    },
  );
}
