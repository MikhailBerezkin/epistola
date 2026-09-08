import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../chat_service.dart';

typedef _ChatUnreadSignature = ({
  int? lastMessageMicroseconds,
  int? afterMicroseconds,
});

class ChatUnreadSummaryController extends ChangeNotifier {
  ChatUnreadSummaryController({ChatService? chatService, FirebaseAuth? auth})
    : _chatService = chatService ?? ChatService(),
      _auth = auth ?? FirebaseAuth.instance;

  final ChatService _chatService;
  final FirebaseAuth _auth;

  StreamSubscription<QuerySnapshot>? _subscription;

  List<QueryDocumentSnapshot> _chats = const [];
  Map<String, int> _unreadCounts = const {};
  Map<String, _ChatUnreadSignature> _signatures = const {};

  bool _isLoading = true;
  Object? _error;
  int _generation = 0;
  bool _isDisposed = false;

  List<QueryDocumentSnapshot> get chats => List.unmodifiable(_chats);

  bool get isLoading => _isLoading;

  Object? get error => _error;

  int unreadCountFor(String chatId) {
    return _unreadCounts[chatId] ?? 0;
  }

  int get totalUnreadCount {
    var total = 0;

    for (final count in _unreadCounts.values) {
      total += count;
    }

    return total;
  }

  void start() {
    if (_subscription != null || _isDisposed) {
      return;
    }

    final userId = _auth.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      _isLoading = false;
      _chats = const [];
      _unreadCounts = const {};
      _signatures = const {};
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;

    _subscription = _chatService.getUserChats().listen(
      _handleSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed) {
          return;
        }

        _error = error;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _handleSnapshot(QuerySnapshot snapshot) {
    if (_isDisposed) {
      return;
    }

    _chats = snapshot.docs;
    _error = null;
    _isLoading = false;

    notifyListeners();

    unawaited(_refreshUnreadCounts(snapshot.docs));
  }

  Future<void> _refreshUnreadCounts(List<QueryDocumentSnapshot> chats) async {
    final userId = _auth.currentUser?.uid ?? '';
    final generation = ++_generation;

    if (userId.isEmpty) {
      if (_isDisposed || generation != _generation) {
        return;
      }

      _unreadCounts = const {};
      _signatures = const {};
      notifyListeners();
      return;
    }

    final nextCounts = <String, int>{};
    final nextSignatures = <String, _ChatUnreadSignature>{};
    final pendingLoads = <Future<void>>[];

    for (final chat in chats) {
      final data = chat.data();

      if (data is! Map<String, dynamic>) {
        nextCounts[chat.id] = 0;
        continue;
      }

      final lastMessageAt = data['lastMessageAt'];

      final lastReadMap =
          (data['lastRead'] as Map<String, dynamic>?) ?? const {};
      final clearedAtByUser =
          (data['clearedAtByUser'] as Map<String, dynamic>?) ?? const {};

      final lastRead = lastReadMap[userId];
      final clearedAt = clearedAtByUser[userId];

      final effectiveAfter = _latestTimestamp(
        lastRead is Timestamp ? lastRead : null,
        clearedAt is Timestamp ? clearedAt : null,
      );

      final signature = (
        lastMessageMicroseconds: lastMessageAt is Timestamp
            ? lastMessageAt.microsecondsSinceEpoch
            : null,
        afterMicroseconds: effectiveAfter?.microsecondsSinceEpoch,
      );

      nextSignatures[chat.id] = signature;

      if (lastMessageAt is! Timestamp) {
        nextCounts[chat.id] = 0;
        continue;
      }

      if (effectiveAfter != null &&
          !lastMessageAt.toDate().isAfter(effectiveAfter.toDate())) {
        nextCounts[chat.id] = 0;
        continue;
      }

      final previousSignature = _signatures[chat.id];
      final previousCount = _unreadCounts[chat.id];

      if (previousSignature == signature && previousCount != null) {
        nextCounts[chat.id] = previousCount;
        continue;
      }

      pendingLoads.add(
        _chatService
            .getUnreadCountAfter(chat.id, after: effectiveAfter)
            .then((unreadCount) {
              nextCounts[chat.id] = unreadCount;
            })
            .catchError((Object _) {
              nextCounts[chat.id] = previousCount ?? 0;
            }),
      );
    }

    await Future.wait(pendingLoads);

    if (_isDisposed || generation != _generation) {
      return;
    }

    _unreadCounts = Map.unmodifiable(nextCounts);
    _signatures = Map.unmodifiable(nextSignatures);

    notifyListeners();
  }

  Timestamp? _latestTimestamp(Timestamp? first, Timestamp? second) {
    if (first == null) {
      return second;
    }

    if (second == null) {
      return first;
    }

    return first.toDate().isAfter(second.toDate()) ? first : second;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;

    unawaited(_subscription?.cancel());
    _subscription = null;

    super.dispose();
  }
}
