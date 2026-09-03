import 'package:epistola/domain/models/spaces_access_role.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/domain/models/spaces_bar_publication_receipt.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarManagementService', () {
    test('member cannot publish', () async {
      var publishCalls = 0;

      final service = SpacesBarManagementService(
        publisher:
            ({
              required String text,
              required SpacesBarMessageLifetime lifetime,
              required String createdByUserId,
            }) async {
              publishCalls += 1;

              return const SpacesBarPublicationReceipt(
                messageId: '1',
                revision: 1,
              );
            },
        messageDeleter: ({required String messageId}) async {
          return true;
        },
      );

      await expectLater(
        service.publish(
          role: SpacesAccessRole.member,
          text: 'Message',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'user-1',
        ),
        throwsA(isA<SpacesBarManagementPermissionException>()),
      );

      expect(publishCalls, 0);
    });

    test('brigadier can publish', () async {
      var publishCalls = 0;

      final service = SpacesBarManagementService(
        publisher:
            ({
              required String text,
              required SpacesBarMessageLifetime lifetime,
              required String createdByUserId,
            }) async {
              publishCalls += 1;

              expect(text, 'Message');
              expect(lifetime, SpacesBarMessageLifetime.twelveHours);
              expect(createdByUserId, 'brigadier-1');

              return const SpacesBarPublicationReceipt(
                messageId: '7',
                revision: 7,
              );
            },
        messageDeleter: ({required String messageId}) async {
          return true;
        },
      );

      final receipt = await service.publish(
        role: SpacesAccessRole.brigadier,
        text: 'Message',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdByUserId: 'brigadier-1',
      );

      expect(publishCalls, 1);
      expect(receipt.messageId, '7');
      expect(receipt.revision, 7);
    });

    test('owner can publish', () async {
      final service = SpacesBarManagementService(
        publisher:
            ({
              required String text,
              required SpacesBarMessageLifetime lifetime,
              required String createdByUserId,
            }) async {
              return const SpacesBarPublicationReceipt(
                messageId: '8',
                revision: 8,
              );
            },
        messageDeleter: ({required String messageId}) async {
          return true;
        },
      );

      final receipt = await service.publish(
        role: SpacesAccessRole.owner,
        text: 'Owner message',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdByUserId: 'owner-1',
      );

      expect(receipt.messageId, '8');
    });

    test('member cannot delete message', () async {
      var deleteCalls = 0;

      final service = SpacesBarManagementService(
        publisher:
            ({
              required String text,
              required SpacesBarMessageLifetime lifetime,
              required String createdByUserId,
            }) async {
              return const SpacesBarPublicationReceipt(
                messageId: '1',
                revision: 1,
              );
            },
        messageDeleter: ({required String messageId}) async {
          deleteCalls += 1;
          return true;
        },
      );

      await expectLater(
        service.deleteMessage(role: SpacesAccessRole.member, messageId: '1'),
        throwsA(isA<SpacesBarManagementPermissionException>()),
      );

      expect(deleteCalls, 0);
    });

    test('brigadier can delete message', () async {
      String? deletedMessageId;

      final service = SpacesBarManagementService(
        publisher:
            ({
              required String text,
              required SpacesBarMessageLifetime lifetime,
              required String createdByUserId,
            }) async {
              return const SpacesBarPublicationReceipt(
                messageId: '1',
                revision: 1,
              );
            },
        messageDeleter: ({required String messageId}) async {
          deletedMessageId = messageId;
          return true;
        },
      );

      final deleted = await service.deleteMessage(
        role: SpacesAccessRole.brigadier,
        messageId: '42',
      );

      expect(deleted, isTrue);
      expect(deletedMessageId, '42');
    });
  });
}
