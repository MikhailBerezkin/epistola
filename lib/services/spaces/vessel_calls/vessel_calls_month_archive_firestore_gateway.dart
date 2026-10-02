import 'package:cloud_firestore/cloud_firestore.dart';

typedef VesselCallsMonthArchiveDocumentReader =
    Future<Map<String, dynamic>?> Function({required String monthId});

final class VesselCallsMonthArchiveFirestoreGateway {
  const VesselCallsMonthArchiveFirestoreGateway({
    required VesselCallsMonthArchiveDocumentReader documentReader,
  }) : _readDocument = documentReader;

  factory VesselCallsMonthArchiveFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final collection = resolvedFirestore
        .collection('spaces')
        .doc('vesselCalls')
        .collection('monthArchives');

    return VesselCallsMonthArchiveFirestoreGateway(
      documentReader: ({required String monthId}) async {
        final snapshot = await collection.doc(monthId).get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  final VesselCallsMonthArchiveDocumentReader _readDocument;

  Future<Map<String, dynamic>?> loadMonth({
    required int year,
    required int month,
  }) {
    return _readDocument(
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
