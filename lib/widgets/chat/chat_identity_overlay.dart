import 'package:flutter/material.dart';

class ChatIdentityOverlay extends StatelessWidget {
  const ChatIdentityOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.64,
  });

  static const _animationDuration = Duration(milliseconds: 340);

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveHeightFactor = heightFactor.clamp(0.45, 0.85);
          final panelHeight = constraints.maxHeight * effectiveHeightFactor;

          return IgnorePointer(
            ignoring: !isOpen,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    curve: Curves.easeOutCubic,
                    opacity: isOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _animationDuration,
                  curve: Curves.easeOutCubic,
                  top: isOpen ? 0 : -panelHeight,
                  left: 0,
                  right: 0,
                  height: panelHeight,
                  child: Material(
                    elevation: 12,
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
