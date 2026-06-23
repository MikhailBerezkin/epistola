import 'package:flutter/material.dart';

class RoleHelper {
  static String title(String role) {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'moderator':
        return 'Модератор';
      case 'guest':
        return 'Гость';
      case 'member':
      default:
        return 'Участник';
    }
  }

  static Color color(String role) {
    switch (role) {
      case 'owner':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      case 'moderator':
        return Colors.blue;
      case 'member':
        return Colors.green;
      case 'guest':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static Color senderNameColor(BuildContext context, String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'moderator':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  static bool isAdminOrOwner(String role) {
    return role == 'admin' || role == 'owner';
  }

  static bool isModeratorOrAbove(String role) {
    return role == 'moderator' || role == 'admin' || role == 'owner';
  }
}
