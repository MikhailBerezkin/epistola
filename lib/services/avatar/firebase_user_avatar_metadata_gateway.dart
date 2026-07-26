import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user_avatar.dart';
import '../../models/app_user.dart';
import 'user_avatar_metadata_gateway.dart';

final class FirebaseUserAvatarMetadataGateway
    implements UserAvatarMetadataGateway {
  FirebaseUserAvatarMetadataGateway({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<UserAvatar?> replace({
    required String uid,
    required UserAvatar avatar,
  }) {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID must not be empty.');
    }

    if (!avatar.isComplete ||
        avatar.thumbnail.ownerId != normalizedUid ||
        avatar.full.ownerId != normalizedUid) {
      throw ArgumentError.value(
        avatar,
        'avatar',
        'Avatar must be complete and owned by the requested user.',
      );
    }

    final userReference = _firestore.collection('users').doc(normalizedUid);

    return _firestore.runTransaction<UserAvatar?>((transaction) async {
      final snapshot = await transaction.get(userReference);
      final snapshotData = snapshot.data();
      final data = snapshotData is Map<String, dynamic> ? snapshotData : null;
      final activeVersion = _readVersion(data?['avatarVersion']);

      requireNewerAvatarVersion(
        candidateVersion: avatar.version,
        activeVersion: activeVersion,
      );

      final previousAvatar = data == null
          ? null
          : AppUser.fromMap({...data, 'uid': normalizedUid}).effectiveAvatar;

      transaction.update(userReference, AppUser.avatarMetadataToMap(avatar));

      return previousAvatar;
    });
  }

  static int _readVersion(dynamic value) {
    if (value is! num) {
      return 0;
    }

    final version = value.toInt();
    return version > 0 ? version : 0;
  }
}
