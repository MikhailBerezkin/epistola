import 'package:epistola/services/spaces/spaces_bar/spaces_bar_hidden_substitution_calls_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns empty hidden call ids by default', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    final hiddenCallIds = await preferences.loadHiddenCallIds(userId: 'user-1');

    expect(hiddenCallIds, isEmpty);
  });

  test('saves and restores hidden call ids', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await preferences.hideCall(userId: 'user-1', callId: '7');

    await preferences.hideCall(userId: 'user-1', callId: '9');

    final restoredPreferences = SpacesBarHiddenSubstitutionCallsPreferences();

    final hiddenCallIds = await restoredPreferences.loadHiddenCallIds(
      userId: 'user-1',
    );

    expect(hiddenCallIds, <String>{'7', '9'});
  });

  test('does not duplicate already hidden call id', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await preferences.hideCall(userId: 'user-1', callId: '7');

    await preferences.hideCall(userId: 'user-1', callId: '7');

    final hiddenCallIds = await preferences.loadHiddenCallIds(userId: 'user-1');

    expect(hiddenCallIds, <String>{'7'});
  });

  test('keeps hidden calls separate for each user', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await preferences.hideCall(userId: 'user-1', callId: '7');

    await preferences.hideCall(userId: 'user-2', callId: '9');

    final firstUserIds = await preferences.loadHiddenCallIds(userId: 'user-1');

    final secondUserIds = await preferences.loadHiddenCallIds(userId: 'user-2');

    expect(firstUserIds, <String>{'7'});

    expect(secondUserIds, <String>{'9'});
  });

  test('does not collide with general spaces bar hidden ids', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'spaces_bar.hidden_message_ids.v1.user-1': <String>['7'],
    });

    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    final hiddenCallIds = await preferences.loadHiddenCallIds(userId: 'user-1');

    expect(hiddenCallIds, isEmpty);

    await preferences.hideCall(userId: 'user-1', callId: '7');

    final sharedPreferences = await SharedPreferences.getInstance();

    expect(
      sharedPreferences.getStringList(
        'spaces_bar.hidden_message_ids.v1.user-1',
      ),
      <String>['7'],
    );

    expect(
      sharedPreferences.getStringList(
        'spaces_bar.hidden_substitution_call_ids.v1.user-1',
      ),
      <String>['7'],
    );
  });

  test('normalizes user id and call id', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await preferences.hideCall(userId: ' user-1 ', callId: ' 7 ');

    final hiddenCallIds = await preferences.loadHiddenCallIds(userId: 'user-1');

    expect(hiddenCallIds, <String>{'7'});
  });

  test('rejects empty user id', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await expectLater(
      preferences.loadHiddenCallIds(userId: '   '),
      throwsArgumentError,
    );
  });

  test('rejects empty call id', () async {
    final preferences = SpacesBarHiddenSubstitutionCallsPreferences();

    await expectLater(
      preferences.hideCall(userId: 'user-1', callId: '   '),
      throwsArgumentError,
    );
  });
}
