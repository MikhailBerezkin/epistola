# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Epistola начиналась как корпоративный messenger, но развивается в единое Android-приложение с чатами, рабочими сервисами и внутренними пространствами.

Проект развивается небольшими проверяемыми этапами и на текущей стадии рассчитан на пилотную группу около 40–50 пользователей.

---

## Статус проекта

| Параметр | Значение |
|---|---|
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution Foundation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last confirmed HEAD before current local changes | `bf24968` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Repository | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| RTDB / Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Main platform | Android |
| Pilot | 40–50 users |

Текущие navigation/security изменения после `bf24968` локально проверены, но ещё не считать committed/pushed/deployed, пока соответствующие Git/Firebase команды не выполнены отдельно.

---

# Что такое Epistola

Epistola объединяет:

```text
private chats
group chats
media
push notifications
contacts
profiles
roles / moderation
internal Spaces
work shifts
announcements
transport
safety information
future internal applications
```

Основной архитектурный принцип:

```text
Flutter UI
→ presentation / controllers
→ application services
→ domain
→ Firebase gateways
```

Business logic, Firestore transactions и Security Rules не должны находиться в visual widgets.

---

# Главная навигация

Новая текущая модель Epistola:

```text
App launch
→ Пространства
```

Bottom navigation:

```text
Контакты | Пространства | Профиль
```

`Пространства` являются центральным и стартовым разделом.

Старая отдельная нижняя вкладка:

```text
Чаты
```

удалена из root navigation.

Messenger не удалён.

Теперь он открывается как отдельное внутреннее приложение:

```text
Пространства
→ Чаты
```

Основные navigation files:

```text
lib/screens/home_screen.dart
lib/screens/spaces_page.dart
lib/screens/chats_space_screen.dart
lib/screens/chats_page.dart
```

`ChatsSpaceScreen` является тонкой presentation wrapper над существующим Messenger UI.

Messenger internals при этом не переписывались и массово не переименовывались.

---

# Пространства

Entry point:

```text
lib/screens/spaces_page.dart
```

Текущие плитки:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Рабочие areas:

```text
Чаты
"Список"
```

Остальные модули пока placeholders.

`"Список"` намеренно отображается с кавычками.

---

# Чаты

В Epistola уже реализованы основные Messenger foundations.

## Private chats

```text
text messages
image messages
pagination
logical delete
push deep links
read receipts ✓ / ✓✓
typing indicator
active-chat notification suppression
chat identity card
per-chat notification settings
```

## Group chats

```text
group creation
members
owner/admin permissions
ownership transfer
group avatars
push deep links
👍 / 👎 reactions
identity card
members-only view
per-chat notification settings
```

## Message history

```text
pagination по 20
older-page loading
scroll position preservation
realtime merge
date separators
floating date indicator
image-aware scroll behavior
```

## Notifications

```text
FCM
active-chat suppression
sound / silent / disabled
custom Epistola seagull sound
Android notification channels
vibration
image notification preview
```

---

# "Список" / Substitution Foundation

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

---

# Spaces roles

Роли:

```text
member
brigadier
owner
```

Capabilities:

```text
member
→ обычное использование
```

```text
brigadier
→ управление "Списком"
```

```text
owner
→ управление "Списком"
→ управление Spaces roles
```

Owner всегда остаётся highest-priority role.

---

# Availability и Status

Критичное разделение:

```text
availability
≠
status
```

Обычный пользователь может менять:

```text
только собственную availability
```

Обычный пользователь не может самостоятельно менять:

```text
active
vacation
sick
```

Status управляется manager-level flow.

Бригадир/owner также не выставляет другому пользователю его availability из participant card.

То есть `"светофор"` остаётся выбором самого пользователя.

---

# Queue

Canonical очередь хранится в:

```text
rotationOrder
```

UI не является authoritative queue.

Call flow:

```text
manager selects participant
→ selects shift
→ application service
→ Firestore transaction
→ canonical queue update
```

---

# Shift selection

При вызове доступны:

```text
Сегодня в ночь
Завтра в день
Отмена
```

Domain shifts:

```text
day   → 08:00–20:00
night → 20:00–08:00 next day
```

Statistics month определяется датой начала смены.

Пример:

```text
31 Aug night
→ August

1 Sep day
→ September
```

---

# Undo + Pending Call

После вызова:

```text
participant moved in queue
→ pendingCall created
→ 6-second Undo window
```

Production path:

```text
spaces/substitution/pendingCalls/{callId}
```

Если Undo успешен:

```text
queue rollback
pending removed
statistics unchanged
```

После окончания окна:

```text
pending
→ finalization transaction
→ statistics
→ pending delete
```

---

# Exactly-once finalization

Core:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Transaction:

```text
read pending
→ read yearly statistics
→ apply increment
→ write statistics
→ delete pending
```

Повторный finalize после successful transaction:

```text
pending missing
→ false / no-op
```

Таким образом один pending call может увеличить statistics максимум один раз.

---

# Recovery

Если приложение закрыли до finalization:

```text
manager opens "Список"
→ one-shot pending recovery
→ expired pending calls finalized
```

Recovery не использует постоянный listener.

Это уменьшает Firestore reads для пилота.

---

# Production statistics

Path:

```text
spaces/substitution/statistics/year_YYYY
```

