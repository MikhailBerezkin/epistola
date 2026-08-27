import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/spaces/substitution/substitution_candidates_service.dart';
import '../widgets/avatar/user_avatar_view.dart';

class SubstitutionAddParticipantsScreen extends StatefulWidget {
  const SubstitutionAddParticipantsScreen({
    super.key,
    this.excludedUserIds = const <String>{},
    this.candidatesService,
  });

  final Set<String> excludedUserIds;
  final SubstitutionCandidatesService? candidatesService;

  @override
  State<SubstitutionAddParticipantsScreen> createState() =>
      _SubstitutionAddParticipantsScreenState();
}

class _SubstitutionAddParticipantsScreenState
    extends State<SubstitutionAddParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};

  late final SubstitutionCandidatesService _candidatesService;
  late Future<List<AppUser>> _candidatesFuture;

  String _query = '';

  @override
  void initState() {
    super.initState();

    _candidatesService =
        widget.candidatesService ?? SubstitutionCandidatesService.firebase();

    _loadCandidates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCandidates() {
    _candidatesFuture = _candidatesService.loadCandidates(
      excludedUserIds: widget.excludedUserIds,
    );
  }

  void _retry() {
    setState(_loadCandidates);
  }

  void _toggleUser(AppUser user) {
    setState(() {
      if (!_selectedUserIds.add(user.uid)) {
        _selectedUserIds.remove(user.uid);
      }
    });
  }

  void _completeSelection(List<AppUser> candidates) {
    if (_selectedUserIds.isEmpty) {
      return;
    }

    final selectedUsers = candidates
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList(growable: false);

    Navigator.of(context).pop<List<AppUser>>(selectedUsers);
  }

  String _displayName(AppUser user) {
    final workDisplayName = user.effectiveWorkDisplayName.trim();

    if (workDisplayName.isNotEmpty) {
      return workDisplayName;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return user.uid;
  }

  List<AppUser> _filterCandidates(List<AppUser> candidates) {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return candidates;
    }

    return candidates
        .where((user) {
          final displayName = _displayName(user).toLowerCase();
          final name = user.name.toLowerCase();
          final email = user.email.toLowerCase();
          final phone = user.phone.toLowerCase();

          return displayName.contains(query) ||
              name.contains(query) ||
              email.contains(query) ||
              phone.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить участников')),
      body: FutureBuilder<List<AppUser>>(
        future: _candidatesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(onRetry: _retry);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final candidates = snapshot.data ?? const <AppUser>[];

          if (candidates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Все зарегистрированные пользователи уже добавлены',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final visibleCandidates = _filterCandidates(candidates);
          final selectedCount = _selectedUserIds.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Поиск сотрудников',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Очистить',
                            onPressed: () {
                              _searchController.clear();

                              setState(() {
                                _query = '';
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: visibleCandidates.isEmpty
                    ? const Center(child: Text('Пользователи не найдены'))
                    : ListView.separated(
                        itemCount: visibleCandidates.length,
                        separatorBuilder: (context, index) {
                          return const Divider(height: 1, indent: 72);
                        },
                        itemBuilder: (context, index) {
                          final user = visibleCandidates[index];
                          final isSelected = _selectedUserIds.contains(
                            user.uid,
                          );

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) {
                              _toggleUser(user);
                            },
                            secondary: UserAvatarView(user: user, radius: 22),
                            title: Text(
                              _displayName(user),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: user.email.trim().isEmpty
                                ? null
                                : Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: selectedCount == 0
                          ? null
                          : () {
                              _completeSelection(candidates);
                            },
                      icon: const Icon(Icons.check),
                      label: Text(
                        selectedCount == 0
                            ? 'Выберите участников'
                            : 'Готово ($selectedCount)',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить пользователей',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
