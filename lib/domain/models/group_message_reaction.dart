enum GroupMessageReaction {
  like('like'),
  dislike('dislike');

  const GroupMessageReaction(this.storageValue);

  final String storageValue;

  static GroupMessageReaction? tryParse(Object? value) {
    return switch (value) {
      'like' => GroupMessageReaction.like,
      'dislike' => GroupMessageReaction.dislike,
      _ => null,
    };
  }

  static GroupMessageReaction? resolveTap({
    required GroupMessageReaction? current,
    required GroupMessageReaction tapped,
  }) {
    if (current == tapped) {
      return null;
    }

    return tapped;
  }
}
