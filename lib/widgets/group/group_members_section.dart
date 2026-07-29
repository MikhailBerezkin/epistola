import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../helpers/role_helper.dart';
import '../../models/app_user.dart';
import '../../screens/group_member_screen.dart';
import '../avatar/user_avatar_view.dart';

class GroupMembersSection extends StatelessWidget {
  final String chatId;
  final List<AppUser> users;
  final Map<String, dynamic> memberRoles;
  final bool isLoading;

  const GroupMembersSection({
    super.key,
    required this.chatId,
    required this.users,
    required this.memberRoles,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Участники',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (users.isEmpty)
          const Text('Участники не найдены')
        else
          ...users.map((user) {
            final role = memberRoles[user.uid] ?? 'member';

            return ListTile(
              leading: UserAvatarView(user: user, radius: 20),
              title: Text(user.name.isNotEmpty ? user.name : 'Без имени'),
              subtitle: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: RoleHelper.title(role),
                      style: TextStyle(
                        color: RoleHelper.color(role),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' • ${user.email}'),
                  ],
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupMemberScreen(chatId: chatId, user: user),
                  ),
                );
              },
            );
          }),
      ],
    );
  }
}
