import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenService {
  static const _installationIdKey = 'push_installation_id';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_registerCurrentToken(user));
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      unawaited(_saveToken(user: user, token: token));
    });
  }

  static Future<void> unregisterCurrentDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final installationId = await _getInstallationId();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(installationId)
          .delete();

      if (kDebugMode) {
        debugPrint('Push device unregistered');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push device unregister error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _registerCurrentToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _saveToken(user: user, token: token);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push token registration error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _saveToken({
    required User user,
    required String token,
  }) async {
    try {
      final installationId = await _getInstallationId();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(installationId)
          .set({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (kDebugMode) {
        debugPrint('Push token registered');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push token save error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<String> _getInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existingId = preferences.getString(_installationIdKey);

    if (existingId != null && existingId.length == 32) {
      return existingId;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final installationId = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    await preferences.setString(_installationIdKey, installationId);
    return installationId;
  }
}
