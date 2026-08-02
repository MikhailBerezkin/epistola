import 'package:cloud_functions/cloud_functions.dart';

typedef FirstPrivateImageUploadGrantCaller =
    Future<Object?> Function(Map<String, Object?> data);

final class FirstPrivateImageUploadGrantService {
  FirstPrivateImageUploadGrantService({
    FirebaseFunctions? functions,
    FirstPrivateImageUploadGrantCaller? caller,
  }) : _caller = _resolveCaller(functions: functions, caller: caller);

  static const String _functionsRegion = 'europe-west1';

  static const String _functionName = 'createFirstPrivateImageUploadGrant';

  static final RegExp _versionPattern = RegExp(r'^v[1-9][0-9]*$');

  final FirstPrivateImageUploadGrantCaller _caller;

  Future<void> createGrant({
    required String peerId,
    required String chatId,
    required String messageId,
    required String version,
  }) async {
    _validateIdentifier(value: peerId, argumentName: 'peerId');

    _validateIdentifier(value: chatId, argumentName: 'chatId');

    _validateIdentifier(value: messageId, argumentName: 'messageId');

    if (!_versionPattern.hasMatch(version)) {
      throw ArgumentError.value(
        version,
        'version',
        'Version must match v[1-9][0-9]*.',
      );
    }

    final response = await _caller({
      'peerId': peerId,
      'chatId': chatId,
      'messageId': messageId,
      'version': version,
    });

    if (response is! Map || response['granted'] != true) {
      throw StateError('The image upload grant response is invalid.');
    }
  }

  static FirstPrivateImageUploadGrantCaller _resolveCaller({
    required FirebaseFunctions? functions,
    required FirstPrivateImageUploadGrantCaller? caller,
  }) {
    if (functions != null && caller != null) {
      throw ArgumentError(
        'Provide either FirebaseFunctions or a caller, not both.',
      );
    }

    if (caller != null) {
      return caller;
    }

    final resolvedFunctions =
        functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

    final callable = resolvedFunctions.httpsCallable(
      _functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );

    return (data) async {
      final result = await callable.call<Object?>(data);

      return result.data;
    };
  }

  static void _validateIdentifier({
    required String value,
    required String argumentName,
  }) {
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty trimmed string.',
      );
    }

    if (value.contains('/')) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must not contain a slash.',
      );
    }
  }
}
