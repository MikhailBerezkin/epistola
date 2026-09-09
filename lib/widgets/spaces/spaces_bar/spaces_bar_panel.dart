import 'dart:async';

import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_item.dart';
import 'package:flutter/material.dart';

class SpacesBarPanel extends StatefulWidget {
  const SpacesBarPanel({
    super.key,
    this.messages = const <SpacesBarMessage>[],
    this.items = const <SpacesBarPresentationItem>[],
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onHideMessage,
    this.onHideSubstitutionCall,
    this.canManage = false,
    this.onEdit,
    this.targetMessageId,
    this.autoRotationInterval = const Duration(seconds: 10),
  });

  /// Временный legacy-вход только для плавного перехода SpacesPage.
  ///
  /// После этапа 5C2 будет удалён.
  final List<SpacesBarMessage> messages;

  /// Новый единый presentation-вход:
  /// general announcements + personal substitution calls.
  final List<SpacesBarPresentationItem> items;

  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;

  final Future<void> Function(String messageId)? onHideMessage;

  final Future<void> Function(String callId)? onHideSubstitutionCall;

  final bool canManage;
  final VoidCallback? onEdit;

  /// Push target относится только к обычному general SpacesBar.
  final String? targetMessageId;

  final Duration autoRotationInterval;

  @override
  State<SpacesBarPanel> createState() => _SpacesBarPanelState();
}

class _SpacesBarPanelState extends State<SpacesBarPanel> {
  static const int _pageAnchor = 1 << 20;

  late final PageController _pageController;

  Timer? _rotationTimer;
  int _currentIndex = 0;
  int _currentPhysicalPage = _pageAnchor;

  List<SpacesBarPresentationItem> get _items {
    if (widget.items.isNotEmpty) {
      return widget.items;
    }

    if (widget.messages.isEmpty) {
      return const <SpacesBarPresentationItem>[];
    }

    return widget.messages
        .map((message) => SpacesBarPresentationItem.general(message: message))
        .toList(growable: false);
  }

  List<SpacesBarPresentationItem> _itemsFor(SpacesBarPanel widget) {
    if (widget.items.isNotEmpty) {
      return widget.items;
    }

    if (widget.messages.isEmpty) {
      return const <SpacesBarPresentationItem>[];
    }

    return widget.messages
        .map((message) => SpacesBarPresentationItem.general(message: message))
        .toList(growable: false);
  }

  bool get _hasMultipleMessages => _items.length > 1;

  bool get _canEdit {
    return widget.canManage && widget.onEdit != null;
  }

  @override
  void initState() {
    super.initState();

    assert(
      widget.messages.isEmpty || widget.items.isEmpty,
      'Use either messages or items, not both.',
    );

    final items = _items;

    _currentIndex = _findTargetIndex(
      items: items,
      targetMessageId: widget.targetMessageId,
    );

    _currentPhysicalPage = _physicalPageForLogicalIndex(
      logicalIndex: _currentIndex,
      itemCount: items.length,
    );

    _pageController = PageController(initialPage: _currentPhysicalPage);

    _scheduleRotation();
  }

