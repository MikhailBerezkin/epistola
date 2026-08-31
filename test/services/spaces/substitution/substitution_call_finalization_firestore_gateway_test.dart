import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('finalizePendingCall', () {
    test('creates first yearly statistics and deletes pending call', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '1': _pendingCallData(
            callId: '1',
            revision: 1,
            userId: 'user-1',
            shiftYear: 2026,
            shiftMonth: 8,
            shiftDay: 31,
            shiftKind: 'day',
          ),
        },
      );

      final gateway = _gateway(context);

      final finalized = await gateway.finalizePendingCall(callId: '1');

      expect(finalized, isTrue);

      expect(context.pendingCallReads, <String>['1']);
      expect(context.statisticsReads, <int>[2026]);

      expect(context.statisticsWrites, hasLength(1));

      final write = context.statisticsWrites.single;

      expect(write.year, 2026);
      expect(write.data['year'], 2026);
      expect(write.data['lastFinalizedCallId'], '1');
      expect(write.data['updatedAt'], isA<FieldValue>());

      expect(write.data['monthCallCounts'], <String, dynamic>{
        '8': <String, dynamic>{'user-1': 1},
      });

      expect(write.data['monthShifts'], <String, dynamic>{
        '8': <String, dynamic>{
          'user-1': <String>['day'],
        },
      });

      expect(write.data['yearCallCounts'], <String, dynamic>{'user-1': 1});

      expect(context.pendingCallDeletes, <String>['1']);
    });

    test('adds confirmed night shift to existing statistics', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '2': _pendingCallData(
            callId: '2',
            revision: 2,
            userId: 'user-1',
            shiftYear: 2026,
            shiftMonth: 8,
            shiftDay: 31,
            shiftKind: 'night',
          ),
        },
        statistics: <int, Map<String, dynamic>>{
          2026: _statisticsData(
            year: 2026,
            lastFinalizedCallId: '1',
            monthCallCounts: <String, dynamic>{
              '8': <String, dynamic>{'user-1': 1},
            },
            monthShifts: <String, dynamic>{
              '8': <String, dynamic>{
                'user-1': <String>['day'],
              },
            },
            yearCallCounts: <String, dynamic>{'user-1': 1},
          ),
        },
      );

      final finalized = await _gateway(
        context,
      ).finalizePendingCall(callId: '2');

      expect(finalized, isTrue);

      final data = context.statisticsWrites.single.data;

      expect(data['monthCallCounts'], <String, dynamic>{
        '8': <String, dynamic>{'user-1': 2},
      });

      expect(data['monthShifts'], <String, dynamic>{
        '8': <String, dynamic>{
          'user-1': <String>['day', 'night'],
        },
      });

      expect(data['yearCallCounts'], <String, dynamic>{'user-1': 2});

      expect(data['lastFinalizedCallId'], '2');
      expect(context.pendingCallDeletes, <String>['2']);
    });

    test('starts new month while preserving previous month', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '2': _pendingCallData(
            callId: '2',
            revision: 2,
            userId: 'user-1',
            shiftYear: 2026,
            shiftMonth: 9,
            shiftDay: 1,
            shiftKind: 'day',
          ),
        },
        statistics: <int, Map<String, dynamic>>{
          2026: _statisticsData(
            year: 2026,
            lastFinalizedCallId: '1',
            monthCallCounts: <String, dynamic>{
              '8': <String, dynamic>{'user-1': 1},
            },
            monthShifts: <String, dynamic>{
              '8': <String, dynamic>{
                'user-1': <String>['night'],
              },
            },
            yearCallCounts: <String, dynamic>{'user-1': 1},
          ),
        },
      );

      final finalized = await _gateway(
        context,
      ).finalizePendingCall(callId: '2');

      expect(finalized, isTrue);

      final data = context.statisticsWrites.single.data;

      expect(data['monthCallCounts'], <String, dynamic>{
        '8': <String, dynamic>{'user-1': 1},
        '9': <String, dynamic>{'user-1': 1},
      });

      expect(data['monthShifts'], <String, dynamic>{
        '8': <String, dynamic>{
          'user-1': <String>['night'],
        },
        '9': <String, dynamic>{
          'user-1': <String>['day'],
        },
      });

      expect(data['yearCallCounts'], <String, dynamic>{'user-1': 2});
    });

    test('december night shift remains in shift start year', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '10': _pendingCallData(
            callId: '10',
            revision: 10,
            userId: 'user-1',
            shiftYear: 2026,
            shiftMonth: 12,
            shiftDay: 31,
            shiftKind: 'night',
          ),
        },
      );

      final finalized = await _gateway(
        context,
      ).finalizePendingCall(callId: '10');

      expect(finalized, isTrue);
      expect(context.statisticsReads, <int>[2026]);
      expect(context.statisticsWrites.single.year, 2026);

      expect(
        context.statisticsWrites.single.data['monthCallCounts'],
        <String, dynamic>{
          '12': <String, dynamic>{'user-1': 1},
        },
      );
    });

    test('missing pending call is harmless and writes nothing', () async {
      final context = _FakeFinalizationContext();

      final finalized = await _gateway(
        context,
      ).finalizePendingCall(callId: '7');

      expect(finalized, isFalse);
      expect(context.pendingCallReads, <String>['7']);
      expect(context.statisticsReads, isEmpty);
      expect(context.statisticsWrites, isEmpty);
      expect(context.pendingCallDeletes, isEmpty);
    });

    test('malformed pending call throws state error', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '7': <String, dynamic>{'callId': '7', 'userId': 'user-1'},
        },
      );

      await expectLater(
        _gateway(context).finalizePendingCall(callId: '7'),
        throwsStateError,
      );

      expect(context.statisticsReads, isEmpty);
      expect(context.statisticsWrites, isEmpty);
      expect(context.pendingCallDeletes, isEmpty);
    });

    test('malformed existing statistics throws state error', () async {
      final context = _FakeFinalizationContext(
        pendingCalls: <String, Map<String, dynamic>>{
          '8': _pendingCallData(
            callId: '8',
            revision: 8,
            userId: 'user-1',
            shiftYear: 2026,
            shiftMonth: 8,
            shiftDay: 31,
            shiftKind: 'night',
          ),
        },
        statistics: <int, Map<String, dynamic>>{
          2026: <String, dynamic>{'year': 2026},
        },
      );

      await expectLater(
        _gateway(context).finalizePendingCall(callId: '8'),
        throwsStateError,
      );

      expect(context.statisticsWrites, isEmpty);
      expect(context.pendingCallDeletes, isEmpty);
    });

    test('invalid call id is rejected before transaction', () {
      final context = _FakeFinalizationContext();
      final runner = _FakeFinalizationRunner(context);
      final gateway = SubstitutionCallFinalizationFirestoreGateway(runner);

      expect(
        () => gateway.finalizePendingCall(callId: '08'),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
    });
  });

  group('statisticsDocumentId', () {
    test('uses stable yearly document id', () {
      expect(
        SubstitutionCallFinalizationFirestoreGateway.statisticsDocumentId(2026),
        'year_2026',
      );
    });
  });
}

