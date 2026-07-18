import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl; // временно, для совместимости

  final String avatarThumbUrl;
  final String avatarFullUrl;

  final String avatarThumbStoragePath;
  final String avatarFullStoragePath;
  final String avatarStoragePath;
  final String avatarProvider;
  final int avatarVersion;
  final DateTime? avatarUpdatedAt;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.about,
    required this.avatarUrl,
    required this.avatarThumbUrl,
    required this.avatarFullUrl,
    required this.avatarThumbStoragePath,
    required this.avatarFullStoragePath,
    required this.avatarStoragePath,
    required this.avatarProvider,
    required this.avatarVersion,
    this.avatarUpdatedAt,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final avatarUpdatedAt = data['avatarUpdatedAt'];

    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      about: data['about'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      avatarThumbUrl: data['avatarThumbUrl'] ?? data['avatarUrl'] ?? '',
      avatarFullUrl: data['avatarFullUrl'] ?? data['avatarUrl'] ?? '',
      avatarThumbStoragePath:
          data['avatarThumbStoragePath'] ?? data['avatarStoragePath'] ?? '',
      avatarFullStoragePath:
          data['avatarFullStoragePath'] ?? data['avatarStoragePath'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      avatarStoragePath: data['avatarStoragePath'] ?? '',
      avatarProvider: data['avatarProvider'] ?? 'firebase',
      avatarVersion: data['avatarVersion'] ?? 0,
      avatarUpdatedAt: avatarUpdatedAt is Timestamp
          ? avatarUpdatedAt.toDate()
          : null,
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser.fromMap(data);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'about': about,
      'avatarUrl': avatarUrl,
      'avatarThumbUrl': avatarThumbUrl,
      'avatarFullUrl': avatarFullUrl,
      'avatarThumbStoragePath': avatarThumbStoragePath,
      'avatarFullStoragePath': avatarFullStoragePath,
      'createdAt': createdAt,
      'avatarStoragePath': avatarStoragePath,
      'avatarProvider': avatarProvider,
      'avatarVersion': avatarVersion,
      'avatarUpdatedAt': avatarUpdatedAt,
    };
  }
}
