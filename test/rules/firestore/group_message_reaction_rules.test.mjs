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
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId =
    'epistola-group-message-reaction-rules-test';

const groupChatId = 'group-reaction-test';
const privateChatId = 'user-1_user-2';

const groupMessageId = 'group-message-1';
const privateMessageId = 'private-message-1';
const deletedMessageId = 'deleted-message-1';

const initialTime =
    new Date('2026-08-04T06:00:00.000Z');

const messageTime =
    new Date('2026-08-04T06:01:00.000Z');

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

const outsider = {
  uid: 'user-3',
  email: 'outsider@example.com',
  name: 'Outside User',
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

describe('Group message reaction rules', () => {
  test('allows a group member to add their own like', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      reaction: 'like',
    });

    await assertSucceeds(result);
  });

  test('allows a group member to add their own dislike', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      reaction: 'dislike',
    });

    await assertSucceeds(result);
  });

  test('allows switching an own reaction', async () => {
    await seedOwnReaction('like');

    const result = updateReaction({
      authenticatedUser: sender,
      reaction: 'dislike',
    });

    await assertSucceeds(result);
  });

  test('allows removing an own reaction', async () => {
    await seedOwnReaction('dislike');

    const result = updateReaction({
      authenticatedUser: sender,
      reaction: null,
    });

    await assertSucceeds(result);
  });

  test('rejects reactions in a private chat', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      chatId: privateChatId,
      messageId: privateMessageId,
      reaction: 'like',
    });

    await assertFails(result);
  });

  test('rejects a reaction from a non-member', async () => {
    const result = updateReaction({
      authenticatedUser: outsider,
      targetUserId: outsider.uid,
      reaction: 'like',
    });

    await assertFails(result);
  });

  test('rejects changing another member reaction', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      targetUserId: peer.uid,
      reaction: 'like',
    });

    await assertFails(result);
  });

  test('rejects an unsupported reaction value', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      reaction: 'love',
    });

    await assertFails(result);
  });

  test('rejects changing message text together with a reaction', async () => {
    const context = authenticatedContext(sender);

    const result = updateDoc(
      messageReference({
        database: context.firestore(),
        chatId: groupChatId,
        messageId: groupMessageId,
      }),
      {
        [`reactions.${sender.uid}`]: 'like',
        text: 'Changed message text',
      },
    );

    await assertFails(result);
  });

  test('rejects replacing reactions and removing another member reaction',
      async () => {
        const context = authenticatedContext(sender);

        const result = updateDoc(
          messageReference({
            database: context.firestore(),
            chatId: groupChatId,
            messageId: groupMessageId,
          }),
          {
            reactions: {
              [sender.uid]: 'like',
            },
          },
        );

        await assertFails(result);
      });

  test('rejects an unauthenticated reaction', async () => {
    const context = testEnvironment.unauthenticatedContext();

    const result = updateDoc(
      messageReference({
        database: context.firestore(),
        chatId: groupChatId,
        messageId: groupMessageId,
      }),
      {
        [`reactions.${sender.uid}`]: 'like',
      },
    );

    await assertFails(result);
  });

  test('rejects reacting to a deleted-for-everyone message', async () => {
    const result = updateReaction({
      authenticatedUser: sender,
      messageId: deletedMessageId,
      reaction: 'like',
    });

    await assertFails(result);
  });
});

async function seedBaseline() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

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
          doc(database, 'users', outsider.uid),
          {
            name: outsider.name,
            email: outsider.email,
          },
        ),
        setDoc(
          doc(database, 'chats', groupChatId),
          chatData({
            type: 'group',
            name: 'Reaction Group',
          }),
        ),
        setDoc(
          doc(database, 'chats', privateChatId),
          chatData({
            type: 'private',
            name: 'private_chat',
          }),
        ),
      ]);

      await Promise.all([
        setDoc(
          messageReference({
            database,
            chatId: groupChatId,
            messageId: groupMessageId,
          }),
          messageData({
            reactions: {
              [peer.uid]: 'dislike',
            },
          }),
        ),
        setDoc(
          messageReference({
            database,
            chatId: privateChatId,
            messageId: privateMessageId,
          }),
          messageData(),
        ),
        setDoc(
          messageReference({
            database,
            chatId: groupChatId,
            messageId: deletedMessageId,
          }),
          messageData({
            deletedForEveryone: true,
          }),
        ),
      ]);
    },
  );
}

function chatData({
  type,
  name,
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
      [sender.uid]: Timestamp.fromDate(initialTime),
      [peer.uid]: Timestamp.fromDate(initialTime),
    },
    isDissolved: false,
    createdAt: Timestamp.fromDate(initialTime),
    lastMessage: 'Previous message',
    lastMessageAt: Timestamp.fromDate(initialTime),
    lastMessageId: 'previous-message',
  };
}

function messageData({
  reactions,
  deletedForEveryone = false,
} = {}) {
  return {
    messageType: 'text',
    text: deletedForEveryone ? '' : 'Group reaction message',
    senderId: peer.uid,
    senderEmail: peer.email,
    senderName: peer.name,
    createdAt: Timestamp.fromDate(messageTime),
    ...(reactions == null ? {} : {reactions}),
    ...(deletedForEveryone
      ? {
          deletedForEveryone: true,
          deletedBy: peer.uid,
          deletedAt: Timestamp.fromDate(
            new Date(messageTime.getTime() + 1000),
          ),
        }
      : {}),
  };
}

async function seedOwnReaction(reaction) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        messageReference({
          database: context.firestore(),
          chatId: groupChatId,
          messageId: groupMessageId,
        }),
        {
          reactions: {
            [peer.uid]: 'dislike',
            [sender.uid]: reaction,
          },
        },
        {
          merge: true,
        },
      );
    },
  );
}

function authenticatedContext(user) {
  return testEnvironment.authenticatedContext(
    user.uid,
    {
      email: user.email,
    },
  );
}

function messageReference({
  database,
  chatId,
  messageId,
}) {
  return doc(
    database,
    'chats',
    chatId,
    'messages',
    messageId,
  );
}

function updateReaction({
  authenticatedUser,
  reaction,
  targetUserId = authenticatedUser.uid,
  chatId = groupChatId,
  messageId = groupMessageId,
}) {
  const context = authenticatedContext(authenticatedUser);

  return updateDoc(
    messageReference({
      database: context.firestore(),
      chatId,
      messageId,
    }),
    {
      [`reactions.${targetUserId}`]:
          reaction == null
              ? deleteField()
              : reaction,
    },
  );
}