import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/value_objects/message_text.dart';

typedef MessageAttachmentAction = Future<void> Function();

class MessageInput extends StatelessWidget {
  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onPickFromGallery,
    this.onTakePhoto,
    this.isBusy = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  final MessageAttachmentAction? onPickFromGallery;
  final MessageAttachmentAction? onTakePhoto;

  final bool isBusy;

  Widget _attachmentTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    MessageAttachmentAction? action,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBusy
            ? null
            : () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                navigator.pop();

                if (action != null) {
                  await action();
                  return;
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '$title появится в одной из следующих версий Epistola.',
                    ),
                  ),
                );
              },
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3,
              children: [
                _attachmentTile(
                  context: sheetContext,
                  icon: Icons.photo_library_outlined,
                  title: 'Галерея',
                  action: onPickFromGallery,
                ),
                _attachmentTile(
                  context: sheetContext,
                  icon: Icons.camera_alt_outlined,
                  title: 'Камера',
                  action: onTakePhoto,
                ),
                _attachmentTile(
                  context: sheetContext,
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Файл',
                ),
                _attachmentTile(
                  context: sheetContext,
                  icon: Icons.mic_none,
                  title: 'Голосовое',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: isBusy
                  ? null
                  : () {
                      _showAttachments(context);
                    },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isBusy,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(MessageText.maxLength),
                ],
                decoration: InputDecoration(
                  hintText: 'Сообщение',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isBusy)
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}
