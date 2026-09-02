# Epistola — Architecture

Основной технический документ проекта Epistola.

При конфликте информации использовать следующий приоритет:

```text
исходный код текущей ветки
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` хранит текущую рабочую контрольную точку и handoff.

`ARCHITECTURE.md` фиксирует устойчивые архитектурные решения.

`README.md` предназначен для краткого обзора проекта.

---

# 1. Статус документа

| Параметр | Значение |
|---|---|
| Версия документа | `5.1` |
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution Foundation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last committed checkpoint | `bf24968` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Main platform | Android |
| Pilot target | 40–50 users |
| Last update | сентябрь 2026 |

`v0.8.0` расширяет Epistola из messenger-first приложения в платформу внутренних приложений.

Главное архитектурное направление:

```text
Epistola
→ Spaces launcher
→ internal applications
```

Одним из внутренних приложений является:

```text
Чаты
```

При этом существующая Messenger/chat architecture не переписывается.

---

# 2. Назначение проекта

Epistola — корпоративная Flutter/Firebase платформа для коммуникации и внутренних сервисов компании.

Краткосрочная цель:

```text
стабильный Android pilot
40–50 пользователей
```

Долгосрочная цель:

```text
communication
+
internal services platform
```

Основные направления:

```text
private chats
group chats
media
notifications
roles / moderation
announcements
documents
work shifts
transport
safety information
internal applications
```

---

# 3. Infrastructure

```text
Repository:
MikhailBerezkin/epistola

Firebase project:
epistola-434b7

Firestore region:
eur3

Realtime Database region:
europe-west1

Cloud Functions region:
europe-west1

Android package:
com.epistola.app
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

Infrastructure configuration и Firebase-specific implementation не должны находиться в pure domain или presentation widgets.

---

# 4. Canonical architecture layers

Основная граница проекта:

```text
Flutter UI
    ↓
Presentation / Screen orchestration
    ↓
Controllers / Application Services
    ↓
Domain Models / Contracts
    ↓
Firebase Gateways / Adapters
    ↓
Firebase
```

## 4.1 Flutter UI

UI отвечает за:

```text
rendering
gestures
navigation
loading presentation
error presentation
dialogs
bottom sheets
overlays
local visual preferences
```

UI не должен:

```text
выполнять Firestore transactions для business flow
самостоятельно считать production statistics
полагаться на скрытую кнопку как security boundary
создавать Firebase schema из visual state
реализовывать rollback correctness
```

## 4.2 Presentation / screen orchestration

Screen может:

```text
создать/получить services
подписаться на streams
хранить screen cache
запускать application operation
показывать результат пользователю
координировать navigation
```

Business invariants остаются ниже presentation layer.

Пример:

```text
SubstitutionSpaceScreen
→ SubstitutionCallService
→ Firestore transaction gateway
```

Recovery:

```text
SubstitutionSpaceScreen
→ SubstitutionCallReconciliationService
→ SubstitutionCallFinalizationFirestoreGateway
```

## 4.3 Application services

Application layer отвечает за:

```text
validation
orchestration
ordering
transaction flow
recovery
retry-safe operations
statistics loading
participant mutations
work-name mutations
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

## 4.4 Domain

Pure domain содержит semantic state.

Domain не должен зависеть от:

```text
Flutter widgets
BuildContext
Colors
Firestore Transaction
Firebase DocumentReference
presentation-specific classes
```

Relevant v0.8.0 domain:

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

## 4.5 Infrastructure

Firebase-aware layer отвечает за:

```text
participant persistence
Spaces roles
pending calls
statistics persistence
transactional call flow
exactly-once finalization
```

Relevant gateways:

```text
SubstitutionPendingCallFirestoreGateway
SubstitutionCallFinalizationFirestoreGateway
SubstitutionStatisticsFirestoreGateway
```

---

# 5. Spaces platform architecture

Spaces — главный launcher внутренних приложений Epistola.

Основной экран:

```text
lib/screens/spaces_page.dart
```

После текущего navigation change root application flow:

```text
App launch
→ HomeScreen
→ SpacesPage
```

Spaces является default root destination.

Это изменение отличает текущую архитектуру от первоначального v0.8.0 foundation, где Chats и Spaces были отдельными соседними bottom-navigation areas.

