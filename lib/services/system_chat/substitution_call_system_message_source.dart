import '../../domain/models/epistola_system_message.dart';
import '../../domain/models/substitution_confirmed_call.dart';
import '../spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'substitution_call_system_message_mapper.dart';

final class SubstitutionCallSystemMessageSource {
  const SubstitutionCallSystemMessageSource({
    required this.gateway,
    this.mapper = const SubstitutionCallSystemMessageMapper(),
  });

  final SubstitutionConfirmedCallFirestoreGateway gateway;
  final SubstitutionCallSystemMessageMapper mapper;

  Future<List<EpistolaSystemMessage>> load({required String userId}) async {
    final calls = await gateway.loadForUser(userId: userId);

    return _map(calls);
  }

  Stream<List<EpistolaSystemMessage>> watch({required String userId}) {
    return gateway.watchForUser(userId: userId).map(_map);
  }

  List<EpistolaSystemMessage> _map(List<SubstitutionConfirmedCall> calls) {
    final messages = calls.map(mapper.map).toList();

    messages.sort(_compareMessages);

    return List<EpistolaSystemMessage>.unmodifiable(messages);
  }

  int _compareMessages(
    EpistolaSystemMessage first,
    EpistolaSystemMessage second,
  ) {
    final timeComparison = first.createdAt.compareTo(second.createdAt);

    if (timeComparison != 0) {
      return timeComparison;
    }

    return first.id.compareTo(second.id);
  }
}
