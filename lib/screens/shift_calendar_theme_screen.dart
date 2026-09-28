import 'package:flutter/material.dart';

import '../domain/models/shift_calendar_theme.dart';
import '../services/spaces/calendar/shift_calendar_theme_preferences.dart';

class ShiftCalendarThemeScreen extends StatefulWidget {
  const ShiftCalendarThemeScreen({super.key, required this.initialState});

  final ShiftCalendarThemeState initialState;

  @override
  State<ShiftCalendarThemeScreen> createState() =>
      _ShiftCalendarThemeScreenState();
}

class _ShiftCalendarThemeScreenState extends State<ShiftCalendarThemeScreen> {
  final ShiftCalendarThemePreferences _preferences =
      ShiftCalendarThemePreferences();

  late ShiftCalendarThemeState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  int get _initialTabIndex {
    return switch (_state.mode) {
      ShiftCalendarThemeMode.light => 0,
      ShiftCalendarThemeMode.dark => 1,
      ShiftCalendarThemeMode.custom => 2,
    };
  }

  Future<void> _setMode(ShiftCalendarThemeMode mode) async {
    if (_state.mode == mode) {
      return;
    }

    setState(() {
      _state = _state.copyWith(mode: mode);
    });

    await _preferences.saveMode(mode);
  }

  Future<void> _setCustomSlot(ShiftCalendarCustomThemeSlot slot) async {
    if (_state.customSlot == slot) {
      return;
    }

    setState(() {
      _state = _state.copyWith(
        mode: ShiftCalendarThemeMode.custom,
        customSlot: slot,
      );
    });

    await _preferences.saveMode(ShiftCalendarThemeMode.custom);
    await _preferences.saveCustomSlot(slot);
  }

  ShiftCalendarThemePalette get _activeCustomPalette {
    return _state.customSlot == ShiftCalendarCustomThemeSlot.first
        ? _state.customFirst
        : _state.customSecond;
  }

  Future<void> _saveCustomPalette(ShiftCalendarThemePalette palette) async {
    final slot = _state.customSlot;

    setState(() {
      _state = switch (slot) {
        ShiftCalendarCustomThemeSlot.first => _state.copyWith(
          mode: ShiftCalendarThemeMode.custom,
          customFirst: palette,
        ),
        ShiftCalendarCustomThemeSlot.second => _state.copyWith(
          mode: ShiftCalendarThemeMode.custom,
          customSecond: palette,
        ),
      };
    });

    await _preferences.saveMode(ShiftCalendarThemeMode.custom);

    await _preferences.saveCustomPalette(slot: slot, palette: palette);
  }

  Future<void> _resetCurrentCustomTheme() async {
    final slot = _state.customSlot;

    final fallback = switch (slot) {
      ShiftCalendarCustomThemeSlot.first =>
        ShiftCalendarThemePalette.customFirstDefault,
      ShiftCalendarCustomThemeSlot.second =>
        ShiftCalendarThemePalette.customSecondDefault,
    };

    await _saveCustomPalette(fallback);
  }

