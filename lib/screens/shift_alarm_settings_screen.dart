import 'package:flutter/material.dart';

import '../domain/models/shift_alarm.dart';
import '../domain/models/shift_cycle.dart';
import '../services/spaces/calendar/shift_alarm_local_store.dart';
import 'shift_alarm_editor_screen.dart';

class ShiftAlarmSettingsScreen extends StatefulWidget {
  const ShiftAlarmSettingsScreen({
    super.key,
    required this.userId,
    this.store = const ShiftAlarmLocalStore(),
    this.onScheduleChanged,
  });

  final String userId;
  final ShiftAlarmLocalStore store;
  final Future<void> Function()? onScheduleChanged;

  @override
  State<ShiftAlarmSettingsScreen> createState() =>
      _ShiftAlarmSettingsScreenState();
}

class _ShiftAlarmSettingsScreenState extends State<ShiftAlarmSettingsScreen> {
  List<ShiftAlarm> _alarms = const <ShiftAlarm>[];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final alarms = await widget.store.loadForUser(userId: widget.userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _alarms = alarms;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openPhase(ShiftCyclePhase phase) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return ShiftAlarmPhaseScreen(
            userId: widget.userId,
            phase: phase,
            store: widget.store,
            onScheduleChanged: widget.onScheduleChanged,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
  }

  List<ShiftAlarm> _alarmsForPhase(ShiftCyclePhase phase) {
    return _alarms
        .where((alarm) => alarm.phase == phase)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Будильники')),
      body: SafeArea(
        child: switch ((_isLoading, _loadFailed)) {
          (true, _) => const Center(child: CircularProgressIndicator()),
          (false, true) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Не удалось загрузить настройки будильников.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
          _ => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Сигналы рабочего цикла',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Каждая плитка настраивается отдельно. '
                'Настройки хранятся только на этом устройстве.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ShiftCyclePhase.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, index) {
                  final phase = ShiftCyclePhase.values[index];
                  final alarms = _alarmsForPhase(phase);
                  final activeCount = alarms
                      .where((alarm) => alarm.enabled)
                      .length;

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openPhase(phase),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Icon(
                                  _phaseIcon(phase),
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            Text(
                              phase.alarmEditorTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alarms.isEmpty
                                  ? 'Сигналов нет'
                                  : '$activeCount активных · ${alarms.length} всего',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        },
      ),
    );
  }

  IconData _phaseIcon(ShiftCyclePhase phase) {
    if (phase.isDayShift) {
      return Icons.light_mode_outlined;
    }

    if (phase.isNightShift) {
      return Icons.dark_mode_outlined;
    }

    if (phase.isRecovery) {
      return Icons.bedtime_outlined;
    }

    return Icons.weekend_outlined;
  }
}

class ShiftAlarmPhaseScreen extends StatefulWidget {
  const ShiftAlarmPhaseScreen({
    super.key,
    required this.userId,
    required this.phase,
    required this.store,
    this.onScheduleChanged,
  });

  final String userId;
  final ShiftCyclePhase phase;
  final ShiftAlarmLocalStore store;
  final Future<void> Function()? onScheduleChanged;

  @override
  State<ShiftAlarmPhaseScreen> createState() => _ShiftAlarmPhaseScreenState();
}

class _ShiftAlarmPhaseScreenState extends State<ShiftAlarmPhaseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<ShiftAlarm> _alarms = const <ShiftAlarm>[];

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isActionInProgress = false;

  ShiftAlarmScope get _currentScope {
    return ShiftAlarmScope.values[_tabController.index];
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: ShiftAlarmScope.values.length,
      vsync: this,
    );

    _tabController.addListener(_handleTabChanged);

    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();

    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    setState(() {});
  }

