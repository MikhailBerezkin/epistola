import 'dart:async';

import 'package:flutter/material.dart';

import '../models/message_presentation.dart';
import 'message_bubble.dart';

class MessageItem extends StatefulWidget {
  const MessageItem({
    super.key,
    required this.message,
    required this.senderRole,
    required this.timeText,
    required this.isMe,
    this.onLongPress,
  });

  final MessagePresentation message;
  final String senderRole;
  final String timeText;
  final bool isMe;
  final VoidCallback? onLongPress;

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  static const _fadeDuration = Duration(milliseconds: 160);
  static const _collapseDuration = Duration(milliseconds: 220);

  Timer? _collapseTimer;

  late bool _isContentVisible;
  late bool _keepsSpace;

  @override
  void initState() {
    super.initState();

    final isVisible = widget.message.isVisible;
    _isContentVisible = isVisible;
    _keepsSpace = isVisible;
  }

  @override
  void didUpdateWidget(covariant MessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasVisible = oldWidget.message.isVisible;
    final isVisible = widget.message.isVisible;

    if (wasVisible == isVisible) return;

    _collapseTimer?.cancel();

    if (isVisible) {
      setState(() {
        _keepsSpace = true;
        _isContentVisible = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.message.isVisible) return;

        setState(() {
          _isContentVisible = true;
        });
      });

      return;
    }

    setState(() {
      _isContentVisible = false;
    });

    _collapseTimer = Timer(_fadeDuration, () {
      if (!mounted || widget.message.isVisible) return;

      setState(() {
        _keepsSpace = false;
      });
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _collapseDuration,
      curve: Curves.easeInOutCubic,
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: _keepsSpace
          ? AnimatedOpacity(
              duration: _fadeDuration,
              curve: Curves.easeOut,
              opacity: _isContentVisible ? 1 : 0,
              child: AnimatedScale(
                duration: _fadeDuration,
                curve: Curves.easeOut,
                scale: _isContentVisible ? 1 : 0.96,
                child: IgnorePointer(
                  ignoring: !_isContentVisible,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: widget.onLongPress,
                    child: MessageBubble(
                      text: widget.message.text,
                      senderName: widget.message.senderName,
                      senderRole: widget.senderRole,
                      timeText: widget.timeText,
                      isMe: widget.isMe,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
