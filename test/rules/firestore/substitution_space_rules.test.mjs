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
  deleteField,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'epistola-substitution-space-rules-test';

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

const candidate = {
  uid: 'candidate-1',
  email: 'candidate@example.com',
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

describe('Substitution space rules', () => {
  test(
    'allows signed-in member to list participants',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        getDocs(
          collection(
            db,
            'spaces',
            'substitution',
            'participants',
          ),
        ),
      );
    },
  );

  test(
    'rejects unauthenticated participant list',
    async () => {
      const db = testEnvironment
          .unauthenticatedContext()
          .firestore();

      await assertFails(
        getDocs(
          collection(
            db,
            'spaces',
            'substitution',
            'participants',
          ),
        ),
      );
    },
  );

  test(
    'allows owner to read substitution module',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertSucceeds(
        getDoc(
          doc(db, 'spaces', 'substitution'),
        ),
      );
    },
  );

  test(
    'rejects ordinary member reading substitution module',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        getDoc(
          doc(db, 'spaces', 'substitution'),
        ),
      );
    },
  );

  test(
    'allows owner to create initial substitution module',
    async () => {
      await deleteModuleWithoutRules();

      const db = authenticatedFirestore(owner);

      await assertSucceeds(
        setDoc(
          doc(db, 'spaces', 'substitution'),
          {
            nextRotationOrder: 1,
          },
        ),
      );
    },
  );

  test(
    'rejects member creating substitution module',
    async () => {
      await deleteModuleWithoutRules();

      const db = authenticatedFirestore(member);

      await assertFails(
        setDoc(
          doc(db, 'spaces', 'substitution'),
          {
            nextRotationOrder: 1,
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to advance next rotation order',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertSucceeds(
        updateDoc(
          doc(db, 'spaces', 'substitution'),
          {
            nextRotationOrder: 3,
          },
        ),
      );
    },
  );

  test(
    'rejects decreasing next rotation order',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertFails(
        updateDoc(
          doc(db, 'spaces', 'substitution'),
          {
            nextRotationOrder: 1,
          },
        ),
      );
    },
  );

  test(
    'allows owner to add green active participant',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertSucceeds(
        setDoc(
          participantDoc(db, candidate.uid),
          {
            rotationOrder: 2,
            availability: 'green',
            status: 'active',
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to add green active participant',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertSucceeds(
        setDoc(
          participantDoc(db, candidate.uid),
          {
            rotationOrder: 2,
            availability: 'green',
            status: 'active',
          },
        ),
      );
    },
  );

  test(
    'rejects ordinary member adding participant',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        setDoc(
          participantDoc(db, candidate.uid),
          {
            rotationOrder: 2,
            availability: 'green',
            status: 'active',
          },
        ),
      );
    },
  );

  test(
    'rejects creating participant with non-green availability',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        setDoc(
          participantDoc(db, candidate.uid),
          {
            rotationOrder: 2,
            availability: 'yellow',
            status: 'active',
          },
        ),
      );
    },
  );

  test(
    'allows member to change own availability',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
        updateDoc(
          participantDoc(db, member.uid),
          {
            availability: 'yellow',
          },
        ),
      );
    },
  );

    test(
    'rejects member moving self to vacation',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            status: 'vacation',
          },
        ),
      );
    },
  );

  test(
    'rejects member returning self to active',
    async () => {
      await setParticipantStatusWithoutRules({
        userId: member.uid,
        status: 'sick',
      });

      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            status: 'active',
          },
        ),
      );
    },
  );

  test(
    'rejects member changing own rotation order',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            rotationOrder: 99,
          },
        ),
      );
    },
  );

  test(
    'rejects member changing another participant',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          participantDoc(db, secondMember.uid),
          {
            status: 'vacation',
          },
        ),
      );
    },
  );

  test(
    'rejects brigadier changing another participant availability',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            availability: 'red',
          },
        ),
      );
    },
  );

  test(
    'rejects owner changing another participant availability',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            availability: 'yellow',
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to change own availability when participating',
    async () => {
      await testEnvironment.withSecurityRulesDisabled(
        async (context) => {
          await setDoc(
            participantDoc(
              context.firestore(),
              brigadier.uid,
            ),
            {
              rotationOrder: 10,
              availability: 'green',
              status: 'active',
            },
          );
        },
      );

      const db = authenticatedFirestore(brigadier);

      await assertSucceeds(
        updateDoc(
          participantDoc(db, brigadier.uid),
          {
            availability: 'yellow',
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to change participant status',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertSucceeds(
        updateDoc(
          participantDoc(db, member.uid),
          {
            status: 'sick',
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to change participant work display name',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertSucceeds(
        updateDoc(
          doc(db, 'users', member.uid),
          {
            workDisplayName: 'Михаил',
          },
        ),
      );
    },
  );

  test(
    'allows owner to change participant work display name',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertSucceeds(
        updateDoc(
          doc(db, 'users', secondMember.uid),
          {
            workDisplayName: 'Александр',
          },
        ),
      );
    },
  );

  test(
    'rejects member changing another participant work display name',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        updateDoc(
          doc(db, 'users', secondMember.uid),
          {
            workDisplayName: 'Чужое имя',
          },
        ),
      );
    },
  );

  test(
    'rejects brigadier changing unrelated participant user fields',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        updateDoc(
          doc(db, 'users', member.uid),
          {
            phone: '+79999999999',
          },
        ),
      );
    },
  );

  test(
    'rejects brigadier changing work display name outside substitution',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        updateDoc(
          doc(db, 'users', candidate.uid),
          {
            workDisplayName: 'Кандидат',
          },
        ),
      );
    },
  );

  test(
    'allows owner to remove participant',
    async () => {
      const db = authenticatedFirestore(owner);

      await assertSucceeds(
        deleteDoc(
          participantDoc(db, member.uid),
        ),
      );
    },
  );

  test(
    'rejects member removing participant',
    async () => {
      const db = authenticatedFirestore(member);

      await assertFails(
        deleteDoc(
          participantDoc(db, secondMember.uid),
        ),
      );
    },
  );

  test(
    'allows brigadier to atomically call active participant with pending call',
    async () => {
      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      addCallWrites({
        batch,
        db,
        calledByUserId: brigadier.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertSucceeds(batch.commit());

      const pendingSnapshot = await assertSucceeds(
        getDoc(
          pendingCallDoc(db, '1'),
        ),
      );

      assert.equal(pendingSnapshot.exists(), true);

      const pendingData = pendingSnapshot.data();

      assert.equal(pendingData.callId, '1');
      assert.equal(pendingData.userId, member.uid);
      assert.equal(pendingData.revision, 1);
      assert.equal(
        pendingData.calledByUserId,
        brigadier.uid,
      );
    },
  );

  test(
    'allows owner to atomically call active participant with pending call',
    async () => {
      const db = authenticatedFirestore(owner);
      const batch = writeBatch(db);

      addCallWrites({
        batch,
        db,
        calledByUserId: owner.uid,
        participantUserId: secondMember.uid,
        previousRotationOrder: 1,
      });

      await assertSucceeds(batch.commit());

      const pendingSnapshot = await assertSucceeds(
        getDoc(
          pendingCallDoc(db, '1'),
        ),
      );

      assert.equal(pendingSnapshot.exists(), true);
      assert.equal(
        pendingSnapshot.data().calledByUserId,
        owner.uid,
      );
    },
  );

  test(
    'rejects call without pending call document',
    async () => {
      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      batch.update(
        doc(db, 'spaces', 'substitution'),
        {
          nextRotationOrder: 3,
          revision: 1,
          lastCall: {
            userId: member.uid,
            previousRotationOrder: 0,
            revision: 1,
          },
        },
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects standalone pending call creation',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        setDoc(
          pendingCallDoc(db, '1'),
          {
            callId: '1',
            userId: member.uid,
            revision: 1,
            calledByUserId: brigadier.uid,
            calledAt: serverTimestamp(),
            shiftYear: 2026,
shiftMonth: 8,
shiftDay: 31,
shiftKind: 'night',
          },
        ),
      );
    },
  );

  test(
    'rejects forged pending calledAt',
    async () => {
      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      batch.update(
        doc(db, 'spaces', 'substitution'),
        {
          nextRotationOrder: 3,
          revision: 1,
          lastCall: {
            userId: member.uid,
            previousRotationOrder: 0,
            revision: 1,
          },
        },
      );

      batch.set(
        pendingCallDoc(db, '1'),
        {
          callId: '1',
          userId: member.uid,
          revision: 1,
          calledByUserId: brigadier.uid,
          calledAt: new Date(0),
          shiftYear: 2026,
shiftMonth: 8,
shiftDay: 31,
shiftKind: 'night',
        },
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects ordinary member calling participant',
    async () => {
      const db = authenticatedFirestore(member);
      const batch = writeBatch(db);

      addCallWrites({
        batch,
        db,
        calledByUserId: member.uid,
        participantUserId: secondMember.uid,
        previousRotationOrder: 1,
      });

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects calling inactive participant',
    async () => {
      await setParticipantStatusWithoutRules({
        userId: member.uid,
        status: 'vacation',
      });

      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      addCallWrites({
        batch,
        db,
        calledByUserId: brigadier.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects call module update without participant rotation update',
    async () => {
      const db = authenticatedFirestore(brigadier);
      const batch = writeBatch(db);

      batch.update(
        doc(db, 'spaces', 'substitution'),
        {
          nextRotationOrder: 3,
          revision: 1,
          lastCall: {
            userId: member.uid,
            previousRotationOrder: 0,
            revision: 1,
          },
        },
      );

      batch.set(
        pendingCallDoc(db, '1'),
        {
          callId: '1',
          userId: member.uid,
          revision: 1,
          calledByUserId: brigadier.uid,
          calledAt: serverTimestamp(),
          shiftYear: 2026,
shiftMonth: 8,
shiftDay: 31,
shiftKind: 'night',
        },
      );

      await assertFails(batch.commit());
    },
  );

  test(
    'rejects participant rotation update without call module update',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        updateDoc(
          participantDoc(db, member.uid),
          {
            rotationOrder: 2,
          },
        ),
      );
    },
  );

  test(
    'allows brigadier to undo latest call and delete pending atomically',
    async () => {
      const db = authenticatedFirestore(brigadier);

      const callBatch = writeBatch(db);

      addCallWrites({
        batch: callBatch,
        db,
        calledByUserId: brigadier.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertSucceeds(callBatch.commit());

      const undoBatch = writeBatch(db);

      addUndoWrites({
        batch: undoBatch,
        db,
        participantUserId: member.uid,
        restoredRotationOrder: 0,
        callId: '1',
      });

      await assertSucceeds(undoBatch.commit());

      const moduleSnapshot = await assertSucceeds(
        getDoc(
          doc(db, 'spaces', 'substitution'),
        ),
      );

      const moduleData = moduleSnapshot.data();

      assert.equal(
        moduleData.nextRotationOrder,
        3,
      );

      assert.equal(
        moduleData.revision,
        1,
      );

      assert.equal(
        Object.hasOwn(moduleData, 'lastCall'),
        false,
      );

      const participantSnapshot = await assertSucceeds(
        getDoc(
          participantDoc(db, member.uid),
        ),
      );

      assert.equal(
        participantSnapshot.data().rotationOrder,
        0,
      );

      const pendingSnapshot = await assertSucceeds(
        getDoc(
          pendingCallDoc(db, '1'),
        ),
      );

      assert.equal(
        pendingSnapshot.exists(),
        false,
      );
    },
  );

  test(
    'rejects undo without deleting pending call',
    async () => {
      const db = authenticatedFirestore(brigadier);

      const callBatch = writeBatch(db);

      addCallWrites({
        batch: callBatch,
        db,
        calledByUserId: brigadier.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertSucceeds(callBatch.commit());

      const undoBatch = writeBatch(db);

      undoBatch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 0,
        },
      );

      undoBatch.update(
        doc(db, 'spaces', 'substitution'),
        {
          lastCall: deleteField(),
        },
      );

      await assertFails(undoBatch.commit());
    },
  );

  test(
    'rejects undo with wrong previous rotation order',
    async () => {
      const db = authenticatedFirestore(owner);

      const callBatch = writeBatch(db);

      addCallWrites({
        batch: callBatch,
        db,
        calledByUserId: owner.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertSucceeds(callBatch.commit());

      const undoBatch = writeBatch(db);

      addUndoWrites({
        batch: undoBatch,
        db,
        participantUserId: member.uid,
        restoredRotationOrder: 1,
        callId: '1',
      });

      await assertFails(undoBatch.commit());
    },
  );

  test(
    'rejects deleting lastCall without restoring participant rotation',
    async () => {
      const db = authenticatedFirestore(brigadier);

      const callBatch = writeBatch(db);

      addCallWrites({
        batch: callBatch,
        db,
        calledByUserId: brigadier.uid,
        participantUserId: member.uid,
        previousRotationOrder: 0,
      });

      await assertSucceeds(callBatch.commit());

      const undoBatch = writeBatch(db);

      undoBatch.update(
        doc(db, 'spaces', 'substitution'),
        {
          lastCall: deleteField(),
        },
      );

      undoBatch.delete(
        pendingCallDoc(db, '1'),
      );

      await assertFails(undoBatch.commit());
    },
  );

  test(
    'rejects undo after six second window has expired',
    async () => {
      await seedCalledStateWithoutRules({
        calledAt: new Date(
          Date.now() - 10_000,
        ),
      });

      const db = authenticatedFirestore(brigadier);
      const undoBatch = writeBatch(db);

      addUndoWrites({
        batch: undoBatch,
        db,
        participantUserId: member.uid,
        restoredRotationOrder: 0,
        callId: '1',
      });

      await assertFails(undoBatch.commit());
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

function participantDoc(db, userId) {
  return doc(
    db,
    'spaces',
    'substitution',
    'participants',
    userId,
  );
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

function addCallWrites({
  batch,
  db,
  calledByUserId,
  participantUserId,
  previousRotationOrder,
}) {
  batch.update(
    participantDoc(db, participantUserId),
    {
      rotationOrder: 2,
    },
  );

  batch.update(
    doc(db, 'spaces', 'substitution'),
    {
      nextRotationOrder: 3,
      revision: 1,
      lastCall: {
        userId: participantUserId,
        previousRotationOrder,
        revision: 1,
      },
    },
  );

  batch.set(
    pendingCallDoc(db, '1'),
    {
      callId: '1',
      userId: participantUserId,
      revision: 1,
      calledByUserId,
      calledAt: serverTimestamp(),
      shiftYear: 2026,
shiftMonth: 8,
shiftDay: 31,
shiftKind: 'night',
    },
  );
}

function addUndoWrites({
  batch,
  db,
  participantUserId,
  restoredRotationOrder,
  callId,
}) {
  batch.update(
    participantDoc(db, participantUserId),
    {
      rotationOrder: restoredRotationOrder,
    },
  );

  batch.update(
    doc(db, 'spaces', 'substitution'),
    {
      lastCall: deleteField(),
    },
  );

  batch.delete(
    pendingCallDoc(db, callId),
  );
}

async function deleteModuleWithoutRules() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await deleteDoc(
        doc(
          context.firestore(),
          'spaces',
          'substitution',
        ),
      );
    },
  );
}

async function setParticipantStatusWithoutRules({
  userId,
  status,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await updateDoc(
        participantDoc(
          context.firestore(),
          userId,
        ),
        {
          status,
        },
      );
    },
  );
}

async function seedCalledStateWithoutRules({
  calledAt,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await updateDoc(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      await setDoc(
  pendingCallDoc(db, '1'),
  {
    callId: '1',
    userId: member.uid,
    revision: 1,
    calledByUserId: brigadier.uid,
    calledAt,
    shiftYear: 2026,
    shiftMonth: 8,
    shiftDay: 31,
    shiftKind: 'night',
  },
);

      await setDoc(
        pendingCallDoc(db, '1'),
        {
          callId: '1',
          userId: member.uid,
          revision: 1,
          calledByUserId: brigadier.uid,
          calledAt,
        },
      );
    },
  );
}

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      for (const user of [
        owner,
        brigadier,
        member,
        secondMember,
        candidate,
      ]) {
        await setDoc(
          doc(db, 'users', user.uid),
          {
            uid: user.uid,
            email: user.email,
            name: user.uid,
            phone: '',
            about: '',
            avatarUrl: '',
          },
        );
      }

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

      await setDoc(
        doc(db, 'spaces', 'substitution'),
        {
          nextRotationOrder: 2,
        },
      );

      await setDoc(
        participantDoc(db, member.uid),
        {
          rotationOrder: 0,
          availability: 'green',
          status: 'active',
        },
      );

      await setDoc(
        participantDoc(db, secondMember.uid),
        {
          rotationOrder: 1,
          availability: 'green',
          status: 'active',
        },
      );
    },
  );
}
