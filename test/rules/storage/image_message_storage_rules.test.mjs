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
} from 'firebase/firestore';

import {
  deleteObject,
  getMetadata,
  ref,
  uploadBytes,
} from 'firebase/storage';

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirectory = path.dirname(currentFilePath);
const projectRoot = path.resolve(currentDirectory, '../../..');

const testProjectId = 'epistola-434b7';

const privateChatId = 'user-1_user-2';
const groupChatId = 'group-chat-1';

const sender = {
  uid: 'user-1',
  email: 'sender@example.com',
};

const peer = {
  uid: 'user-2',
  email: 'peer@example.com',
};

const outsider = {
  uid: 'user-3',
  email: 'outsider@example.com',
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
    storage: {
      rules: fs.readFileSync(
        path.join(projectRoot, 'storage.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await seedChats();
});

afterEach(async () => {
  await testEnvironment.clearStorage();
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe('Storage image message baseline', () => {
  test(
    'allows a private chat participant to upload a valid thumbnail',
    async () => {
      const messageId = 'message-1';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows a private chat participant to upload a valid full image',
    async () => {
      const messageId = 'message-1';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/full.jpg`,
        sizeBytes: 280 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows a private chat participant to read chat_media',
    async () => {
      const storagePath =
          `chat_media/${privateChatId}/`
          + 'messages/message-2/v1/thumb.jpg';

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
      });

      const result = getMetadata(
        storageReference(sender, storagePath),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects an outsider read from chat_media',
    async () => {
      const storagePath =
          `chat_media/${privateChatId}/`
          + 'messages/message-3/v1/full.jpg';

      await seedStorageObject({
        storagePath,
        sizeBytes: 280 * 1024,
      });

      const result = getMetadata(
        storageReference(outsider, storagePath),
      );

      await assertFails(result);
    },
  );

  test(
    'currently rejects deletion from chat_media',
    async () => {
      const storagePath =
          `chat_media/${privateChatId}/`
          + 'messages/message-4/v1/thumb.jpg';

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
      });

      const result = deleteObject(
        storageReference(sender, storagePath),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an arbitrary image message file name',
    async () => {
      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + 'messages/message-5/v1/original.jpg',
        sizeBytes: 280 * 1024,
      });

      await assertFails(result);
    },
  );
});
describe('Storage image message validation', () => {
  test(
    'rejects an unauthenticated image upload',
    async () => {
      const messageId = 'unauthenticated-message';
      const version = 'v1';
      const context = testEnvironment.unauthenticatedContext();

      const result = uploadBytes(
        ref(
          context.storage(),
          `chat_media/${privateChatId}/`
              + `messages/${messageId}/${version}/thumb.jpg`,
        ),
        jpegBytes(24 * 1024),
        {
          contentType: 'image/jpeg',
          customMetadata: imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId: privateChatId,
            messageId,
            version,
          }),
        },
      );

      await assertFails(result);
    },
  );

  test(
    'rejects an image upload from a non-member',
    async () => {
      const messageId = 'outsider-upload';
      const version = 'v1';

      const result = uploadJpeg({
        user: outsider,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: outsider.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a PNG image upload',
    async () => {
      const messageId = 'png-message';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        contentType: 'image/png',
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a thumbnail larger than 128 KiB',
    async () => {
      const messageId = 'oversized-thumbnail';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: (128 * 1024) + 1,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a full image larger than 1 MiB',
    async () => {
      const messageId = 'oversized-full-image';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/full.jpg`,
        sizeBytes: (1024 * 1024) + 1,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an invalid image version',
    async () => {
      const messageId = 'invalid-version-message';
      const version = 'v0';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an image upload without custom metadata',
    async () => {
      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + 'messages/missing-metadata/v1/thumb.jpg',
        sizeBytes: 24 * 1024,
      });

      await assertFails(result);
    },
  );

  test(
    'rejects metadata belonging to another chat',
    async () => {
      const messageId = 'incorrect-chat-metadata';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${privateChatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: 'another-chat',
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );

  test(
    'rejects overwriting an existing versioned object',
    async () => {
      const messageId = 'immutable-message';
      const version = 'v1';
      const storagePath =
          `chat_media/${privateChatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
      });

      const result = uploadJpeg({
        user: sender,
        storagePath,
        sizeBytes: 20 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await assertFails(result);
    },
  );
});
describe('Group image message write permissions', () => {
  test(
    'allows a regular member when message permission is all',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'all',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-all-member',
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a regular member when permission is moderators',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'moderators',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-moderators-member',
      });

      await assertFails(result);
    },
  );

  test(
    'allows a moderator when permission is moderators',
    async () => {
      await configureGroupPeerAccess({
        role: 'moderator',
        messagePermission: 'moderators',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-moderators-moderator',
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a regular member when permission is admins',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'admins',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-admins-member',
      });

      await assertFails(result);
    },
  );

  test(
    'allows an admin when permission is admins',
    async () => {
      await configureGroupPeerAccess({
        role: 'admin',
        messagePermission: 'admins',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-admins-admin',
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a guest even when permission is all',
    async () => {
      await configureGroupPeerAccess({
        role: 'guest',
        messagePermission: 'all',
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-guest',
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an actively muted member',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'all',
        statusData: {
          status: 'muted',
          permanent: false,
          expiresAt: new Date('2030-01-01T00:00:00.000Z'),
        },
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-active-mute',
      });

      await assertFails(result);
    },
  );

  test(
    'allows a member after temporary mute has expired',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'all',
        statusData: {
          status: 'muted',
          permanent: false,
          expiresAt: new Date('2020-01-01T00:00:00.000Z'),
        },
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-expired-mute',
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a permanently banned member',
    async () => {
      await configureGroupPeerAccess({
        role: 'member',
        messagePermission: 'all',
        statusData: {
          status: 'banned',
          permanent: true,
        },
      });

      const result = uploadGroupThumbnail({
        user: peer,
        messageId: 'group-permanent-ban',
      });

      await assertFails(result);
    },
  );
});

describe('Image message rollback deletion', () => {
  test(
    'allows the uploader to delete an orphaned upload',
    async () => {
      const messageId = 'rollback-orphan';
      const version = 'v1';
      const storagePath =
          `chat_media/${privateChatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      const result = deleteObject(
        storageReference(sender, storagePath),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'allows rollback before a new private chat exists',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'first-private-image-rollback';
      const version = 'v1';
      const storagePath =
          `chat_media/${chatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      const result = deleteObject(
        storageReference(sender, storagePath),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects the peer deleting a first private orphaned upload',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'first-private-image-foreign-delete';
      const version = 'v1';
      const storagePath =
          `chat_media/${chatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      const result = deleteObject(
        storageReference(outsider, storagePath),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects another participant deleting an orphaned upload',
    async () => {
      const messageId = 'rollback-foreign-user';
      const version = 'v1';
      const storagePath =
          `chat_media/${privateChatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      const result = deleteObject(
        storageReference(peer, storagePath),
      );

      await assertFails(result);
    },
  );

  test(
    'rejects deletion after the message document exists',
    async () => {
      const messageId = 'successful-image-message';
      const version = 'v1';
      const storagePath =
          `chat_media/${privateChatId}/`
          + `messages/${messageId}/${version}/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
        customMetadata: imageMessageCustomMetadata({
          uploaderId: sender.uid,
          chatId: privateChatId,
          messageId,
          version,
        }),
      });

      await seedMessageDocument(messageId);

      const result = deleteObject(
        storageReference(sender, storagePath),
      );

      await assertFails(result);
    },
  );
});

describe('First private image upload grant', () => {
  test(
    'allows a server-granted first private image upload',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'first-private-image-message';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId,
        messageId,
        version,
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a first private image upload without a grant',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'first-image-without-grant';
      const version = 'v1';

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a grant issued to another uploader',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'grant-another-uploader';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        uploaderId: outsider.uid,
        peerId: sender.uid,
        chatId,
        messageId,
        version,
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a grant belonging to another chat',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'grant-another-chat';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId: 'user-1_user-2',
        messageId,
        version,
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a grant containing another message ID',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'grant-message-id-path';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        grantDocumentId: messageId,
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId,
        messageId: 'grant-message-id-data',
        version,
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a grant containing another version',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'grant-another-version';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId,
        messageId,
        version: 'v2',
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects an expired first private image grant',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'expired-first-image-grant';
      const version = 'v1';

      await seedFirstPrivateImageUploadGrant({
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId,
        messageId,
        version,
        createdAt:
            new Date(Date.now() - (6 * 60 * 1000)),
        expiresAt:
            new Date(Date.now() - (60 * 1000)),
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );

  test(
    'rejects a grant valid for longer than ten minutes',
    async () => {
      const chatId = 'user-1_user-3';
      const messageId = 'overlong-first-image-grant';
      const version = 'v1';
      const createdAt = new Date(Date.now() - 1000);

      await seedFirstPrivateImageUploadGrant({
        uploaderId: sender.uid,
        peerId: outsider.uid,
        chatId,
        messageId,
        version,
        createdAt,
        expiresAt:
            new Date(createdAt.getTime() + (11 * 60 * 1000)),
      });

      const result = uploadJpeg({
        user: sender,
        storagePath:
            `chat_media/${chatId}/`
            + `messages/${messageId}/${version}/thumb.jpg`,
        sizeBytes: 24 * 1024,
        customMetadata: {
          ...imageMessageCustomMetadata({
            uploaderId: sender.uid,
            chatId,
            messageId,
            version,
          }),
          uploadGrantType: 'first_private_image',
        },
      });

      await assertFails(result);
    },
  );
});

describe('Existing avatar Storage baseline', () => {
  test(
    'allows a user to upload their versioned thumbnail',
    async () => {
      const result = uploadJpeg({
        user: sender,
        storagePath:
            `user_avatars/${sender.uid}/v1/thumb.jpg`,
        sizeBytes: 24 * 1024,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'allows another signed-in user to read a user avatar',
    async () => {
      const storagePath =
          `user_avatars/${sender.uid}/v1/thumb.jpg`;

      await seedStorageObject({
        storagePath,
        sizeBytes: 24 * 1024,
      });

      const result = getMetadata(
        storageReference(peer, storagePath),
      );

      await assertSucceeds(result);
    },
  );

  test(
    'rejects uploading an avatar for another user',
    async () => {
      const result = uploadJpeg({
        user: peer,
        storagePath:
            `user_avatars/${sender.uid}/v1/thumb.jpg`,
        sizeBytes: 24 * 1024,
      });

      await assertFails(result);
    },
  );

  test(
    'allows a group owner to upload a versioned full avatar',
    async () => {
      const result = uploadJpeg({
        user: sender,
        storagePath:
            `group_avatars/${groupChatId}/v1/full.jpg`,
        sizeBytes: 280 * 1024,
      });

      await assertSucceeds(result);
    },
  );

  test(
    'rejects a regular member group avatar upload',
    async () => {
      const result = uploadJpeg({
        user: peer,
        storagePath:
            `group_avatars/${groupChatId}/v1/thumb.jpg`,
        sizeBytes: 24 * 1024,
      });

      await assertFails(result);
    },
  );
});
async function configureGroupPeerAccess({
  role,
  messagePermission,
  statusData = {
    status: 'normal',
  },
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

      await setDoc(
        doc(database, 'chats', groupChatId),
        {
          memberRoles: {
            [sender.uid]: 'owner',
            [peer.uid]: role,
          },
          memberStatus: {
            [sender.uid]: {
              status: 'normal',
            },
            [peer.uid]: statusData,
          },
          groupSettings: {
            messagePermission,
          },
        },
        {
          merge: true,
        },
      );
    },
  );
}

function uploadGroupThumbnail({
  user,
  messageId,
  version = 'v1',
}) {
  return uploadJpeg({
    user,
    storagePath:
        `chat_media/${groupChatId}/`
        + `messages/${messageId}/${version}/thumb.jpg`,
    sizeBytes: 24 * 1024,
    customMetadata: imageMessageCustomMetadata({
      uploaderId: user.uid,
      chatId: groupChatId,
      messageId,
      version,
    }),
  });
}
async function seedMessageDocument(messageId) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

      await setDoc(
        doc(
          database,
          'chats',
          privateChatId,
          'messages',
          messageId,
        ),
        {
          messageType: 'image',
          text: '',
          senderId: sender.uid,
          createdAt:
              new Date('2026-07-30T10:00:00.000Z'),
        },
      );
    },
  );
}
async function seedFirstPrivateImageUploadGrant({
  grantDocumentId,
  uploaderId,
  peerId,
  chatId,
  messageId,
  version,
  createdAt = new Date(Date.now() - 1000),
  expiresAt =
      new Date(Date.now() + (5 * 60 * 1000)),
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

      await setDoc(
        doc(
          database,
          'imageMessageUploadGrants',
          grantDocumentId ?? messageId,
        ),
        {
          grantType: 'first_private_image',
          uploaderId,
          peerId,
          chatId,
          messageId,
          version,
          createdAt,
          expiresAt,
        },
      );
    },
  );
}

async function seedChats() {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();
      const seedTimestamp =
          new Date('2026-07-30T09:00:00.000Z');

      await setDoc(
        doc(database, 'chats', privateChatId),
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

      await setDoc(
        doc(database, 'chats', groupChatId),
        {
          name: 'Storage Rules Group',
          type: 'group',
          memberIds: [
            sender.uid,
            peer.uid,
          ],
          memberEmails: [
            sender.email,
            peer.email,
          ],
          memberRoles: {
            [sender.uid]: 'owner',
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
          lastMessage: 'Previous group message',
          lastMessageAt: seedTimestamp,
          lastMessageId: 'previous-group-message',
        },
      );
    },
  );
}

async function seedStorageObject({
  storagePath,
  sizeBytes,
  customMetadata,
}) {
  await testEnvironment.withSecurityRulesDisabled(
    async (context) => {
      const metadata = {
        contentType: 'image/jpeg',
      };

      if (customMetadata != null) {
        metadata.customMetadata = customMetadata;
      }

      await uploadBytes(
        ref(context.storage(), storagePath),
        jpegBytes(sizeBytes),
        metadata,
      );
    },
  );
}

function imageMessageCustomMetadata({
  uploaderId,
  chatId,
  messageId,
  version,
}) {
  return {
    uploaderId,
    chatId,
    messageId,
    version,
  };
}

function uploadJpeg({
  user,
  storagePath,
  sizeBytes,
  contentType = 'image/jpeg',
  customMetadata,
}) {
  const metadata = {
    contentType,
  };

  if (customMetadata != null) {
    metadata.customMetadata = customMetadata;
  }

  return uploadBytes(
    storageReference(user, storagePath),
    jpegBytes(sizeBytes),
    metadata,
  );
}

function storageReference(user, storagePath) {
  const context = testEnvironment.authenticatedContext(
    user.uid,
    {
      email: user.email,
    },
  );

  return ref(context.storage(), storagePath);
}

function jpegBytes(sizeBytes) {
  return new Uint8Array(sizeBytes);
}