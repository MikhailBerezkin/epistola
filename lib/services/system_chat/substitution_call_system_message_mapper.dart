import '../../domain/models/epistola_system_message.dart';
import '../../domain/models/substitution_confirmed_call.dart';
import '../../domain/models/substitution_shift.dart';

final class SubstitutionCallSystemMessageMapper {
  const SubstitutionCallSystemMessageMapper();

  EpistolaSystemMessage map(SubstitutionConfirmedCall call) {
    return EpistolaSystemMessage(
      id: 'substitutionCall:${call.callId}',
      source: EpistolaSystemMessageSource.substitutionCall,
      sourceId: call.callId,
      text: _buildText(call),
      createdAt: call.calledAt,
    );
  }

  String _buildText(SubstitutionConfirmedCall call) {
    final shift = call.shift;

    final day = shift.day.toString().padLeft(2, '0');

    final month = shift.month.toString().padLeft(2, '0');

    final hour = shift.startHour.toString().padLeft(2, '0');

    final shiftLabel = switch (shift.kind) {
      SubstitutionShiftKind.day => 'дневную',
      SubstitutionShiftKind.night => 'ночную',
    };

    return 'Вы вызваны на $shiftLabel смену '
        '$day.$month.${shift.year} в $hour:00';
  }
}
