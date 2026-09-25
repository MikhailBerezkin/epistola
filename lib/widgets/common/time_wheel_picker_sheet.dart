import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<TimeOfDay?> showTimeWheelPickerSheet({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return TimeWheelPickerSheet(initialTime: initialTime);
    },
  );
}

class TimeWheelPickerSheet extends StatefulWidget {
  const TimeWheelPickerSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<TimeWheelPickerSheet> createState() => _TimeWheelPickerSheetState();
}

class _TimeWheelPickerSheetState extends State<TimeWheelPickerSheet> {
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
