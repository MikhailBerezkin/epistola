import 'package:flutter/material.dart';

class MemberRoleCard extends StatelessWidget {
  final String roleTitle;
  final bool canManage;
  final VoidCallback onEdit;

  const MemberRoleCard({
    super.key,
    required this.roleTitle,
    required this.canManage,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings),
        title: const Text('Роль'),
        subtitle: Text(roleTitle),
        trailing: canManage
            ? IconButton(icon: const Icon(Icons.edit), onPressed: onEdit)
            : null,
      ),
    );
  }
}
