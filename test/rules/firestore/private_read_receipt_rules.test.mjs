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
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'epistola-private-read-receipt-rules-test';

const privateChatId = 'user-1_user-2';
const groupChatId = 'group-read-receipt-test';

const firstMessageId = 'message-1';
const secondMessageId = 'message-2';
const missingMessageId = 'missing-message';

const firstMessageTime =
    new Date('2026-08-03T14:00:00.000Z');

const secondMessageTime =
    new Date('2026-08-03T14:01:00.000Z');

const sender = {
  uid: 'user-1',
  email: 'sender@example.com',
  name: 'Sender User',
};

const peer = {
  uid: 'user-2',
  email: 'peer@example.com',
  name: 'Peer User',
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

describe('Private read receipt rules', () => {
  test(
    'allows a private member to update only their own lastRead',
    async () => {
      const result = updateOwnLastRead({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects changing another private member lastRead',
    async () => {
      const result = updateOwnLastRead({
        authenticatedUser: sender,
        targetUserId: peer.uid,
        chatId: privateChatId,
      });

      await assertFails(result);
    },
  );

  test(
    'allows a private member to create their own read cursor',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows advancing an existing private read cursor',
    async () => {
      await seedReadCursor({
        chatId: privateChatId,
        userId: sender.uid,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
      });

      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: secondMessageId,
        messageCreatedAt: secondMessageTime,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows refreshing the same private read cursor',
    async () => {
      await seedReadCursor({
        chatId: privateChatId,
        userId: sender.uid,
        messageId: secondMessageId,
        messageCreatedAt: secondMessageTime,
      });

      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: secondMessageId,
        messageCreatedAt: secondMessageTime,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects moving a private read cursor backwards',
    async () => {
      await seedReadCursor({
        chatId: privateChatId,
        userId: sender.uid,
        messageId: secondMessageId,
        messageCreatedAt: secondMessageTime,
      });

      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
      });

      await assertFails(result);
    },
  );

  test(
    'rejects changing another member private read cursor',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: peer.uid,
        chatId: privateChatId,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a cursor pointing to a missing message',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: missingMessageId,
        messageCreatedAt: secondMessageTime,
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a cursor containing an incorrect message timestamp',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: secondMessageId,
        messageCreatedAt: firstMessageTime,
      });

      await assertFails(result);
    },
  );

  test(
    'rejects private read state in a group chat',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: groupChatId,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
      });

      await assertFails(result);
    },
  );

  test(
    'keeps own lastRead updates available in a group chat',
    async () => {
      const result = updateOwnLastRead({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: groupChatId,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects unexpected fields inside a private read cursor',
    async () => {
      const result = updateReadReceipt({
        authenticatedUser: sender,
        targetUserId: sender.uid,
        chatId: privateChatId,
        messageId: firstMessageId,
        messageCreatedAt: firstMessageTime,
        additionalCursorData: {
          deviceId: 'unexpected-device',
        },
      });

      await assertFails(result);
    },
  );
});

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();
      const initialTime =
          new Date('2026-08-03T13:50:00.000Z');

      await Promise.all([
        setDoc(
          doc(database, 'users', sender.uid),
          {
            name: sender.name,
            email: sender.email,
          },
        ),
        setDoc(
          doc(database, 'users', peer.uid),
          {
            name: peer.name,
            email: peer.email,
          },
        ),
        setDoc(
          doc(database, 'chats', privateChatId),
          chatData({
            type: 'private',
            name: 'private_chat',
            initialTime,
          }),
        ),
        setDoc(
          doc(database, 'chats', groupChatId),
          chatData({
            type: 'group',
            name: 'Read Receipt Group',
            initialTime,
          }),
        ),
      ]);

      await Promise.all([
        seedMessage({
          database,
          chatId: privateChatId,
          messageId: firstMessageId,
          messageCreatedAt: firstMessageTime,
        }),
        seedMessage({
          database,
          chatId: privateChatId,
          messageId: secondMessageId,
          messageCreatedAt: secondMessageTime,
        }),
        seedMessage({
          database,
          chatId: groupChatId,
          messageId: firstMessageId,
          messageCreatedAt: firstMessageTime,
        }),
      ]);
    },
  );
}

function chatData({
  type,
  name,
  initialTime,
}) {
  return {
    name,
    type,
    memberIds: [
      sender.uid,
      peer.uid,
    ],
    memberEmails: [
      sender.email,
      peer.email,
    ],
    memberRoles: {
      [sender.uid]: type === 'group' ? 'owner' : 'member',
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
      [sender.uid]: initialTime,
      [peer.uid]: initialTime,
    },
    isDissolved: false,
    createdAt: initialTime,
    lastMessage: 'Previous message',
    lastMessageAt: initialTime,
    lastMessageId: 'previous-message',
  };
}

function seedMessage({
  database,
  chatId,
  messageId,
  messageCreatedAt,
}) {
  return setDoc(
    doc(
      database,
      'chats',
      chatId,
      'messages',
      messageId,
    ),
    {
      messageType: 'text',
      text: `Text for ${messageId}`,
      senderId: peer.uid,
      senderEmail: peer.email,
      senderName: peer.name,
      createdAt: Timestamp.fromDate(messageCreatedAt),
    },
  );
}

async function seedReadCursor({
  chatId,
  userId,
  messageId,
  messageCreatedAt,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();
      const readAt =
          new Date(messageCreatedAt.getTime() + 1000);

      await setDoc(
        doc(database, 'chats', chatId),
        {
          lastRead: {
            [sender.uid]:
                userId === sender.uid
                    ? readAt
                    : firstMessageTime,
            [peer.uid]:
                userId === peer.uid
                    ? readAt
                    : firstMessageTime,
          },
          privateReadState: {
            [userId]: {
              messageId,
              messageCreatedAt:
                  Timestamp.fromDate(messageCreatedAt),
              readAt: Timestamp.fromDate(readAt),
            },
          },
        },
        {
          merge: true,
        },
      );
    },
  );
}

function updateOwnLastRead({
  authenticatedUser,
  targetUserId,
  chatId,
}) {
  const context = testEnvironment.authenticatedContext(
    authenticatedUser.uid,
    {
      email: authenticatedUser.email,
    },
  );

  return updateDoc(
    doc(context.firestore(), 'chats', chatId),
    {
      [`lastRead.${targetUserId}`]:
          serverTimestamp(),
    },
  );
}

function updateReadReceipt({
  authenticatedUser,
  targetUserId,
  chatId,
  messageId,
  messageCreatedAt,
  additionalCursorData = {},
}) {
  const context = testEnvironment.authenticatedContext(
    authenticatedUser.uid,
    {
      email: authenticatedUser.email,
    },
  );

  return updateDoc(
    doc(context.firestore(), 'chats', chatId),
    {
      [`lastRead.${targetUserId}`]:
          serverTimestamp(),
      [`privateReadState.${targetUserId}`]: {
        messageId,
        messageCreatedAt:
            Timestamp.fromDate(messageCreatedAt),
        readAt: serverTimestamp(),
        ...additionalCursorData,
      },
    },
  );
}