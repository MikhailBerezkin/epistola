import '../../../domain/models/substitution_test_statistics.dart';

typedef SubstitutionTestStatisticsLoader =
    Future<SubstitutionTestStatistics> Function();

final class SubstitutionTestStatisticsService {
  SubstitutionTestStatisticsService({
    required SubstitutionTestStatisticsLoader statisticsLoader,
  }) : _loadStatistics = statisticsLoader;

  final SubstitutionTestStatisticsLoader _loadStatistics;

  Future<SubstitutionTestStatistics> load() {
    return _loadStatistics();
  }
}
