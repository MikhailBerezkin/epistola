# Epistola — Architecture

Основной технический документ проекта Epistola.

При конфликте информации:

```text
исходный код текущей ветки
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` хранит текущий handoff и контрольную точку.

`ARCHITECTURE.md` фиксирует устойчивые архитектурные решения.

`README.md` предназначен для быстрого обзора проекта.

## 1. Статус документа

| Параметр | Значение |
|---|---|
| Версия документа | `5.0` |
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution Foundation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Functional checkpoint | `63c405e` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Main platform | Android |
| Pilot target | 40–50 users |
| Last update | август 2026 |

`v0.8.0` расширяет Epistola за пределы messenger-only UX и создаёт основу внутренних приложений Spaces.

Главное архитектурное изменение:

```text
Chats
и
Spaces
являются соседними application areas
```

Spaces не должны моделироваться как chat type.

## 2. Назначение проекта

Epistola — корпоративный Flutter/Firebase messenger и foundation будущей внутренней платформы.

Краткосрочная цель:

```text
стабильный Android pilot на 40–50 пользователей
```

Долгосрочная цель:

```text
communication + internal services platform
для сотен сотрудников
```

Направления:

```text
private/group chats
media
notifications
roles/moderation
tasks
announcements
documents
work shifts
transport
safety information
internal applications
```

## 3. Infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Android package: com.epistola.app
```

Firebase services:

```text
Authentication
Firestore
Realtime Database
Storage
Messaging
Functions
Security Rules
```

Infrastructure configuration не должна находиться в pure domain или виджетах.

## 4. Основные архитектурные слои

Canonical layering:

```text
Flutter UI
    ↓
Presentation / Screen orchestration
    ↓
Application Services
    ↓
Domain Models / Contracts
    ↓
Infrastructure Gateways / Adapters
    ↓
Firebase
```

### 4.1 Flutter UI

UI отвечает за:

```text
rendering
gestures
loading/error presentation
dialogs
bottom sheets
overlay
local preferences
navigation
```

UI не должен:

```text
выполнять Firestore transaction напрямую для business flow
считать production statistics самостоятельно
определять security permissions по видимости кнопки
создавать Firebase schema из presentation-specific объектов
```

### 4.2 Presentation / Screen orchestration

Screen может:

```text
собрать services
подписаться на participant stream
держать screen cache
запустить application operation
обновить UI после результата
```

Но business invariants должны оставаться ниже.

Пример v0.8.0:

```text
SubstitutionSpaceScreen
→ SubstitutionCallService
→ Firestore gateway / transaction
```

и:

```text
SubstitutionSpaceScreen
→ SubstitutionCallReconciliationService
→ FinalizationGateway
```

### 4.3 Application services

Application layer отвечает за orchestration:

```text
validation
ordering
transaction sequence
recovery
retry-safe flow
statistics loading
participant mutations
work name mutations
```

Relevant v0.8.0 services:

```text
SubstitutionParticipantsService
SubstitutionCallService
SubstitutionCallReconciliationService
SubstitutionParticipantActionsService
SubstitutionWorkDisplayNameService
SubstitutionStatisticsService
```

### 4.4 Domain

Pure domain содержит semantic state без Flutter/Firebase dependency.

v0.8.0 domain:

```text
SpacesAccessRole
SubstitutionParticipant
SubstitutionAvailability
SubstitutionParticipantStatus
SubstitutionShift
SubstitutionShiftKind
SubstitutionCallReceipt
SubstitutionPendingCall
SubstitutionStatistics
```

Domain не хранит:

```text
Colors
Widgets
BuildContext
Firebase DocumentReference
Firestore Transaction
```

### 4.5 Infrastructure

Firebase-aware layer реализует чтение/запись:

```text
participant persistence
pending calls
statistics document
call finalization transaction
Spaces role storage
```

Relevant gateways:

```text
SubstitutionPendingCallFirestoreGateway
SubstitutionCallFinalizationFirestoreGateway
SubstitutionStatisticsFirestoreGateway
```

## 5. Spaces architecture

Spaces — container внутренних приложений.

Current entry point:

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

Только `"Список"` имеет production foundation.

Остальные modules пока placeholders.

Architecture rule:

```text
новый Space
→ собственный domain/application/infrastructure flow
→ не превращать его в chat subtype только ради reuse существующего UI
```

## 6. Spaces access roles

Domain:

```text
SpacesAccessRole
```

Values:

```text
member
brigadier
owner
```

Capabilities:

```text
member:
  use allowed module features

