import 'package:cloud_firestore/cloud_firestore.dart';

import '../spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'epistola_system_chat_service.dart';
import 'substitution_call_system_message_source.dart';

EpistolaSystemChatService createEpistolaSystemChatService({
  FirebaseFirestore? firestore,
  SubstitutionConfirmedCallFirestoreGateway? substitutionCallGateway,
}) {
  final resolvedSubstitutionCallGateway =
      substitutionCallGateway ??
      SubstitutionConfirmedCallFirestoreGateway.firebase(firestore: firestore);

  final substitutionCallSource = SubstitutionCallSystemMessageSource(
    gateway: resolvedSubstitutionCallGateway,
  );

  return EpistolaSystemChatService(
    loader: substitutionCallSource.load,
    watcher: substitutionCallSource.watch,
  );
}