  Future<void> _load() async {
    try {
      final alarms = await widget.store.loadForUser(userId: widget.userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _alarms = alarms
            .where((alarm) => alarm.phase == widget.phase)
            .toList(growable: false);
        _sortAlarms();
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _sortAlarms() {
    _alarms = [..._alarms]
      ..sort((first, second) {
        final timeComparison = first.minutesOfDay.compareTo(
          second.minutesOfDay,
        );

        if (timeComparison != 0) {
          return timeComparison;
        }

        return first.title.compareTo(second.title);
      });
  }

  List<ShiftAlarm> _alarmsForScope(ShiftAlarmScope scope) {
    return _alarms
        .where((alarm) => alarm.scope == scope)
        .toList(growable: false);
  }

  Future<void> _openAddEditor() async {
    if (_isActionInProgress) {
      return;
    }

    final result = await Navigator.of(context).push<ShiftAlarmEditorResult>(
      MaterialPageRoute<ShiftAlarmEditorResult>(
        builder: (_) {
          return ShiftAlarmEditorScreen(
            phase: widget.phase,
            scope: _currentScope,
          );
        },
      ),
    );

    if (!mounted || result?.alarm == null) {
      return;
    }

    await _saveAlarm(result!.alarm!);
  }

  Future<void> _openEditEditor(ShiftAlarm alarm) async {
    if (_isActionInProgress) {
      return;
    }

    final result = await Navigator.of(context).push<ShiftAlarmEditorResult>(
      MaterialPageRoute<ShiftAlarmEditorResult>(
        builder: (_) {
          return ShiftAlarmEditorScreen(
            phase: alarm.phase,
            scope: alarm.scope,
            initialAlarm: alarm,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.shouldDelete) {
      await _deleteAlarm(alarm);
      return;
    }

    final updated = result.alarm;

    if (updated != null) {
      await _saveAlarm(updated);
    }
  }

  Future<void> _notifyScheduleChanged() async {
    final callback = widget.onScheduleChanged;

    if (callback == null) {
      return;
    }

    try {
      await callback();
    } catch (_) {
      if (mounted) {
        _showError(
          'Настройки сохранены, но расписание будильников не обновилось',
        );
      }
    }
  }

  Future<void> _saveAlarm(ShiftAlarm alarm) async {
    setState(() {
      _isActionInProgress = true;
    });

    try {
      await widget.store.save(userId: widget.userId, alarm: alarm);

      if (!mounted) {
        return;
      }

      final updated = [..._alarms];
      final index = updated.indexWhere((candidate) => candidate.id == alarm.id);

      if (index >= 0) {
        updated[index] = alarm;
      } else {
        updated.add(alarm);
      }

      setState(() {
        _alarms = updated;
        _sortAlarms();
      });

      await _notifyScheduleChanged();
    } catch (_) {
      if (mounted) {
        _showError('Не удалось сохранить сигнал');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<void> _deleteAlarm(ShiftAlarm alarm) async {
    setState(() {
      _isActionInProgress = true;
    });

    try {
      await widget.store.delete(userId: widget.userId, alarmId: alarm.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _alarms = _alarms
            .where((candidate) => candidate.id != alarm.id)
            .toList(growable: false);
      });
      await _notifyScheduleChanged();
    } catch (_) {
      if (mounted) {
        _showError('Не удалось удалить сигнал');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<void> _setEnabled(ShiftAlarm alarm, bool enabled) async {
    if (_isActionInProgress || alarm.enabled == enabled) {
      return;
    }

    final updated = alarm.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now().toUtc(),
    );

    await _saveAlarm(updated);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _subtitle(ShiftAlarm alarm) {
    final time = _formatMinutes(alarm.minutesOfDay);

    return switch (alarm.type) {
      ShiftAlarmType.alarm => '$time · Будильник',
      ShiftAlarmType.notification =>
        '$time · Оповещение · ${alarm.durationSeconds} сек',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.phase.alarmEditorTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final scope in ShiftAlarmScope.values)
              Tab(text: scope.displayTitle),
          ],
        ),
      ),
      floatingActionButton: _isLoading || _loadFailed
          ? null
          : FloatingActionButton.extended(
              onPressed: _isActionInProgress ? null : _openAddEditor,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            ),
      body: SafeArea(
        child: switch ((_isLoading, _loadFailed)) {
          (true, _) => const Center(child: CircularProgressIndicator()),
          (false, true) => Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Повторить загрузку'),
            ),
          ),
          _ => TabBarView(
            controller: _tabController,
            children: [
              for (final scope in ShiftAlarmScope.values)
                _buildScopePage(context, theme, scope),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildScopePage(
    BuildContext context,
    ThemeData theme,
    ShiftAlarmScope scope,
  ) {
    final alarms = _alarmsForScope(scope);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          _scopeDescription(scope),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        if (alarms.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.alarm_add_outlined, size: 36),
                  const SizedBox(height: 10),
                  const Text('Сигналов пока нет', textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите «Добавить», чтобы создать первый сигнал.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final alarm in alarms) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                enabled: !_isActionInProgress,
                onTap: _isActionInProgress
                    ? null
                    : () => _openEditEditor(alarm),
                leading: Icon(
                  alarm.type == ShiftAlarmType.alarm
                      ? Icons.alarm
                      : Icons.notifications_outlined,
                ),
                title: Text(
                  alarm.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_subtitle(alarm)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: alarm.enabled,
                      onChanged: _isActionInProgress
                          ? null
                          : (value) {
                              _setEnabled(alarm, value);
                            },
                    ),
                    IconButton(
                      tooltip: 'Редактировать',
                      onPressed: _isActionInProgress
                          ? null
                          : () => _openEditEditor(alarm),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  String _scopeDescription(ShiftAlarmScope scope) {
    return switch (scope) {
      ShiftAlarmScope.work =>
        'Обычные сигналы этой фазы рабочего цикла. '
            'Во время отпуска они будут отключаться.',
      ShiftAlarmScope.always =>
        'Эти сигналы будут работать независимо от рабочего цикла '
            'и отпуска.',
      ShiftAlarmScope.vacation =>
        'Эти сигналы предназначены только для периода отпуска.',
    };
  }
}