brigadier:
  canManageSubstitution

owner:
  canManageSubstitution
  canManageSpacesRoles
```

Owner — highest priority role.

Security authorization не должна основываться только на Flutter role state.

Flutter state определяет UX, Firestore Rules защищают backend.

## 7. Substitution participant architecture

Canonical participant:

```text
userId
rotationOrder
availability
status
```

Availability:

```text
green
yellow
red
```

Status:

```text
active
vacation
sick
```

Queue membership:

```text
status == active
```

Vacation/sick participants остаются participant records, но выводятся в отдельные tabs.

Это лучше, чем удалять пользователя из domain и создавать заново при каждом отпуске/больничном.

## 8. User data boundary

Participant document не должен дублировать весь `users/{uid}` profile.

UID остаётся canonical identity.

Participant stream даёт substitution state.

User cache по UID даёт:

```text
name
workDisplayName
email
avatar metadata
```

Это сокращает повторные reads.

Relevant component:

```text
SubstitutionUserCache
```

## 9. Work display name

Рабочее имя — отдельная рабочая presentation identity.

Fallback:

```text
workDisplayName
→ regular name
→ email
→ uid
```

Manager может изменять рабочее имя.

Пустое рабочее имя означает возврат к обычному profile name.

## 10. Queue architecture

Canonical order хранится в Firestore:

```text
rotationOrder
```

Кнопка call не должна локально переставлять List и считать это authoritative result.

Flow:

```text
manager selects active participant
→ selects shift
→ application call service
→ transaction updates queue/revision
→ creates pendingCall
→ realtime participant stream updates UI
```

Таким образом два manager-клиента не должны иметь два независимых canonical порядка.

## 11. Shift domain

`SubstitutionShift` содержит:

```text
year
month
day
kind
```

Kinds:

```text
day
night
```

Business times:

```text
day   08:00–20:00
night 20:00–08:00 next day
```

Statistics attribution:

```text
statisticsYear  = shift.year
statisticsMonth = shift.month
```

Ночная смена полностью относится к календарной дате старта.

Это invariant domain layer.

## 12. Two-phase call model

Call разделён на две фазы.

### Phase A — queue mutation + pending

```text
call participant
→ queue changes immediately
→ revision/callId advances
→ pendingCalls/{callId} created
→ UI shows Undo
```

### Phase B — finalization

После Undo window:

```text
pending call
→ yearly statistics
→ pending deleted
```

Преимущество:

```text
Undo может отменить call до начисления статистики
```

и:

```text
закрытие приложения не теряет незавершённую статистику
```

## 13. Undo architecture

Undo window:

```text
6 seconds
```

Timer существует в UI только для удобства пользователя.

Авторитетность времени и прав доступа остаётся в backend/Rules/application flow.

UI timer не должен быть единственным механизмом защиты.

Undo operation использует receipt/revision, чтобы не откатывать уже изменившуюся очередь.

## 14. Pending call storage

Path:

```text
spaces/substitution/pendingCalls/{callId}
```

Properties:

```text
canonical callId
participant/user identity
caller identity
shift
timing required for finalization eligibility
```

PendingCall — durable work item.

Он не является статистикой и не должен отображаться как подтверждённый вызов до finalization.

## 15. Exactly-once finalization transaction

Core file:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Transaction sequence:

```text
read pending
→ validate
→ read year statistics
→ validate
→ accumulate
→ write year statistics
→ delete pending
```

Exactly-once invariant:

```text
one pending document
can produce
at most one statistics increment
```

Reason:

```text
после успешного transaction pending удалён
```

Повторная попытка:

```text
pending missing
→ false/no-op
```

Concurrency:

Firestore transaction retry/conflict handling используется как часть correctness model.

Нельзя заменять эту transaction последовательностью отдельных writes.

## 16. Recovery architecture

Проблема:

```text
app может закрыться после call,
но до UI Timer finalize
```

Решение:

```text
manager enters module
→ load pending calls one time
→ expired only
→ sequential finalize
```

Relevant:

```text
SubstitutionCallReconciliationService
SubstitutionPendingCallFirestoreGateway
```

Почему one-shot, а не listener:

```text
pending recovery не нужен постоянно
и listener создавал бы лишние reads
```

Failure policy:

```text
recovery failure
→ не блокировать screen
→ pending остаётся
→ later manager can retry
```

## 17. Statistics architecture

Production path:

```text
spaces/substitution/statistics/year_YYYY
```

Один документ на год.

Пример:

```text
year_2026
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

