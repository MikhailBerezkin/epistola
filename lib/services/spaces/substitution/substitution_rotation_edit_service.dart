import '../../../domain/models/substitution_participant.dart';
import '../../../domain/models/substitution_rotation_draft.dart';

final class SubstitutionRotationEditBaseline {
  const SubstitutionRotationEditBaseline({
    required this.nextRotationOrder,
    required this.revision,
  });

  final int nextRotationOrder;
  final int revision;
}

enum SubstitutionRotationEditApplyResult { noChanges, applied, conflict }

typedef SubstitutionRotationEditBaselineLoader =
    Future<SubstitutionRotationEditBaseline> Function();

typedef SubstitutionRotationEditWriter =
    Future<bool> Function({
      required List<SubstitutionParticipant> originalParticipants,
      required List<SubstitutionParticipant> participants,
      required int expectedNextRotationOrder,
      required int expectedRevision,
    });

final class SubstitutionRotationEditService {
  SubstitutionRotationEditService({
    required SubstitutionRotationEditBaselineLoader baselineLoader,
    required SubstitutionRotationEditWriter rotationWriter,
  }) : _loadBaseline = baselineLoader,
       _writeRotation = rotationWriter;

  final SubstitutionRotationEditBaselineLoader _loadBaseline;
  final SubstitutionRotationEditWriter _writeRotation;

  Future<SubstitutionRotationEditBaseline> beginEditing() async {
    final baseline = await _loadBaseline();

    if (baseline.nextRotationOrder < 0) {
      throw StateError('Substitution nextRotationOrder must be non-negative.');
    }

    if (baseline.revision < 0) {
      throw StateError('Substitution revision must be non-negative.');
    }

    return baseline;
  }

  Future<SubstitutionRotationEditApplyResult> apply({
    required SubstitutionRotationDraft draft,
    required SubstitutionRotationEditBaseline baseline,
  }) async {
    if (!draft.hasChanges) {
      return SubstitutionRotationEditApplyResult.noChanges;
    }

    final applied = await _writeRotation(
      originalParticipants: draft.originalParticipants,
      participants: draft.normalizedParticipants(),
      expectedNextRotationOrder: baseline.nextRotationOrder,
      expectedRevision: baseline.revision,
    );

    return applied
        ? SubstitutionRotationEditApplyResult.applied
        : SubstitutionRotationEditApplyResult.conflict;
  }
}
