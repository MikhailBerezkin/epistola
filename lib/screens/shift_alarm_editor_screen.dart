import 'package:flutter/material.dart';

import '../domain/models/shift_alarm.dart';
import '../domain/models/shift_cycle.dart';
import '../widgets/common/time_wheel_picker_sheet.dart';

final class ShiftAlarmEditorResult {
  const ShiftAlarmEditorResult({this.alarm, this.shouldDelete = false});

  final ShiftAlarm? alarm;
  final bool shouldDelete;
}

class ShiftAlarmEditorScreen extends StatefulWidget {
  const ShiftAlarmEditorScreen({
    super.key,
    required this.phase,
    required this.scope,
    this.initialAlarm,
  });

  final ShiftCyclePhase phase;
  final ShiftAlarmScope scope;
  final ShiftAlarm? initialAlarm;

  @override
  State<ShiftAlarmEditorScreen> createState() => _ShiftAlarmEditorScreenState();
}

class _ShiftAlarmEditorScreenState extends State<ShiftAlarmEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;

  late ShiftAlarmType _type;
  late TimeOfDay _time;
  late int _durationSeconds;
  late bool _enabled;

  bool get _isEditing => widget.initialAlarm != null;

  @override
  void initState() {
    super.initState();

    final alarm = widget.initialAlarm;

    _titleController = TextEditingController(text: alarm?.title ?? '');

    _type = alarm?.type ?? ShiftAlarmType.alarm;

    final minutes = alarm?.minutesOfDay ?? 7 * 60;

    _time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    _durationSeconds = alarm?.durationSeconds ?? 15;
    _enabled = alarm?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final selected = await showTimeWheelPickerSheet(
      context: context,
      initialTime: _time,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _time = selected;
    });
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final now = DateTime.now().toUtc();
    final initial = widget.initialAlarm;

    final alarm = ShiftAlarm(
      id: initial?.id ?? 'shift_alarm_${DateTime.now().microsecondsSinceEpoch}',
      phase: widget.phase,
      scope: widget.scope,
      type: _type,
      title: _titleController.text.trim(),
      minutesOfDay: _time.hour * 60 + _time.minute,
      durationSeconds: _type == ShiftAlarmType.notification
          ? _durationSeconds
          : null,
      enabled: _enabled,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );

    if (!alarm.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте параметры сигнала')),
      );
      return;
    }

    Navigator.of(context).pop(ShiftAlarmEditorResult(alarm: alarm));
  }

  Future<void> _delete() async {
    if (!_isEditing) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить сигнал?'),
          content: Text(
            '«${widget.initialAlarm!.title}» будет удалён с этого устройства.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    Navigator.of(context).pop(const ShiftAlarmEditorResult(shouldDelete: true));
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать сигнал' : 'Новый сигнал'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Удалить',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                widget.phase.alarmEditorTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.scope.displayTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Подъём',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<ShiftAlarmType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Тип',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in ShiftAlarmType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.displayTitle),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _type = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Время'),
                  subtitle: Text(
                    _formatTime(_time),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _selectTime,
                ),
              ),

              if (_type == ShiftAlarmType.notification) ...[
                const SizedBox(height: 20),
                Text(
                  'Длительность оповещения',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final duration
                        in ShiftAlarm.allowedNotificationDurations)
                      ChoiceChip(
                        label: Text('$duration сек'),
                        selected: _durationSeconds == duration,
                        onSelected: (_) {
                          setState(() {
                            _durationSeconds = duration;
                          });
                        },
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              Card(
                child: SwitchListTile(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                  secondary: Icon(
                    _enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(_enabled ? 'Сигнал включён' : 'Сигнал выключен'),
                  subtitle: const Text('Можно временно выключить без удаления'),
                ),
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(
                  _isEditing ? 'Сохранить изменения' : 'Добавить сигнал',
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
