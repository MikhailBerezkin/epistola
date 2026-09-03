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
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-spaces-bar-rules-test';

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

const guest = {
  uid: 'guest-1',
  email: 'guest@example.com',
};

const baselineCreatedAt = Timestamp.fromMillis(1_700_000_000_000);
const baselineUpdatedAt = Timestamp.fromMillis(1_700_000_100_000);

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

describe('SpacesBar rules', () => {
  test('allows signed-in ordinary member to read SpacesBar', async () => {
    const db = authenticatedFirestore(member);

    await assertSucceeds(getDoc(spacesBarDoc(db)));
  });

  test('allows signed-in group guest to read SpacesBar', async () => {
    const db = authenticatedFirestore(guest);

    await assertSucceeds(getDoc(spacesBarDoc(db)));
  });

  test('rejects unauthenticated SpacesBar read', async () => {
    const db = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(spacesBarDoc(db)));
  });

  test('allows owner to create initial SpacesBar board', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({publisherUserId: owner.uid}),
      ),
    );
  });

  test('allows brigadier to create initial SpacesBar board', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({publisherUserId: brigadier.uid}),
      ),
    );
  });

  test('rejects ordinary member creating SpacesBar board', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({publisherUserId: member.uid}),
      ),
    );
  });

  test('allows brigadier to publish next message', async () => {
    const db = authenticatedFirestore(brigadier);

    await assertSucceeds(
      setDoc(
        spacesBarDoc(db),
        boardWithNextMessage({publisherUserId: brigadier.uid}),
      ),
    );
  });

  test('allows owner to remove existing message', async () => {
    const db = authenticatedFirestore(owner);

    await assertSucceeds(
      setDoc(
        spacesBarDoc(db),
        {
          schemaVersion: 1,
          revision: 3,
          messages: {},
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects ordinary member updating SpacesBar board', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        boardWithNextMessage({publisherUserId: member.uid}),
      ),
    );
  });

  test('rejects board with more than three messages', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          schemaVersion: 1,
          revision: 3,
          messages: {
            '2': baselineMessageData(),
            '3': newMessageData({publisherUserId: owner.uid}),
            '4': newMessageData({publisherUserId: owner.uid}),
            '5': newMessageData({publisherUserId: owner.uid}),
          },
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects empty message text', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({
          publisherUserId: owner.uid,
          text: '',
        }),
      ),
    );
  });

  test('rejects message text longer than 250 characters', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({
          publisherUserId: owner.uid,
          text: 'x'.repeat(251),
        }),
      ),
    );
  });

  test('rejects unsupported message lifetime', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({
          publisherUserId: owner.uid,
          lifetime: 'forever',
        }),
      ),
    );
  });

  test('rejects forged publisher on new message', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        initialBoardData({publisherUserId: brigadier.uid}),
      ),
    );
  });

  test('rejects forged createdAt on new message', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);
    const data = initialBoardData({publisherUserId: owner.uid});
    data.messages['1'].createdAt = baselineCreatedAt;

    await assertFails(setDoc(spacesBarDoc(db), data));
  });

  test('rejects changing an existing message', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          schemaVersion: 1,
          revision: 3,
          messages: {
            '2': {
              ...baselineMessageData(),
              text: 'Подменённый текст',
            },
          },
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects new message id that does not match next revision', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          schemaVersion: 1,
          revision: 3,
          messages: {
            '2': baselineMessageData(),
            '999': newMessageData({publisherUserId: owner.uid}),
          },
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('rejects revision jump', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          ...boardWithNextMessage({publisherUserId: owner.uid}),
          revision: 4,
          messages: {
            '2': baselineMessageData(),
            '4': newMessageData({publisherUserId: owner.uid}),
          },
        },
      ),
    );
  });

  test('rejects forged updatedAt', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          ...boardWithNextMessage({publisherUserId: owner.uid}),
          updatedAt: baselineUpdatedAt,
        },
      ),
    );
  });

  test('rejects extra board field', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);

    await assertFails(
      setDoc(
        spacesBarDoc(db),
        {
          ...initialBoardData({publisherUserId: owner.uid}),
          unexpected: true,
        },
      ),
    );
  });

  test('rejects extra message field', async () => {
    await deleteSpacesBarWithoutRules();

    const db = authenticatedFirestore(owner);
    const data = initialBoardData({publisherUserId: owner.uid});
    data.messages['1'].unexpected = true;

    await assertFails(setDoc(spacesBarDoc(db), data));
  });

  test('rejects deleting whole SpacesBar board document', async () => {
    const db = authenticatedFirestore(owner);

    await assertFails(deleteDoc(spacesBarDoc(db)));
  });
});

function authenticatedFirestore(user) {
  return testEnvironment
      .authenticatedContext(user.uid, {email: user.email})
      .firestore();
}

function spacesBarDoc(db) {
  return doc(db, 'spaces', 'spacesBar');
}

function baselineMessageData() {
  return {
    text: 'Базовое сообщение',
    lifetime: 'untilCancelled',
    createdByUserId: owner.uid,
    createdAt: baselineCreatedAt,
  };
}

function newMessageData({
  publisherUserId,
  text = 'Новое сообщение',
  lifetime = 'oneHour',
}) {
  return {
    text,
    lifetime,
    createdByUserId: publisherUserId,
    createdAt: serverTimestamp(),
  };
}

function initialBoardData({
  publisherUserId,
  text = 'Первое сообщение',
  lifetime = 'oneHour',
}) {
  return {
    schemaVersion: 1,
    revision: 1,
    messages: {
      '1': newMessageData({
        publisherUserId,
        text,
        lifetime,
      }),
    },
    updatedAt: serverTimestamp(),
  };
}

function boardWithNextMessage({publisherUserId}) {
  return {
    schemaVersion: 1,
    revision: 3,
    messages: {
      '2': baselineMessageData(),
      '3': newMessageData({publisherUserId}),
    },
    updatedAt: serverTimestamp(),
  };
}

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    for (const user of [owner, brigadier, member, guest]) {
      await setDoc(
        doc(db, 'users', user.uid),
        {
          uid: user.uid,
          email: user.email,
          username: user.uid,
        },
      );
    }

    await setDoc(
      doc(db, 'spaces_access', owner.uid),
      {role: 'owner'},
    );

    await setDoc(
      doc(db, 'spaces_access', brigadier.uid),
      {role: 'brigadier'},
    );

    await setDoc(
      doc(db, 'chats', 'guest-role-fixture'),
      {
        memberRoles: {
          [guest.uid]: 'guest',
        },
      },
    );

    await setDoc(
      spacesBarDoc(db),
      {
        schemaVersion: 1,
        revision: 2,
        messages: {
          '2': baselineMessageData(),
        },
        updatedAt: baselineUpdatedAt,
      },
    );
  });
}

async function deleteSpacesBarWithoutRules() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(spacesBarDoc(context.firestore()));
  });
}