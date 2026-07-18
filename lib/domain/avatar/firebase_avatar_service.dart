import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/media/media_storage_service.dart';
import '../models/avatar_upload_request.dart';
import 'avatar_service.dart';
import 'avatar_image_processor.dart';

class FirebaseAvatarService implements AvatarService {
  final FirebaseFirestore _firestore;
  final MediaStorageService _mediaStorageService;
  final AvatarImageProcessor _imageProcessor;

  FirebaseAvatarService({
    FirebaseFirestore? firestore,
    MediaStorageService? mediaStorageService,
    AvatarImageProcessor? imageProcessor,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _mediaStorageService = mediaStorageService ?? MediaStorageService(),
       _imageProcessor = imageProcessor ?? AvatarImageProcessor();

  @override
  Future<void> uploadAvatar({
    required String userId,
    required AvatarUploadRequest request,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();

    final currentVersion = userData?['avatarVersion'];
    final nextVersion = currentVersion is int ? currentVersion + 1 : 1;

    final preparedFile = await _imageProcessor.prepareForUpload(request);

    final asset = await _mediaStorageService.uploadUserAvatar(
      userId: userId,
      file: preparedFile,
      mimeType: request.mimeType,
      version: nextVersion,
    );

    await userRef.update({
      'avatarUrl': asset.downloadUrl ?? '',
      'avatarStoragePath': asset.path,
      'avatarProvider': asset.provider,
      'avatarVersion': nextVersion,
      'avatarUpdatedAt': FieldValue.serverTimestamp(),
    });
    await _syncUserAvatarToPrivateChats(
      userId: userId,
      avatarUrl: asset.downloadUrl ?? '',
      avatarStoragePath: asset.path,
      avatarProvider: asset.provider,
      avatarVersion: nextVersion,
    );
  }

  Future<void> _syncUserAvatarToPrivateChats({
    required String userId,
    required String avatarUrl,
    required String avatarStoragePath,
    required String avatarProvider,
    required int avatarVersion,
  }) async {
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('type', isEqualTo: 'private')
        .where('memberIds', arrayContains: userId)
        .get();

    final batch = _firestore.batch();

    for (final chatDoc in chatsSnapshot.docs) {
      batch.update(chatDoc.reference, {
        'memberAvatars.$userId.thumbUrl': avatarUrl,
        'memberAvatars.$userId.fullUrl': avatarUrl,
        'memberAvatars.$userId.storagePath': avatarStoragePath,
        'memberAvatars.$userId.provider': avatarProvider,
        'memberAvatars.$userId.version': avatarVersion,
        'memberAvatars.$userId.updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> deleteAvatar({required String userId}) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();

    final avatarStoragePath = userData?['avatarStoragePath'];

    if (avatarStoragePath is String && avatarStoragePath.isNotEmpty) {
      await _mediaStorageService.deleteMedia(avatarStoragePath);
    }

    await userRef.update({
      'avatarUrl': '',
      'avatarStoragePath': '',
      'avatarProvider': 'firebase',
      'avatarVersion': FieldValue.increment(1),
      'avatarUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