  @override
  void didUpdateWidget(covariant SpacesBarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldItems = _itemsFor(oldWidget);
    final newItems = _items;

    if (_samePresentationIds(oldItems, newItems) &&
        oldWidget.autoRotationInterval == widget.autoRotationInterval &&
        oldWidget.targetMessageId == widget.targetMessageId) {
      return;
    }

    final previousPresentationId =
        _currentIndex >= 0 && _currentIndex < oldItems.length
        ? oldItems[_currentIndex].presentationId
        : null;

    var nextIndex = 0;

    final targetMessageId = widget.targetMessageId;

    final targetIndex = targetMessageId == null
        ? -1
        : newItems.indexWhere((item) => _matchesTarget(item, targetMessageId));

    final targetWasAvailable =
        targetMessageId != null &&
        oldItems.any((item) => _matchesTarget(item, targetMessageId));

    final targetChanged = oldWidget.targetMessageId != widget.targetMessageId;

    final shouldApplyTarget =
        targetIndex >= 0 && (targetChanged || !targetWasAvailable);

    if (shouldApplyTarget) {
      nextIndex = targetIndex;
    } else if (targetIndex >= 0 &&
        previousPresentationId == newItems[targetIndex].presentationId) {
      nextIndex = targetIndex;
    } else {
      final oldPresentationIds = oldItems
          .map((item) => item.presentationId)
          .toSet();

      final addedItemIndex = newItems.indexWhere(
        (item) => !oldPresentationIds.contains(item.presentationId),
      );

      if (addedItemIndex >= 0) {
        nextIndex = addedItemIndex;
      } else if (previousPresentationId != null) {
        final preservedIndex = newItems.indexWhere(
          (item) => item.presentationId == previousPresentationId,
        );

        if (preservedIndex >= 0) {
          nextIndex = preservedIndex;
        }
      }
    }

    _currentIndex = newItems.isEmpty
        ? 0
        : nextIndex.clamp(0, newItems.length - 1);

    _currentPhysicalPage = _physicalPageForLogicalIndex(
      logicalIndex: _currentIndex,
      itemCount: newItems.length,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      _pageController.jumpToPage(_currentPhysicalPage);
    });

