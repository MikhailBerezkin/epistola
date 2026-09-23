import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../services/work_schedule/user_assigned_crew_service.dart';
import '../widgets/work_schedule/assigned_crew_selector.dart';

class AssignedCrewSetupScreen extends StatefulWidget {
  const AssignedCrewSetupScreen({
    super.key,
    required this.userId,
    this.service,
    this.allowBack = true,
    this.onSaved,
  });

  final String userId;
  final UserAssignedCrewService? service;
  final bool allowBack;
  final ValueChanged<ShiftCrew>? onSaved;

  @override
  State<AssignedCrewSetupScreen> createState() =>
      _AssignedCrewSetupScreenState();
}

class _AssignedCrewSetupScreenState extends State<AssignedCrewSetupScreen> {
  late final UserAssignedCrewService _service;

  ShiftCrew? _selectedCrew;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? UserAssignedCrewService.firebase();
  }

  Future<void> _confirmSelection() async {
    final selectedCrew = _selectedCrew;

    if (selectedCrew == null || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Подтвердить звено?'),
          content: Text(
            'Вы выбрали ${selectedCrew.displayName}. '
            'После подтверждения самостоятельно изменить звено будет нельзя. '
            'При ошибке обратитесь к бригадиру.',
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
              child: const Text('Подтвердить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.selectInitialCrew(
        userId: widget.userId,
        crew: selectedCrew,
      );

      if (!mounted) {
        return;
      }

      final onSaved = widget.onSaved;

      if (onSaved != null) {
        onSaved(selectedCrew);
        return;
      }

      Navigator.of(context).pop(selectedCrew);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить звено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedCrew != null && !_isSaving;

    return PopScope(
      canPop: widget.allowBack,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.allowBack,
          title: const Text('Выбор звена'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AssignedCrewSelector(
                  selectedCrew: _selectedCrew,
                  enabled: !_isSaving,
                  onChanged: (crew) {
                    setState(() {
                      _selectedCrew = crew;
                    });
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canSave ? _confirmSelection : null,
                  child: Text(_isSaving ? 'Сохраняем...' : 'Сохранить звено'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
