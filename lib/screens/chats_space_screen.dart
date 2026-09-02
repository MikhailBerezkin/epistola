import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_search_screen.dart';
import 'chats_page.dart';
import 'new_message_screen.dart';

class ChatsSpaceScreen extends StatelessWidget {
  const ChatsSpaceScreen({super.key});

  void _openSearch(BuildContext context) {
    HapticFeedback.selectionClick();

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChatSearchScreen()));
  }

  void _openNewMessage(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Epistola'),
        actions: [
          IconButton(
            onPressed: () => _openSearch(context),
            icon: const Icon(Icons.search),
            tooltip: 'Поиск',
          ),
        ],
      ),
      body: const ChatsPage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewMessage(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
