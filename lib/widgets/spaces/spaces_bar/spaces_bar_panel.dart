import 'dart:async';

import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:flutter/material.dart';

class SpacesBarPanel extends StatefulWidget {
  const SpacesBarPanel({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onHideMessage,
    this.canManage = false,
    this.onEdit,
    this.autoRotationInterval = const Duration(seconds: 15),
  });

  final List<SpacesBarMessage> messages;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;
  final Future<void> Function(String messageId)? onHideMessage;

  final bool canManage;
  final VoidCallback? onEdit;

  final Duration autoRotationInterval;

  @override
  State<SpacesBarPanel> createState() => _SpacesBarPanelState();
}

class _SpacesBarPanelState extends State<SpacesBarPanel> {
  final PageController _pageController = PageController();

  Timer? _rotationTimer;
  int _currentIndex = 0;

  bool get _hasMultipleMessages => widget.messages.length > 1;

  bool get _canEdit {
    return widget.canManage && widget.onEdit != null;
  }

  @override
  void initState() {
    super.initState();
    _scheduleRotation();
  }

  @override
  void didUpdateWidget(covariant SpacesBarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_sameMessageIds(oldWidget.messages, widget.messages) &&
        oldWidget.autoRotationInterval == widget.autoRotationInterval) {
      return;
    }

    final previousMessageId =
        oldWidget.messages.isNotEmpty &&
            _currentIndex < oldWidget.messages.length
        ? oldWidget.messages[_currentIndex].id
        : null;

    var nextIndex = 0;

    if (previousMessageId != null) {
      final preservedIndex = widget.messages.indexWhere(
        (message) => message.id == previousMessageId,
      );

      if (preservedIndex >= 0) {
        nextIndex = preservedIndex;
      } else if (widget.messages.isNotEmpty) {
        nextIndex = _currentIndex.clamp(0, widget.messages.length - 1);
      }
    }

