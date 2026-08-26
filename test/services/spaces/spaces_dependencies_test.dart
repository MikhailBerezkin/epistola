import 'package:epistola/domain/models/spaces_access_role.dart';
import 'package:epistola/services/spaces/spaces_access_firestore_gateway.dart';
import 'package:epistola/services/spaces/spaces_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wires owner role through firestore gateway', () async {
    final service = createSpacesAccessService(
      gateway: SpacesAccessFirestoreGateway(
        documentReader: ({required String userId}) async {
          expect(userId, 'user-1');

          return const {'role': 'owner'};
        },
      ),
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.owner);
  });

  test('wires missing access document as member', () async {
    final service = createSpacesAccessService(
      gateway: SpacesAccessFirestoreGateway(
        documentReader: ({required String userId}) async {
          return null;
        },
      ),
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.member);
  });

  test('created service preserves role cache', () async {
    var readCount = 0;

    final service = createSpacesAccessService(
      gateway: SpacesAccessFirestoreGateway(
        documentReader: ({required String userId}) async {
          readCount++;

          return const {'role': 'brigadier'};
        },
      ),
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.brigadier);

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.brigadier);

    expect(readCount, 1);
  });
}
