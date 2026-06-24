import 'package:flutter/material.dart';

class MemberStatusCard extends StatelessWidget {
  final String status;
  final String statusTitle;
  final String statusDetails;

  const MemberStatusCard({
    super.key,
    required this.status,
    required this.statusTitle,
    required this.statusDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(status == 'banned' ? Icons.block : Icons.volume_off),
        title: Text(statusTitle),
        subtitle: statusDetails.isEmpty ? null : Text(statusDetails),
      ),
    );
  }
}
