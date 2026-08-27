import 'package:flutter/material.dart';

import '../identity/identity_overlay.dart';

class ChatIdentityOverlay extends StatelessWidget {
  const ChatIdentityOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.64,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return IdentityOverlay(
      isOpen: isOpen,
      onClose: onClose,
      heightFactor: heightFactor,
      child: child,
    );
  }
}
