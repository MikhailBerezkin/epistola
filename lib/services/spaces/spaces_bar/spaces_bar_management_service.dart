import '../../../domain/models/spaces_access_role.dart';
import '../../../domain/models/spaces_bar_message.dart';
import '../../../domain/models/spaces_bar_publication_receipt.dart';

typedef SpacesBarPublisher =
    Future<SpacesBarPublicationReceipt> Function({
      required String text,
      required SpacesBarMessageLifetime lifetime,
      required String createdByUserId,
    });

typedef SpacesBarMessageDeleter =
    Future<bool> Function({required String messageId});

final class SpacesBarManagementPermissionException implements Exception {
  const SpacesBarManagementPermissionException();

  @override
  String toString() {
    return 'SpacesBarManagementPermissionException: '
        'Current Spaces role cannot manage SpacesBar.';
  }
}

final class SpacesBarManagementService {
  factory SpacesBarManagementService({
    required SpacesBarPublisher publisher,
    required SpacesBarMessageDeleter messageDeleter,
  }) {
    return SpacesBarManagementService._(publisher, messageDeleter);
  }

  const SpacesBarManagementService._(this._publisher, this._messageDeleter);

  final SpacesBarPublisher _publisher;
  final SpacesBarMessageDeleter _messageDeleter;

  Future<SpacesBarPublicationReceipt> publish({
    required SpacesAccessRole role,
    required String text,
    required SpacesBarMessageLifetime lifetime,
    required String createdByUserId,
  }) async {
    _requireManager(role);

    return _publisher(
      text: text,
      lifetime: lifetime,
      createdByUserId: createdByUserId,
    );
  }

  Future<bool> deleteMessage({
    required SpacesAccessRole role,
    required String messageId,
  }) async {
    _requireManager(role);

    return _messageDeleter(messageId: messageId);
  }

  static void _requireManager(SpacesAccessRole role) {
    if (!role.canManageSpacesBar) {
      throw const SpacesBarManagementPermissionException();
    }
  }
}
