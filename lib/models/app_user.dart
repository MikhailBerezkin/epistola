import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/media_asset.dart';
import '../domain/models/user_avatar.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String about;

  /// Старое поле сохраняется временно для совместимости
  /// с существующими документами пользователей.
  final String avatarUrl;

  final UserAvatar? avatar;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.about,
    this.avatarUrl = '',
    this.avatar,
    this.createdAt,
  });

  UserAvatar? get effectiveAvatar {
    final currentAvatar = avatar;

    if (currentAvatar == null || !currentAvatar.isComplete) {
      return null;
    }

    return currentAvatar;
  }

  String? get effectiveAvatarThumbnailUrl {
    final thumbnailUrl = effectiveAvatar?.thumbnailUrl?.trim();

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    return effectiveAvatarFullUrl;
  }

  String? get effectiveAvatarFullUrl {
    final fullUrl = effectiveAvatar?.fullUrl?.trim();

    if (fullUrl != null && fullUrl.isNotEmpty) {
      return fullUrl;
    }

    final legacyUrl = avatarUrl.trim();

    return legacyUrl.isEmpty ? null : legacyUrl;
  }

  bool get hasAvatar => effectiveAvatarFullUrl != null;

  factory AppUser.fromMap(Map<String, dynamic> data) {
    final uid = _readString(data['uid']);

    return AppUser(
      uid: uid,
      email: _readString(data['email']),
      name: _readString(data['name']),
      phone: _readString(data['phone']),
      about: _readString(data['about']),
      avatarUrl: _readString(data['avatarUrl']),
      avatar: _readAvatar(data: data, userId: uid),
      createdAt: _readDateTime(data['createdAt']),
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();

    if (data is! Map<String, dynamic>) {
      return AppUser(uid: doc.id, email: '', name: '', phone: '', about: '');
    }

    final normalizedData = Map<String, dynamic>.from(data);

    if (_readString(normalizedData['uid']).isEmpty) {
      normalizedData['uid'] = doc.id;
    }

    return AppUser.fromMap(normalizedData);
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'about': about,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt,
    };

    final currentAvatar = effectiveAvatar;

    if (currentAvatar != null) {
      data.addAll({
        'avatarProvider': currentAvatar.provider,
        'avatarThumbUrl': currentAvatar.thumbnailUrl,
        'avatarFullUrl': currentAvatar.fullUrl,
        'avatarThumbStoragePath': currentAvatar.thumbnailStoragePath,
        'avatarFullStoragePath': currentAvatar.fullStoragePath,
        'avatarVersion': currentAvatar.version,
        'avatarUpdatedAt': currentAvatar.updatedAt,
      });
    }

    return data;
  }

  static UserAvatar? _readAvatar({
    required Map<String, dynamic> data,
    required String userId,
  }) {
    final provider = _readString(data['avatarProvider']);
    final thumbnailUrl = _readString(data['avatarThumbUrl']);
    final fullUrl = _readString(data['avatarFullUrl']);
    final thumbnailPath = _readString(data['avatarThumbStoragePath']);
    final fullPath = _readString(data['avatarFullStoragePath']);
    final version = _readInt(data['avatarVersion']);
    final updatedAt = _readDateTime(data['avatarUpdatedAt']);

    final hasCompleteMetadata =
        userId.isNotEmpty &&
        provider.isNotEmpty &&
        thumbnailUrl.isNotEmpty &&
        fullUrl.isNotEmpty &&
        thumbnailPath.isNotEmpty &&
        fullPath.isNotEmpty &&
        version > 0;

    if (!hasCompleteMetadata) {
      return null;
    }

    final avatar = UserAvatar(
      thumbnail: MediaAsset(
        id: 'user-avatar-$userId-v$version-thumb',
        provider: provider,
        path: thumbnailPath,
        type: 'userAvatarThumbnail',
        ownerType: 'user',
        ownerId: userId,
        mimeType: 'image/jpeg',
        version: version,
        updatedAt: updatedAt,
        downloadUrl: thumbnailUrl,
      ),
      full: MediaAsset(
        id: 'user-avatar-$userId-v$version-full',
        provider: provider,
        path: fullPath,
        type: 'userAvatarFull',
        ownerType: 'user',
        ownerId: userId,
        mimeType: 'image/jpeg',
        version: version,
        updatedAt: updatedAt,
        downloadUrl: fullUrl,
      ),
    );

    return avatar.isComplete ? avatar : null;
  }

  static String _readString(dynamic value) {
    return value is String ? value.trim() : '';
  }

  static int _readInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
