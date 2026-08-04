import 'package:flutter/material.dart';

class PrivateReadReceiptIndicator extends StatelessWidget {
  const PrivateReadReceiptIndicator({super.key, required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final symbol = isRead ? '✓✓' : '✓';

    final semanticsLabel = isRead
        ? 'Сообщение прочитано'
        : 'Сообщение сохранено';

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Text(
          symbol,
          style: TextStyle(
            height: 1,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isRead ? colorScheme.primary : colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
