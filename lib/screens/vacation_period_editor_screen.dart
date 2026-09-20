import 'package:flutter/material.dart';

import '../services/spaces/calendar/vacation_date_parser.dart';

class VacationPeriodEditorResult {
  const VacationPeriodEditorResult.save(this.range) : shouldDelete = false;

  const VacationPeriodEditorResult.delete() : range = null, shouldDelete = true;

  final VacationDateRange? range;
  final bool shouldDelete;
}

class VacationPeriodEditorScreen extends StatefulWidget {
  const VacationPeriodEditorScreen({
    super.key,
    required this.calendarYear,
    this.initialRange,
  });

  final int calendarYear;
  final VacationDateRange? initialRange;

  @override
  State<VacationPeriodEditorScreen> createState() =>
      _VacationPeriodEditorScreenState();
}

class _VacationPeriodEditorScreenState
    extends State<VacationPeriodEditorScreen> {
  static const _parser = VacationDateParser();

  final _startController = TextEditingController();
  final _endController = TextEditingController();

  final _startFocusNode = FocusNode();
  final _endFocusNode = FocusNode();

  String? _startError;
  String? _endError;
  String? _rangeError;

  bool get _isEditing => widget.initialRange != null;

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить отпуск?'),
          content: const Text('Этот период будет удалён.'),
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

    if (!mounted || shouldDelete != true) {
      return;
    }

    Navigator.of(context).pop(const VacationPeriodEditorResult.delete());
  }

  @override
  void initState() {
    super.initState();

    final initialRange = widget.initialRange;

    if (initialRange != null) {
      _startController.text = _formatDate(initialRange.startDate);
      _endController.text = _formatDate(initialRange.endDate);
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();

    super.dispose();
  }

  void _save() {
    final startText = _startController.text.trim();
    final endText = _endController.text.trim();

    String? startError;
    String? endError;
    String? rangeError;

    if (startText.isEmpty) {
      startError = 'Укажите дату начала.';
    }

    if (endText.isEmpty) {
      endError = 'Укажите дату окончания.';
    }

    final startDate = startError == null
        ? _parser.parseDate(startText, defaultYear: widget.calendarYear)
        : null;

    if (startError == null && startDate == null) {
      startError = 'Не удалось распознать дату.';
    }

    final endDate = endError == null
        ? _parser.parseDate(
            endText,
            defaultYear: startDate?.year ?? widget.calendarYear,
          )
        : null;

    if (endError == null && endDate == null) {
      endError = 'Не удалось распознать дату.';
    }

    VacationDateRange? range;

    if (startError == null && endError == null) {
      range = _parser.parseRange(
        startText: startText,
        endText: endText,
        calendarYear: widget.calendarYear,
      );

      if (range == null) {
        rangeError = 'Дата окончания не может быть раньше даты начала.';
      }
    }

    setState(() {
      _startError = startError;
      _endError = endError;
      _rangeError = rangeError;
    });

    if (range == null) {
      return;
    }

    Navigator.of(context).pop(VacationPeriodEditorResult.save(range));
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Изменить отпуск' : 'Добавить отпуск'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Период отпуска',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Если год не указан, используется год открытого календаря: '
              '${widget.calendarYear}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _startController,
              focusNode: _startFocusNode,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Начало',
                hintText: '18.09',
                errorText: _startError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_startError == null && _rangeError == null) {
                  return;
                }

                setState(() {
                  _startError = null;
                  _rangeError = null;
                });
              },
              onSubmitted: (_) {
                _endFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endController,
              focusNode: _endFocusNode,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Конец',
                hintText: '02.10',
                errorText: _endError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_endError == null && _rangeError == null) {
                  return;
                }

                setState(() {
                  _endError = null;
                  _rangeError = null;
                });
              },
              onSubmitted: (_) {
                _save();
              },
            ),
            if (_rangeError != null) ...[
              const SizedBox(height: 12),
              Text(
                _rangeError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Можно вводить:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '18.09 или 18/09\n'
              '18.09.2026 или 18/09/2026\n'
              '18 сентября\n'
              '18 сентября 2026',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Сохранить изменения' : 'Сохранить'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить отпуск'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
