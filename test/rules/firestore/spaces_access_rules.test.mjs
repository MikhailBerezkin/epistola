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

const testProjectId = 'epistola-spaces-access-rules-test';

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

describe('Spaces access rules', () => {
  test('allows user to read own missing access document', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(
      getDoc(doc(db, 'spaces_access', member.uid)),
    );
  });

  test('allows brigadier to read own role', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      getDoc(doc(db, 'spaces_access', brigadier.uid)),
    );
  });

  test('rejects member reading another user role', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      getDoc(doc(db, 'spaces_access', owner.uid)),
    );
  });

  test('allows owner to read another user role', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      getDoc(doc(db, 'spaces_access', brigadier.uid)),
    );
  });

  test('rejects unauthenticated access read', async () => {
    const db = testEnvironment
        .unauthenticatedContext()
        .firestore();

    await assertFails(
      getDoc(doc(db, 'spaces_access', owner.uid)),
    );
  });

  test('allows owner to list access documents', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      getDocs(collection(db, 'spaces_access')),
    );
  });

  test('rejects member listing access documents', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      getDocs(collection(db, 'spaces_access')),
    );
  });

  test('rejects member assigning brigadier to self', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        doc(db, 'spaces_access', member.uid),
        {
          role: 'brigadier',
        },
      ),
    );
  });

  test('rejects brigadier assigning another brigadier', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertFails(
      setDoc(
        doc(db, 'spaces_access', candidate.uid),
        {
          role: 'brigadier',
        },
      ),
    );
  });

  test('allows owner to assign brigadier to existing user', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      setDoc(
        doc(db, 'spaces_access', candidate.uid),
        {
          role: 'brigadier',
        },
      ),
    );
  });

  test('rejects owner creating another owner', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        doc(db, 'spaces_access', candidate.uid),
        {
          role: 'owner',
        },
      ),
    );
  });

  test('rejects assigning brigadier to unknown user', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        doc(db, 'spaces_access', 'missing-user'),
        {
          role: 'brigadier',
        },
      ),
    );
  });

  test('rejects changing brigadier document into owner', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      updateDoc(
        doc(db, 'spaces_access', brigadier.uid),
        {
          role: 'owner',
        },
      ),
    );
  });

  test('allows owner to revoke brigadier', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      deleteDoc(
        doc(db, 'spaces_access', brigadier.uid),
      ),
    );
  });

  test('rejects deleting owner document', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      deleteDoc(
        doc(db, 'spaces_access', owner.uid),
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

      for (const user of [
        owner,
        brigadier,
        member,
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
    },
  );
}