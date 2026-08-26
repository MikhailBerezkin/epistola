import '../../../domain/models/substitution_call_receipt.dart';

typedef SubstitutionParticipantCaller =
    Future<SubstitutionCallReceipt> Function({required String userId});

typedef SubstitutionCallUndoer =
    Future<bool> Function({required SubstitutionCallReceipt receipt});

final class SubstitutionCallService {
  SubstitutionCallService({
    required SubstitutionParticipantCaller participantCaller,
    required SubstitutionCallUndoer callUndoer,
  }) : _callParticipant = participantCaller,
       _undoCall = callUndoer;

  final SubstitutionParticipantCaller _callParticipant;
  final SubstitutionCallUndoer _undoCall;

  Future<SubstitutionCallReceipt> callParticipant({required String userId}) {
    return _callParticipant(userId: _normalizeUserId(userId));
  }

  Future<bool> undoLastCall({required SubstitutionCallReceipt receipt}) {
    if (receipt.revision < 1) {
      throw ArgumentError.value(
        receipt.revision,
        'receipt.revision',
        'revision must be greater than zero.',
      );
    }

    final normalizedUserId = _normalizeUserId(receipt.userId);

    return _undoCall(
      receipt: SubstitutionCallReceipt(
        userId: normalizedUserId,
        revision: receipt.revision,
      ),
    );
  }

  static String _normalizeUserId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'userId',
        'userId must be non-empty and must not contain slashes.',
      );
    }

    return normalized;
  }
}
