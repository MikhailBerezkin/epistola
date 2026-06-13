import 'package:flutter/material.dart';

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: showChevron ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
