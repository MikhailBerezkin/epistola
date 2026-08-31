import 'package:flutter/material.dart';

import '../../../domain/models/substitution_shift.dart';

class SubstitutionStatisticsSummary extends StatelessWidget {
  const SubstitutionStatisticsSummary({
    super.key,
    required this.month,
    required this.monthCallCount,
    required this.monthShifts,
    required this.yearCallCount,
  });

  final int month;
  final int monthCallCount;
  final List<SubstitutionShiftKind> monthShifts;
  final int yearCallCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Статистика',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _monthName(month),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
            Text(
              '$monthCallCount',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SubstitutionShiftBar(shifts: monthShifts),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'За год',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
            Text(
              '$yearCallCount',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _monthName(int month) {
    return switch (month) {
      1 => 'Январь',
      2 => 'Февраль',
      3 => 'Март',
      4 => 'Апрель',
      5 => 'Май',
      6 => 'Июнь',
      7 => 'Июль',
      8 => 'Август',
      9 => 'Сентябрь',
      10 => 'Октябрь',
      11 => 'Ноябрь',
      12 => 'Декабрь',
      _ => '',
    };
  }
}

class _SubstitutionShiftBar extends StatelessWidget {
  const _SubstitutionShiftBar({required this.shifts});

  final List<SubstitutionShiftKind> shifts;

  @override
  Widget build(BuildContext context) {
    final capacity = _capacityFor(shifts.length);

    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List<Widget>.generate(capacity, (index) {
          final shift = index < shifts.length ? shifts[index] : null;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == capacity - 1 ? 0 : 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _segmentColor(shift),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _capacityFor(int count) {
    if (count <= 5) {
      return 5;
    }

    if (count <= 9) {
      return 9;
    }

    return 12;
  }

  Color _segmentColor(SubstitutionShiftKind? shift) {
    if (shift == null) {
      return Colors.white.withValues(alpha: 0.12);
    }

    return switch (shift) {
      SubstitutionShiftKind.day => Colors.amber,
      SubstitutionShiftKind.night => const Color(0xFF3857A6),
    };
  }
}