### 17.1 monthCallCounts

Logical structure:

```text
month
→ uid
→ count
```

Пример:

```text
monthCallCounts["8"]["uid-123"] = 4
```

### 17.2 monthShifts

Logical structure:

```text
month
→ uid
→ ordered shift kind list
```

Пример:

```text
monthShifts["8"]["uid-123"]
=
["night", "day", "day", "night"]
```

Это позволяет UI построить ordered visual history без дополнительных documents.

### 17.3 yearCallCounts

```text
uid
→ total count for year
```

### 17.4 lastFinalizedCallId

Technical diagnostic/integrity field.

Не предназначено для отображения пользователю.

### 17.5 updatedAt

Server timestamp текущего агрегата.

## 18. Statistics consistency invariants

Mapper должен отвергать внутренне противоречивый документ.

Для каждого month/uid:

```text
monthCallCounts
==
monthShifts.length
```

Для каждого uid:

```text
yearCallCounts
==
sum(all monthCallCounts)
```

Accumulator является единственным application utility, который строит новое aggregate state из:

```text
current statistics
+
confirmed pending call
```

UI никогда не корректирует годовые totals самостоятельно.

## 19. Statistics read model

Для отображения текущей статистики нужен один read:

```text
statistics/year_<currentYear>
```

Не использовать:

```text
one query per participant
```

Screen cache:

```text
loaded flag
loading flag
error
year
statistics model
```

`showStatistics == false`:

```text
statistics document не нужен для UI
→ не делать лишний read
```

После successful finalize:

```text
reload once
```

После no-op finalize:

```text
не reload
```

## 20. Statistics presentation

Widget:

```text
SubstitutionStatisticsSummary
```

Domain data:

```text
count
ordered day/night shifts
```

Presentation:

```text
month title
monthly count
visual segments
year total
```

Slot scaling:

```text
<=5  → 5
<=9  → 9
else → 12
```

Color mapping принадлежит widget layer.

Нельзя записывать `amber`, `blue` или Flutter `Color` в Firestore/domain.

## 21. UI preferences

Queue badge display mode и statistics visibility — локальные пользовательские предпочтения.

Они не влияют на backend statistics accumulation.

Критичный invariant:

```text
showStatistics == false
не означает
disable statistics counting
```

Counting идёт независимо от того, скрыт UI или показан.

## 22. Participant management permissions

Manager actions:

```text
add participants
edit work name
call participant
vacation
sick
return active
remove
```

Self-only member action:

```text
change own availability
```

Availability ownership rule:

```text
participant.userId == currentUid
```

Бригадир не меняет availability другого пользователя из participant card.

## 23. Settings UI boundary

`SubstitutionSettingsSheet` отображает:

```text
queue display preference
statistics visibility
manager-only add participants
```

Sheet не делает Firestore writes напрямую.

Callbacks уходят в screen/application services.

## 24. Firestore security

`firestore.rules` является authoritative security boundary.

Substitution Rules защищают:

```text
module access
role-aware management
participant writes
call flow
pending call lifecycle
statistics finalization
statistics reads
manager recovery/list
```

Overlapping Firestore Rules работают как OR.

Поэтому специальные deny-like блоки нельзя проектировать так, будто более общий allow их отменит.

При cleanup TEST statistics учитывался именно этот принцип.

## 25. Obsolete TEST statistics removal

Temporary TEST statistics model/gateway/service/rules tests удалены.

Architecture rule:

```text
production code must use
SubstitutionStatistics*
```

Не возвращать:

```text
SubstitutionTestStatistics*
```

Новый чат должен считать их retired.

## 26. Firestore cost model

Pilot:

```text
40–50 users
```

Optimization decisions v0.8.0:

```text
participant stream один на module
user cache by UID
statistics one document per year
statistics one read for current year
pending recovery one-shot
no pending listener
no per-participant statistics reads
reload statistics only after actual finalization
```

При дальнейшем росте необходимо профилировать размер yearly statistics document.

