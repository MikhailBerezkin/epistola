import 'package:flutter/material.dart';

class RoleSelectionSheet extends StatelessWidget {
  final bool canTransferAdmin;
  final bool isCurrentUserOwner;

  const RoleSelectionSheet({
    super.key,
    required this.canTransferAdmin,
    required this.isCurrentUserOwner,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Выберите роль',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Гость'),
            onTap: () => Navigator.pop(context, 'guest'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Участник'),
            onTap: () => Navigator.pop(context, 'member'),
          ),
          if (canTransferAdmin) ...[
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.workspace_premium,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Передать права администратора',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(context, 'transfer_admin'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('Модератор'),
            onTap: () => Navigator.pop(context, 'moderator'),
          ),
          if (isCurrentUserOwner)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Администратор'),
              onTap: () => Navigator.pop(context, 'admin'),
            ),
        ],
      ),
    );
  }
}
