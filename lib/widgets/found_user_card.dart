import 'package:flutter/material.dart';

import '../models/app_user.dart';

class FoundUserCard extends StatelessWidget {
  final AppUser user;
  final bool isLoading;
  final VoidCallback onOpenChat;

  const FoundUserCard({
    super.key,
    required this.user,
    required this.isLoading,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            user.name.isNotEmpty
                ? user.name[0].toUpperCase()
                : user.email[0].toUpperCase(),
          ),
        ),
        title: Text(user.name.isNotEmpty ? user.name : 'Без имени'),
        subtitle: Text(user.email),
        trailing: FilledButton(
          onPressed: isLoading ? null : onOpenChat,
          child: const Text('Написать'),
        ),
      ),
    );
  }
}