Текущая модель:

```text
Epistola
├── Контакты
├── Пространства
│   ├── Чаты
│   ├── "Список"
│   ├── Судозаходы
│   ├── Календарь смен
│   ├── Автобусы
│   └── ОТ и ТБ
└── Профиль
```

Bottom navigation:

```text
Контакты
Пространства
Профиль
```

Default:

```text
Пространства
```

---

# 6. Root navigation architecture

Root screen:

```text
lib/screens/home_screen.dart
```

Canonical indexes:

```text
0 → Контакты
1 → Пространства
2 → Профиль
```

Default state:

```text
selectedIndex = Spaces
```

То есть после нормального входа:

```text
HomeScreen
→ Пространства
```

## 6.1 Root Back behavior

Root navigation contract:

```text
Контакты
→ Back
→ Пространства
```

```text
Профиль
→ Back
→ Пространства
```

```text
Пространства
→ Back
→ system app exit
```

Child routes используют обычный Navigator stack.

Пример:

```text
Пространства
→ Чаты
→ ChatScreen
→ Back
→ Чаты
→ Back
→ Пространства
```

Это уже вручную проверенный UX contract.

---

# 7. Chats as a Space

Новая presentation wrapper:

```text
lib/screens/chats_space_screen.dart
```

Flow:

```text
SpacesPage
→ Чаты
→ ChatsSpaceScreen
→ ChatsPage
```

`ChatsSpaceScreen` предоставляет существующему messenger:

```text
AppBar
search action
FloatingActionButton
ChatsPage
```

Search:

```text
ChatSearchScreen
```

Create/start message:

```text
NewMessageScreen
```

## 7.1 Messenger internals remain intact

Navigation migration не является rewrite Messenger.

Не переименовывать массово:

```text
Chat*
Chats*
message*
privateChat*
groupChat*
```

Существующие business/domain/Firebase concepts остаются chat concepts.

Architecture rule:

```text
Spaces launcher
может открывать Messenger

но Messenger не становится
Substitution Space implementation
```

## 7.2 Reuse boundary

Разрешено:

```text
Spaces tile
→ presentation wrapper
→ existing ChatsPage
```

Не требуется:

```text
копировать ChatsPage
переписывать ChatService
создавать новый chat backend
менять message schema
```

Таким образом migration минимальна и сохраняет проверенные messenger foundations.

---

# 8. Current Spaces modules

Текущие плитки:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Production-ready areas текущего этапа:

```text
Чаты
"Список"
```

Чаты используют ранее существующий production Messenger.

`"Список"` является новым v0.8.0 production foundation.

Остальные:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

пока placeholders.

Architecture rule для будущего Space:

```text
новый Space
→ собственный presentation
→ собственный application/domain flow при необходимости
→ собственные gateways при backend state
```

Не превращать новые Spaces в chat subtype только ради reuse.

---

# 9. Future Spaces customization

В будущем Spaces launcher должен позволять развитие в сторону:

```text
user-configurable tile order
visibility
role-based available modules
```

Текущая архитектура не должна создавать жёсткую зависимость:

```text
tile position == business identity
```

Business module должен идентифицироваться semantic identifier, а не номером позиции в Grid.

Эта функция пока не реализована.

---

# 10. SpacesBar future architecture

`SpacesBar` — запланированный отдельный foundation.

Текущий статус:

```text
DESIGN DIRECTION
NOT IMPLEMENTED
```

SpacesBar предназначен для persistent high-level information на Spaces launcher.

Conceptual placement:

```text
Spaces screen
→ information/status bar
→ app tiles
```

## 10.1 Message kinds

Предполагаемые semantic kinds:

```text
announcement
substitutionCall
future system kinds
```

Kind и priority являются разными dimensions.

Пример:

```text
kind = announcement
priority = 1
```

или:

```text
kind = announcement
priority = 3
```

Substitution call:

```text
kind = substitutionCall
```

может иметь отдельный maximum-priority presentation.

Не кодировать semantics только цветом.

## 10.2 Presentation

Предполагаемо:

```text
announcement
→ style based on priority

substitutionCall
→ purple/high-priority style
```

Color остаётся presentation concern.

Firestore/domain не хранит Flutter `Color`.

## 10.3 Multiple active messages

При нескольких active items планируется:

