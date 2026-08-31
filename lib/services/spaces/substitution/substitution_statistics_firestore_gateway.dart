import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_statistics.dart';
import 'substitution_statistics_mapper.dart';

typedef SubstitutionStatisticsDocumentReader =
    Future<Map<String, dynamic>?> Function({required int year});

final class SubstitutionStatisticsFirestoreGateway {
  SubstitutionStatisticsFirestoreGateway({
    required SubstitutionStatisticsDocumentReader documentReader,
  }) : _readDocument = documentReader;

  factory SubstitutionStatisticsFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return SubstitutionStatisticsFirestoreGateway(
      documentReader: ({required int year}) async {
        if (year <= 0) {
          throw ArgumentError.value(year, 'year', 'Year must be positive.');
        }

        final snapshot = await resolvedFirestore
            .collection('spaces')
            .doc('substitution')
            .collection('statistics')
            .doc('year_$year')
            .get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  final SubstitutionStatisticsDocumentReader _readDocument;

  Future<SubstitutionStatistics?> load({required int year}) async {
    if (year <= 0) {
      throw ArgumentError.value(year, 'year', 'Year must be positive.');
    }

    final data = await _readDocument(year: year);

    if (data == null) {
      return null;
    }

    final statistics = SubstitutionStatisticsMapper.fromMap(
      data,
      expectedYear: year,
    );

    if (statistics == null) {
      throw StateError(
        'Substitution statistics year_$year '
        'contains invalid data.',
      );
    }

    return statistics;
  }
}