Example:

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

Read model:

```text
one current-year document
```

Нет one-read-per-participant.

Statistics привязана к UID.

Remove/reinvite участника не удаляет его историческую статистику.

---

# Statistics UI

Participant card может показывать:

```text
Статистика
Август            4
[shift segments]
За год            7
```

Segments:

```text
day   → yellow/amber
night → dark blue
```

Domain хранит:

```text
day
night
```

а не Flutter colors.

Widget:

```text
lib/widgets/spaces/substitution/substitution_statistics_summary.dart
```

---

# Settings

Bottom sheet:

```text
Настройки списка
```

Local preferences:

```text
queue badge:
- Аватар
- Номер

statistics:
- show
- hide
```

Manager дополнительно видит:

```text
Добавить участников
```

`show/hide statistics` влияет только на presentation.

Statistics accumulation продолжается независимо.

---

# Firestore Security Rules

Authoritative security boundary:

```text
firestore.rules
```

Substitution Rules защищают:

```text
participants
role-aware management
call flow
pendingCalls
statistics
recovery
```

Текущий security invariant:

```text
member
→ can change own availability only
```

Member не может client-side write изменить собственный:

```text
status
rotationOrder
```

---

## Rules deploy state

Предыдущий Substitution Rules foundation был deployed в:

```text
epistola-434b7
```

После этого сделана дополнительная локальная security correction:

```text
member self update
→ availability only
→ status immutable
```

Эта новая correction сейчас:

```text
LOCAL
TESTED
NOT DEPLOYED
```

Не считать production Rules обновлёнными до отдельного Firebase deploy.

---

# Verification checkpoint

Flutter:

```text
flutter.bat analyze
→ No issues found
```

```text
flutter.bat test
→ 751 passed
```

Firestore:

```text
full Firestore Rules suite
→ 133 passed
→ 0 failed
```

Release APK:

```text
flutter.bat build apk --release
→ SUCCESS
→ build\app\outputs\flutter-apk\app-release.apk
→ 56.8 MB
```

`git diff --check`:

```text
clean
```

LF→CRLF messages являются line-ending warnings, а не diff errors.

---

# Manual verification

Substitution scenarios:

```text
normal participant call
Undo
statistics unchanged after Undo
app close before finalization
manager recovery
exactly-once finalization
remove/reinvite preserving statistics
same-screen statistics refresh
August/September boundary
availability ownership
manager/member permission split
statistics rendering
```

Navigation scenarios:

```text
app launch
→ Пространства
```

```text
Пространства
→ Чаты
→ chat
→ Back
→ chat list
→ Back
→ Пространства
```

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
→ application exit
```

Manual result:

```text
работает
```

---

# Future SpacesBar

Следующее крупное архитектурное направление может быть:

```text
SpacesBar / Announcements Foundation
```

Concept:

```text
persistent information/status bar
на экране Пространства
```

Potential message kinds:

```text
announcement
substitutionCall
future system events
```

`kind` и `priority` должны оставаться разными semantic fields.

Несколько active messages потенциально отображаются через carousel.

Substitution call должен иметь возможность немедленно выйти на первый план.

Предпочтительный принцип:

```text
one business event
→ push
→ SpacesBar
→ system notification area
```

а не несколько независимых копий одного события.

Перед implementation отдельно требуется решить:

```text
Firestore schema
permissions
expiration
priority
active-message limits
carousel
dismiss/read behavior
system notification integration
```

---

# Cost model

Проект рассчитан на пилот:

```text
40–50 пользователей
```

Основные ограничения:

```text
не делать лишние Firestore reads
не делать лишние writes
не создавать per-widget listeners
кэшировать user data по UID
использовать one-shot operations там, где listener не нужен
```

---

# Development environment

Основная среда:

```text
Windows
PowerShell
VS Code
Android
```

Java:

```text
Java 21.0.10
```

JDK:

```text
C:\Program Files\Android\Android Studio\jbr
```

Для новой PowerShell-сессии:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Основные команды:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git
```

В инструкциях использовать repo-relative paths:

```text
lib/...
test/...
```

---

# Project documents

При конфликте:

```text
source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Назначение:

```text
PROJECT_CONTEXT.md
→ текущая рабочая контрольная точка и handoff

ARCHITECTURE.md
→ устойчивые технические решения

README.md
→ быстрый обзор проекта
```

---

# Git state

Current feature branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Last confirmed HEAD before current local navigation/security changes:

```text
bf24968
```

Current local work пока нельзя считать:

```text
committed
pushed
deployed
merged
released
```

пока соответствующая операция явно не выполнена.

Не считать выполненными без Git confirmation:

```text
merge into main
tag v0.8.0
release closure
```

---

# Development protocol

Работа ведётся:

```text
маленькими проверяемыми шагами
```

Для небольших изменений:

```text
точная замена нескольких строк
```

Для крупных изменений:

```text
полный файл
```

Перед functional commit:

```text
manual test
→ format
→ analyze
→ tests
→ release build
→ restore generated plugin noise
→ git diff --check
→ git status --short
```

Docs-only изменения не требуют повторной Flutter-сборки.

State-changing действия:

```text
commit
push
merge
tag
deploy
branch creation
```

выполняются только после явного подтверждения пользователя.