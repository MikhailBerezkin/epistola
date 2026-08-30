import 'package:epistola/services/spaces/substitution/substitution_work_display_name_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updates only work display name field', () async {
    String? writtenUserId;
    Map<String, dynamic>? writtenData;

    final gateway = SubstitutionWorkDisplayNameFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) async {
            writtenUserId = userId;
            writtenData = data;
          },
    );

    await gateway.updateWorkDisplayName(
      userId: 'user-1',
      workDisplayName: 'Михаил',
    );

    expect(writtenUserId, 'user-1');
    expect(writtenData, <String, dynamic>{'workDisplayName': 'Михаил'});
  });

  test('writes empty work display name for reset', () async {
    Map<String, dynamic>? writtenData;

    final gateway = SubstitutionWorkDisplayNameFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) async {
            writtenData = data;
          },
    );

    await gateway.updateWorkDisplayName(userId: 'user-1', workDisplayName: '');

    expect(writtenData, <String, dynamic>{'workDisplayName': ''});
  });
}