```text
carousel / banner rotation
manual swipe / navigation
position indicator
```

Ориентировочная auto-rotation:

```text
30–60 seconds
```

High-priority event должен иметь возможность немедленно выйти на первый план.

Точное поведение утверждается отдельно перед реализацией.

## 10.4 Read/display state

Не создавать backend write на каждый визуальный показ без необходимости.

Предпочтение для presentation-only state:

```text
seen
dismissed
carousel position
```

→ local storage.

Server остаётся authoritative для:

```text
active
expired
cancelled
publisher
priority
kind
```

## 10.5 Publisher permissions

Publishing/editing/cancelling предполагается для:

```text
brigadier
owner
```

Но окончательная capability model должна быть отдельно утверждена.

UI permissions недостаточно.

Firestore Rules должны защищать операции на backend.

## 10.6 Potential schema

Conceptual only:

```text
id
kind
text
priority
createdByUserId
createdAt
expiresAt
cancelledAt
```

Не считать schema production contract до отдельного implementation stage.

## 10.7 Unified event principle

Будущий substitution call желательно моделировать как:

```text
one business event
```

который может проецироваться в:

```text
push
SpacesBar
system notifications area
```

Не создавать три независимых business events для одного вызова.

---

# 11. Spaces access roles

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
member
→ ordinary module usage
```

```text
brigadier
→ canManageSubstitution
```

```text
owner
→ canManageSubstitution
→ canManageSpacesRoles
```

Owner является highest-priority role.

Security authorization не должна зависеть только от Flutter role state.

Architecture:

```text
Flutter role
→ UX/capability presentation

Firestore Rules
→ authoritative backend authorization
```

---

# 12. Substitution participant architecture

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

Vacation/sick users остаются participant records.

Они не удаляются из domain при каждом изменении статуса.

---

# 13. Participant state ownership

Критичное разделение:

```text
availability
и
status
```

имеют разную authority semantics.

## 13.1 Availability

Availability описывает готовность пользователя.

Member может менять:

```text
только собственную availability
```

Constraint:

```text
participant.userId == currentUid
```

Manager не должен менять чужую availability из participant card.

Причина:

```text
"светофор"
является заявлением самого пользователя
```

## 13.2 Status

Status:

```text
active
vacation
sick
```

является managed substitution state.

Member не может самостоятельно менять status прямым client write.

Status изменяется manager-level business operations.

Таким образом:

```text
member self write
→ availability only
```

а не:

```text
availability + status
```

---

# 14. User data boundary

Participant document не должен дублировать весь:

```text
users/{uid}
```

Canonical identity:

```text
UID
```

Participant state хранит substitution-specific fields.

User cache по UID предоставляет reusable identity data:

```text
name
workDisplayName
email
avatar metadata
```

Relevant:

```text
SubstitutionUserCache
```

Это уменьшает повторные Firestore reads.

---

# 15. Work display name

Work display name является рабочой presentation identity.

Fallback:

```text
workDisplayName
→ regular profile name
→ email
→ uid
```

Manager может изменять work display name.

Пустое значение означает fallback к обычному profile identity.

Relevant:

```text
lib/services/spaces/substitution/substitution_work_display_name_service.dart
```

---

# 16. Queue architecture

Canonical queue order хранится через:

```text
rotationOrder
```

UI не является authoritative queue.

Call flow:

```text
manager selects participant
→ selects shift
→ application call service
→ Firestore transaction
→ canonical queue mutation
→ pendingCall created
→ realtime participant stream updates UI
```

Это важно для нескольких manager clients.

Нельзя иметь:

```text
client A canonical order
и
client B canonical order
```

только на основе local List mutation.

---

# 17. Shift domain

`SubstitutionShift` содержит semantic date и shift kind.

Core fields:

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
day
08:00–20:00
```

```text
night
20:00–08:00 next day
```

Statistics attribution:

```text
statisticsYear = shift.year
statisticsMonth = shift.month
```

Ночная смена целиком относится к дате начала.

Пример:

```text
31 August night
→ August statistics
```

Даже если окончание смены:

```text
1 September 08:00
```

Этот invariant находится в domain semantics.

---

# 18. Two-phase substitution call

Call разделён на две фазы.

## 18.1 Phase A — queue mutation + pending

