import 'package:flutter/material.dart';

import '../../domain/models/epistola_system_message.dart';
import '../../helpers/chat_date_formatter.dart';
import '../chat/chat_date_separator.dart';

class EpistolaSystemMessagesList extends StatelessWidget {
  const EpistolaSystemMessagesList({
    super.key,
    required this.messages,
    this.controller,
    this.now,
  });

  final List<EpistolaSystemMessage> messages;

  final ScrollController? controller;

  /// Используется для детерминированных widget-тестов.
  /// В приложении обычно не передаётся.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('epistola-system-messages-list'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        final previousMessage = index == 0 ? null : messages[index - 1];

        final startsNewDay = ChatDateFormatter.startsNewDay(
          current: message.createdAt,
          previous: previousMessage?.createdAt,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsNewDay)
              ChatDateSeparator(
                label: ChatDateFormatter.format(message.createdAt, now: now),
              ),
            _EpistolaSystemMessageBubble(
              key: ValueKey('epistola-system-message-${message.id}'),
              message: message,
            ),
          ],
        );
      },
    );
  }
}

class _EpistolaSystemMessageBubble extends StatelessWidget {
  const _EpistolaSystemMessageBubble({super.key, required this.message});

  final EpistolaSystemMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final localCreatedAt = message.createdAt.toLocal();

    final hour = localCreatedAt.hour.toString().padLeft(2, '0');

    final minute = localCreatedAt.minute.toString().padLeft(2, '0');

    final timeText = '$hour:$minute';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(message.text, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Text(
              timeText,
              key: ValueKey('epistola-system-message-time-${message.id}'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
