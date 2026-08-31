import '../../../domain/models/substitution_statistics.dart';

typedef SubstitutionStatisticsLoader =
    Future<SubstitutionStatistics?> Function({required int year});

final class SubstitutionStatisticsService {
  SubstitutionStatisticsService({
    required SubstitutionStatisticsLoader statisticsLoader,
  }) : _loadStatistics = statisticsLoader;

  final SubstitutionStatisticsLoader _loadStatistics;

  Future<SubstitutionStatistics?> load({required int year}) {
    return _loadStatistics(year: year);
  }
}
