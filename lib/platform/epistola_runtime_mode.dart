import 'package:flutter/foundation.dart';

abstract final class EpistolaRuntimeMode {
  static const bool isTest = bool.fromEnvironment(
    'EPISTOLA_TEST_MODE',
    defaultValue: false,
  );

  static String get appTitle {
    final regularTitle = kIsWeb ? 'EpiLite' : 'Epistola';

    return isTest ? '$regularTitle Test' : regularTitle;
  }
}
