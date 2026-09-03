enum SpacesBarMessageLifetime {
  oneHour(storageValue: 'oneHour', duration: Duration(hours: 1)),
  twelveHours(storageValue: 'twelveHours', duration: Duration(hours: 12)),
  twentyFourHours(
    storageValue: 'twentyFourHours',
    duration: Duration(hours: 24),
  ),
  untilCancelled(storageValue: 'untilCancelled', duration: null);

  const SpacesBarMessageLifetime({
    required this.storageValue,
    required this.duration,
  });

  final String storageValue;
  final Duration? duration;

  DateTime? expiresAtFrom(DateTime createdAt) {
    final resolvedDuration = duration;

    if (resolvedDuration == null) {
      return null;
    }

    return createdAt.add(resolvedDuration);
  }

  static SpacesBarMessageLifetime? tryParse(Object? value) {
    return switch (value) {
      'oneHour' => SpacesBarMessageLifetime.oneHour,
      'twelveHours' => SpacesBarMessageLifetime.twelveHours,
      'twentyFourHours' => SpacesBarMessageLifetime.twentyFourHours,
      'untilCancelled' => SpacesBarMessageLifetime.untilCancelled,
      _ => null,
    };
  }
}

final class SpacesBarMessage {
  const SpacesBarMessage._({
    required this.id,
    required this.text,
    required this.lifetime,
    required this.createdByUserId,
    required this.createdAt,
    required this.expiresAt,
  });

  static const int maxTextLength = 250;

  final String id;
  final String text;
  final SpacesBarMessageLifetime lifetime;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  static SpacesBarMessage? tryCreate({
    required String id,
    required String text,
    required SpacesBarMessageLifetime lifetime,
    required String createdByUserId,
    required DateTime createdAt,
  }) {
    final normalizedId = id.trim();
    final normalizedText = text.trim();
    final normalizedCreatedByUserId = createdByUserId.trim();

    if (normalizedId.isEmpty ||
        normalizedCreatedByUserId.isEmpty ||
        normalizedText.isEmpty ||
        normalizedText.length > maxTextLength) {
      return null;
    }

    return SpacesBarMessage._(
      id: normalizedId,
      text: normalizedText,
      lifetime: lifetime,
      createdByUserId: normalizedCreatedByUserId,
      createdAt: createdAt,
      expiresAt: lifetime.expiresAtFrom(createdAt),
    );
  }

  bool isActiveAt(DateTime time) {
    final deadline = expiresAt;

    if (deadline == null) {
      return true;
    }

    return time.isBefore(deadline);
  }
}
