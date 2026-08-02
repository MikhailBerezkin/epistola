import 'package:flutter/material.dart';

import '../domain/models/image_message_metadata.dart';
import 'image_message_thumbnail.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.senderRole,
    required this.timeText,
    required this.isMe,
    this.isImageMessage = false,
    this.imageMetadata,
  });

  final String text;
  final String senderName;
  final String senderRole;
  final String timeText;
  final bool isMe;

  final bool isImageMessage;
  final ImageMessageMetadata? imageMetadata;

  Color getSenderNameColor(BuildContext context) {
    switch (senderRole) {
      case 'admin':
        return Colors.purple;
      case 'moderator':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = imageMetadata;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: getSenderNameColor(context),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (isImageMessage) ...[
              if (metadata != null)
                ImageMessageThumbnail(metadata: metadata)
              else
                const _UnavailableImage(),
              if (text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (text.isNotEmpty)
              Text(text, style: const TextStyle(fontSize: 16)),
            if (timeText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnavailableImage extends StatelessWidget {
  const _UnavailableImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined),
            SizedBox(height: 6),
            Text('Фотография недоступна'),
          ],
        ),
      ),
    );
  }
}
