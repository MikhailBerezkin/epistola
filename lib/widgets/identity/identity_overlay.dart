import 'package:flutter/material.dart';

class IdentityOverlay extends StatefulWidget {
  const IdentityOverlay({
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
  State<IdentityOverlay> createState() {
    return _IdentityOverlayState();
  }
}

class _IdentityOverlayState extends State<IdentityOverlay> {
  static const _animationDuration = Duration(milliseconds: 340);

  late bool _hasOpened;

  @override
  void initState() {
    super.initState();
    _hasOpened = widget.isOpen;
  }

  @override
  void didUpdateWidget(covariant IdentityOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_hasOpened && widget.isOpen) {
      _hasOpened = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveHeightFactor = widget.heightFactor.clamp(0.45, 0.85);
          final panelHeight = constraints.maxHeight * effectiveHeightFactor;

          return IgnorePointer(
            ignoring: !widget.isOpen,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    curve: Curves.easeOutCubic,
                    opacity: widget.isOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _animationDuration,
                  curve: Curves.easeOutCubic,
                  top: widget.isOpen ? 0 : -panelHeight,
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
                    child: _hasOpened ? widget.child : const SizedBox.expand(),
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
