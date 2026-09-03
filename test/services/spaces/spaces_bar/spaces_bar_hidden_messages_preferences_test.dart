import 'package:epistola/services/spaces/spaces_bar/spaces_bar_hidden_messages_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns empty hidden message ids by default', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    final hiddenMessageIds = await preferences.loadHiddenMessageIds(
      userId: 'user-1',
    );

    expect(hiddenMessageIds, isEmpty);
  });

  test('saves and restores hidden message ids', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await preferences.hideMessage(userId: 'user-1', messageId: '7');
    await preferences.hideMessage(userId: 'user-1', messageId: '9');

    final restoredPreferences = SpacesBarHiddenMessagesPreferences();
    final hiddenMessageIds = await restoredPreferences.loadHiddenMessageIds(
      userId: 'user-1',
    );

    expect(hiddenMessageIds, <String>{'7', '9'});
  });

  test('does not duplicate an already hidden message id', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await preferences.hideMessage(userId: 'user-1', messageId: '7');
    await preferences.hideMessage(userId: 'user-1', messageId: '7');

    final hiddenMessageIds = await preferences.loadHiddenMessageIds(
      userId: 'user-1',
    );

    expect(hiddenMessageIds, <String>{'7'});
  });

  test('keeps hidden message ids separate for each user', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await preferences.hideMessage(userId: 'user-1', messageId: '7');
    await preferences.hideMessage(userId: 'user-2', messageId: '9');

    final firstUserHiddenIds = await preferences.loadHiddenMessageIds(
      userId: 'user-1',
    );
    final secondUserHiddenIds = await preferences.loadHiddenMessageIds(
      userId: 'user-2',
    );

    expect(firstUserHiddenIds, <String>{'7'});
    expect(secondUserHiddenIds, <String>{'9'});
  });

  test('normalizes user id and message id before saving', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await preferences.hideMessage(userId: ' user-1 ', messageId: ' 7 ');

    final hiddenMessageIds = await preferences.loadHiddenMessageIds(
      userId: 'user-1',
    );

    expect(hiddenMessageIds, <String>{'7'});
  });

  test('rejects empty user id', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await expectLater(
      preferences.loadHiddenMessageIds(userId: '   '),
      throwsArgumentError,
    );
  });

  test('rejects empty message id', () async {
    final preferences = SpacesBarHiddenMessagesPreferences();

    await expectLater(
      preferences.hideMessage(userId: 'user-1', messageId: '   '),
      throwsArgumentError,
    );
  });
}
