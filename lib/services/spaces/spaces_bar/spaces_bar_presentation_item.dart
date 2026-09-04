import '../../../domain/models/spaces_bar_message.dart';
import '../../../domain/models/substitution_confirmed_call.dart';

enum SpacesBarPresentationItemSource { generalMessage, substitutionCall }

final class SpacesBarPresentationItem {
  const SpacesBarPresentationItem._({
    required this.source,
    required this.sourceId,
    required this.presentationId,
    required this.text,
    required this.publishedAt,
    required this.generalMessage,
    required this.substitutionCall,
  });

  factory SpacesBarPresentationItem.general({
    required SpacesBarMessage message,
  }) {
    return SpacesBarPresentationItem._(
      source: SpacesBarPresentationItemSource.generalMessage,
      sourceId: message.id,
      presentationId: 'general:${message.id}',
      text: message.text,
      publishedAt: message.createdAt,
      generalMessage: message,
      substitutionCall: null,
    );
  }

  factory SpacesBarPresentationItem.substitution({
    required SubstitutionConfirmedCall call,
    required String text,
  }) {
    final normalizedText = text.trim();

    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }

    return SpacesBarPresentationItem._(
      source: SpacesBarPresentationItemSource.substitutionCall,
      sourceId: call.callId,
      presentationId: 'substitution:${call.callId}',
      text: normalizedText,
      publishedAt: call.finalizedAt,
      generalMessage: null,
      substitutionCall: call,
    );
  }

  final SpacesBarPresentationItemSource source;

  /// Исходный id внутри своего источника.
  ///
  /// Для общего сообщения — message.id.
  /// Для персонального вызова — callId.
  final String sourceId;

  /// Глобально уникальный id именно внутри presentation-слоя.
  ///
  /// Примеры:
  /// general:7
  /// substitution:7
  final String presentationId;

  final String text;

  /// Момент появления элемента.
  ///
  /// Для manager announcement — createdAt.
  /// Для confirmed substitution call — finalizedAt.
  final DateTime publishedAt;

  final SpacesBarMessage? generalMessage;
  final SubstitutionConfirmedCall? substitutionCall;

  bool get isGeneralMessage {
    return source == SpacesBarPresentationItemSource.generalMessage;
  }

  bool get isSubstitutionCall {
    return source == SpacesBarPresentationItemSource.substitutionCall;
  }

  String? get generalMessageId {
    return generalMessage?.id;
  }

  String? get substitutionCallId {
    return substitutionCall?.callId;
  }
}