SubstitutionCallFinalizationFirestoreGateway _gateway(
  _FakeFinalizationContext context,
) {
  return SubstitutionCallFinalizationFirestoreGateway(
    _FakeFinalizationRunner(context),
  );
}

Map<String, dynamic> _pendingCallData({
  required String callId,
  required int revision,
  required String userId,
  required int shiftYear,
  required int shiftMonth,
  required int shiftDay,
  required String shiftKind,
}) {
  return <String, dynamic>{
    'callId': callId,
    'userId': userId,
    'revision': revision,
    'calledByUserId': 'brigadier-1',
    'calledAt': Timestamp.fromDate(DateTime.utc(2026, 8, 31, 10)),
    'shiftYear': shiftYear,
    'shiftMonth': shiftMonth,
    'shiftDay': shiftDay,
    'shiftKind': shiftKind,
  };
}

Map<String, dynamic> _statisticsData({
  required int year,
  required String lastFinalizedCallId,
  required Map<String, dynamic> monthCallCounts,
  required Map<String, dynamic> monthShifts,
  required Map<String, dynamic> yearCallCounts,
}) {
  return <String, dynamic>{
    'year': year,
    'monthCallCounts': monthCallCounts,
    'monthShifts': monthShifts,
    'yearCallCounts': yearCallCounts,
    'lastFinalizedCallId': lastFinalizedCallId,
    'updatedAt': Timestamp.fromDate(DateTime.utc(year, 8, 20, 10)),
  };
}

final class _FakeFinalizationRunner
    implements SubstitutionCallFinalizationTransactionRunner {
  _FakeFinalizationRunner(this.context);

  final SubstitutionCallFinalizationTransactionContext context;

  int runCount = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallFinalizationTransactionContext context)
    action,
  ) async {
    runCount += 1;
    return action(context);
  }
}

final class _FakeFinalizationContext
    implements SubstitutionCallFinalizationTransactionContext {
  _FakeFinalizationContext({
    Map<String, Map<String, dynamic>> pendingCalls =
        const <String, Map<String, dynamic>>{},
    Map<int, Map<String, dynamic>> statistics =
        const <int, Map<String, dynamic>>{},
  }) : _pendingCalls = pendingCalls.map(
         (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
       ),
       _statistics = statistics.map(
         (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
       );

  final Map<String, Map<String, dynamic>> _pendingCalls;
  final Map<int, Map<String, dynamic>> _statistics;

  final List<String> pendingCallReads = <String>[];
  final List<int> statisticsReads = <int>[];
  final List<_StatisticsWrite> statisticsWrites = <_StatisticsWrite>[];
  final List<String> pendingCallDeletes = <String>[];

  @override
  Future<Map<String, dynamic>?> readPendingCall({
    required String callId,
  }) async {
    pendingCallReads.add(callId);

    final data = _pendingCalls[callId];

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> readStatistics({required int year}) async {
    statisticsReads.add(year);

    final data = _statistics[year];

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  void writeStatistics({
    required int year,
    required Map<String, dynamic> data,
  }) {
    statisticsWrites.add(
      _StatisticsWrite(year: year, data: Map<String, dynamic>.from(data)),
    );
  }

  @override
  void deletePendingCall({required String callId}) {
    pendingCallDeletes.add(callId);
  }
}

final class _StatisticsWrite {
  const _StatisticsWrite({required this.year, required this.data});

  final int year;
  final Map<String, dynamic> data;
}