```text
call participant
→ queue changes
→ revision/callId advances
→ pendingCalls/{callId} created
→ UI starts Undo opportunity
```

## 18.2 Phase B — finalization

После Undo window:

```text
pending call
→ yearly statistics
→ pending deleted
```

Преимущества:

```text
Undo не требует вычитать уже начисленную статистику
```

и:

```text
app close не теряет незавершённую операцию
```

---

# 19. Undo architecture

Undo window:

```text
6 seconds
```

UI timer существует для user interaction.

Он не является authoritative security/time mechanism.

Undo operation использует receipt/revision/business conditions.

Нельзя безусловно откатить очередь только потому, что локальный UI ещё показывает кнопку.

Если canonical state уже изменился:

```text
Undo rejected
```

---

# 20. Pending call architecture

Path:

```text
spaces/substitution/pendingCalls/{callId}
```

PendingCall является durable work item.

Содержит данные для finalization:

```text
canonical callId
participant identity
caller identity
shift
timing/finalization data
```

PendingCall:

```text
не является statistics
```

и до successful finalization не считается подтверждённой statistics increment.

---

# 21. Exactly-once finalization

Core:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Transaction:

```text
read pending
→ validate pending
→ read yearly statistics
→ validate statistics
→ accumulate
→ write statistics
→ delete pending
```

Exactly-once invariant:

```text
one pending document
→ at most one statistics increment
```

После successful transaction:

```text
pending missing
```

Repeated finalize:

```text
missing pending
→ false / no-op
```

Firestore transaction conflict/retry является частью correctness model.

Нельзя заменять transaction несколькими независимыми writes.

---

# 22. Recovery architecture

Проблема:

```text
application closes
after call
before UI timer finalization
```

Решение:

```text
manager enters "Список"
→ one-shot pending load
→ expired selection
→ sequential finalization
```

Relevant:

```text
SubstitutionCallReconciliationService
SubstitutionPendingCallFirestoreGateway
```

Recovery intentionally не использует permanent listener.

Причина:

```text
pending recovery требуется редко
permanent listener создавал бы лишние reads
```

Failure policy:

```text
recovery failure
→ screen remains usable
→ pending remains
→ future manager open retries
```

Если хотя бы один call реально finalized:

```text
statistics reload
```

Если все operations no-op:

```text
no unnecessary statistics reload
```

---

# 23. Statistics architecture

Production path:

```text
spaces/substitution/statistics/year_YYYY
```

Example:

```text
spaces/substitution/statistics/year_2026
```

Один document на год.

Schema:

```text
year
monthCallCounts
monthShifts
yearCallCounts
lastFinalizedCallId
updatedAt
```

## 23.1 monthCallCounts

Structure:

```text
month
→ uid
→ count
```

Example:

```text
monthCallCounts["8"]["uid-123"] = 4
```

## 23.2 monthShifts

Structure:

```text
month
→ uid
→ ordered shift list
```

Example:

```text
monthShifts["8"]["uid-123"]
=
["night", "day", "day", "night"]
```

Ordered values позволяют строить visual history без отдельных documents на каждый call.

## 23.3 yearCallCounts

Structure:

```text
uid
→ yearly count
```

## 23.4 lastFinalizedCallId

Technical diagnostic/integrity field.

Не предназначено для обычного UI.

## 23.5 updatedAt

Server timestamp последней модификации aggregate.

---

# 24. Statistics consistency invariants

Statistics mapper обязан reject внутренне противоречивые documents.

Per month/uid:

```text
monthCallCounts
==
monthShifts.length
```

Per uid/year:

```text
yearCallCounts
==
sum(all monthCallCounts)
```

Accumulator является application utility для:

```text
current statistics
+
confirmed pending call
→
new statistics state
```

UI не корректирует totals самостоятельно.

---

# 25. Statistics read model

Current-year UI использует один read:

```text
statistics/year_<currentYear>
```

Не использовать:

```text
one statistics query per participant
```

Screen cache может хранить:

```text
loaded
loading
error
year
statistics model
```

Если:

```text
showStatistics == false
```

current-year statistics document не нужен presentation:

```text
не выполнять лишний read
```

После actual successful finalization:

```text
reload once
```

После false/no-op finalization:

```text
no reload
```

---

