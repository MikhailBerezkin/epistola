enum SpacesAccessRole {
  member('member'),
  brigadier('brigadier'),
  owner('owner');

  const SpacesAccessRole(this.storageValue);

  final String storageValue;

  bool get canManageSubstitution {
    return this == SpacesAccessRole.brigadier || this == SpacesAccessRole.owner;
  }

  bool get canManageSpacesRoles {
    return this == SpacesAccessRole.owner;
  }

  static SpacesAccessRole? tryParse(Object? value) {
    return switch (value) {
      'member' => SpacesAccessRole.member,
      'brigadier' => SpacesAccessRole.brigadier,
      'owner' => SpacesAccessRole.owner,
      _ => null,
    };
  }
}