  Future<void> _editColor({
    required String title,
    required Color currentColor,
    required ValueChanged<int> apply,
  }) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) {
        return _CalendarColorDialog(title: title, initialColor: currentColor);
      },
    );

    if (color == null) {
      return;
    }

    apply(color.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _initialTabIndex,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          tabController.addListener(() {
            if (tabController.indexIsChanging) {
              return;
            }

            final mode = switch (tabController.index) {
              0 => ShiftCalendarThemeMode.light,
              1 => ShiftCalendarThemeMode.dark,
              _ => ShiftCalendarThemeMode.custom,
            };

            if (_state.mode != mode) {
              _setMode(mode);
            }
          });

          return Scaffold(
            appBar: AppBar(
              title: const Text('Темы календаря'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Светлая'),
                  Tab(text: 'Тёмная'),
                  Tab(text: 'Своя'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _BuiltInThemeTab(
                  title: 'Светлая тема',
                  description:
                      'Светлая палитра календаря с мягким разделением '
                      'смен и выходных.',
                  palette: ShiftCalendarThemePalette.light,
                ),
                _BuiltInThemeTab(
                  title: 'Тёмная тема',
                  description:
                      'Тёмная палитра календаря для использования '
                      'при слабом освещении.',
                  palette: ShiftCalendarThemePalette.dark,
                ),
                _buildCustomTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomTab() {
    final palette = _activeCustomPalette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SegmentedButton<ShiftCalendarCustomThemeSlot>(
          segments: const [
            ButtonSegment(
              value: ShiftCalendarCustomThemeSlot.first,
              label: Text('Своя 1'),
            ),
            ButtonSegment(
              value: ShiftCalendarCustomThemeSlot.second,
              label: Text('Своя 2'),
            ),
          ],
          selected: <ShiftCalendarCustomThemeSlot>{_state.customSlot},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }

            _setCustomSlot(selection.first);
          },
        ),
        const SizedBox(height: 18),
        _CalendarThemePreview(palette: palette),
        const SizedBox(height: 24),
        const _SectionTitle('Плитки 8-дневного цикла'),
        const SizedBox(height: 8),
        _ColorSettingTile(
          title: 'День 1',
          color: Color(palette.day1),
          onTap: () {
            _editColor(
              title: 'День 1',
              currentColor: Color(palette.day1),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(day1: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'День 2',
          color: Color(palette.day2),
          onTap: () {
            _editColor(
              title: 'День 2',
              currentColor: Color(palette.day2),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(day2: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Выходной перед ночью',
          color: Color(palette.offBeforeNight),
          onTap: () {
            _editColor(
              title: 'Выходной перед ночью',
              currentColor: Color(palette.offBeforeNight),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(offBeforeNight: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Ночь 1',
          color: Color(palette.night1),
          onTap: () {
            _editColor(
              title: 'Ночь 1',
              currentColor: Color(palette.night1),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(night1: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Ночь 2',
          color: Color(palette.night2),
          onTap: () {
            _editColor(
              title: 'Ночь 2',
              currentColor: Color(palette.night2),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(night2: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Отсыпной',
          color: Color(palette.recovery),
          onTap: () {
            _editColor(
              title: 'Отсыпной',
              currentColor: Color(palette.recovery),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(recovery: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Выходной 1',
          color: Color(palette.offAfterRecovery1),
          onTap: () {
            _editColor(
              title: 'Выходной 1',
              currentColor: Color(palette.offAfterRecovery1),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(offAfterRecovery1: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Выходной 2',
          color: Color(palette.offAfterRecovery2),
          onTap: () {
            _editColor(
              title: 'Выходной 2',
              currentColor: Color(palette.offAfterRecovery2),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(offAfterRecovery2: value));
              },
            );
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Остальные элементы'),
        const SizedBox(height: 8),
        _ColorSettingTile(
          title: 'Фон календаря',
          color: Color(palette.background),
          onTap: () {
            _editColor(
              title: 'Фон календаря',
              currentColor: Color(palette.background),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(background: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Отпуск',
          color: Color(palette.vacation),
          onTap: () {
            _editColor(
              title: 'Отпуск',
              currentColor: Color(palette.vacation),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(vacation: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Рамка халтуры',
          color: Color(palette.additionalShift),
          onTap: () {
            _editColor(
              title: 'Рамка халтуры',
              currentColor: Color(palette.additionalShift),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(additionalShift: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Выбранный день',
          color: Color(palette.selectedDay),
          onTap: () {
            _editColor(
              title: 'Выбранный день',
              currentColor: Color(palette.selectedDay),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(selectedDay: value));
              },
            );
          },
        ),
        _ColorSettingTile(
          title: 'Бар часов за месяц',
          color: Color(palette.monthHoursBar),
          onTap: () {
            _editColor(
              title: 'Бар часов за месяц',
              currentColor: Color(palette.monthHoursBar),
              apply: (value) {
                _saveCustomPalette(palette.copyWith(monthHoursBar: value));
              },
            );
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Размер текста'),
        const SizedBox(height: 8),
        SegmentedButton<ShiftCalendarTextScale>(
          segments: ShiftCalendarTextScale.values
              .map(
                (scale) => ButtonSegment<ShiftCalendarTextScale>(
                  value: scale,
                  label: Text(scale.displayName),
                ),
              )
              .toList(growable: false),
          selected: <ShiftCalendarTextScale>{palette.textScale},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }

            _saveCustomPalette(palette.copyWith(textScale: selection.first));
          },
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _resetCurrentCustomTheme,
          icon: const Icon(Icons.restart_alt),
          label: Text('Сбросить ${_state.customSlot.displayName}'),
        ),
      ],
    );
  }
}

class _BuiltInThemeTab extends StatelessWidget {
  const _BuiltInThemeTab({
    required this.title,
    required this.description,
    required this.palette,
  });

  final String title;
  final String description;
  final ShiftCalendarThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _CalendarThemePreview(palette: palette),
      ],
    );
  }
}

class _CalendarThemePreview extends StatelessWidget {
  const _CalendarThemePreview({required this.palette});

  final ShiftCalendarThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = <int>[
      palette.day1,
      palette.day2,
      palette.offBeforeNight,
      palette.night1,
      palette.night2,
      palette.recovery,
      palette.offAfterRecovery1,
      palette.offAfterRecovery2,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(palette.background),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _automaticBorderColor(Color(palette.background)),
        ),
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final color = Color(colors[index]);

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _contrastColor(color),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Color(palette.monthHoursBar),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '180 ч  ·  57,5 ч  ·  237,5 ч',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _contrastColor(Color(palette.monthHoursBar)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSettingTile extends StatelessWidget {
  const _ColorSettingTile({
    required this.title,
    required this.color,
    required this.onTap,
  });

  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Container(
        width: 42,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _automaticBorderColor(color)),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _CalendarColorDialog extends StatefulWidget {
  const _CalendarColorDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_CalendarColorDialog> createState() => _CalendarColorDialogState();
}

class _CalendarColorDialogState extends State<_CalendarColorDialog> {
  late int _red;
  late int _green;
  late int _blue;

  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();

    final argb = widget.initialColor.toARGB32();

    _red = (argb >> 16) & 0xFF;
    _green = (argb >> 8) & 0xFF;
    _blue = argb & 0xFF;

    _hexController = TextEditingController(
      text: _hexColor(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color {
    return Color.fromARGB(255, _red, _green, _blue);
  }

  void _syncHexFromRgb() {
    final value = _hexColor(_color);

    _hexController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _applyHex(String rawValue) {
    var value = rawValue.trim().toUpperCase();

    if (value.startsWith('#')) {
      value = value.substring(1);
    }

    if (value.length != 6) {
      return;
    }

    final rgb = int.tryParse(value, radix: 16);

    if (rgb == null) {
      return;
    }

    setState(() {
      _red = (rgb >> 16) & 0xFF;
      _green = (rgb >> 8) & 0xFF;
      _blue = rgb & 0xFF;
    });
  }

  void _normalizeHex() {
    final value = _hexColor(_color);

    _hexController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _setRed(int value) {
    setState(() {
      _red = value;
      _syncHexFromRgb();
    });
  }

  void _setGreen(int value) {
    setState(() {
      _green = value;
      _syncHexFromRgb();
    });
  }

  void _setBlue(int value) {
    setState(() {
      _blue = value;
      _syncHexFromRgb();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _automaticBorderColor(_color)),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _hexController,
                textAlign: TextAlign.center,
                maxLength: 7,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _contrastColor(_color),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  hintText: '#RRGGBB',
                  hintStyle: TextStyle(
                    color: _contrastColor(_color).withValues(alpha: 0.55),
                  ),
                ),
                onTap: () {
                  _hexController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _hexController.text.length,
                  );
                },
                onChanged: _applyHex,
                onEditingComplete: () {
                  _applyHex(_hexController.text);
                  _normalizeHex();
                  FocusScope.of(context).unfocus();
                },
                onSubmitted: (value) {
                  _applyHex(value);
                  _normalizeHex();
                },
              ),
            ),
            const SizedBox(height: 18),
            _RgbSlider(label: 'R', value: _red, onChanged: _setRed),
            _RgbSlider(label: 'G', value: _green, onChanged: _setGreen),
            _RgbSlider(label: 'B', value: _blue, onChanged: _setBlue),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            _applyHex(_hexController.text);

            Navigator.of(context).pop(_color);
          },
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.toDouble(),
            onChanged: (nextValue) {
              onChanged(nextValue.round());
            },
          ),
        ),
        SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}

Color _contrastColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

Color _automaticBorderColor(Color background) {
  return _contrastColor(background).withValues(alpha: 0.22);
}

String _hexColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;

  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