# 26. Statistics presentation

Widget:

```text
SubstitutionStatisticsSummary
```

Domain supplies:

```text
count
ordered day/night shifts
```

Presentation:

```text
month title
monthly count
segments
year total
```

Slot scaling:

```text
<= 5 → 5
<= 9 → 9
> 9  → 12
```

Color mapping принадлежит widget layer.

Не хранить:

```text
amber
blue
Flutter Color
```

в Firestore/domain.

---

# 27. UI preferences

Queue badge display и statistics visibility являются локальными preferences.

Например:

```text
queue display:
- avatar
- number
```

```text
showStatistics:
true / false
```

Критичный invariant:

```text
showStatistics == false
```

не означает:

```text
stop statistics accumulation
```

Backend counting продолжается независимо от presentation preference.

---

# 28. Participant management permissions

Manager-level roles:

```text
brigadier
owner
```

Manager actions:

```text
add participant
edit work name
call participant
move to vacation
move to sick
return active
remove participant
```

Member action:

```text
change own availability
```

Member НЕ должен:

```text
change own status
change own rotationOrder
change another participant
```

Manager НЕ должен через participant card:

```text
change another user's availability
```

Owner сохраняет максимальный role priority.

---

# 29. Settings UI boundary

Widget:

```text
SubstitutionSettingsSheet
```

Presentation options:

```text
queue display preference
statistics visibility
manager add-participants action
```

Sheet не должен выполнять Firestore business writes напрямую.

Callbacks:

```text
widget
→ screen orchestration
→ application service
```

---

# 30. Firestore Security Rules

`firestore.rules` является authoritative backend security boundary.

Substitution Rules защищают:

```text
module access
role-aware management
participant state
queue call flow
pending lifecycle
statistics finalization
statistics reads
manager recovery/list
```

Flutter UI не является security mechanism.

## 30.1 Rule overlap

Firestore `allow` expressions могут перекрываться.

Architecture rule:

```text
нельзя рассматривать один deny-like condition
как отменяющий другой allow
```

При изменениях всегда проверять полный path/rule interaction.

## 30.2 Member self-update rule

Canonical current intent:

```text
member
→ own availability only
```

Required invariants:

```text
request.auth.uid == participant userId
rotationOrder unchanged
status unchanged
changed keys only availability
```

Таким образом прямой client write не должен позволить member самостоятельно изменить:

```text
active
vacation
sick
```

## 30.3 Manager status operations

Managed status changes должны использовать manager-authorized flow.

UI absence/presence controls UX.

Firestore Rules independently validate authorization.

## 30.4 Deploy distinction

Предыдущий Substitution Rules foundation был deployed в:

```text
epistola-434b7
```

После него локально выполнено дополнительное tightening:

```text
member self state update
availability only
status immutable
```

На текущей контрольной точке это изменение:

```text
LOCAL
TESTED
NOT DEPLOYED
```

Нельзя считать production Rules синхронизированными с local `firestore.rules`, пока отдельный deploy не подтверждён.

---

# 31. Obsolete TEST statistics removal

Temporary TEST statistics architecture retired.

Production code использует:

```text
SubstitutionStatistics*
```

Не восстанавливать:

```text
SubstitutionTestStatistics*
```

Это касается:

```text
domain model
mapper
service
Firestore gateway
Rules tests
Flutter tests
```

Production statistics foundation является единственным актуальным path.

---

# 32. Firestore cost model

Pilot:

```text
40–50 users
```

Текущие optimization decisions:

```text
one participant stream per module
UID-based reusable user cache
one yearly statistics document
one current-year statistics read
one-shot pending recovery
no pending permanent listener
no per-participant statistics reads
reload statistics only after real finalization
```

Future scaling:

```text
monitor yearly statistics document size
monitor listener count
monitor reads/writes
```

Не оптимизировать заранее ценой ненужной complexity, но не вводить per-widget Firestore reads.

---

# 33. Messaging architecture retained

Spaces-first navigation не заменяет существующий Messenger.

Still valid foundations:

```text
private chats
group chats
message pagination
logical deletion
image messages
push deep links
date separators
private read receipts
group 👍 / 👎 reactions
private typing via RTDB
avatars
identity cards
per-chat notification controls
custom push sound
active-chat notification suppression
```

