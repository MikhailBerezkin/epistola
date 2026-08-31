# Epistola

Корпоративный Flutter/Firebase messenger и foundation внутренних приложений компании.

Epistola развивается небольшими проверяемыми этапами. Проект Android-first и на текущем этапе ориентирован на пилотную группу около 40–50 пользователей.

## Статус проекта

| Параметр | Значение |
|---|---|
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution Foundation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Functional checkpoint | `63c405e` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Repository | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| RTDB / Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Main platform | Android |
| Pilot | 40–50 users |

Функциональный checkpoint:

```text
63c405e feat(spaces): finalize substitution statistics foundation
```

Feature branch синхронизирована с origin.

Merge в `main` и tag `v0.8.0` не считать выполненными до отдельного подтверждения Git.

## Что такое Epistola

Epistola начиналась как корпоративный messenger, но развивается в коммуникационную платформу с внутренними приложениями.

Основные направления:

```text
private chats
group chats
images/media
push notifications
roles/moderation
internal Spaces
work shifts
transport
safety information
documents
tasks
announcements
```

Главный архитектурный принцип:

```text
UI
→ presentation
→ application services
→ domain
→ Firebase gateways
```

Business logic и Firestore transactions не должны находиться в widgets.

## Реализованные messenger foundations

На стабильной базе проекта уже реализованы:

### Пользователи

- Firebase Authentication;
- profile;
- user search;
- contacts;
- user avatars;
- initials fallback;
- work/display identity helpers.

### Private chats

- text messages;
- deterministic private chat identity;
- chat создаётся после первого сообщения;
- image messages;
- first image message;
- logical delete;
- push deep link;
- read receipts `✓ / ✓✓`;
- typing indicator;
- active-chat notification suppression;
- chat identity card;
- per-chat notification settings.

### Group chats

- creation;
- members;
- owner/admin/moderation roles;
- permissions;
- last-admin protection;
- ownership transfer;
- group avatars;
- push deep link;
- message reactions `👍 / 👎`;
- identity card;
- members-only view;
- per-chat notifications.

### Message history

- pagination по 20;
- older page loading;
- scroll position preservation;
- realtime merge;
- date separators;
- floating date indicator;
- image-aware scroll behavior.

### Notifications

- FCM;
- active-chat suppression;
- `sound / silent / disabled`;
- custom Epistola seagull sound;
- Android notification channels;
- vibration behavior;
- image push preview.

## Spaces — v0.8.0

Spaces — новая область внутренних приложений.

```text
Chats ≠ Spaces
```

Spaces не являются новым chat type.

Entry point:

```text
lib/screens/spaces_page.dart
```

Current tiles:

```text
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Рабочий foundation сейчас реализован для `"Списка"`.

Остальные модули пока placeholders.

## "Список" / Substitution Foundation

Основной экран:

```text
lib/screens/substitution_space_screen.dart
```

Tabs:

```text
Список
Отпуск
Больничный
```

Participant state:

```text
userId
rotationOrder
availability
status
```

Availability:

```text
green  → Всегда готов!
yellow → Только в день
red    → Занят
```

Status:

```text
active
vacation
sick
```

## Roles

Spaces roles:

```text
member
brigadier
owner
```

`brigadier` и `owner` могут управлять `"Списком"`.

Только `owner` управляет Spaces roles.

Owner остаётся highest priority role.

Обычный пользователь может менять только собственную availability.

Manager не меняет availability другого пользователя из его карточки.

## Participant management

Manager может:

- добавлять участников;
- задавать рабочее имя;
- вызывать active участника;
- переводить в отпуск;
- переводить на больничный;
- возвращать в список;
- удалять участника.

Statistics привязана к UID, поэтому remove/reinvite не удаляет исторический счётчик пользователя.

## Queue

Canonical очередь хранится через:

```text
rotationOrder
```

Порядок не является только локальным UI-state.

Call flow изменяет очередь через service/Firestore transaction.

## Shift selection

При вызове доступны:

```text
Сегодня в ночь
Завтра в день
Отмена
```

Domain shift:

```text
day   → 08:00–20:00
night → 20:00–08:00 next day
```

Statistics month определяется датой начала смены.

Пример:

```text
31 Aug night → August
1 Sep day    → September
```

## Undo + Pending Call

После call:

```text
participant moved in queue
→ pendingCall created
→ 6 second Undo window
```

Path:

```text
spaces/substitution/pendingCalls/{callId}
```

Если Undo выполнен вовремя:

```text
queue rollback
pending removed
statistics unchanged
```

Если Undo window закончился:

```text
pending
→ finalization transaction
→ statistics
→ pending delete
```

## Exactly-once finalization

Core:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Transaction:

```text
read pending
read yearly statistics
apply increment
write yearly statistics
delete pending
```

Повторный finalize после successful transaction:

```text
pending missing
→ false/no-op
```

Это защищает statistics от двойного начисления.

## Recovery

Если приложение закрыли до 6-second finalization:

```text
manager opens "Список"
→ one-shot pending recovery
→ expired pending calls finalized
```

Recovery не использует постоянный listener.

Это снижает Firestore reads.

## Production statistics

Path:

```text
spaces/substitution/statistics/year_YYYY
```

Пример:

```text
spaces/substitution/statistics/year_2026
```

Schema:

```text
year
monthCallCounts
monthShifts
yearCallCounts
lastFinalizedCallId
updatedAt
```

Пример semantics:

```text
monthCallCounts["8"][uid] = August count

