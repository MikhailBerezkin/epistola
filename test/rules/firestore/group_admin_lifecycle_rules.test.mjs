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
  deleteField,
  doc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const projectId = 'epistola-group-admin-lifecycle-rules-test';
const chatId = 'group-admin-lifecycle-test';

const admin = {
  uid: 'admin-1',
  email: 'admin@example.com',
};

const member = {
  uid: 'member-1',
  email: 'member@example.com',
};

const outsider = {
  uid: 'outsider-1',
  email: 'outsider@example.com',
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
  await seedGroup();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Group admin lifecycle rules', () => {
  test('allows admin to transfer admin rights', async () => {
    const db = authenticatedFirestore(admin);

    await assertSucceeds(
      updateDoc(
        doc(db, 'chats', chatId),
        {
          [`memberRoles.${member.uid}`]: 'admin',
          [`memberRoles.${admin.uid}`]: 'member',
          lastMessage: 'Права администратора переданы',
          lastMessageAt: serverTimestamp(),
          lastMessageId: deleteField(),
        },
      ),
    );
  });

  test('rejects member transferring admin rights', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      updateDoc(
        doc(db, 'chats', chatId),
        {
          [`memberRoles.${admin.uid}`]: 'member',
          [`memberRoles.${member.uid}`]: 'admin',
          lastMessage: 'Права администратора переданы',
          lastMessageAt: serverTimestamp(),
          lastMessageId: deleteField(),
        },
      ),
    );
  });

  test('allows admin to dissolve group', async () => {
    const db = authenticatedFirestore(admin);

    await assertSucceeds(
      updateDoc(
        doc(db, 'chats', chatId),
        {
          isDissolved: true,
          dissolvedBy: admin.uid,
          dissolvedAt: serverTimestamp(),
          lastMessage: 'Группа распущена',
          lastMessageAt: serverTimestamp(),
          lastMessageId: deleteField(),
          memberIds: [],
          memberEmails: [],
        },
      ),
    );
  });

  test('rejects member dissolving group', async () => {
    const db = authenticatedFirestore(member);

    await assertFails(
      updateDoc(
        doc(db, 'chats', chatId),
        {
          isDissolved: true,
          dissolvedBy: member.uid,
          dissolvedAt: serverTimestamp(),
          lastMessage: 'Группа распущена',
          lastMessageAt: serverTimestamp(),
          lastMessageId: deleteField(),
          memberIds: [],
          memberEmails: [],
        },
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

async function seedGroup() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();
      const timestamp =
          new Date('2026-09-26T09:00:00.000Z');

      for (const user of [admin, member, outsider]) {
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
        doc(db, 'chats', chatId),
        {
          name: 'Test group',
          type: 'group',
          memberIds: [
            admin.uid,
            member.uid,
          ],
          memberEmails: [
            admin.email,
            member.email,
          ],
          memberRoles: {
            [admin.uid]: 'admin',
            [member.uid]: 'member',
          },
          memberStatus: {
            [admin.uid]: {
              status: 'normal',
            },
            [member.uid]: {
              status: 'normal',
            },
          },
          groupSettings: {
            messagePermission: 'all',
          },
          lastRead: {
            [admin.uid]: timestamp,
            [member.uid]: timestamp,
          },
          isDissolved: false,
          createdAt: timestamp,
          lastMessage: 'Previous message',
          lastMessageAt: timestamp,
          lastMessageId: 'previous-message',
        },
      );
    },
  );
}