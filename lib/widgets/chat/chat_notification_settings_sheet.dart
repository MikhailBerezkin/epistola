import 'package:flutter/material.dart';

import '../../models/chat_notification_settings.dart';
import '../../services/chat/chat_notification_settings_service.dart';

class ChatNotificationSettingsSheet extends StatefulWidget {
  const ChatNotificationSettingsSheet({
    super.key,
    required this.chatId,
    required this.initialSettings,
    this.service,
  });

  final String chatId;
  final ChatNotificationSettings initialSettings;
  final ChatNotificationSettingsService? service;

  @override
  State<ChatNotificationSettingsSheet> createState() {
    return _ChatNotificationSettingsSheetState();
  }
}

class _ChatNotificationSettingsSheetState
    extends State<ChatNotificationSettingsSheet> {
  late final ChatNotificationSettingsService _service;

  bool _showSilentDurations = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? ChatNotificationSettingsService.firebase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _showSilentDurations
            ? _buildSilentDurationPage(context)
            : _buildMainPage(context),
      ),
    );
  }

  Widget _buildMainPage(BuildContext context) {
    final effectiveMode = widget.initialSettings.effectiveModeAt(
      DateTime.now(),
    );

    return Column(
      key: const ValueKey('notification-main'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Уведомления',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Со звуком'),
          subtitle: const Text('Push, звук и вибрация'),
          trailing: effectiveMode == ChatNotificationMode.sound
              ? const Icon(Icons.check)
              : null,
          onTap: () {
            _save((service) {
              return service.enableSound(chatId: widget.chatId);
            });
          },
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.notifications_off_outlined),
          title: const Text('Без звука'),
          subtitle: const Text('Push останется, звук и вибрация отключатся'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (effectiveMode == ChatNotificationMode.silent)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            setState(() {
              _showSilentDurations = true;
            });
          },
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.notifications_paused_outlined),
          title: const Text('Отключить уведомления'),
          subtitle: const Text('Не показывать push для этого чата'),
          trailing: effectiveMode == ChatNotificationMode.disabled
              ? const Icon(Icons.check)
              : null,
          onTap: () {
            _save((service) {
              return service.disableNotifications(chatId: widget.chatId);
            });
          },
        ),
        const Divider(height: 1),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.music_note_outlined),
          title: const Text('Звук уведомлений'),
          subtitle: const Text('Стандартный'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final messenger = ScaffoldMessenger.of(context);

            Navigator.of(context).pop();

            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Пока в разработке')),
              );
          },
        ),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: LinearProgressIndicator(),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSilentDurationPage(BuildContext context) {
    return Column(
      key: const ValueKey('notification-silent-duration'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _showSilentDurations = false;
                        });
                      },
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Назад',
              ),
              const SizedBox(width: 4),
              const Text(
                'Без звука',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('На 1 час'),
          onTap: () {
            _save((service) {
              return service.silenceFor(
                chatId: widget.chatId,
                duration: const Duration(hours: 1),
              );
            });
          },
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.today_outlined),
          title: const Text('На 24 часа'),
          onTap: () {
            _save((service) {
              return service.silenceFor(
                chatId: widget.chatId,
                duration: const Duration(hours: 24),
              );
            });
          },
        ),
        ListTile(
          enabled: !_isSaving,
          leading: const Icon(Icons.notifications_off_outlined),
          title: const Text('Навсегда'),
          onTap: () {
            _save((service) {
              return service.silenceForever(chatId: widget.chatId);
            });
          },
        ),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: LinearProgressIndicator(),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _save(
    Future<ChatNotificationSettingsWriteResult> Function(
      ChatNotificationSettingsService service,
    )
    action,
  ) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await action(_service);

      if (!mounted) {
        return;
      }

      if (result ==
          ChatNotificationSettingsWriteResult.skippedUnauthenticated) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Не удалось изменить настройки уведомлений'),
            ),
          );

        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить настройки уведомлений'),
          ),
        );
    }
  }
}
