import 'substitution_participant.dart';
import 'substitution_rotation.dart';

final class SubstitutionRotationDraft {
  SubstitutionRotationDraft._({
    required List<SubstitutionParticipant> originalParticipants,
    required List<SubstitutionParticipant> participants,
  }) : _originalParticipants = List<SubstitutionParticipant>.unmodifiable(
         originalParticipants,
       ),
       _participants = List<SubstitutionParticipant>.unmodifiable(participants);

  factory SubstitutionRotationDraft.fromParticipants(
    Iterable<SubstitutionParticipant> participants,
  ) {
    final orderedParticipants = SubstitutionRotation.ordered(participants);

    return SubstitutionRotationDraft._(
      originalParticipants: orderedParticipants,
      participants: orderedParticipants,
    );
  }

  final List<SubstitutionParticipant> _originalParticipants;
  final List<SubstitutionParticipant> _participants;

  List<SubstitutionParticipant> get participants => _participants;
  List<SubstitutionParticipant> get originalParticipants =>
      _originalParticipants;

  List<String> get originalUserIds {
    return List<String>.unmodifiable(
      _originalParticipants.map((participant) => participant.userId),
    );
  }

  List<String> get currentUserIds {
    return List<String>.unmodifiable(
      _participants.map((participant) => participant.userId),
    );
  }

  bool get hasChanges {
    if (_originalParticipants.length != _participants.length) {
      return true;
    }

    for (var index = 0; index < _participants.length; index++) {
      if (_originalParticipants[index].userId != _participants[index].userId) {
        return true;
      }
    }

    return false;
  }

  bool canMoveUp(String userId) {
    final index = _indexOf(userId);

    return index > 0;
  }

  bool canMoveDown(String userId) {
    final index = _indexOf(userId);

    return index >= 0 && index < _participants.length - 1;
  }

  bool canMoveActiveUp(String userId) {
    final index = _requireIndexOf(userId);

    if (!_participants[index].isActive) {
      return false;
    }

    return _previousActiveIndex(index) != null;
  }

  bool canMoveActiveDown(String userId) {
    final index = _requireIndexOf(userId);

    if (!_participants[index].isActive) {
      return false;
    }

    return _nextActiveIndex(index) != null;
  }

  SubstitutionRotationDraft moveActiveUp(String userId) {
    final index = _requireIndexOf(userId);

    if (!_participants[index].isActive) {
      throw StateError(
        'Only an active participant can be moved in the active rotation.',
      );
    }

    final targetIndex = _previousActiveIndex(index);

    if (targetIndex == null) {
      return this;
    }

    return _swap(index, targetIndex);
  }

  SubstitutionRotationDraft moveActiveDown(String userId) {
    final index = _requireIndexOf(userId);

    if (!_participants[index].isActive) {
      throw StateError(
        'Only an active participant can be moved in the active rotation.',
      );
    }

    final targetIndex = _nextActiveIndex(index);

    if (targetIndex == null) {
      return this;
    }

    return _swap(index, targetIndex);
  }

  SubstitutionRotationDraft moveUp(String userId) {
    final index = _requireIndexOf(userId);

    if (index == 0) {
      return this;
    }

    return _swap(index, index - 1);
  }

  SubstitutionRotationDraft moveDown(String userId) {
    final index = _requireIndexOf(userId);

    if (index == _participants.length - 1) {
      return this;
    }

    return _swap(index, index + 1);
  }

  List<SubstitutionParticipant> normalizedParticipants() {
    return List<SubstitutionParticipant>.unmodifiable(<SubstitutionParticipant>[
      for (var index = 0; index < _participants.length; index++)
        _participants[index].copyWith(rotationOrder: index),
    ]);
  }

  SubstitutionRotationDraft _swap(int firstIndex, int secondIndex) {
    final updated = _participants.toList();

    final first = updated[firstIndex];
    updated[firstIndex] = updated[secondIndex];
    updated[secondIndex] = first;

    return SubstitutionRotationDraft._(
      originalParticipants: _originalParticipants,
      participants: updated,
    );
  }

  int? _previousActiveIndex(int index) {
    for (
      var candidateIndex = index - 1;
      candidateIndex >= 0;
      candidateIndex--
    ) {
      if (_participants[candidateIndex].isActive) {
        return candidateIndex;
      }
    }

    return null;
  }

  int? _nextActiveIndex(int index) {
    for (
      var candidateIndex = index + 1;
      candidateIndex < _participants.length;
      candidateIndex++
    ) {
      if (_participants[candidateIndex].isActive) {
        return candidateIndex;
      }
    }

    return null;
  }

  int _indexOf(String userId) {
    final normalizedUserId = _normalizeUserId(userId);

    return _participants.indexWhere(
      (participant) => participant.userId == normalizedUserId,
    );
  }

  int _requireIndexOf(String userId) {
    final index = _indexOf(userId);

    if (index == -1) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Participant is not in the rotation draft.',
      );
    }

    return index;
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
