import 'package:flutter/material.dart';

class SubstitutionStatisticsBadge extends StatelessWidget {
  const SubstitutionStatisticsBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final normalizedCount = count < 0 ? 0 : count;
    final style = _styleForCount(context: context, count: normalizedCount);

    return Tooltip(
      message: 'За текущий месяц: $normalizedCount',
      child: Semantics(
        label: 'Статистика за текущий месяц: $normalizedCount',
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$normalizedCount',
            style: TextStyle(
              color: style.foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  _StatisticsBadgeStyle _styleForCount({
    required BuildContext context,
    required int count,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (count == 0) {
      return _StatisticsBadgeStyle(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
      );
    }

    if (count <= 2) {
      return const _StatisticsBadgeStyle(
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      );
    }

    if (count <= 4) {
      return const _StatisticsBadgeStyle(
        backgroundColor: Color(0xFFF9A825),
        foregroundColor: Colors.black,
      );
    }

    return const _StatisticsBadgeStyle(
      backgroundColor: Color(0xFFC62828),
      foregroundColor: Colors.white,
    );
  }
}

final class _StatisticsBadgeStyle {
  const _StatisticsBadgeStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}
