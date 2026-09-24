import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/vacation_period.dart';
import 'vacation_period_mapper.dart';

typedef VacationPeriodDocument = ({String id, Map<String, dynamic> data});

typedef VacationPeriodDocumentsLoader =
    Future<List<VacationPeriodDocument>> Function({required String userId});

typedef VacationPeriodDocumentsWatcher =
    Stream<List<VacationPeriodDocument>> Function({required String userId});

typedef VacationPeriodAllDocumentsWatcher =
    Stream<List<VacationPeriodDocument>> Function();

typedef VacationPeriodDocumentSaver =
    Future<void> Function({
      required String documentId,
      required Map<String, dynamic> data,
    });

typedef VacationPeriodDocumentDeleter =
    Future<void> Function({required String documentId});

final class VacationPeriodFirestoreGateway {
  VacationPeriodFirestoreGateway({
    required VacationPeriodDocumentsLoader documentsLoader,
    VacationPeriodDocumentsWatcher? documentsWatcher,
    VacationPeriodAllDocumentsWatcher? allDocumentsWatcher,
    required VacationPeriodDocumentSaver documentSaver,
    required VacationPeriodDocumentDeleter documentDeleter,
  }) : this._(
         documentsLoader,
         documentsWatcher,
         allDocumentsWatcher,
         documentSaver,
         documentDeleter,
       );

  VacationPeriodFirestoreGateway._(
    this._documentsLoader,
    this._documentsWatcher,
    this._allDocumentsWatcher,
    this._documentSaver,
    this._documentDeleter,
  );

  factory VacationPeriodFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final vacationPeriodsCollection = resolvedFirestore
        .collection('spaces')
        .doc('calendar')
        .collection('vacationPeriods');

    return VacationPeriodFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        final snapshot = await vacationPeriodsCollection
            .where('userId', isEqualTo: userId)
            .get();

        return snapshot.docs
            .map((document) => (id: document.id, data: document.data()))
            .toList(growable: false);
      },
      documentsWatcher: ({required String userId}) {
        return vacationPeriodsCollection
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((document) => (id: document.id, data: document.data()))
                  .toList(growable: false),
            );
      },
      allDocumentsWatcher: () {
        return vacationPeriodsCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((document) => (id: document.id, data: document.data()))
              .toList(growable: false),
        );
      },
      documentSaver:
          ({required String documentId, required Map<String, dynamic> data}) {
            return vacationPeriodsCollection.doc(documentId).set(data);
          },
      documentDeleter: ({required String documentId}) {
        return vacationPeriodsCollection.doc(documentId).delete();
      },
    );
  }

  final VacationPeriodDocumentsLoader _documentsLoader;
  final VacationPeriodDocumentsWatcher? _documentsWatcher;
  final VacationPeriodAllDocumentsWatcher? _allDocumentsWatcher;
  final VacationPeriodDocumentSaver _documentSaver;
  final VacationPeriodDocumentDeleter _documentDeleter;

  Future<List<VacationPeriod>> loadForUser({required String userId}) async {
    final normalizedUserId = _normalizeUserId(userId);

    final documents = await _documentsLoader(userId: normalizedUserId);

    return _mapDocuments(documents, expectedUserId: normalizedUserId);
  }

  Stream<List<VacationPeriod>> watchForUser({required String userId}) async* {
    final normalizedUserId = _normalizeUserId(userId);
    final documentsWatcher = _documentsWatcher;

    if (documentsWatcher == null) {
      throw StateError('Vacation period watcher is not configured.');
    }

    await for (final documents in documentsWatcher(userId: normalizedUserId)) {
      yield _mapDocuments(documents, expectedUserId: normalizedUserId);
    }
  }

  Stream<List<VacationPeriod>> watchAll() async* {
    final documentsWatcher = _allDocumentsWatcher;

    if (documentsWatcher == null) {
      throw StateError(
        'Vacation period all-documents watcher is not configured.',
      );
    }

    await for (final documents in documentsWatcher()) {
      yield _mapAllDocuments(documents);
    }
  }

  Future<void> save(VacationPeriod period) async {
    if (!period.isValid) {
      throw ArgumentError.value(
        period,
        'period',
        'must be a valid vacation period',
      );
    }

    final normalizedUserId = _normalizeUserId(period.userId);

    final normalizedPeriod = VacationPeriod(
      userId: normalizedUserId,
      slot: period.slot,
      startDate: period.startDateOnly,
      endDate: period.endDateOnly,
    );

    await _documentSaver(
      documentId: normalizedPeriod.documentId,
      data: VacationPeriodMapper.toMap(normalizedPeriod),
    );
  }

  Future<void> delete({required String userId, required int slot}) async {
    final normalizedUserId = _normalizeUserId(userId);

    if (slot < 1 || slot > 6) {
      throw ArgumentError.value(slot, 'slot', 'must be between 1 and 6');
    }

    await _documentDeleter(documentId: '${normalizedUserId}__$slot');
  }

  List<VacationPeriod> _mapDocuments(
    List<VacationPeriodDocument> documents, {
    required String expectedUserId,
  }) {
    final periods = <VacationPeriod>[];

    for (final document in documents) {
      final period = VacationPeriodMapper.fromMap(document.data);

      if (period == null) {
        throw StateError('Vacation period document contains invalid data.');
      }

      if (period.userId != expectedUserId) {
        throw StateError('Vacation period belongs to another user.');
      }

      if (period.documentId != document.id) {
        throw StateError(
          'Vacation period document id does not match userId and slot.',
        );
      }

      periods.add(period);
    }

    periods.sort((first, second) => first.slot.compareTo(second.slot));

    return List<VacationPeriod>.unmodifiable(periods);
  }

  List<VacationPeriod> _mapAllDocuments(
    List<VacationPeriodDocument> documents,
  ) {
    final periods = <VacationPeriod>[];

    for (final document in documents) {
      final period = VacationPeriodMapper.fromMap(document.data);

      if (period == null) {
        throw StateError('Vacation period document contains invalid data.');
      }

      if (period.documentId != document.id) {
        throw StateError(
          'Vacation period document id does not match userId and slot.',
        );
      }

      periods.add(period);
    }

    periods.sort((first, second) {
      final userComparison = first.userId.compareTo(second.userId);

      if (userComparison != 0) {
        return userComparison;
      }

      return first.slot.compareTo(second.slot);
    });

    return List<VacationPeriod>.unmodifiable(periods);
  }

  static String _normalizeUserId(String userId) {
    final normalized = userId.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(userId, 'userId', 'must be a valid user id');
    }

    return normalized;
  }
}