Текущая схема достаточна для небольшого пилота и ограниченного количества вызовов.

## 27. Testing architecture

Coverage текущего foundation включает:

```text
domain model tests
mapper tests
accumulator tests
gateway tests
reconciliation tests
dependencies tests
widget statistics summary tests
Firestore Rules tests
```

Новые test files:

```text
test/domain/models/substitution_statistics_test.dart
test/services/spaces/substitution/substitution_call_finalization_firestore_gateway_test.dart
test/services/spaces/substitution/substitution_call_reconciliation_service_test.dart
test/services/spaces/substitution/substitution_pending_call_firestore_gateway_test.dart
test/services/spaces/substitution/substitution_statistics_accumulator_test.dart
test/services/spaces/substitution/substitution_statistics_firestore_gateway_test.dart
test/services/spaces/substitution/substitution_statistics_mapper_test.dart
test/widgets/spaces/substitution/substitution_statistics_summary_test.dart
test/rules/firestore/substitution_finalize_rules.test.mjs
```

## 28. Verification checkpoint

Flutter:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 751 passed
```

Targeted widget statistics:

```text
5/5 passed
```

Firestore Rules:

```text
targeted substitution/finalization
→ 53/53

full Firestore suite
→ 133/133
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
56.8 MB
```

Rules:

```text
deployed successfully to epistola-434b7
```

## 29. Manual verification checkpoint

Confirmed scenarios:

```text
normal finalize
Undo before 6 sec
app close before finalize + recovery
remove/reinvite preserves UID statistics
same-screen statistics refresh
Aug/Sep boundary attribution
availability UI
statistics segment rendering
manager/member action split
```

## 30. Stable messaging architecture retained from earlier releases

v0.8.0 does not replace existing messenger architecture.

Still valid:

```text
private/group chats
cursor pagination
logical message deletion
image messages
push deep links
date separators
private read receipts
group 👍/👎 reactions
private typing via RTDB
avatar foundation
chat identity cards
per-chat notification controls
custom notification sound
```

Spaces additions must not break these foundations.

## 31. Project structure relevant to Spaces

```text
lib/
├── domain/
│   └── models/
│       ├── spaces_access_role.dart
│       ├── substitution_participant.dart
│       ├── substitution_shift.dart
│       ├── substitution_pending_call.dart
│       └── substitution_statistics.dart
│
├── screens/
│   ├── spaces_page.dart
│   ├── substitution_space_screen.dart
│   └── substitution_add_participants_screen.dart
│
├── services/
│   └── spaces/
│       └── substitution/
│           ├── substitution_call_service.dart
│           ├── substitution_call_reconciliation_service.dart
│           ├── substitution_call_finalization_firestore_gateway.dart
│           ├── substitution_pending_call_firestore_gateway.dart
│           ├── substitution_statistics_accumulator.dart
│           ├── substitution_statistics_firestore_gateway.dart
│           ├── substitution_statistics_mapper.dart
│           ├── substitution_statistics_service.dart
│           └── substitution_dependencies.dart
│
└── widgets/
    └── spaces/
        └── substitution/
            ├── substitution_availability_selector.dart
            ├── substitution_participant_overlay.dart
            ├── substitution_queue_badge.dart
            ├── substitution_settings_sheet.dart
            └── substitution_statistics_summary.dart
```

## 32. Architectural rules for next stages

When expanding Spaces:

```text
1. keep each Space modular
2. reuse shared identity/cache services where appropriate
3. do not couple Spaces to ChatScreen
4. keep Firebase writes in service/gateway layer
5. preserve strict Rules coverage
6. avoid unbounded listeners
7. store semantics, not visual styles
8. preserve UID as identity
9. keep owner highest role
10. manually verify role boundaries
```

When extending Substitution:

```text
do not bypass pending/finalization model
do not increment statistics from UI
do not add parallel TEST statistics model
do not change shift month attribution casually
do not allow brigadier to edit another participant's availability
```

## 33. Release-state rule

Functional checkpoint:

```text
63c405e
```

is pushed to feature branch.

Documentation is prepared as a separate finalization step.

Do not claim:

```text
main merged
v0.8.0 tag created
release closed
```

until Git confirms it.

Documentation-only changes do not require unnecessary Flutter rebuild.

After doc replacement:

```powershell
git.exe diff --check
git.exe status --short
```

Then commit/push only with explicit user approval.