    _currentIndex = nextIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || widget.messages.isEmpty) {
        return;
      }

      _pageController.jumpToPage(_currentIndex);
    });

    _scheduleRotation();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  bool _sameMessageIds(
    List<SpacesBarMessage> first,
    List<SpacesBarMessage> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index += 1) {
      if (first[index].id != second[index].id) {
        return false;
      }
    }

    return true;
  }

  void _scheduleRotation() {
    _rotationTimer?.cancel();

    if (widget.isLoading ||
        widget.error != null ||
        widget.messages.length <= 1) {
      return;
    }

    _rotationTimer = Timer(widget.autoRotationInterval, _rotateToNextMessage);
  }

  void _rotateToNextMessage() {
    if (!mounted || !_hasMultipleMessages) {
      return;
    }

    if (!_pageController.hasClients) {
      _scheduleRotation();
      return;
    }

    _animateToPage((_currentIndex + 1) % widget.messages.length);
  }

  void _goToPreviousMessage() {
    if (!_hasMultipleMessages) {
      return;
    }

    final previousIndex =
        (_currentIndex - 1 + widget.messages.length) % widget.messages.length;

    _scheduleRotation();
    _animateToPage(previousIndex);
  }

  void _goToNextMessage() {
    if (!_hasMultipleMessages) {
      return;
    }

    final nextIndex = (_currentIndex + 1) % widget.messages.length;

    _scheduleRotation();
    _animateToPage(nextIndex);
  }

  void _animateToPage(int index) {
    if (!_pageController.hasClients) {
      return;
    }

    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _handlePageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }

    // Любой переход, включая swipe,
    // начинает новый полный 20-секундный интервал.
    _scheduleRotation();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const _SpacesBarFrame(
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (widget.error != null) {
      return _SpacesBarFrame(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(height: 8),
              const Text(
                'Не удалось загрузить закреплённые сообщения',
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widget.messages.isEmpty) {
      return _SpacesBarFrame(
        onEdit: _canEdit ? widget.onEdit : null,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin_outlined, size: 32),
              SizedBox(height: 8),
              Text(
                'Нет новых закреплённых сообщений',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentMessage = widget.messages[_currentIndex];

    return SizedBox(
      height: 141,
      child: Semantics(
        label: 'spaces-bar-current-message-${currentMessage.id}',
        container: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.messages.length,
                onPageChanged: _handlePageChanged,
                itemBuilder: (context, index) {
                  return _SpacesBarMessageCard(
                    message: widget.messages[index],
                    onHideMessage: widget.onHideMessage,
                    hasNavigation: _hasMultipleMessages,
                    reserveBottomSpace: _hasMultipleMessages || _canEdit,
                  );
                },
              ),
            ),

            if (_hasMultipleMessages) ...[
              Positioned(
                left: 5,
                top: 4,
                child: _SpacesBarNavigationButton(
                  key: const ValueKey('spaces-bar-chevron-left'),
                  icon: Icons.chevron_left,
                  tooltip: 'Предыдущее сообщение',
                  onPressed: _goToPreviousMessage,
                ),
              ),
              Positioned(
                right: 5,
                top: 4,
                child: _SpacesBarNavigationButton(
                  key: const ValueKey('spaces-bar-chevron-right'),
                  icon: Icons.chevron_right,
                  tooltip: 'Следующее сообщение',
                  onPressed: _goToNextMessage,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: Center(
                  child: _SpacesBarDots(
                    count: widget.messages.length,
                    currentIndex: _currentIndex,
                  ),
                ),
              ),
            ],

            if (_canEdit)
              Positioned(
                right: 7,
                bottom: 4,
                child: _SpacesBarEditButton(onPressed: widget.onEdit!),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpacesBarFrame extends StatelessWidget {
  const _SpacesBarFrame({required this.child, this.onEdit});

  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 141,
      child: Card(
        margin: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
            if (onEdit != null)
              Positioned(
                right: 7,
                bottom: 4,
                child: _SpacesBarEditButton(onPressed: onEdit!),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpacesBarMessageCard extends StatelessWidget {
  const _SpacesBarMessageCard({
    required this.message,
    required this.onHideMessage,
    required this.hasNavigation,
    required this.reserveBottomSpace,
  });

  final SpacesBarMessage message;
  final Future<void> Function(String messageId)? onHideMessage;
  final bool hasNavigation;

  final bool reserveBottomSpace;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForLifetime(message.lifetime);
    final borderRadius = BorderRadius.circular(16);

    return Card(
      key: ValueKey<String>('spaces-bar-message-${message.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: accent, width: 1.6),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpacesBarInnerGlowPainter(color: accent),
                ),
              ),
            ),
            Positioned.fill(
              child: InkWell(
                onLongPress: onHideMessage == null
                    ? null
                    : () {
                        unawaited(_showMessageActions(context));
                      },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    hasNavigation ? 40 : 16,
                    12,
                    hasNavigation ? 40 : 16,
                    reserveBottomSpace ? 26 : 12,
                  ),
                  child: _OverflowAwareMessageText(message: message),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    final action = await showModalBottomSheet<_SpacesBarMessageAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Убрать сообщение'),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop(_SpacesBarMessageAction.hide);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Отмена'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action != _SpacesBarMessageAction.hide) {
      return;
    }

    final hideMessage = onHideMessage;

    if (hideMessage != null) {
      await hideMessage(message.id);
    }
  }
}

class _SpacesBarInnerGlowPainter extends CustomPainter {
  const _SpacesBarInnerGlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 10 || size.height <= 10) {
      return;
    }

    final glowRect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withAlpha(42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, const Radius.circular(13)),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _SpacesBarInnerGlowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SpacesBarNavigationButton extends StatelessWidget {
  const _SpacesBarNavigationButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 22,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _SpacesBarEditButton extends StatelessWidget {
  const _SpacesBarEditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('spaces-bar-edit'),
      dimension: 32,
      child: IconButton(
        tooltip: 'Редактировать закреплённые сообщения',
        padding: EdgeInsets.zero,
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _OverflowAwareMessageText extends StatelessWidget {
  const _OverflowAwareMessageText({required this.message});

  final SpacesBarMessage message;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: message.text, style: textStyle),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                message.text,
                maxLines: hasOverflow ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (hasOverflow)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    _showFullMessage(context);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.only(top: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Подробнее'),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showFullMessage(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Закреплённое сообщение',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _lifetimeLabel(message.lifetime),
                  style: Theme.of(sheetContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(child: Text(message.text)),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpacesBarDots extends StatelessWidget {
  const _SpacesBarDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (index) {
        final selected = index == currentIndex;

        return AnimatedContainer(
          key: ValueKey<String>('spaces-bar-dot-$index'),
          duration: const Duration(milliseconds: 180),
          width: selected ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        );
      }),
    );
  }
}

enum _SpacesBarMessageAction { hide }

String _lifetimeLabel(SpacesBarMessageLifetime lifetime) {
  return switch (lifetime) {
    SpacesBarMessageLifetime.oneHour => '1 час',
    SpacesBarMessageLifetime.twelveHours => '12 часов',
    SpacesBarMessageLifetime.twentyFourHours => '24 часа',
    SpacesBarMessageLifetime.untilCancelled => 'До отмены',
  };
}

Color _accentForLifetime(SpacesBarMessageLifetime lifetime) {
  return switch (lifetime) {
    SpacesBarMessageLifetime.oneHour => Colors.green,
    SpacesBarMessageLifetime.twelveHours => Colors.blue,
    SpacesBarMessageLifetime.twentyFourHours => Colors.orange,
    SpacesBarMessageLifetime.untilCancelled => Colors.red,
  };
}
