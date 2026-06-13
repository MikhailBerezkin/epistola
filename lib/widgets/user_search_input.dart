import 'package:flutter/material.dart';

class UserSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSearch;

  const UserSearchInput({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: 'Введите email или телефон',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onSearch,
            icon: const Icon(Icons.search),
            label: Text(isLoading ? 'Поиск...' : 'Найти'),
          ),
        ),
      ],
    );
  }
}
