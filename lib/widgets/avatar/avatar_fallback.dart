import 'package:flutter/material.dart';

import 'avatar_initials.dart';

class AvatarFallback extends StatelessWidget {
  final String stableKey;
  final String name;
  final String email;
  final double radius;

  const AvatarFallback({
    super.key,
    required this.stableKey,
    required this.name,
    required this.email,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final initials = AvatarInitials.resolve(name: name, email: email);

    final colorIndex = AvatarInitials.stablePaletteIndex(
      stableKey: stableKey,
      paletteLength: 4,
    );

    final colors = _resolveColors(Theme.of(context).colorScheme, colorIndex);

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
      child: Text(
        initials,
        maxLines: 1,
        style: TextStyle(fontSize: radius * 0.72, fontWeight: FontWeight.w600),
      ),
    );
  }

  _AvatarColors _resolveColors(ColorScheme colorScheme, int colorIndex) {
    switch (colorIndex) {
      case 0:
        return _AvatarColors(
          background: colorScheme.primaryContainer,
          foreground: colorScheme.onPrimaryContainer,
        );
      case 1:
        return _AvatarColors(
          background: colorScheme.secondaryContainer,
          foreground: colorScheme.onSecondaryContainer,
        );
      case 2:
        return _AvatarColors(
          background: colorScheme.tertiaryContainer,
          foreground: colorScheme.onTertiaryContainer,
        );
      default:
        return _AvatarColors(
          background: colorScheme.surfaceContainerHighest,
          foreground: colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _AvatarColors {
  final Color background;
  final Color foreground;

  const _AvatarColors({required this.background, required this.foreground});
}
