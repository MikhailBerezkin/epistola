import 'package:cloud_firestore/cloud_firestore.dart';

import '../substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'spaces_bar_board_firestore_gateway.dart';
import 'spaces_bar_board_transaction_gateway.dart';
import 'spaces_bar_hidden_messages_preferences.dart';
import 'spaces_bar_hidden_substitution_calls_preferences.dart';
import 'spaces_bar_management_service.dart';
import 'spaces_bar_presentation_service.dart';
import 'spaces_bar_substitution_call_resolver.dart';
import 'spaces_bar_visible_messages_resolver.dart';

SpacesBarPresentationService createSpacesBarPresentationService({
  FirebaseFirestore? firestore,
  SpacesBarBoardFirestoreGateway? boardGateway,
  SpacesBarHiddenMessagesPreferences? hiddenMessagesPreferences,
  SubstitutionConfirmedCallFirestoreGateway? confirmedCallGateway,
  SpacesBarHiddenSubstitutionCallsPreferences?
  hiddenSubstitutionCallsPreferences,
  SpacesBarVisibleMessagesResolver resolver =
      const SpacesBarVisibleMessagesResolver(),
  SpacesBarSubstitutionCallResolver substitutionCallResolver =
      const SpacesBarSubstitutionCallResolver(),
  DateTime Function()? clock,
  DateTime Function()? localClock,
}) {
  final resolvedBoardGateway =
      boardGateway ??
      SpacesBarBoardFirestoreGateway.firebase(firestore: firestore);

  final resolvedHiddenMessagesPreferences =
      hiddenMessagesPreferences ?? SpacesBarHiddenMessagesPreferences();

  final resolvedConfirmedCallGateway =
      confirmedCallGateway ??
      SubstitutionConfirmedCallFirestoreGateway.firebase(firestore: firestore);

  final resolvedHiddenSubstitutionCallsPreferences =
      hiddenSubstitutionCallsPreferences ??
      SpacesBarHiddenSubstitutionCallsPreferences();

  return SpacesBarPresentationService(
    boardLoader: resolvedBoardGateway.load,
    boardWatcher: resolvedBoardGateway.watch,
    hiddenMessageIdsLoader:
        resolvedHiddenMessagesPreferences.loadHiddenMessageIds,
    messageHider: resolvedHiddenMessagesPreferences.hideMessage,
    confirmedCallsLoader: resolvedConfirmedCallGateway.loadForUser,
    confirmedCallsWatcher: resolvedConfirmedCallGateway.watchForUser,
    hiddenSubstitutionCallIdsLoader:
        resolvedHiddenSubstitutionCallsPreferences.loadHiddenCallIds,
    substitutionCallHider: resolvedHiddenSubstitutionCallsPreferences.hideCall,
    resolver: resolver,
    substitutionCallResolver: substitutionCallResolver,
    clock: clock,
    localClock: localClock,
  );
}

SpacesBarManagementService createSpacesBarManagementService({
  FirebaseFirestore? firestore,
  SpacesBarBoardTransactionGateway? transactionGateway,
}) {
  final resolvedGateway =
      transactionGateway ??
      SpacesBarBoardTransactionGateway.firebase(firestore: firestore);

  return SpacesBarManagementService(
    publisher: resolvedGateway.publish,
    messageDeleter: resolvedGateway.deleteMessage,
  );
}
