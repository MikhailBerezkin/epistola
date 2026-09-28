import 'package:flutter/material.dart';

class ShiftAlarmRingScreen extends StatefulWidget {
  const ShiftAlarmRingScreen({
    super.key,
    required this.title,
    required this.onStop,
    required this.onSnooze,
  });

  final String title;
  final Future<void> Function() onStop;
  final Future<void> Function() onSnooze;

  @override
  State<ShiftAlarmRingScreen> createState() => _ShiftAlarmRingScreenState();
}

class _ShiftAlarmRingScreenState extends State<ShiftAlarmRingScreen> {
  bool _isActionInProgress = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                const Spacer(),

                Icon(Icons.alarm, size: 72, color: theme.colorScheme.primary),

                const SizedBox(height: 24),

                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Будильник рабочего календаря',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isActionInProgress
                        ? null
                        : () => _runAction(widget.onSnooze),
                    icon: const Icon(Icons.snooze),
                    label: const Text('+10 минут'),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _isActionInProgress
                        ? null
                        : () => _runAction(widget.onStop),
                    icon: const Icon(Icons.alarm_off),
                    label: const Text(
                      'Остановить',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
