import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<TimeOfDay?> showTimeWheelPickerSheet({
  required BuildContext context,
  required TimeOfDay initialTime,
  Color? backgroundColor,
  Color? foregroundColor,
  Color? accentColor,
}) {
  final baseTheme = Theme.of(context);
  final resolvedBackground = backgroundColor ?? baseTheme.colorScheme.surface;
  final resolvedForeground =
      foregroundColor ?? _timePickerContrastColor(resolvedBackground);
  final resolvedAccent = accentColor ?? baseTheme.colorScheme.primary;
  final accentForeground = _timePickerContrastColor(resolvedAccent);

  final brightness =
      ThemeData.estimateBrightnessForColor(resolvedBackground) ==
          Brightness.dark
      ? Brightness.dark
      : Brightness.light;

  final colorScheme = baseTheme.colorScheme.copyWith(
    brightness: brightness,
    primary: resolvedAccent,
    onPrimary: accentForeground,
    surface: resolvedBackground,
    onSurface: resolvedForeground,
  );

  final localTheme = baseTheme.copyWith(
    colorScheme: colorScheme,
    canvasColor: resolvedBackground,
    textTheme: baseTheme.textTheme.apply(
      bodyColor: resolvedForeground,
      displayColor: resolvedForeground,
    ),
    bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
      backgroundColor: resolvedBackground,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: resolvedForeground.withValues(alpha: 0.35),
    ),
  );

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    backgroundColor: resolvedBackground,
    builder: (context) {
      return Theme(
        data: localTheme,
        child: TimeWheelPickerSheet(
          initialTime: initialTime,
          backgroundColor: resolvedBackground,
          foregroundColor: resolvedForeground,
          accentColor: resolvedAccent,
        ),
      );
    },
  );
}

class TimeWheelPickerSheet extends StatefulWidget {
  const TimeWheelPickerSheet({
    super.key,
    required this.initialTime,
    this.backgroundColor,
    this.foregroundColor,
    this.accentColor,
  });

  final TimeOfDay initialTime;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? accentColor;

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
    final background = widget.backgroundColor ?? theme.colorScheme.surface;
    final foreground =
        widget.foregroundColor ?? _timePickerContrastColor(background);
    final secondary = foreground.withValues(alpha: 0.68);
    final accent = widget.accentColor ?? theme.colorScheme.primary;
    final accentForeground = _timePickerContrastColor(accent);

    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выберите время',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: foreground,
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
                        color: secondary,
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
                        color: secondary,
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: foreground,
                              ),
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
                          color: foreground,
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: foreground,
                              ),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foreground,
                        side: BorderSide(
                          color: foreground.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: accentForeground,
                      ),
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
      ),
    );
  }
}

Color _timePickerContrastColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}