Spaces additions не должны ломать эти foundations.

---

# 34. Navigation compatibility with Messenger

Existing Messenger route structure сохраняется.

Typical flow:

```text
ChatsSpaceScreen
→ ChatsPage
→ ChatScreen
```

Возврат:

```text
ChatScreen
→ ChatsPage
→ ChatsSpaceScreen pop
→ SpacesPage
```

Existing chat deep-link logic не следует переписывать только из-за того, что Chats теперь открываются из Spaces.

Если future push/deep-link требует навигационного изменения, оно должно проектироваться отдельно и сохранять direct chat opening.

---

# 35. UI replaceability

Visual layer должен оставаться заменяемым.

Future changes могут включать:

```text
themes
typography
backgrounds
bubble shapes
animations
tile design
SpacesBar design
avatars
spacing
```

Такие изменения не должны требовать rewriting:

```text
Firestore schemas
transactions
security
statistics
business domain
```

Domain хранит semantics.

Presentation выбирает visual representation.

---

# 36. Testing architecture

Coverage Substitution foundation включает:

```text
domain tests
mapper tests
accumulator tests
gateway tests
reconciliation tests
dependency tests
widget tests
Firestore Rules tests
```

Relevant tests:

```text
test/domain/models/substitution_statistics_test.dart

test/services/spaces/substitution/
substitution_call_finalization_firestore_gateway_test.dart
substitution_call_reconciliation_service_test.dart
substitution_pending_call_firestore_gateway_test.dart
substitution_statistics_accumulator_test.dart
substitution_statistics_firestore_gateway_test.dart
substitution_statistics_mapper_test.dart

test/widgets/spaces/substitution/
substitution_statistics_summary_test.dart

test/rules/firestore/
substitution_space_rules.test.mjs
substitution_finalize_rules.test.mjs
```

Rule behavior should be verified with Firestore emulator.

---

# 37. Current verification checkpoint

After navigation + member-security tightening:

Flutter:

```text
flutter.bat analyze
→ No issues found
```

Full Flutter tests:

```text
flutter.bat test
→ 751 passed
```

Known test diagnostic noise may include:

```text
Corrupt JPEG data
JPEG datastream contains no image
```

If suite ends:

```text
All tests passed!
```

это не считается failure.

Firestore Rules:

```text
tests 133
suites 9
pass 133
fail 0
```

Release APK:

```text
flutter.bat build apk --release
→ SUCCESS
→ 56.8 MB
```

`git diff --check`:

```text
clean
```

LF→CRLF warnings не являются diff error.

---

# 38. Manual verification checkpoint

Confirmed Substitution scenarios:

```text
normal finalize
Undo before 6 seconds
statistics unchanged after Undo
app close before finalization
recovery after manager re-entry
exactly-once update
remove/reinvite preserves UID statistics
same-screen statistics refresh
August/September attribution
availability UI
manager/member action split
statistics rendering
```

Confirmed navigation scenarios:

```text
app launch
→ Spaces
```

```text
bottom navigation
→ Контакты | Пространства | Профиль
```

```text
Spaces
→ Чаты
→ chat
→ Back
→ chat list
→ Back
→ Spaces
```

```text
Contacts
→ Back
→ Spaces
```

```text
Profile
→ Back
→ Spaces
```

```text
Spaces root
→ Back
→ app exit
```

Manual result:

```text
работает
```

---

# 39. Relevant project structure

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
│   ├── home_screen.dart
│   ├── spaces_page.dart
│   ├── chats_space_screen.dart
│   ├── chats_page.dart
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

Rules:

```text
firestore.rules
```

Rules tests:

```text
test/rules/firestore/
```

---

# 40. Architectural rules for new Spaces

When adding another Space:

```text
1. keep the module isolated
2. use clear domain semantics
3. reuse shared identity/cache where appropriate
4. keep Firebase operations below presentation
5. add Rules coverage for backend writes
6. avoid unbounded listeners
7. store semantics, not Flutter visual styles
8. preserve UID as identity
9. preserve owner as highest role
10. manually test role boundaries
```

Не делать:

```text
новый Space
→ ChatScreen subtype
```

если это не является настоящим chat feature.

---

# 41. Architectural rules for Substitution

Do not:

