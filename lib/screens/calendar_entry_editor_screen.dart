import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/models/calendar_entry.dart';

enum CalendarEntryEditorAction { save, delete }

final class CalendarEntryEditorResult {
  const CalendarEntryEditorResult({
    required this.action,
    required this.kind,
    required this.date,
    required this.title,
    required this.priority,
    this.description,
    this.scheduledMinutes,
    this.reminderMinutes,
  });

  final CalendarEntryEditorAction action;
  final CalendarEntryKind kind;
  final DateTime date;
  final String title;
  final String? description;
  final int? scheduledMinutes;
  final int? reminderMinutes;
  final CalendarEntryPriority priority;
}

class CalendarEntryEditorScreen extends StatefulWidget {
  const CalendarEntryEditorScreen({
    super.key,
    required this.kind,
    required this.date,
    this.initialEntry,
  });

  final CalendarEntryKind kind;
  final DateTime date;
  final CalendarEntry? initialEntry;

  @override
  State<CalendarEntryEditorScreen> createState() =>
      _CalendarEntryEditorScreenState();
}

class _CalendarEntryEditorScreenState extends State<CalendarEntryEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _scheduledMinutes;
  int? _reminderMinutes;

  CalendarEntryPriority _priority = CalendarEntryPriority.none;

  bool _reminderEnabled = false;

  bool get _isEditing => widget.initialEntry != null;

  String get _screenTitle {
    return switch (widget.kind) {
      CalendarEntryKind.task =>
        _isEditing ? 'Редактировать дело' : 'Новое дело',
      CalendarEntryKind.note =>
        _isEditing ? 'Редактировать заметку' : 'Новая заметка',
    };
  }

  String get _descriptionLabel {
    return switch (widget.kind) {
      CalendarEntryKind.task => 'Описание',
      CalendarEntryKind.note => 'Текст заметки',
    };
  }

  String get _submitLabel {
    return _isEditing ? 'Сохранить' : 'Добавить';
  }

  @override
  void initState() {
    super.initState();

    final entry = widget.initialEntry;

    if (entry == null) {
      return;
    }

    _titleController.text = entry.title;
    _descriptionController.text = entry.description ?? '';

    _scheduledMinutes = entry.scheduledMinutes;
    _reminderMinutes = entry.reminderMinutes;
    _priority = entry.priority;
    _reminderEnabled = entry.hasReminder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectScheduledTime() async {
    final initialTime = _timeFromMinutes(_scheduledMinutes);

    final result = await _showTimeInputPicker(initialTime: initialTime);

    if (result == null) {
      return;
    }

    setState(() {
      _scheduledMinutes = _minutesFromTime(result);
    });
  }

  Future<void> _selectReminderTime() async {
    final initialMinutes = _reminderMinutes ?? _scheduledMinutes ?? 9 * 60;

    final result = await _showTimeInputPicker(
      initialTime: _timeFromMinutes(initialMinutes),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _reminderMinutes = _minutesFromTime(result);
    });
  }

  Future<TimeOfDay?> _showTimeInputPicker({required TimeOfDay initialTime}) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _TimeWheelPicker(initialTime: initialTime);
      },
    );
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    if (!enabled) {
      setState(() {
        _reminderEnabled = false;
        _reminderMinutes = null;
      });
      return;
    }

    setState(() {
      _reminderEnabled = true;
    });

    await _selectReminderTime();

    if (!mounted) {
      return;
    }

    if (_reminderMinutes == null) {
      setState(() {
        _reminderEnabled = false;
      });
    }
  }

  Future<void> _deleteEntry() async {
    final entry = widget.initialEntry;

    if (entry == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить запись?'),
          content: const Text('Запись будет удалена с этого устройства.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    Navigator.of(context).pop(
      CalendarEntryEditorResult(
        action: CalendarEntryEditorAction.delete,
        kind: entry.kind,
        date: entry.date,
        title: entry.title,
        description: entry.description,
        scheduledMinutes: entry.scheduledMinutes,
        reminderMinutes: entry.reminderMinutes,
        priority: entry.priority,
      ),
    );
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }

    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(
      CalendarEntryEditorResult(
        action: CalendarEntryEditorAction.save,
        kind: widget.kind,
        date: widget.date,
        title: title,
        description: description.isEmpty ? null : description,
        scheduledMinutes: _scheduledMinutes,
        reminderMinutes: _reminderEnabled ? _reminderMinutes : null,
        priority: _priority,
      ),
    );
  }

  void _selectPriority(CalendarEntryPriority priority) {
    setState(() {
      _priority = priority;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                ),
                Switch(value: _reminderEnabled, onChanged: _setReminderEnabled),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            _EditorOptionTile(
              icon: Icons.schedule_rounded,
              title: 'Время',
              value: _scheduledMinutes == null
                  ? 'Без времени'
                  : _formatMinutes(_scheduledMinutes!),
              onTap: _selectScheduledTime,
            ),
            if (_scheduledMinutes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _scheduledMinutes = null;
                    });
                  },
                  child: const Text('Убрать время'),
                ),
              ),
            if (_reminderEnabled) ...[
              const SizedBox(height: 8),
              _EditorOptionTile(
                icon: Icons.notifications_active_rounded,
                title: 'Напомнить',
                value: _reminderMinutes == null
                    ? 'Выбрать время'
                    : _formatMinutes(_reminderMinutes!),
                onTap: _selectReminderTime,
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Приоритет',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PriorityChip(
                    label: 'Нет',
                    priority: CalendarEntryPriority.none,
                    selectedPriority: _priority,
                    onSelected: _selectPriority,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PriorityChip(
                    label: 'Низкий',
                    priority: CalendarEntryPriority.low,
                    selectedPriority: _priority,
                    onSelected: _selectPriority,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PriorityChip(
                    label: 'Средний',
                    priority: CalendarEntryPriority.medium,
                    selectedPriority: _priority,
                    onSelected: _selectPriority,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PriorityChip(
                    label: 'Высокий',
                    priority: CalendarEntryPriority.high,
                    selectedPriority: _priority,
                    onSelected: _selectPriority,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: _descriptionLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_isEditing) ...[
              OutlinedButton.icon(
                onPressed: _deleteEntry,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _submit,
              icon: Icon(
                _isEditing ? Icons.save_outlined : Icons.check_rounded,
              ),
              label: Text(_submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  static int _minutesFromTime(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  static TimeOfDay _timeFromMinutes(int? minutes) {
    if (minutes == null) {
      return TimeOfDay.now();
    }

    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  static String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}

class _EditorOptionTile extends StatelessWidget {
  const _EditorOptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.priority,
    required this.selectedPriority,
    required this.onSelected,
  });

  final String label;
  final CalendarEntryPriority priority;
  final CalendarEntryPriority selectedPriority;

  final ValueChanged<CalendarEntryPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ChoiceChip(
        label: SizedBox(
          width: double.infinity,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        selected: priority == selectedPriority,
        showCheckmark: false,
        onSelected: (_) {
          onSelected(priority);
        },
      ),
    );
  }
}

class _TimeWheelPicker extends StatefulWidget {
  const _TimeWheelPicker({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<_TimeWheelPicker> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();

    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _hour);

    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Выберите время',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'ч',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 100,
                  child: Text(
                    'м',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 190,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: CupertinoPicker(
                      scrollController: _hourController,
                      itemExtent: 46,
                      useMagnifier: true,
                      looping: true,
                      magnification: 1.12,
                      squeeze: 1,
                      onSelectedItemChanged: (value) {
                        _hour = value;
                      },
                      children: List<Widget>.generate(24, (index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: theme.textTheme.headlineSmall,
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      ':',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: CupertinoPicker(
                      scrollController: _minuteController,
                      itemExtent: 46,
                      useMagnifier: true,
                      looping: true,
                      magnification: 1.12,
                      squeeze: 1,
                      onSelectedItemChanged: (value) {
                        _minute = value;
                      },
                      children: List<Widget>.generate(60, (index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: theme.textTheme.headlineSmall,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(TimeOfDay(hour: _hour, minute: _minute));
                    },
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
