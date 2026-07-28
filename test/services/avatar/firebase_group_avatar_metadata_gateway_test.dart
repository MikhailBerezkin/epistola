import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/firebase_group_avatar_metadata_gateway.dart';
import 'package:epistola/services/avatar/group_avatar_metadata_gateway.dart';
import 'package:epistola/services/avatar/group_avatar_metadata_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prepareGroupAvatarMetadataReplacement', () {
    test('prepares the first avatar for a group', () {
      final candidate = _avatar(chatId: 'group-1', version: 7);

      final replacement = prepareGroupAvatarMetadataReplacement(
        chatId: 'group-1',
        currentData: const {'type': 'group'},
        candidateAvatar: candidate,
      );

      expect(replacement.previousAvatar, isNull);
      expect(
        replacement.metadata,
        GroupAvatarMetadataMapper.toMap(chatId: 'group-1', avatar: candidate),
      );
    });

    test('returns the previous avatar before replacement', () {
      final previous = _avatar(chatId: 'group-1', version: 7);

      final candidate = _avatar(chatId: 'group-1', version: 9);

      final replacement = prepareGroupAvatarMetadataReplacement(
        chatId: 'group-1',
        currentData: {
          'type': 'group',
          ...GroupAvatarMetadataMapper.toMap(
            chatId: 'group-1',
            avatar: previous,
          ),
        },
        candidateAvatar: candidate,
      );

      expect(replacement.previousAvatar, isNotNull);
      expect(replacement.previousAvatar!.version, 7);
      expect(replacement.metadata['groupAvatarVersion'], 9);
    });

    for (final candidateVersion in [6, 7]) {
      test('rejects candidate version $candidateVersion '
          'when active version is 7', () {
        expect(
          () => prepareGroupAvatarMetadataReplacement(
            chatId: 'group-1',
            currentData: {
              'type': 'group',
              ...GroupAvatarMetadataMapper.toMap(
                chatId: 'group-1',
                avatar: _avatar(chatId: 'group-1', version: 7),
              ),
            },
            candidateAvatar: _avatar(
              chatId: 'group-1',
              version: candidateVersion,
            ),
          ),
          throwsA(
            isA<GroupAvatarVersionConflictException>()
                .having(
                  (error) => error.candidateVersion,
                  'candidateVersion',
                  candidateVersion,
                )
                .having((error) => error.activeVersion, 'activeVersion', 7),
          ),
        );
      });
    }

    test('rejects a private chat target', () {
      expect(
        () => prepareGroupAvatarMetadataReplacement(
          chatId: 'private-1',
          currentData: const {'type': 'private'},
          candidateAvatar: _avatar(chatId: 'private-1', version: 3),
        ),
        throwsA(
          isA<GroupAvatarTargetTypeException>()
              .having((error) => error.chatId, 'chatId', 'private-1')
              .having((error) => error.actualType, 'actualType', 'private'),
        ),
      );
    });

    test('rejects an empty chat id', () {
      expect(
        () => prepareGroupAvatarMetadataReplacement(
          chatId: '   ',
          currentData: const {'type': 'group'},
          candidateAvatar: _avatar(chatId: 'group-1', version: 3),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an avatar belonging to another group', () {
      expect(
        () => prepareGroupAvatarMetadataReplacement(
          chatId: 'group-1',
          currentData: const {'type': 'group'},
          candidateAvatar: _avatar(chatId: 'group-2', version: 3),
        ),
        throwsArgumentError,
      );
    });
  });
}

GroupAvatar _avatar({required String chatId, required int version}) {
  final updatedAt = DateTime.utc(2026, 7, 28, 16);

  return GroupAvatar(
    thumbnail: MediaAsset(
      id: 'group-avatar-$chatId-v$version-thumb',
      provider: 'firebase',
      path: 'group_avatars/$chatId/v$version/thumb.jpg',
      type: 'groupAvatarThumbnail',
      ownerType: 'group',
      ownerId: chatId,
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      width: 128,
      height: 128,
      version: version,
      updatedAt: updatedAt,
    ),
    full: MediaAsset(
      id: 'group-avatar-$chatId-v$version-full',
      provider: 'firebase',
      path: 'group_avatars/$chatId/v$version/full.jpg',
      type: 'groupAvatarFull',
      ownerType: 'group',
      ownerId: chatId,
      mimeType: 'image/jpeg',
      sizeBytes: 240000,
      width: 512,
      height: 512,
      version: version,
      updatedAt: updatedAt,
    ),
  );
}
