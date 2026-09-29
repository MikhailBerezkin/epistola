import 'package:flutter/material.dart';

import '../domain/models/calendar_entry.dart';
import '../domain/models/shift_calendar_theme.dart';
import '../widgets/common/time_wheel_picker_sheet.dart';

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
    required this.palette,
    this.initialEntry,
  });

  final CalendarEntryKind kind;
  final DateTime date;
  final ShiftCalendarThemePalette palette;
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

  Color get _background => Color(widget.palette.background);
  Color get _foreground => _editorContrastColor(_background);
  Color get _accent => Color(widget.palette.selectedDay);
  Color get _accentForeground => _editorContrastColor(_accent);

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
    return showTimeWheelPickerSheet(
      context: context,
      initialTime: initialTime,
      backgroundColor: _background,
      foregroundColor: _foreground,
      accentColor: _accent,
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
        final dialogBackground = _editorLayerColor(_background, 0.05);
        final dialogForeground = _editorContrastColor(dialogBackground);

        return AlertDialog(
          backgroundColor: dialogBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Удалить запись?',
            style: TextStyle(color: dialogForeground),
          ),
          content: Text(
            'Запись будет удалена с этого устройства.',
            style: TextStyle(color: dialogForeground.withValues(alpha: 0.72)),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: dialogForeground),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accentForeground,
              ),
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
    final baseTheme = Theme.of(context);
    final background = _background;
    final foreground = _foreground;
    final accent = _accent;
    final accentForeground = _accentForeground;

    final secondary = foreground.withValues(alpha: 0.68);
    final fieldBackground = _editorLayerColor(background, 0.035);
    final chipBackground = _editorLayerColor(background, 0.055);
    final selectedChipBackground = Color.lerp(chipBackground, accent, 0.18)!;
    final outline = foreground.withValues(alpha: 0.34);

    final brightness =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Brightness.dark
        : Brightness.light;

    final localColorScheme = baseTheme.colorScheme.copyWith(
      brightness: brightness,
      primary: accent,
      onPrimary: accentForeground,
      surface: background,
      onSurface: foreground,
      outline: outline,
    );

    final localTheme = baseTheme.copyWith(
      colorScheme: localColorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
        backgroundColor: _editorLayerColor(background, 0.05),
        surfaceTintColor: Colors.transparent,
      ),
    );

    InputDecoration fieldDecoration({
      required String label,
      bool alignLabelWithHint = false,
    }) {
      return InputDecoration(
        labelText: label,
        alignLabelWithHint: alignLabelWithHint,
        labelStyle: TextStyle(color: secondary),
        filled: true,
        fillColor: fieldBackground,
        border: OutlineInputBorder(borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      );
    }

    return Theme(
      data: localTheme,
      child: Scaffold(
        backgroundColor: background,
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
                    color: foreground,
                  ),
                  Switch(
                    value: _reminderEnabled,
                    onChanged: _setReminderEnabled,
                  ),
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
                style: TextStyle(color: foreground),
                cursorColor: accent,
                decoration: fieldDecoration(label: 'Название'),
              ),
              const SizedBox(height: 18),
              _EditorOptionTile(
                icon: Icons.schedule_rounded,
                title: 'Время',
                value: _scheduledMinutes == null
                    ? 'Без времени'
                    : _formatMinutes(_scheduledMinutes!),
                foregroundColor: foreground,
                secondaryColor: secondary,
                onTap: _selectScheduledTime,
              ),
              if (_scheduledMinutes != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: accent),
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
                  foregroundColor: foreground,
                  secondaryColor: secondary,
                  onTap: _selectReminderTime,
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Приоритет',
                style: localTheme.textTheme.titleMedium?.copyWith(
                  color: foreground,
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
                      foregroundColor: foreground,
                      backgroundColor: chipBackground,
                      selectedBackgroundColor: selectedChipBackground,
                      outlineColor: outline,
                      onSelected: _selectPriority,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PriorityChip(
                      label: 'Низкий',
                      priority: CalendarEntryPriority.low,
                      selectedPriority: _priority,
                      foregroundColor: foreground,
                      backgroundColor: chipBackground,
                      selectedBackgroundColor: selectedChipBackground,
                      outlineColor: outline,
                      onSelected: _selectPriority,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PriorityChip(
                      label: 'Средний',
                      priority: CalendarEntryPriority.medium,
                      selectedPriority: _priority,
                      foregroundColor: foreground,
                      backgroundColor: chipBackground,
                      selectedBackgroundColor: selectedChipBackground,
                      outlineColor: outline,
                      onSelected: _selectPriority,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PriorityChip(
                      label: 'Высокий',
                      priority: CalendarEntryPriority.high,
                      selectedPriority: _priority,
                      foregroundColor: foreground,
                      backgroundColor: chipBackground,
                      selectedBackgroundColor: selectedChipBackground,
                      outlineColor: outline,
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
                style: TextStyle(color: foreground),
                cursorColor: accent,
                decoration: fieldDecoration(
                  label: _descriptionLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              if (_isEditing) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: outline),
                  ),
                  onPressed: _deleteEntry,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Удалить'),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: accentForeground,
                ),
                onPressed: _submit,
                icon: Icon(
                  _isEditing ? Icons.save_outlined : Icons.check_rounded,
                ),
                label: Text(_submitLabel),
              ),
            ],
          ),
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
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color foregroundColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: foregroundColor),
      title: Text(title, style: TextStyle(color: foregroundColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: secondaryColor)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: foregroundColor),
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
    required this.foregroundColor,
    required this.backgroundColor,
    required this.selectedBackgroundColor,
    required this.outlineColor,
    required this.onSelected,
  });

  final String label;
  final CalendarEntryPriority priority;
  final CalendarEntryPriority selectedPriority;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color selectedBackgroundColor;
  final Color outlineColor;
  final ValueChanged<CalendarEntryPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = priority == selectedPriority;

    return SizedBox(
      width: double.infinity,
      child: ChoiceChip(
        backgroundColor: backgroundColor,
        selectedColor: selectedBackgroundColor,
        side: BorderSide(color: outlineColor),
        label: SizedBox(
          width: double.infinity,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? foregroundColor
                  : foregroundColor.withValues(alpha: 0.82),
            ),
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) {
          onSelected(priority);
        },
      ),
    );
  }
}

Color _editorLayerColor(Color background, double amount) {
  final foreground = _editorContrastColor(background);

  return Color.lerp(background, foreground, amount)!;
}

Color _editorContrastColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}
