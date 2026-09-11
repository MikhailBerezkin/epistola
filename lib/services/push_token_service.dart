import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenService {
  static const _installationIdKey = 'push_installation_id';
  static const _functionsRegion = 'europe-west1';

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: _functionsRegion,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;

      unawaited(_registerCurrentToken());
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (FirebaseAuth.instance.currentUser == null) return;

      unawaited(_claimToken(token));
    });
  }

  static Future<void> unregisterCurrentDevice() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final installationId = await _getInstallationId();

      await _functions.httpsCallable('releasePushInstallation').call({
        'installationId': installationId,
      });

      if (kDebugMode) {
        debugPrint('Push installation released');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push installation release error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _claimToken(token);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push token registration error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _claimToken(String token) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        return;
      }

      final installationId = await _getInstallationId();

      await _functions.httpsCallable('claimPushInstallation').call({
        'installationId': installationId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      });

      if (kDebugMode) {
        debugPrint('Push installation claimed');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push installation claim error: $error');
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
