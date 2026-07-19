import 'package:epistola/domain/models/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaAsset', () {
    test('serializes to map and restores all fields', () {
      final createdAt = DateTime.utc(2026, 7, 18, 10, 30);
      final updatedAt = DateTime.utc(2026, 7, 18, 11, 45);

      final asset = MediaAsset(
        id: 'avatar-user-1-v2',
        provider: 'firebase',
        path: 'user_avatars/user-1/v2/full.jpg',
        type: 'avatar',
        ownerType: 'user',
        ownerId: 'user-1',
        mimeType: 'image/jpeg',
        sizeBytes: 120000,
        width: 1024,
        height: 1024,
        version: 2,
        createdAt: createdAt,
        updatedAt: updatedAt,
        downloadUrl: 'https://example.com/avatar.jpg',
      );

      final restored = MediaAsset.fromMap(asset.toMap());

      expect(restored.id, asset.id);
      expect(restored.provider, asset.provider);
      expect(restored.path, asset.path);
      expect(restored.type, asset.type);
      expect(restored.ownerType, asset.ownerType);
      expect(restored.ownerId, asset.ownerId);
      expect(restored.mimeType, asset.mimeType);
      expect(restored.sizeBytes, asset.sizeBytes);
      expect(restored.width, asset.width);
      expect(restored.height, asset.height);
      expect(restored.version, asset.version);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
      expect(restored.downloadUrl, asset.downloadUrl);
    });

    test('uses safe defaults for missing required map values', () {
      final asset = MediaAsset.fromMap({});

      expect(asset.id, isEmpty);
      expect(asset.provider, isEmpty);
      expect(asset.path, isEmpty);
      expect(asset.type, isEmpty);
      expect(asset.version, 1);
      expect(asset.ownerId, isNull);
      expect(asset.downloadUrl, isNull);
    });

    test('copyWith changes only selected fields', () {
      const original = MediaAsset(
        id: 'asset-1',
        provider: 'firebase',
        path: 'original/path.jpg',
        type: 'image',
        version: 1,
      );

      final updated = original.copyWith(path: 'updated/path.jpg', version: 2);

      expect(updated.id, original.id);
      expect(updated.provider, original.provider);
      expect(updated.type, original.type);
      expect(updated.path, 'updated/path.jpg');
      expect(updated.version, 2);
    });
  });
}
