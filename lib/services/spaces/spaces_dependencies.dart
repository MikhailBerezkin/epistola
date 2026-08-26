import 'spaces_access_firestore_gateway.dart';
import 'spaces_access_service.dart';

SpacesAccessService? _defaultSpacesAccessService;

SpacesAccessService get defaultSpacesAccessService {
  return _defaultSpacesAccessService ??= createSpacesAccessService();
}

SpacesAccessService createSpacesAccessService({
  SpacesAccessFirestoreGateway? gateway,
}) {
  final resolvedGateway = gateway ?? SpacesAccessFirestoreGateway.firebase();

  return SpacesAccessService(roleReader: resolvedGateway.readRole);
}
