import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/spaces_access_role.dart';
import '../domain/models/substitution_call_receipt.dart';
import '../domain/models/substitution_participant.dart';
import '../models/app_user.dart';
import '../services/spaces/spaces_dependencies.dart';
import '../services/spaces/substitution/substitution_call_service.dart';
import '../services/spaces/substitution/substitution_dependencies.dart';
import '../services/spaces/substitution/substitution_participant_actions_service.dart';
import '../services/spaces/substitution/substitution_participants_service.dart';
import '../services/spaces/substitution/substitution_user_cache.dart';
import '../widgets/avatar/user_avatar_view.dart';
import 'substitution_add_participants_screen.dart';

class SubstitutionSpaceScreen extends StatefulWidget {
  const SubstitutionSpaceScreen({super.key});

  @override
  State<SubstitutionSpaceScreen> createState() =>
      _SubstitutionSpaceScreenState();
}

class _SubstitutionSpaceScreenState extends State<SubstitutionSpaceScreen> {
  late final SubstitutionParticipantsService _participantsService;
  late final SubstitutionUserCache _userCache;
  late final SubstitutionCallService _callService;
  late final SubstitutionParticipantActionsService _participantActionsService;

  SpacesAccessRole _accessRole = SpacesAccessRole.member;
  bool _isAccessRoleLoading = true;
  bool _isRotationActionInProgress = false;
  bool _isAvailabilityActionInProgress = false;

  StreamSubscription<List<SubstitutionParticipant>>? _participantsSubscription;

  List<SubstitutionParticipant> _participants =
      const <SubstitutionParticipant>[];

  bool _isLoading = true;
  Object? _participantsError;
  Object? _usersError;

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  bool get _isActionInProgress {
    return _isRotationActionInProgress || _isAvailabilityActionInProgress;
  }

  @override
  void initState() {
    super.initState();

    _participantsService = SubstitutionParticipantsService.firebase();
    _userCache = SubstitutionUserCache.firebase();
    _callService = createSubstitutionCallService();
    _participantActionsService = createSubstitutionParticipantActionsService();

    unawaited(_loadAccessRole());
    _watchParticipants();
  }

  @override
  void dispose() {
    final subscription = _participantsSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }

