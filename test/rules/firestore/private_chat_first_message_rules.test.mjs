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
  writeBatch,
} from 'firebase/firestore';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'demo-epistola-first-msg';

const chatId = 'user-1_user-2';

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
  await seedUsers();
});

afterEach(async () => {
  if (testEnvironment != null) {
    await testEnvironment.clearFirestore();
  }
});

after(async () => {
  if (testEnvironment != null) {
    await testEnvironment.cleanup();
  }
});

describe('First message of a new private chat', () => {
  test('allows a legacy text first message', async () => {
    const messageId = 'legacy-first-message';

    const result = createPrivateChatWithFirstMessage({
      messageId,
      lastMessage: 'Legacy first message',
      messageData: {
        text: 'Legacy first message',
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertSucceeds(result);
  });

  test('allows an explicit text first message', async () => {
    const messageId = 'explicit-first-message';

    const result = createPrivateChatWithFirstMessage({
      messageId,
      lastMessage: 'Explicit first message',
      messageData: {
        messageType: 'text',
        text: 'Explicit first message',
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertSucceeds(result);
  });

  test('allows an image as the first message', async () => {
    const messageId = 'image-first-message';

    const result = createPrivateChatWithFirstMessage({
      messageId,
      lastMessage: 'Фотография',
      messageData: {
        messageType: 'image',
        text: '',
        image: imageMetadata(messageId),
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertSucceeds(result);
  });

  test('rejects an incorrect preview for a first image', async () => {
    const messageId = 'image-invalid-preview';

    const result = createPrivateChatWithFirstMessage({
      messageId,
      lastMessage: 'Фото',
      messageData: {
        messageType: 'image',
        text: '',
        image: imageMetadata(messageId),
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertFails(result);
  });

  test('rejects sender impersonation in a first message', async () => {
    const messageId = 'spoofed-first-message';

    const result = createPrivateChatWithFirstMessage({
      messageId,
      lastMessage: 'Spoofed first message',
      messageData: {
        messageType: 'text',
        text: 'Spoofed first message',
        senderId: peer.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertFails(result);
  });
});

async function seedUsers() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

      await setDoc(
        doc(database, 'users', sender.uid),
        {
          name: sender.name,
          email: sender.email,
        },
      );

      await setDoc(
        doc(database, 'users', peer.uid),
        {
          name: peer.name,
          email: peer.email,
        },
      );
    },
  );
}

function createPrivateChatWithFirstMessage({
  messageId,
  lastMessage,
  messageData,
}) {
  const context = testEnvironment.authenticatedContext(
    sender.uid,
    {
      email: sender.email,
    },
  );

  const database = context.firestore();
  const batch = writeBatch(database);

  batch.set(
    doc(database, 'chats', chatId),
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
        [sender.uid]: serverTimestamp(),
      },
      isDissolved: false,
      createdAt: serverTimestamp(),
      lastMessage,
      lastMessageAt: serverTimestamp(),
      lastMessageId: messageId,
      firstMessageId: messageId,
    },
  );

  batch.set(
    doc(
      database,
      'chats',
      chatId,
      'messages',
      messageId,
    ),
    messageData,
  );

  return batch.commit();
}

function imageMetadata(messageId) {
  return {
    provider: 'firebase',
    thumbStoragePath:
        `chat_media/${chatId}/messages/${messageId}/v3/thumb.jpg`,
    fullStoragePath:
        `chat_media/${chatId}/messages/${messageId}/v3/full.jpg`,
    thumbSizeBytes: 24000,
    fullSizeBytes: 280000,
    thumbWidth: 320,
    thumbHeight: 180,
    fullWidth: 1600,
    fullHeight: 900,
    mimeType: 'image/jpeg',
    version: 3,
  };
}