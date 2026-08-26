import 'package:flutter/material.dart';

class SubstitutionSpaceScreen extends StatelessWidget {
  const SubstitutionSpaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Подсменка'),
          actions: [
            IconButton(
              tooltip: 'Добавить участников',
              onPressed: () {
                _showNotConnectedYet(context);
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Список 0'),
              Tab(text: 'Отпуск 0'),
              Tab(text: 'Больничный 0'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _EmptySubstitutionTab(text: 'В ротации пока нет участников'),
            _EmptySubstitutionTab(text: 'В отпуске никого нет'),
            _EmptySubstitutionTab(text: 'На больничном никого нет'),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotConnectedYet(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Добавление участников'),
          content: const Text(
            'Выбор пользователей из контактов подключим следующим шагом.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptySubstitutionTab extends StatelessWidget {
  const _EmptySubstitutionTab({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
