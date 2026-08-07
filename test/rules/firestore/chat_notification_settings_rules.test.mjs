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
  doc,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'epistola-chat-notification-settings-rules-test';

const privateChatId = 'user-1_user-2';
const groupChatId = 'group-notification-settings-test';

const sender = {
  uid: 'user-1',
  email: 'sender@example.com',
};

const peer = {
  uid: 'user-2',
  email: 'peer@example.com',
};

const groupAdmin = {
  uid: 'admin-1',
  email: 'admin@example.com',
};

const groupMember = {
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
  await seedBaseline();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Chat notification settings rules', () => {
  test(
    'allows a private member to enable sound',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'sound',
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows a private member to disable push notifications',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'disabled',
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows a group member to mute notifications for one hour',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: groupMember,
        chatId: groupChatId,
        targetUserId: groupMember.uid,
        settings: {
          mode: 'silent',
          expiresAt: futureTimestamp({hours: 1}),
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows a group member to mute notifications for 24 hours',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: groupMember,
        chatId: groupChatId,
        targetUserId: groupMember.uid,
        settings: {
          mode: 'silent',
          expiresAt: futureTimestamp({hours: 24}),
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows permanent silent mode',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'silent',
          permanent: true,
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects changing another private member settings',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: peer.uid,
        settings: {
          mode: 'disabled',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an admin changing another group member settings',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: groupAdmin,
        chatId: groupChatId,
        targetUserId: groupMember.uid,
        settings: {
          mode: 'disabled',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an unknown notification mode',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'something-else',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects malformed permanent silent mode',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'silent',
          permanent: false,
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an expired temporary silent mode',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'silent',
          expiresAt: pastTimestamp(),
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects temporary silent mode longer than allowed',
    async () => {
      const result = updateNotificationSettings({
        authenticatedUser: sender,
        chatId: privateChatId,
        targetUserId: sender.uid,
        settings: {
          mode: 'silent',
          expiresAt: futureTimestamp({hours: 26}),
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects changing notification settings together with another chat field',
    async () => {
      const db = authenticatedFirestore(groupAdmin);

      const result = updateDoc(
        doc(db, 'chats', groupChatId),
        {
          [`notificationSettingsByUser.${groupAdmin.uid}`]: {
            mode: 'sound',
          },
          name: 'Tampered group name',
        },
      );

      await assertFails(result);
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

function updateNotificationSettings({
  authenticatedUser,
  chatId,
  targetUserId,
  settings,
}) {
  const db = authenticatedFirestore(authenticatedUser);

  return updateDoc(
    doc(db, 'chats', chatId),
    {
      [`notificationSettingsByUser.${targetUserId}`]:
          settings,
    },
  );
}

function futureTimestamp({hours}) {
  return Timestamp.fromMillis(
    Date.now() + hours * 60 * 60 * 1000,
  );
}

function pastTimestamp() {
  return Timestamp.fromMillis(
    Date.now() - 60 * 60 * 1000,
  );
}

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      const baselineTime = Timestamp.fromDate(
        new Date('2026-08-07T08:00:00.000Z'),
      );

      await setDoc(
        doc(db, 'chats', privateChatId),
        {
          name: 'private_chat',
          type: 'private',
          memberIds: [
            sender.uid,
            peer.uid,
          ],
          memberEmails: [
            sender.email,
            peer.email,
          ],
          memberRoles: {
            [sender.uid]: 'member',
            [peer.uid]: 'member',
          },
          memberStatus: {
            [sender.uid]: {
              status: 'normal',
            },
            [peer.uid]: {
              status: 'normal',
            },
          },
          groupSettings: {
            messagePermission: 'all',
          },
          lastRead: {
            [sender.uid]: baselineTime,
            [peer.uid]: baselineTime,
          },
          isDissolved: false,
          createdAt: baselineTime,
          lastMessage: 'Baseline',
          lastMessageAt: baselineTime,
          lastMessageId: 'message-1',
          firstMessageId: 'message-1',
        },
      );

      await setDoc(
        doc(db, 'chats', groupChatId),
        {
          name: 'Notification group',
          type: 'group',
          memberIds: [
            groupAdmin.uid,
            groupMember.uid,
          ],
          memberEmails: [
            groupAdmin.email,
            groupMember.email,
          ],
          memberRoles: {
            [groupAdmin.uid]: 'admin',
            [groupMember.uid]: 'member',
          },
          memberStatus: {
            [groupAdmin.uid]: {
              status: 'normal',
            },
            [groupMember.uid]: {
              status: 'normal',
            },
          },
          groupSettings: {
            messagePermission: 'all',
          },
          lastRead: {
            [groupAdmin.uid]: baselineTime,
            [groupMember.uid]: baselineTime,
          },
          isDissolved: false,
          createdAt: baselineTime,
          lastMessage: 'Baseline',
          lastMessageAt: baselineTime,
          lastMessageId: 'message-1',
        },
      );
    },
  );
}