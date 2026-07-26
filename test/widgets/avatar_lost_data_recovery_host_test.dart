import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/services/avatar/avatar_lost_data_recovery_coordinator.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_replacement_controller.dart';
import 'package:epistola/widgets/avatar_lost_data_recovery_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android with no lost data finishes without UI', (tester) async {
    var recoveryCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      prepareRecovered: () async {
        recoveryCalls++;
        return null;
      },
      replace: _unexpectedReplacement,
    );
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    await _pumpHost(tester, controller: controller, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(recoveryCalls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('crop cancellation after recovery is silent', (tester) async {
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      // The preparation service represents crop cancellation with null.
      prepareRecovered: () async => null,
      replace: _unexpectedReplacement,
    );

    await _pumpHost(
      tester,
      controller: controller,
      coordinator: AvatarLostDataRecoveryCoordinator(isAndroid: () => true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('lost data failure shows one clear SnackBar', (tester) async {
    var recoveryCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      prepareRecovered: () async {
        recoveryCalls++;
        throw StateError('retrieveLostData failed');
      },
      replace: _unexpectedReplacement,
    );
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    await _pumpHost(tester, controller: controller, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Не удалось восстановить выбранное фото. '
        'Старый аватар сохранён.',
      ),
      findsOneWidget,
    );

    await _pumpHost(tester, controller: controller, coordinator: coordinator);
    await tester.pump();

    expect(recoveryCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('rebuild does not start recovery again', (tester) async {
    var recoveryCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      prepareRecovered: () async {
        recoveryCalls++;
        return null;
      },
      replace: _unexpectedReplacement,
    );
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    await _pumpHost(tester, controller: controller, coordinator: coordinator);
    await tester.pumpAndSettle();

    await _pumpHost(tester, controller: controller, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(recoveryCalls, 1);
  });

  testWidgets('non-Android host never calls recovery', (tester) async {
    var recoveryCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      prepareRecovered: () async {
        recoveryCalls++;
        return null;
      },
      replace: _unexpectedReplacement,
    );

    await _pumpHost(
      tester,
      controller: controller,
      coordinator: AvatarLostDataRecoveryCoordinator(isAndroid: () => false),
    );
    await tester.pumpAndSettle();

    expect(recoveryCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required AvatarReplacementController controller,
  required AvatarLostDataRecoveryCoordinator coordinator,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: AvatarLostDataRecoveryHost(
        uid: 'user-1',
        controller: controller,
        coordinator: coordinator,
        child: const Scaffold(body: Text('Home')),
      ),
    ),
  );
}

Future<UserAvatar> _unexpectedReplacement({
  required String uid,
  required PreparedAvatarImages images,
}) {
  throw StateError('replacement must not run');
}
