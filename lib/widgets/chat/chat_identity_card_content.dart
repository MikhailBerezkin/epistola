import 'package:flutter/material.dart';

class ChatIdentityCardContent extends StatelessWidget {
  const ChatIdentityCardContent({
    super.key,
    required this.title,
    required this.onClose,
    this.details = const [],
    this.actions = const [],
  });

  final String title;
  final VoidCallback onClose;
  final List<String> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final visibleDetails = details
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              onPressed: onClose,
              color: Colors.white,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Свернуть карточку',
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
                  ),
                ),
                for (final detail in visibleDetails) ...[
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      shadows: [
                        Shadow(color: Color(0xB3000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(child: actions[index]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
