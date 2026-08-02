import 'package:epistola/services/chat/first_private_image_upload_grant_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirstPrivateImageUploadGrantService', () {
    test('sends the exact callable payload', () async {
      Map<String, Object?>? capturedData;

      final service = FirstPrivateImageUploadGrantService(
        caller: (data) async {
          capturedData = Map<String, Object?>.from(data);

          return <String, Object?>{'granted': true};
        },
      );

      await service.createGrant(
        peerId: 'user-2',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        version: 'v1',
      );

      expect(capturedData, {
        'peerId': 'user-2',
        'chatId': 'user-1_user-2',
        'messageId': 'message-1',
        'version': 'v1',
      });
    });

    test('accepts a valid multi-digit version', () async {
      var invocationCount = 0;

      final service = FirstPrivateImageUploadGrantService(
        caller: (data) async {
          invocationCount += 1;

          return <String, Object?>{'granted': true};
        },
      );

      await service.createGrant(
        peerId: 'user-2',
        chatId: 'user-1_user-2',
        messageId: 'message-10',
        version: 'v10',
      );

      expect(invocationCount, 1);
    });

    test('rejects an invalid callable response', () async {
      final service = FirstPrivateImageUploadGrantService(
        caller: (data) async {
          return <String, Object?>{'granted': false};
        },
      );

      final result = service.createGrant(
        peerId: 'user-2',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        version: 'v1',
      );

      await expectLater(result, throwsA(isA<StateError>()));
    });

    test('rejects invalid identifiers before calling Firebase', () async {
      var invocationCount = 0;

      final service = FirstPrivateImageUploadGrantService(
        caller: (data) async {
          invocationCount += 1;

          return <String, Object?>{'granted': true};
        },
      );

      for (final invalidPeerId in ['', ' user-2', 'user-2 ', 'user/2']) {
        final result = service.createGrant(
          peerId: invalidPeerId,
          chatId: 'user-1_user-2',
          messageId: 'message-1',
          version: 'v1',
        );

        await expectLater(result, throwsArgumentError);
      }

      expect(invocationCount, 0);
    });

    test('rejects invalid versions before calling Firebase', () async {
      var invocationCount = 0;

      final service = FirstPrivateImageUploadGrantService(
        caller: (data) async {
          invocationCount += 1;

          return <String, Object?>{'granted': true};
        },
      );

      for (final invalidVersion in [
        '',
        '1',
        'v0',
        'v01',
        'v-1',
        ' v1',
        'v1 ',
      ]) {
        final result = service.createGrant(
          peerId: 'user-2',
          chatId: 'user-1_user-2',
          messageId: 'message-1',
          version: invalidVersion,
        );

        await expectLater(result, throwsArgumentError);
      }

      expect(invocationCount, 0);
    });
  });
}
