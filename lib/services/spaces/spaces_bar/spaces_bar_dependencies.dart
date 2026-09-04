import 'package:cloud_firestore/cloud_firestore.dart';

import 'spaces_bar_board_firestore_gateway.dart';
import 'spaces_bar_hidden_messages_preferences.dart';
import 'spaces_bar_presentation_service.dart';
import 'spaces_bar_visible_messages_resolver.dart';
import 'spaces_bar_board_transaction_gateway.dart';
import 'spaces_bar_management_service.dart';

SpacesBarPresentationService createSpacesBarPresentationService({
  FirebaseFirestore? firestore,
  SpacesBarBoardFirestoreGateway? boardGateway,
  SpacesBarHiddenMessagesPreferences? hiddenMessagesPreferences,
  SpacesBarVisibleMessagesResolver resolver =
      const SpacesBarVisibleMessagesResolver(),
  DateTime Function()? clock,
}) {
  final resolvedBoardGateway =
      boardGateway ??
      SpacesBarBoardFirestoreGateway.firebase(firestore: firestore);

  final resolvedHiddenMessagesPreferences =
      hiddenMessagesPreferences ?? SpacesBarHiddenMessagesPreferences();

  return SpacesBarPresentationService(
    boardLoader: resolvedBoardGateway.load,
    boardWatcher: resolvedBoardGateway.watch,
    hiddenMessageIdsLoader:
        resolvedHiddenMessagesPreferences.loadHiddenMessageIds,
    messageHider: resolvedHiddenMessagesPreferences.hideMessage,
    resolver: resolver,
    clock: clock,
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
