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
    'allows member to move self to vacation',
    async () => {
      const db = authenticatedFirestore(member);

      await assertSucceeds(
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
    'allows member to return self to active',
    async () => {
      await setParticipantStatusWithoutRules({
        userId: member.uid,
        status: 'sick',
      });

      const db = authenticatedFirestore(member);

      await assertSucceeds(
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
    'allows brigadier to atomically call active participant',
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

      await assertSucceeds(batch.commit());
    },
  );

  test(
    'allows owner to atomically call active participant',
    async () => {
      const db = authenticatedFirestore(owner);
      const batch = writeBatch(db);

      batch.update(
        participantDoc(db, secondMember.uid),
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
            userId: secondMember.uid,
            previousRotationOrder: 1,
            revision: 1,
          },
        },
      );

      await assertSucceeds(batch.commit());
    },
  );

  test(
    'rejects ordinary member calling participant',
    async () => {
      const db = authenticatedFirestore(member);
      const batch = writeBatch(db);

      batch.update(
        participantDoc(db, secondMember.uid),
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
            userId: secondMember.uid,
            previousRotationOrder: 1,
            revision: 1,
          },
        },
      );

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
    'rejects call module update without participant rotation update',
    async () => {
      const db = authenticatedFirestore(brigadier);

      await assertFails(
        updateDoc(
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
        ),
      );
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
    'allows brigadier to undo latest call atomically',
    async () => {
      const db = authenticatedFirestore(brigadier);

      const callBatch = writeBatch(db);

      callBatch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      callBatch.update(
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
    },
  );

  test(
    'rejects undo with wrong previous rotation order',
    async () => {
      const db = authenticatedFirestore(owner);

      const callBatch = writeBatch(db);

      callBatch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      callBatch.update(
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

      await assertSucceeds(callBatch.commit());

      const undoBatch = writeBatch(db);

      undoBatch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 1,
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
    'rejects deleting lastCall without restoring participant rotation',
    async () => {
      const db = authenticatedFirestore(brigadier);

      const callBatch = writeBatch(db);

      callBatch.update(
        participantDoc(db, member.uid),
        {
          rotationOrder: 2,
        },
      );

      callBatch.update(
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

      await assertSucceeds(callBatch.commit());

      await assertFails(
        updateDoc(
          doc(db, 'spaces', 'substitution'),
          {
            lastCall: deleteField(),
          },
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

function participantDoc(db, userId) {
  return doc(
    db,
    'spaces',
    'substitution',
    'participants',
    userId,
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