```text
bypass pending/finalization model
increment statistics from UI
restore TEST statistics model
change shift month attribution casually
allow member to change own status
allow manager to edit another user's availability
replace transactions with unrelated writes
```

Preserve:

```text
exactly-once finalization
UID identity
role-aware Rules
one-shot recovery
small read model
```

---

# 42. Architectural rules for SpacesBar

Before implementation separately decide:

```text
Firestore collection/path
message kind enum
priority semantics
publisher capabilities
expiration model
cancel/edit policy
maximum simultaneous active messages
carousel ordering
local seen/dismissed storage
substitution event integration
system notification integration
```

Do not implement speculative schema piecemeal before these decisions.

Core desired principle:

```text
business event
≠
presentation channel
```

One event may feed several channels.

---

# 43. Development environment notes

Primary development environment:

```text
Windows + PowerShell
```

Java for Firebase emulator/rules work:

```text
Java 21.0.10
```

JDK:

```text
C:\Program Files\Android\Android Studio\jbr
```

Current PowerShell-session setup:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Project command forms:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git
```

Repository-relative paths should be preferred in development instructions:

```text
lib/...
test/...
```

rather than repeating the full Windows project path.

---

# 44. Generated files policy

Flutter commands may modify platform-generated plugin files:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

If changes are generated noise only:

```text
run complete Flutter command series
→ restore generated files once at the end
```

Do not repeatedly restore them between every Flutter command.

---

# 45. Verification protocol

Functional change checkpoint:

```text
manual scenario
→ dart format
→ flutter analyze
→ targeted/full tests as appropriate
→ Firestore emulator tests when Rules changed
→ release APK
→ restore generated noise
→ git diff --check
→ git status --short
```

Docs-only edits do not require unnecessary Flutter rebuild.

---

# 46. State-changing operations

The following are explicit state-changing actions:

```text
commit
push
merge
tag
branch creation
deploy
```

Perform them only after explicit user approval.

Do not commit a changed user scenario before manual verification.

Do not deploy Rules simply because emulator tests passed.

---

# 47. Current Git/release state

Current feature branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Last confirmed HEAD before current local changes:

```text
bf24968
```

Commit:

```text
bf24968 docs: update v0.8.0 substitution foundation
```

Current navigation/security work was performed after that checkpoint.

Therefore until a new commit actually exists:

```text
HEAD remains bf24968
```

Do not claim current local navigation/security work is pushed.

Do not claim:

```text
main merged
v0.8.0 tag created
release closed
```

until Git confirms these actions.

---

# 48. Current Rules release state

Two states must be distinguished.

Previously deployed Substitution Rules foundation:

```text
DEPLOYED
```

New tightening:

```text
member
→ own availability only
→ own status immutable
```

is currently:

```text
LOCAL
TESTED
NOT DEPLOYED
```

This distinction must remain explicit in handoff documentation.

---

# 49. Documentation hierarchy

Use:

```text
PROJECT_CONTEXT.md
```

for:

```text
current exact branch/HEAD
working-tree state
latest checks
current handoff
next immediate steps
```

Use:

```text
ARCHITECTURE.md
```

for:

```text
stable boundaries
design rules
data flow
security semantics
navigation architecture
future architecture directions
```

Use:

```text
README.md
```

for:

```text
quick project overview
major implemented features
basic current status
```

Do not overload README with every implementation detail.

---

# 50. Next architectural direction

After current navigation/security checkpoint is safely fixed, likely next major design area:

```text
SpacesBar / Announcements Foundation
```

Before writing production code, separately design:

```text
event model
collection structure
expiration
permissions
priority
carousel
local read/display state
push integration
substitution integration
```

Current navigation/security change should remain independent from that future work.

---

# 51. Final architectural principles

Preserve these rules throughout Epistola development:

```text
source is authoritative
```

```text
UI is replaceable
```

```text
business rules live below widgets
```

```text
Firestore Rules are authoritative security
```

```text
transactions protect canonical concurrent state
```

```text
UID is canonical user identity
```

```text
owner is highest-priority role
```

```text
member controls own availability, not own managed status
```

```text
Spaces is the main launcher
```

```text
Chats is available through Spaces without Messenger rewrite
```

```text
avoid unnecessary Firestore reads/writes
```

```text
commit/push/deploy only after explicit approval
```