import 'package:flutter/material.dart';

import 'chat_date_separator.dart';

class ChatScrollDateIndicator extends StatelessWidget {
  const ChatScrollDateIndicator({
    super.key,
    required this.label,
    required this.isVisible,
  });

  final String? label;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final shouldShow = isVisible && label != null;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: shouldShow ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, -0.15),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
          child: label == null
              ? const SizedBox.shrink()
              : ChatDateSeparator(key: ValueKey(label), label: label!),
        ),
      ),
    );
  }
}
