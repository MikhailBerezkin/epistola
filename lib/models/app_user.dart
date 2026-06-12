import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.about,
    required this.avatarUrl,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];

    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      about: data['about'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
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
      'createdAt': createdAt,
    };
  }
}
