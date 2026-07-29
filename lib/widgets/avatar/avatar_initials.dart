class AvatarInitials {
  const AvatarInitials._();

  static String resolve({required String name, required String email}) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.length >= 2) {
      return '${_firstCharacter(words.first)}'
              '${_firstCharacter(words.last)}'
          .toUpperCase();
    }

    if (words.length == 1) {
      return _firstCharacter(words.first).toUpperCase();
    }

    final normalizedEmail = email.trim();

    if (normalizedEmail.isNotEmpty) {
      final localPart = normalizedEmail.split('@').first.trim();

      if (localPart.isNotEmpty) {
        return _firstCharacter(localPart).toUpperCase();
      }
    }

    return '?';
  }

  static int stablePaletteIndex({
    required String stableKey,
    required int paletteLength,
  }) {
    if (paletteLength <= 0) {
      throw ArgumentError.value(
        paletteLength,
        'paletteLength',
        'Длина палитры должна быть больше нуля',
      );
    }

    final normalizedKey = stableKey.trim().isEmpty ? '?' : stableKey.trim();

    var hash = 0;

    for (final rune in normalizedKey.runes) {
      hash = ((hash * 31) + rune) & 0x7fffffff;
    }

    return hash % paletteLength;
  }

  static String _firstCharacter(String value) {
    final normalizedValue = value.trim();

    if (normalizedValue.isEmpty) {
      return '?';
    }

    return String.fromCharCode(normalizedValue.runes.first);
  }
}
