import 'package:flutter/material.dart';

import '../../../domain/models/spaces_bar_board.dart';
import '../../../domain/models/spaces_bar_message.dart';

sealed class SpacesBarEditorAction {
  const SpacesBarEditorAction();
}

final class SpacesBarEditorPublishAction extends SpacesBarEditorAction {
  const SpacesBarEditorPublishAction({
    required this.text,
    required this.lifetime,
  });

  final String text;
  final SpacesBarMessageLifetime lifetime;
}

final class SpacesBarEditorDeleteAction extends SpacesBarEditorAction {
  const SpacesBarEditorDeleteAction({required this.messageId});

  final String messageId;
}

class SpacesBarEditorSheet extends StatefulWidget {
  const SpacesBarEditorSheet({super.key, required this.activeMessages});

  final List<SpacesBarMessage> activeMessages;

  @override
  State<SpacesBarEditorSheet> createState() => _SpacesBarEditorSheetState();
}

class _SpacesBarEditorSheetState extends State<SpacesBarEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();

  SpacesBarMessageLifetime _lifetime = SpacesBarMessageLifetime.oneHour;

  bool get _hasFreeSlot {
    return widget.activeMessages.length < SpacesBarBoard.maxMessages;
  }

  @override
  void dispose() {
    _textController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Закреплённые сообщения',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Активные сообщения '
                '${widget.activeMessages.length}/'
                '${SpacesBarBoard.maxMessages}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.activeMessages.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...widget.activeMessages.map(
                  (message) => _ActiveMessageTile(
                    message: message,
                    onDelete: () {
                      _requestDelete(message);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_hasFreeSlot)
                _buildPublisher(context)
              else
                _buildCapacityMessage(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublisher(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Новое сообщение',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('spaces-bar-editor-text'),
            controller: _textController,
            autofocus: widget.activeMessages.isEmpty,
            minLines: 3,
            maxLines: 4,
            maxLength: SpacesBarMessage.maxTextLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Текст',
              hintText: 'Введите закреплённое сообщение',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите текст сообщения';
              }

              return null;
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SpacesBarMessageLifetime>(
            key: const ValueKey('spaces-bar-editor-lifetime'),
            initialValue: _lifetime,
            decoration: const InputDecoration(
              labelText: 'Срок',
              border: OutlineInputBorder(),
            ),
            items: SpacesBarMessageLifetime.values
                .map(
                  (lifetime) => DropdownMenuItem<SpacesBarMessageLifetime>(
                    value: lifetime,
                    child: Text(_lifetimeLabel(lifetime)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _lifetime = value;
              });
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('spaces-bar-editor-publish'),
            onPressed: _publish,
            icon: const Icon(Icons.push_pin_outlined),
            label: const Text('Опубликовать'),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Достигнут лимит 3/3. '
        'Удалите одно из активных сообщений, '
        'чтобы опубликовать новое.',
      ),
    );
  }

  void _publish() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop<SpacesBarEditorAction>(
      SpacesBarEditorPublishAction(
        text: _textController.text.trim(),
        lifetime: _lifetime,
      ),
    );
  }

  Future<void> _requestDelete(SpacesBarMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить сообщение?'),
          content: const Text(
            'Сообщение исчезнет из SpacesBar '
            'у всех пользователей.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.of(context).pop<SpacesBarEditorAction>(
      SpacesBarEditorDeleteAction(messageId: message.id),
    );
  }
}

class _ActiveMessageTile extends StatelessWidget {
  const _ActiveMessageTile({required this.message, required this.onDelete});

  final SpacesBarMessage message;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        leading: const Icon(Icons.push_pin_outlined),
        title: Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_lifetimeLabel(message.lifetime)),
        trailing: IconButton(
          key: ValueKey<String>('spaces-bar-editor-delete-${message.id}'),
          tooltip: 'Удалить для всех',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

String _lifetimeLabel(SpacesBarMessageLifetime lifetime) {
  return switch (lifetime) {
    SpacesBarMessageLifetime.oneHour => '1 час',
    SpacesBarMessageLifetime.twelveHours => '12 часов',
    SpacesBarMessageLifetime.twentyFourHours => '24 часа',
    SpacesBarMessageLifetime.untilCancelled => 'До отмены',
  };
}
