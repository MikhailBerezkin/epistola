import 'package:epistola/domain/models/message_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageType', () {
    test('uses stable storage values', () {
      expect(MessageType.text.storageValue, 'text');
      expect(MessageType.image.storageValue, 'image');
    });

    test('treats a missing type as a legacy text message', () {
      expect(MessageType.tryParseStorageValue(null), MessageType.text);
    });

    test('reads explicit text and image types', () {
      expect(MessageType.tryParseStorageValue('text'), MessageType.text);
      expect(MessageType.tryParseStorageValue('image'), MessageType.image);
    });

    test('rejects an unknown type', () {
      expect(MessageType.tryParseStorageValue('video'), isNull);
      expect(MessageType.tryParseStorageValue(' text '), isNull);
    });

    test('rejects a non-string stored value', () {
      expect(MessageType.tryParseStorageValue(1), isNull);
      expect(MessageType.tryParseStorageValue(true), isNull);
    });
  });
}
