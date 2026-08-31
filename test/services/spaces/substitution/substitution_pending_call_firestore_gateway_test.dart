import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_pending_call_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps pending calls and sorts them by revision', () async {
    final reader = _FakePendingCallReader(<SubstitutionPendingCallDocument>[
      SubstitutionPendingCallDocument(
        id: '3',
        data: _pendingCallData(callId: '3', revision: 3, shiftKind: 'day'),
      ),
      SubstitutionPendingCallDocument(
        id: '1',
        data: _pendingCallData(callId: '1', revision: 1, shiftKind: 'night'),
      ),
      SubstitutionPendingCallDocument(
        id: '2',
        data: _pendingCallData(callId: '2', revision: 2, shiftKind: 'day'),
      ),
    ]);

    final gateway = SubstitutionPendingCallFirestoreGateway(reader);

    final pendingCalls = await gateway.loadPendingCalls();

    expect(pendingCalls.map((call) => call.callId).toList(), <String>[
      '1',
      '2',
      '3',
    ]);

    expect(pendingCalls.first.shift.kind, SubstitutionShiftKind.night);

    expect(pendingCalls.last.shift.kind, SubstitutionShiftKind.day);
  });

  test('rejects malformed pending call document', () async {
    final gateway = SubstitutionPendingCallFirestoreGateway(
      _FakePendingCallReader(<SubstitutionPendingCallDocument>[
        const SubstitutionPendingCallDocument(
          id: '1',
          data: <String, dynamic>{'callId': '1', 'userId': 'user-1'},
        ),
      ]),
    );

    await expectLater(gateway.loadPendingCalls(), throwsStateError);
  });

  test('rejects document id that differs from callId', () async {
    final gateway = SubstitutionPendingCallFirestoreGateway(
      _FakePendingCallReader(<SubstitutionPendingCallDocument>[
        SubstitutionPendingCallDocument(
          id: '2',
          data: _pendingCallData(callId: '1', revision: 1, shiftKind: 'night'),
        ),
      ]),
    );

    await expectLater(gateway.loadPendingCalls(), throwsStateError);
  });
}

Map<String, dynamic> _pendingCallData({
  required String callId,
  required int revision,
  required String shiftKind,
}) {
  return <String, dynamic>{
    'callId': callId,
    'userId': 'user-1',
    'revision': revision,
    'calledByUserId': 'brigadier-1',
    'calledAt': Timestamp.fromDate(DateTime.utc(2026, 8, 31, 10)),
    'shiftYear': 2026,
    'shiftMonth': 8,
    'shiftDay': 31,
    'shiftKind': shiftKind,
  };
}

final class _FakePendingCallReader implements SubstitutionPendingCallReader {
  _FakePendingCallReader(this.documents);

  final List<SubstitutionPendingCallDocument> documents;

  @override
  Future<List<SubstitutionPendingCallDocument>> readPendingCalls() async {
    return documents;
  }
}
