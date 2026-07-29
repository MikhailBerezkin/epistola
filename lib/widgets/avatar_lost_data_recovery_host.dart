import 'package:flutter/material.dart';

import '../services/avatar/avatar_lost_data_recovery_coordinator.dart';
import '../services/avatar/avatar_replacement_controller.dart';

class AvatarLostDataRecoveryHost extends StatefulWidget {
  const AvatarLostDataRecoveryHost({
    super.key,
    required this.uid,
    required this.controller,
    required this.coordinator,
    required this.child,
  });

  final String uid;
  final AvatarReplacementController controller;
  final AvatarLostDataRecoveryCoordinator coordinator;
  final Widget child;

  @override
  State<AvatarLostDataRecoveryHost> createState() =>
      _AvatarLostDataRecoveryHostState();
}

class _AvatarLostDataRecoveryHostState
    extends State<AvatarLostDataRecoveryHost> {
  @override
  void initState() {
    super.initState();
    _scheduleRecovery();
  }

  @override
  void didUpdateWidget(covariant AvatarLostDataRecoveryHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uid != widget.uid ||
        oldWidget.controller != widget.controller ||
        oldWidget.coordinator != widget.coordinator) {
      _scheduleRecovery();
    }
  }

  void _scheduleRecovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostImage();
    });
  }

  Future<void> _recoverLostImage() async {
    final result = await widget.coordinator.recoverOnce(
      uid: widget.uid,
      recover: widget.controller.recoverLostImage,
    );

    if (!mounted || result?.status != AvatarReplacementStatus.failure) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось восстановить выбранное фото. '
            'Старый аватар сохранён.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