    _scheduleRotation();
  }

  bool _matchesTarget(SpacesBarPresentationItem item, String targetId) {
    return item.presentationId == targetId || item.generalMessageId == targetId;
  }

  int _findTargetIndex({
    required List<SpacesBarPresentationItem> items,
    required String? targetMessageId,
  }) {
    if (items.isEmpty || targetMessageId == null) {
      return 0;
    }

    final targetIndex = items.indexWhere(
      (item) => _matchesTarget(item, targetMessageId),
    );

    return targetIndex >= 0 ? targetIndex : 0;
  }

  int _physicalPageForLogicalIndex({
    required int logicalIndex,
    required int itemCount,
  }) {
    if (itemCount <= 0) {
      return _pageAnchor;
    }

    final cycleStart = _pageAnchor - (_pageAnchor % itemCount);

    return cycleStart + logicalIndex;
  }

  int _logicalIndexForPhysicalPage({
    required int physicalPage,
    required int itemCount,
  }) {
    if (itemCount <= 0) {
      return 0;
    }

    return physicalPage % itemCount;
  }

  Color _glowColorForCurrentPosition(List<SpacesBarPresentationItem> items) {
    if (items.isEmpty) {
      return Colors.transparent;
    }

    final fallbackIndex = _currentIndex.clamp(0, items.length - 1);

    final fallbackColor = _accentForItem(items[fallbackIndex]);

    if (!_pageController.hasClients) {
      return fallbackColor;
    }

    final page = _pageController.page;

    if (page == null) {
      return fallbackColor;
    }

    final lowerPhysicalPage = page.floor();
    final upperPhysicalPage = page.ceil();

    final lowerIndex = _logicalIndexForPhysicalPage(
      physicalPage: lowerPhysicalPage,
      itemCount: items.length,
    );

    final upperIndex = _logicalIndexForPhysicalPage(
      physicalPage: upperPhysicalPage,
      itemCount: items.length,
    );

    if (lowerPhysicalPage == upperPhysicalPage) {
      return _accentForItem(items[lowerIndex]);
    }

    final progress = (page - lowerPhysicalPage).clamp(0.0, 1.0).toDouble();

    return Color.lerp(
          _accentForItem(items[lowerIndex]),
          _accentForItem(items[upperIndex]),
          progress,
        ) ??
        fallbackColor;
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  bool _samePresentationIds(
    List<SpacesBarPresentationItem> first,
    List<SpacesBarPresentationItem> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index += 1) {
      if (first[index].presentationId != second[index].presentationId) {
        return false;
      }
    }

    return true;
  }

  void _scheduleRotation() {
    _rotationTimer?.cancel();

    if (widget.isLoading || widget.error != null || _items.length <= 1) {
      return;
    }

    _rotationTimer = Timer(widget.autoRotationInterval, _rotateToNextMessage);
  }

  void _rotateToNextMessage() {
    final items = _items;

    if (!mounted || items.length <= 1) {
      return;
    }

    if (!_pageController.hasClients) {
      _scheduleRotation();
      return;
    }

    unawaited(_animateToPhysicalPage(_currentPhysicalPage + 1));
  }

  void _goToPreviousMessage() {
    if (_items.length <= 1) {
      return;
    }

    _scheduleRotation();

    unawaited(_animateToPhysicalPage(_currentPhysicalPage - 1));
  }

  void _goToNextMessage() {
    if (_items.length <= 1) {
      return;
    }

    _scheduleRotation();

    unawaited(_animateToPhysicalPage(_currentPhysicalPage + 1));
  }

  Future<void> _animateToPhysicalPage(int physicalPage) async {
    if (!_pageController.hasClients) {
      return;
    }

    await _pageController.animateToPage(
      physicalPage,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int physicalPage) {
    final items = _items;

    if (items.isEmpty) {
      return;
    }

    final logicalIndex = _logicalIndexForPhysicalPage(
      physicalPage: physicalPage,
      itemCount: items.length,
    );

    _currentPhysicalPage = physicalPage;

    if (_currentIndex != logicalIndex) {
      setState(() {
        _currentIndex = logicalIndex;
      });
    }

    // Любой переход, включая swipe,
    // начинает новый полный интервал.
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

    final items = _items;

    if (items.isEmpty) {
      return _SpacesBarFrame(
        onEdit: _canEdit ? widget.onEdit : null,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/epistola_seagull_stencil.png',
                key: const Key('spaces-bar-empty-seagull'),
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 4),
              const Text(
                'Нет новых закреплённых сообщений',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= items.length) {
      _currentIndex = 0;
    }

    final currentItem = items[_currentIndex];
    final borderRadius = BorderRadius.circular(16);

    final frameBorderColor = Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      height: 141,
      child: Semantics(
        label: _currentItemSemanticsLabel(currentItem),
        container: true,
        child: Card(
          key: const ValueKey('spaces-bar-stationary-frame'),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: frameBorderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        return CustomPaint(
                          key: const ValueKey('spaces-bar-inner-glow'),
                          painter: _SpacesBarInnerGlowPainter(
                            color: _glowColorForCurrentPosition(items),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _hasMultipleMessages
                        ? const PageScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, physicalPage) {
                      final logicalIndex = _logicalIndexForPhysicalPage(
                        physicalPage: physicalPage,
                        itemCount: items.length,
                      );

                      return _SpacesBarItemContent(
                        item: items[logicalIndex],
                        onHideMessage: widget.onHideMessage,
                        onHideSubstitutionCall: widget.onHideSubstitutionCall,
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
                        count: items.length,
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

class _SpacesBarItemContent extends StatelessWidget {
  const _SpacesBarItemContent({
    required this.item,
    required this.onHideMessage,
    required this.onHideSubstitutionCall,
    required this.hasNavigation,
    required this.reserveBottomSpace,
  });

  final SpacesBarPresentationItem item;

  final Future<void> Function(String messageId)? onHideMessage;

  final Future<void> Function(String callId)? onHideSubstitutionCall;

  final bool hasNavigation;
  final bool reserveBottomSpace;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>(_cardKey(item)),
      onLongPress: _canHideItem
          ? () {
              unawaited(_showMessageActions(context));
            }
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasNavigation ? 40 : 16,
          12,
          hasNavigation ? 40 : 16,
          reserveBottomSpace ? 26 : 12,
        ),
        child: _OverflowAwareMessageText(item: item),
      ),
    );
  }

  bool get _canHideItem {
    return switch (item.source) {
      SpacesBarPresentationItemSource.generalMessage => onHideMessage != null,
      SpacesBarPresentationItemSource.substitutionCall =>
        onHideSubstitutionCall != null,
    };
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

    switch (item.source) {
      case SpacesBarPresentationItemSource.generalMessage:
        final hideMessage = onHideMessage;

        if (hideMessage != null) {
          await hideMessage(item.sourceId);
        }

      case SpacesBarPresentationItemSource.substitutionCall:
        final hideCall = onHideSubstitutionCall;

        if (hideCall != null) {
          await hideCall(item.sourceId);
        }
    }
  }
}

class _SpacesBarInnerGlowPainter extends CustomPainter {
  const _SpacesBarInnerGlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final depth = size.shortestSide * 0.30;

    final strongColor = color.withAlpha(45);
    final middleColor = color.withAlpha(10);
    final transparentColor = color.withAlpha(0);

    final colors = <Color>[strongColor, middleColor, transparentColor];

    const stops = <double>[0, 0.45, 1];

    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(15),
    );

    canvas.save();
    canvas.clipRRect(clip);

    final topRect = Rect.fromLTWH(0, 0, size.width, depth);

    canvas.drawRect(
      topRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(topRect),
    );

    final bottomRect = Rect.fromLTWH(0, size.height - depth, size.width, depth);

    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
          stops: stops,
        ).createShader(bottomRect),
    );

    final leftRect = Rect.fromLTWH(0, 0, depth, size.height);

    canvas.drawRect(
      leftRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
          stops: stops,
        ).createShader(leftRect),
    );

    final rightRect = Rect.fromLTWH(size.width - depth, 0, depth, size.height);

    canvas.drawRect(
      rightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: colors,
          stops: stops,
        ).createShader(rightRect),
    );

    canvas.restore();
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
  const _OverflowAwareMessageText({required this.item});

  final SpacesBarPresentationItem item;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: item.text, style: textStyle),
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
                item.text,
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
        final generalMessage = item.generalMessage;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.isSubstitutionCall
                      ? 'Вызов на смену'
                      : 'Закреплённое сообщение',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                if (generalMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _lifetimeLabel(generalMessage.lifetime),
                    style: Theme.of(sheetContext).textTheme.labelLarge,
                  ),
                ],
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: Text(item.text))),
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