  Future<void> _loadAccessRole() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = SpacesAccessRole.member;
        _isAccessRoleLoading = false;
      });

      return;
    }

    try {
      final role = await defaultSpacesAccessService.getRole(userId: userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = role;
        _isAccessRoleLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = SpacesAccessRole.member;
        _isAccessRoleLoading = false;
      });
    }
  }

  void _watchParticipants() {
    _participantsSubscription = _participantsService.watchParticipants().listen(
      (participants) {
        if (!mounted) {
          return;
        }

        setState(() {
          _participants = participants;
          _isLoading = false;
          _participantsError = null;
        });

        unawaited(_loadMissingUsers(participants));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _participantsError = error;
        });
      },
    );
  }

  Future<void> _loadMissingUsers(
    List<SubstitutionParticipant> participants,
  ) async {
    try {
      final changed = await _userCache.loadMissing(
        participants.map((participant) => participant.userId),
      );

      if (!mounted) {
        return;
      }

      if (changed || _usersError != null) {
        setState(() {
          _usersError = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _usersError = error;
      });
    }
  }

  void _retryParticipants() {
    final subscription = _participantsSubscription;
    _participantsSubscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    setState(() {
      _isLoading = true;
      _participantsError = null;
    });

    _watchParticipants();
  }

  void _retryUsers() {
    setState(() {
      _usersError = null;
    });

    unawaited(_loadMissingUsers(_participants));
  }

  Future<void> _openAddParticipants() async {
    if (_isActionInProgress) {
      return;
    }

    final selectedUsers = await Navigator.of(context).push<List<AppUser>>(
      MaterialPageRoute<List<AppUser>>(
        builder: (_) {
          return SubstitutionAddParticipantsScreen(
            excludedUserIds: _participants
                .map((participant) => participant.userId)
                .toSet(),
          );
        },
      ),
    );

    if (!mounted || selectedUsers == null || selectedUsers.isEmpty) {
      return;
    }

    try {
      final addedCount = await _participantsService.addParticipants(
        selectedUsers.map((user) => user.uid),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount == 1
                ? 'Участник добавлен'
                : 'Добавлено участников: $addedCount',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить участников')),
      );
    }
  }

  Future<void> _confirmCallParticipant(
    SubstitutionParticipant participant,
  ) async {
    if (!_accessRole.canManageSubstitution ||
        _isActionInProgress ||
        !participant.isActive) {
      return;
    }

    final displayName = _displayNameForParticipant(participant);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Вызвать участника?'),
          content: Text(
            '$displayName будет перемещён в конец активной очереди.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Вызвать'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _callParticipant(participant: participant, displayName: displayName);
  }

  Future<void> _callParticipant({
    required SubstitutionParticipant participant,
    required String displayName,
  }) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      final receipt = await _callService.callParticipant(
        userId: participant.userId,
      );

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: Text('$displayName вызван'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () {
              unawaited(_undoLastCall(receipt));
            },
          ),
        ),
      );

      Timer(const Duration(seconds: 6), () {
        if (!mounted) {
          return;
        }

        messenger.hideCurrentSnackBar();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выполнить вызов')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  Future<void> _undoLastCall(SubstitutionCallReceipt receipt) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      final undone = await _callService.undoLastCall(receipt: receipt);

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            undone
                ? 'Вызов отменён'
                : 'Отмена недоступна: очередь уже изменилась',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отменить вызов')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  Future<void> _openAvailabilityPicker(
    SubstitutionParticipant participant,
  ) async {
    if (_isActionInProgress ||
        !participant.isActive ||
        participant.userId != _currentUserId) {
      return;
    }

    final selectedAvailability =
        await showModalBottomSheet<SubstitutionAvailability>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Доступность',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    _AvailabilityOption(
                      availability: SubstitutionAvailability.green,
                      selected:
                          participant.availability ==
                          SubstitutionAvailability.green,
                      onTap: () {
                        Navigator.of(
                          sheetContext,
                        ).pop(SubstitutionAvailability.green);
                      },
                    ),
                    _AvailabilityOption(
                      availability: SubstitutionAvailability.yellow,
                      selected:
                          participant.availability ==
                          SubstitutionAvailability.yellow,
                      onTap: () {
                        Navigator.of(
                          sheetContext,
                        ).pop(SubstitutionAvailability.yellow);
                      },
                    ),
                    _AvailabilityOption(
                      availability: SubstitutionAvailability.red,
                      selected:
                          participant.availability ==
                          SubstitutionAvailability.red,
                      onTap: () {
                        Navigator.of(
                          sheetContext,
                        ).pop(SubstitutionAvailability.red);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );

    if (!mounted ||
        selectedAvailability == null ||
        selectedAvailability == participant.availability) {
      return;
    }

    setState(() {
      _isAvailabilityActionInProgress = true;
    });

    try {
      await _participantActionsService.updateAvailability(
        userId: participant.userId,
        availability: selectedAvailability,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить доступность')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAvailabilityActionInProgress = false;
        });
      }
    }
  }

  String _displayNameForParticipant(SubstitutionParticipant participant) {
    final user = _userCache.usersById[participant.userId];

    if (user == null) {
      return participant.userId;
    }

    final displayName = user.effectiveWorkDisplayName.trim();

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return participant.userId;
  }

  @override
  Widget build(BuildContext context) {
    final activeParticipants = _participants
        .where((participant) => participant.isActive)
        .toList(growable: false);

    final vacationParticipants = _participants
        .where((participant) => participant.isOnVacation)
        .toList(growable: false);

    final sickParticipants = _participants
        .where((participant) => participant.isSick)
        .toList(growable: false);

    final usersById = _userCache.usersById;

    final canManageSubstitution =
        !_isAccessRoleLoading && _accessRole.canManageSubstitution;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Подсменка'),
          actions: [
            if (canManageSubstitution)
              IconButton(
                tooltip: 'Добавить участников',
                onPressed: _isActionInProgress ? null : _openAddParticipants,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Список ${activeParticipants.length}'),
              Tab(text: 'Отпуск ${vacationParticipants.length}'),
              Tab(text: 'Больничный ${sickParticipants.length}'),
            ],
          ),
        ),
        body: _buildBody(
          activeParticipants: activeParticipants,
          vacationParticipants: vacationParticipants,
          sickParticipants: sickParticipants,
          usersById: usersById,
          canManageSubstitution: canManageSubstitution,
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<SubstitutionParticipant> activeParticipants,
    required List<SubstitutionParticipant> vacationParticipants,
    required List<SubstitutionParticipant> sickParticipants,
    required Map<String, AppUser> usersById,
    required bool canManageSubstitution,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_participantsError != null) {
      return _LoadError(
        text: 'Не удалось загрузить участников',
        onRetry: _retryParticipants,
      );
    }

    return Column(
      children: [
        if (_usersError != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text(
                'Не удалось загрузить данные части пользователей',
              ),
              trailing: TextButton(
                onPressed: _retryUsers,
                child: const Text('Повторить'),
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            children: [
              _ParticipantListTab(
                participants: activeParticipants,
                usersById: usersById,
                currentUserId: _currentUserId,
                emptyText: 'В ротации пока нет участников',
                showQueueNumber: true,
                onParticipantTap: canManageSubstitution && !_isActionInProgress
                    ? (participant) {
                        unawaited(_confirmCallParticipant(participant));
                      }
                    : null,
                onAvailabilityTap: !_isActionInProgress
                    ? (participant) {
                        unawaited(_openAvailabilityPicker(participant));
                      }
                    : null,
              ),
              _ParticipantListTab(
                participants: vacationParticipants,
                usersById: usersById,
                currentUserId: _currentUserId,
                emptyText: 'В отпуске никого нет',
                showQueueNumber: false,
              ),
              _ParticipantListTab(
                participants: sickParticipants,
                usersById: usersById,
                currentUserId: _currentUserId,
                emptyText: 'На больничном никого нет',
                showQueueNumber: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantListTab extends StatelessWidget {
  const _ParticipantListTab({
    required this.participants,
    required this.usersById,
    required this.currentUserId,
    required this.emptyText,
    required this.showQueueNumber,
    this.onParticipantTap,
    this.onAvailabilityTap,
  });

  final List<SubstitutionParticipant> participants;
  final Map<String, AppUser> usersById;
  final String currentUserId;
  final String emptyText;
  final bool showQueueNumber;
  final ValueChanged<SubstitutionParticipant>? onParticipantTap;
  final ValueChanged<SubstitutionParticipant>? onAvailabilityTap;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return _EmptySubstitutionTab(text: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: participants.length,
      separatorBuilder: (context, index) {
        return const Divider(height: 1, indent: 72);
      },
      itemBuilder: (context, index) {
        final participant = participants[index];
        final user = usersById[participant.userId];

        final canChangeOwnAvailability =
            showQueueNumber &&
            currentUserId.isNotEmpty &&
            participant.userId == currentUserId &&
            onAvailabilityTap != null;

        return _ParticipantRow(
          participant: participant,
          user: user,
          queuePosition: showQueueNumber ? index + 1 : null,
          onTap: onParticipantTap == null
              ? null
              : () {
                  onParticipantTap!(participant);
                },
          onAvailabilityTap: canChangeOwnAvailability
              ? () {
                  onAvailabilityTap!(participant);
                }
              : null,
        );
      },
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.user,
    required this.queuePosition,
    this.onTap,
    this.onAvailabilityTap,
  });

  final SubstitutionParticipant participant;
  final AppUser? user;
  final int? queuePosition;
  final VoidCallback? onTap;
  final VoidCallback? onAvailabilityTap;

  @override
  Widget build(BuildContext context) {
    final resolvedUser = user;

    final displayName = resolvedUser == null
        ? participant.userId
        : _resolveDisplayName(resolvedUser, participant.userId);

    final avatar = resolvedUser == null
        ? const CircleAvatar(radius: 22, child: Icon(Icons.person_outline))
        : UserAvatarView(user: resolvedUser, radius: 22);

    return ListTile(
      onTap: onTap,
      leading: _QueueAvatar(
        avatar: avatar,
        queuePosition: queuePosition,
        availability: participant.availability,
        onAvailabilityTap: onAvailabilityTap,
      ),
      title: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  String _resolveDisplayName(AppUser user, String fallbackUserId) {
    final workDisplayName = user.effectiveWorkDisplayName.trim();

    if (workDisplayName.isNotEmpty) {
      return workDisplayName;
    }

    return fallbackUserId;
  }
}

class _QueueAvatar extends StatelessWidget {
  const _QueueAvatar({
    required this.avatar,
    required this.queuePosition,
    required this.availability,
    required this.onAvailabilityTap,
  });

  final Widget avatar;
  final int? queuePosition;
  final SubstitutionAvailability availability;
  final VoidCallback? onAvailabilityTap;

  @override
  Widget build(BuildContext context) {
    final position = queuePosition;

    if (position == null) {
      return avatar;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final label = _availabilityLabel(availability);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -3,
          bottom: -3,
          child: Tooltip(
            message: onAvailabilityTap == null
                ? label
                : '$label — нажмите для изменения',
            child: Semantics(
              button: onAvailabilityTap != null,
              label: onAvailabilityTap == null
                  ? 'Доступность: $label'
                  : 'Изменить доступность. Сейчас: $label',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAvailabilityTap,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _availabilityColor(availability),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.surface, width: 2),
                  ),
                  child: Text(
                    '$position',
                    style: TextStyle(
                      color: _availabilityTextColor(availability),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityOption extends StatelessWidget {
  const _AvailabilityOption({
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final SubstitutionAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.circle, color: _availabilityColor(availability)),
      title: Text(_availabilityLabel(availability)),
      trailing: selected ? const Icon(Icons.check) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

String _availabilityLabel(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => 'Готов',
    SubstitutionAvailability.yellow => 'Не в приоритете',
    SubstitutionAvailability.red => 'Не вызывать',
  };
}

Color _availabilityColor(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => Colors.green,
    SubstitutionAvailability.yellow => Colors.amber,
    SubstitutionAvailability.red => Colors.red,
  };
}

Color _availabilityTextColor(SubstitutionAvailability availability) {
  return switch (availability) {
    SubstitutionAvailability.green => Colors.white,
    SubstitutionAvailability.yellow => Colors.black87,
    SubstitutionAvailability.red => Colors.white,
  };
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.text, required this.onRetry});

  final String text;
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
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
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
