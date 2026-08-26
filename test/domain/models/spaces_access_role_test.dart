import 'package:epistola/domain/models/spaces_access_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesAccessRole', () {
    test('parses supported roles', () {
      expect(SpacesAccessRole.tryParse('member'), SpacesAccessRole.member);
      expect(
        SpacesAccessRole.tryParse('brigadier'),
        SpacesAccessRole.brigadier,
      );
      expect(SpacesAccessRole.tryParse('owner'), SpacesAccessRole.owner);
    });

    test('rejects unsupported roles', () {
      expect(SpacesAccessRole.tryParse('admin'), isNull);
      expect(SpacesAccessRole.tryParse(''), isNull);
      expect(SpacesAccessRole.tryParse(null), isNull);
    });

    test('member cannot manage substitution', () {
      expect(SpacesAccessRole.member.canManageSubstitution, isFalse);
    });

    test('brigadier can manage substitution', () {
      expect(SpacesAccessRole.brigadier.canManageSubstitution, isTrue);
    });

    test('owner can manage substitution', () {
      expect(SpacesAccessRole.owner.canManageSubstitution, isTrue);
    });

    test('only owner can manage spaces roles', () {
      expect(SpacesAccessRole.member.canManageSpacesRoles, isFalse);
      expect(SpacesAccessRole.brigadier.canManageSpacesRoles, isFalse);
      expect(SpacesAccessRole.owner.canManageSpacesRoles, isTrue);
    });
  });
}
