import 'package:flutter/material.dart';

import '../domain/models/vacation_period.dart';
import '../services/spaces/calendar/vacation_date_parser.dart';
import '../services/spaces/calendar/vacation_period_service.dart';
import 'vacation_period_editor_screen.dart';

class VacationPeriodsScreen extends StatefulWidget {
  const VacationPeriodsScreen({
    super.key,
    required this.calendarYear,
    required this.userId,
    required this.initialPeriods,
    required this.service,
    required this.onPeriodsChanged,
  });

  final int calendarYear;
  final String userId;
  final List<VacationPeriod> initialPeriods;
  final VacationPeriodService service;
  final ValueChanged<List<VacationPeriod>> onPeriodsChanged;

  @override
  State<VacationPeriodsScreen> createState() => _VacationPeriodsScreenState();
}

class _VacationPeriodsScreenState extends State<VacationPeriodsScreen> {
  late final List<VacationPeriod> _periods;

  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();

    _periods = List<VacationPeriod>.from(widget.initialPeriods);
    _sortPeriods();
  }

  void _sortPeriods() {
    _periods.sort((first, second) {
      final startComparison = first.startDateOnly.compareTo(
        second.startDateOnly,
      );

      if (startComparison != 0) {
        return startComparison;
      }

      return first.slot.compareTo(second.slot);
    });
  }

  void _notifyPeriodsChanged() {
    widget.onPeriodsChanged(List<VacationPeriod>.unmodifiable(_periods));
  }

  Future<void> _openAddEditor() async {
    if (_isActionInProgress ||
        _periods.length >= VacationPeriodService.maxSlots) {
      return;
    }

    final result = await Navigator.of(context).push<VacationPeriodEditorResult>(
      MaterialPageRoute<VacationPeriodEditorResult>(
        builder: (_) {
          return VacationPeriodEditorScreen(calendarYear: widget.calendarYear);
        },
      ),
    );

    if (!mounted || result == null || result.range == null) {
      return;
    }

    final range = result.range!;

    setState(() {
      _isActionInProgress = true;
    });

    try {
      final created = await widget.service.create(
        userId: widget.userId,
        startDate: range.startDate,
        endDate: range.endDate,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _periods.add(created);
        _sortPeriods();
      });

      _notifyPeriodsChanged();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Не удалось сохранить отпуск');
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<void> _openEditEditor(VacationPeriod period) async {
    if (_isActionInProgress) {
      return;
    }

    final result = await Navigator.of(context).push<VacationPeriodEditorResult>(
      MaterialPageRoute<VacationPeriodEditorResult>(
        builder: (_) {
          return VacationPeriodEditorScreen(
            calendarYear: widget.calendarYear,
            initialRange: VacationDateRange(
              startDate: period.startDateOnly,
              endDate: period.endDateOnly,
            ),
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });

    try {
      if (result.shouldDelete) {
        await widget.service.delete(period: period);

        if (!mounted) {
          return;
        }

        setState(() {
          _periods.removeWhere(
            (candidate) =>
                candidate.userId == period.userId &&
                candidate.slot == period.slot,
          );
        });

        _notifyPeriodsChanged();
        return;
      }

      final range = result.range;

      if (range == null) {
        return;
      }

      final updated = await widget.service.update(
        currentPeriod: period,
        startDate: range.startDate,
        endDate: range.endDate,
      );

      if (!mounted) {
        return;
      }

      final index = _periods.indexWhere(
        (candidate) =>
            candidate.userId == period.userId && candidate.slot == period.slot,
      );

      setState(() {
        if (index >= 0) {
          _periods[index] = updated;
        } else {
          _periods.add(updated);
        }

        _sortPeriods();
      });

      _notifyPeriodsChanged();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        result.shouldDelete
            ? 'Не удалось удалить отпуск'
            : 'Не удалось сохранить изменения',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd =
        !_isActionInProgress &&
        _periods.length < VacationPeriodService.maxSlots;

    return Scaffold(
      appBar: AppBar(title: const Text('Отпуска')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Год календаря: ${widget.calendarYear}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final period in _periods) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  enabled: !_isActionInProgress,
                  onTap: _isActionInProgress
                      ? null
                      : () {
                          _openEditEditor(period);
                        },
                  leading: const Icon(Icons.beach_access_outlined),
                  title: const Text('Отпуск'),
                  subtitle: Text(
                    '${_formatDate(period.startDateOnly)}'
                    ' — '
                    '${_formatDate(period.endDateOnly)}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                enabled: canAdd,
                onTap: canAdd ? _openAddEditor : null,
                leading: const Icon(Icons.add),
                title: const Text('Добавить отпуск'),
                subtitle: _periods.length >= VacationPeriodService.maxSlots
                    ? const Text('Максимальное количество отпусков добавлено')
                    : null,
              ),
            ),
            if (_isActionInProgress) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
