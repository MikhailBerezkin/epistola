import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_test_statistics.dart';
import 'substitution_test_statistics_mapper.dart';

typedef SubstitutionTestStatisticsDocumentReader =
    Future<Map<String, dynamic>?> Function();

final class SubstitutionTestStatisticsFirestoreGateway {
  SubstitutionTestStatisticsFirestoreGateway({
    required SubstitutionTestStatisticsDocumentReader documentReader,
  }) : _readDocument = documentReader;

  factory SubstitutionTestStatisticsFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final statisticsReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution')
        .collection('statistics')
        .doc('test');

    return SubstitutionTestStatisticsFirestoreGateway(
      documentReader: () async {
        final snapshot = await statisticsReference.get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  final SubstitutionTestStatisticsDocumentReader _readDocument;

  Future<SubstitutionTestStatistics> load() async {
    final data = await _readDocument();

    if (data == null) {
      return SubstitutionTestStatistics();
    }

    final statistics = SubstitutionTestStatisticsMapper.fromMap(data);

    if (statistics == null) {
      throw StateError(
        'TEST substitution statistics document contains invalid data.',
      );
    }

    return statistics;
  }
}