String _currentItemSemanticsLabel(SpacesBarPresentationItem item) {
  return switch (item.source) {
    SpacesBarPresentationItemSource.generalMessage =>
      'spaces-bar-current-message-${item.sourceId}',
    SpacesBarPresentationItemSource.substitutionCall =>
      'spaces-bar-current-substitution-call-${item.sourceId}',
  };
}

String _cardKey(SpacesBarPresentationItem item) {
  return switch (item.source) {
    SpacesBarPresentationItemSource.generalMessage =>
      'spaces-bar-message-${item.sourceId}',
    SpacesBarPresentationItemSource.substitutionCall =>
      'spaces-bar-substitution-call-${item.sourceId}',
  };
}

String _lifetimeLabel(SpacesBarMessageLifetime lifetime) {
  return switch (lifetime) {
    SpacesBarMessageLifetime.oneHour => '1 час',
    SpacesBarMessageLifetime.twelveHours => '12 часов',
    SpacesBarMessageLifetime.twentyFourHours => '24 часа',
    SpacesBarMessageLifetime.untilCancelled => 'До отмены',
  };
}

Color _accentForItem(SpacesBarPresentationItem item) {
  if (item.isSubstitutionCall) {
    return Colors.purple;
  }

  final generalMessage = item.generalMessage;

  if (generalMessage == null) {
    throw StateError(
      'General SpacesBar item '
      'does not contain a message.',
    );
  }

  return _accentForLifetime(generalMessage.lifetime);
}

Color _accentForLifetime(SpacesBarMessageLifetime lifetime) {
  return switch (lifetime) {
    SpacesBarMessageLifetime.oneHour => Colors.green,
    SpacesBarMessageLifetime.twelveHours => Colors.blue,
    SpacesBarMessageLifetime.twentyFourHours => Colors.orange,
    SpacesBarMessageLifetime.untilCancelled => Colors.red,
  };
}
