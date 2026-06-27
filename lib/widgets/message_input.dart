import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
  });
  Widget _attachmentTile(BuildContext context, IconData icon, String title) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (context) {
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
                              context,
                              Icons.photo_library_outlined,
                              'Галерея',
                            ),
                            _attachmentTile(
                              context,
                              Icons.camera_alt_outlined,
                              'Камера',
                            ),
                            _attachmentTile(
                              context,
                              Icons.insert_drive_file_outlined,
                              'Файл',
                            ),
                            _attachmentTile(
                              context,
                              Icons.mic_none,
                              'Голосовое',
                            ),
                            _attachmentTile(
                              context,
                              Icons.location_on_outlined,
                              'Геопозиция',
                            ),
                            _attachmentTile(
                              context,
                              Icons.person_outline,
                              'Контакт',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Сообщение',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}
