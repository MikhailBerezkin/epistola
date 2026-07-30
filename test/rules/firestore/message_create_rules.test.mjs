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

const testProjectId = 'epistola-rules-test';

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
  await seedExistingPrivateChat();
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Firestore message creation baseline', () => {
  test('allows the current legacy text message format', async () => {
    const result = createMessageBatch({
      messageId: 'legacy-message-1',
      lastMessage: 'Legacy text message',
      messageData: {
        text: 'Legacy text message',
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertSucceeds(result);
  });

  test('currently rejects explicit text messageType', async () => {
    const result = createMessageBatch({
      messageId: 'explicit-text-message-1',
      lastMessage: 'Explicit text message',
      messageData: {
        messageType: 'text',
        text: 'Explicit text message',
        senderId: sender.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertFails(result);
  });

  test('currently rejects image message metadata', async () => {
    const messageId = 'image-message-1';

    const result = createMessageBatch({
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

    await assertFails(result);
  });

  test('rejects sender ID impersonation', async () => {
    const result = createMessageBatch({
      messageId: 'spoofed-message-1',
      lastMessage: 'Spoofed message',
      messageData: {
        text: 'Spoofed message',
        senderId: peer.uid,
        senderEmail: sender.email,
        senderName: sender.name,
        createdAt: serverTimestamp(),
      },
    });

    await assertFails(result);
  });
});

async function seedExistingPrivateChat() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();
      const seedTimestamp = new Date('2026-07-30T09:00:00.000Z');

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

      await setDoc(
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
            [sender.uid]: seedTimestamp,
            [peer.uid]: seedTimestamp,
          },
          isDissolved: false,
          createdAt: seedTimestamp,
          lastMessage: 'Previous message',
          lastMessageAt: seedTimestamp,
          lastMessageId: 'previous-message',
        },
      );
    },
  );
}

function createMessageBatch({
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

  batch.update(
    doc(database, 'chats', chatId),
    {
      lastMessage,
      lastMessageAt: serverTimestamp(),
      lastMessageId: messageId,
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