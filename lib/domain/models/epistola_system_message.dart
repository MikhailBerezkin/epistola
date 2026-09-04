enum EpistolaSystemMessageSource { substitutionCall }

final class EpistolaSystemMessage {
  const EpistolaSystemMessage({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.text,
    required this.createdAt,
  });

  /// Глобально уникальный presentation-id внутри системного чата.
  ///
  /// Например:
  /// substitutionCall:17
  final String id;

  final EpistolaSystemMessageSource source;

  /// ID исходного immutable business event.
  final String sourceId;

  /// Готовый текст технического сообщения.
  final String text;

  /// Время самого события.
  ///
  /// Храним DateTime источника как есть.
  /// В UI время будет переводиться в local time.
  final DateTime createdAt;
}
