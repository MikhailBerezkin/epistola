import 'package:epistola/domain/models/group_message_reaction.dart';
import 'package:epistola/widgets/chat/group_message_reaction_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides the bar when there are no reactions', (tester) async {
    await pumpReactionBar(tester, likeCount: 0, dislikeCount: 0);

    expect(find.text('👍'), findsNothing);
    expect(find.text('👎'), findsNothing);
  });

  testWidgets('shows only a non-zero like count', (tester) async {
    await pumpReactionBar(tester, likeCount: 3, dislikeCount: 0);

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('👎'), findsNothing);
  });

  testWidgets('shows only a non-zero dislike count', (tester) async {
    await pumpReactionBar(tester, likeCount: 0, dislikeCount: 2);

    expect(find.text('👍'), findsNothing);
    expect(find.text('👎'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows both non-zero reaction counts', (tester) async {
    await pumpReactionBar(tester, likeCount: 4, dislikeCount: 1);

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('👎'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('marks the current user reaction as selected', (tester) async {
    await pumpReactionBar(
      tester,
      likeCount: 2,
      dislikeCount: 1,
      selectedReaction: GroupMessageReaction.dislike,
    );

    final likeStat = tester.widget<Semantics>(
      find.byKey(GroupMessageReactionBar.likeStatKey),
    );

    final dislikeStat = tester.widget<Semantics>(
      find.byKey(GroupMessageReactionBar.dislikeStatKey),
    );

    expect(likeStat.properties.selected, isFalse);
    expect(dislikeStat.properties.selected, isTrue);
  });
}

Future<void> pumpReactionBar(
  WidgetTester tester, {
  required int likeCount,
  required int dislikeCount,
  GroupMessageReaction? selectedReaction,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GroupMessageReactionBar(
          likeCount: likeCount,
          dislikeCount: dislikeCount,
          selectedReaction: selectedReaction,
        ),
      ),
    ),
  );
}
