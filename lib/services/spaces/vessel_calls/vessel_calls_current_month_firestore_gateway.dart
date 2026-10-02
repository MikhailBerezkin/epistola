import 'package:cloud_firestore/cloud_firestore.dart';

typedef VesselCallsMonthDocumentReader =
    Future<Map<String, dynamic>?> Function({required String monthId});

final class VesselCallsCurrentMonthFirestoreGateway {
  const VesselCallsCurrentMonthFirestoreGateway({
    required VesselCallsMonthDocumentReader metaReader,
    required VesselCallsMonthDocumentReader snapshotReader,
  }) : _readMeta = metaReader,
       _readSnapshot = snapshotReader;

  factory VesselCallsCurrentMonthFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final moduleDocument = resolvedFirestore
        .collection('spaces')
        .doc('vesselCalls');

    final metaCollection = moduleDocument.collection('monthMeta');

    final snapshotCollection = moduleDocument.collection('monthSnapshots');

    return VesselCallsCurrentMonthFirestoreGateway(
      metaReader: ({required String monthId}) async {
        final snapshot = await metaCollection.doc(monthId).get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
      snapshotReader: ({required String monthId}) async {
        final snapshot = await snapshotCollection.doc(monthId).get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  final VesselCallsMonthDocumentReader _readMeta;
  final VesselCallsMonthDocumentReader _readSnapshot;

  Future<VesselCallsMonthRevision?> loadRevision({
    required int year,
    required int month,
  }) async {
    final data = await _readMeta(
      monthId: monthIdFor(year: year, month: month),
    );

    if (data == null) {
      return null;
    }

    final revision = data['revision'];

    if (revision is! int || revision < 0) {
      return null;
    }

    return VesselCallsMonthRevision(revision: revision);
  }

  Future<Map<String, dynamic>?> loadSnapshot({
    required int year,
    required int month,
  }) {
    return _readSnapshot(
      monthId: monthIdFor(year: year, month: month),
    );
  }

  static String monthIdFor({required int year, required int month}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'month must be between 1 and 12.',
      );
    }

    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}';
  }
}

final class VesselCallsMonthRevision {
  const VesselCallsMonthRevision({required this.revision});

  final int revision;
}