monthShifts["8"][uid]
= ordered [day, night, ...]

yearCallCounts[uid]
= year total
```

Statistics model:

```text
lib/domain/models/substitution_statistics.dart
```

Read-side:

```text
one current-year document read
```

Нет one-read-per-participant.

## Statistics UI

Карточка участника может показывать:

```text
Статистика
Август            4
[shift bar]
За год            7
```

Shift bar:

```text
day   → yellow/amber
night → dark blue
```

Slot capacity:

```text
0–5  → 5
6–9  → 9
10+  → 12
```

Domain хранит `day/night`, а не Flutter colors.

Widget:

```text
lib/widgets/spaces/substitution/substitution_statistics_summary.dart
```

## Settings

Bottom sheet:

```text
Настройки списка
```

User preferences:

```text
queue badge:
- Аватар
- Номер

statistics:
- show/hide
```

Manager additionally sees:

```text
Добавить участников
```

`show statistics` является только UI preference.

Statistics accumulation продолжается независимо от того, скрыта статистика в UI или показана.

## Firestore Rules

`firestore.rules` обновлены для production Substitution foundation.

Protected areas include:

```text
participants
call flow
pendingCalls
statistics
manager recovery
role-aware writes
```

Obsolete TEST statistics access удалён.

Rules текущего состояния были deployed:

```text
Firebase project epistola-434b7
→ Deploy complete!
```

Functions и Storage этим deploy не изменялись.

## Проверки v0.8.0 checkpoint

Flutter:

```text
targeted statistics widget tests
→ 5/5 passed

flutter.bat analyze
→ No issues found

flutter.bat test
→ 751 passed
```

Firestore:

```text
targeted substitution/finalization
→ 53/53 passed

full Firestore suite
→ 133/133 passed
```

Release APK:

```text
flutter.bat build apk --release
→ SUCCESS
→ build\app\outputs\flutter-apk\app-release.apk
→ 56.8 MB
```

Material Icons tree-shaking output during release build является нормальной оптимизацией.

## Manual scenarios

Проверены:

- normal participant call;
- Undo before 6 seconds;
- statistics unchanged after Undo;
- app close before finalization;
- recovery on next manager open;
- exactly-once statistics update;
- participant remove/reinvite with stats preserved by UID;
- immediate statistics refresh on same screen;
- August/September shift boundary;
- availability selector;
- manager vs self availability permissions;
- statistics segment rendering.

## Cleanup

Удалён старый временный TEST statistics foundation:

```text
SubstitutionTestStatistics
SubstitutionTestStatisticsFirestoreGateway
SubstitutionTestStatisticsMapper
SubstitutionTestStatisticsService
```

Production code должен использовать только:

```text
SubstitutionStatistics*
```

## Основные v0.8.0 файлы

```text
lib/screens/spaces_page.dart
lib/screens/substitution_space_screen.dart
lib/screens/substitution_add_participants_screen.dart

lib/domain/models/spaces_access_role.dart
lib/domain/models/substitution_participant.dart
lib/domain/models/substitution_shift.dart
lib/domain/models/substitution_pending_call.dart
lib/domain/models/substitution_statistics.dart

lib/services/spaces/substitution/substitution_call_service.dart
lib/services/spaces/substitution/substitution_call_reconciliation_service.dart
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
lib/services/spaces/substitution/substitution_pending_call_firestore_gateway.dart
lib/services/spaces/substitution/substitution_statistics_accumulator.dart
lib/services/spaces/substitution/substitution_statistics_firestore_gateway.dart
lib/services/spaces/substitution/substitution_statistics_mapper.dart
lib/services/spaces/substitution/substitution_statistics_service.dart
lib/services/spaces/substitution/substitution_dependencies.dart

lib/widgets/spaces/substitution/substitution_availability_selector.dart
lib/widgets/spaces/substitution/substitution_participant_overlay.dart
lib/widgets/spaces/substitution/substitution_settings_sheet.dart
lib/widgets/spaces/substitution/substitution_statistics_summary.dart

firestore.rules
```

## Git state

Functional checkpoint:

```text
63c405e feat(spaces): finalize substitution statistics foundation
```

Pushed to:

```text
origin/feat/v0.8.0-spaces-substitution-foundation
```

Before documentation replacement:

```text
working tree CLEAN
```

Documentation should be committed separately after replacing:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

## Для следующего чата

Сначала выполнить:

```powershell
git.exe branch --show-current
git.exe rev-parse --short HEAD
git.exe status --short
```

После этого читать актуальный source текущей ветки.

Не начинать с `main`, если feature branch ещё не merged.

Не восстанавливать старые TEST statistics files.

Не менять shift month attribution без отдельного product decision.

Не переносить finalization/statistics logic в UI.

Не делать commit, push, deploy, merge или tag без явного подтверждения пользователя.
