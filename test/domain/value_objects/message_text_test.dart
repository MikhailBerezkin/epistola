import 'package:epistola/domain/value_objects/message_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageText', () {
    test('normalizes leading and trailing whitespace', () {
      expect(
        MessageText.normalize('  Привет, Epistola!  '),
        'Привет, Epistola!',
      );
    });

    test('preserves whitespace inside the message', () {
      expect(
        MessageText.normalize('Первая строка\n\nВторая строка'),
        'Первая строка\n\nВторая строка',
      );
    });

    test('rejects an empty message', () {
      expect(MessageText.isValid(''), isFalse);
    });

    test('rejects a whitespace-only message', () {
      expect(MessageText.isValid('   \n\t   '), isFalse);
    });

    test('accepts a message at the maximum length', () {
      final text = 'a' * MessageText.maxLength;

      expect(MessageText.isValid(text), isTrue);
      expect(MessageText.tryParse(text)?.value, text);
    });

    test('rejects a message longer than the maximum length', () {
      final text = 'a' * (MessageText.maxLength + 1);

      expect(MessageText.isValid(text), isFalse);
      expect(MessageText.tryParse(text), isNull);
    });

    test('tryParse returns the normalized value', () {
      final message = MessageText.tryParse('  Тестовое сообщение  ');

      expect(message, isNotNull);
      expect(message?.value, 'Тестовое сообщение');
    });
  });
}
