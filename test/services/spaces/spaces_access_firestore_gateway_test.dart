import 'package:epistola/domain/models/spaces_access_role.dart';
import 'package:epistola/services/spaces/spaces_access_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads owner role', () async {
    final gateway = SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        expect(userId, 'user-1');

        return const {'role': 'owner'};
      },
    );

    expect(await gateway.readRole(userId: 'user-1'), SpacesAccessRole.owner);
  });

  test('reads brigadier role', () async {
    final gateway = SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        return const {'role': 'brigadier'};
      },
    );

    expect(
      await gateway.readRole(userId: 'user-1'),
      SpacesAccessRole.brigadier,
    );
  });

  test('missing document returns null', () async {
    final gateway = SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        return null;
      },
    );

    expect(await gateway.readRole(userId: 'user-1'), isNull);
  });

  test('unsupported role returns null', () async {
    final gateway = SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        return const {'role': 'admin'};
      },
    );

    expect(await gateway.readRole(userId: 'user-1'), isNull);
  });

  test('missing role field returns null', () async {
    final gateway = SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        return const {'otherField': true};
      },
    );

    expect(await gateway.readRole(userId: 'user-1'), isNull);
  });
}
