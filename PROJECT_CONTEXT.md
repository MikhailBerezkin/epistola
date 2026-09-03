# Epistola — Project Context

> Живой handoff-документ проекта.
>
> При конфликте источников использовать порядок:
>
> ```text
> исходный код текущей ветки
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```

## 1. Актуальная контрольная точка

Repository:

```text
MikhailBerezkin/epistola
```

Feature branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Последний functional checkpoint:

```text
769544f feat(spaces): add spaces bar presentation and management
```

Предыдущий SpacesBar security checkpoint:

```text
60966a6 feat(spaces): secure spaces bar board
```

На момент подготовки документа:

```text
HEAD = 769544f
origin/feat/v0.8.0-spaces-substitution-foundation = 769544f
working tree = CLEAN
```

`v0.8.0` всё ещё находится в feature-ветке. Merge в `main` и release tag не считать выполненными без отдельного подтверждения Git-командами.

Последний стабильный release до v0.8.0:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

---

## 2. Проверки checkpoint 769544f

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 835 tests passed

flutter.bat build apk --release
→ SUCCESS
→ app-release.apk 57.4 MB

git.exe diff --check
→ clean
```

Во время полного Flutter suite может появляться диагностический вывод JPEG decoder (`Corrupt JPEG data...`), но если итог `All tests passed`, это не считать падением suite.

Firestore Rules:

```text
SpacesBar targeted Rules suite → 22/22
Full Firestore Rules suite → 155/155
```

Новые SpacesBar Rules задеплоены в production после отдельного подтверждения пользователя.

Generated Flutter plugin files после финальных Flutter-команд восстановлены и в functional commit не попали.

---

## 3. Infrastructure

```text
Firebase project: epistola-434b7
Android package: com.epistola.app
Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Primary platform: Android
Pilot target: 40–50 users
```

Cost principles:

```text
минимум лишних Firestore reads/writes
никаких per-widget Firestore queries
UID-keyed caches для повторно используемых данных
локальный presentation state не переносить в backend без необходимости
```

---

## 4. Development workflow

Environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Studio JBR
Java 21.0.10
```

Commands:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git.exe
```

Пути в чате по умолчанию указывать от repository root.

Working style:

```text
2–3 безопасных связанных шага за раз
рискованные действия отдельно
manual test до commit
commit/push/deploy только после явного подтверждения
большая правка → полный файл
малая правка → точная замена
```

Generated plugin files восстанавливать один раз после последней Flutter-команды серии.

---

# PART I — SPACES PLATFORM

## 5. Spaces является root launcher

Root flow:

```text
App launch
→ Пространства
```

Bottom navigation:

```text
Контакты | Пространства | Профиль
              ↑
            default
```

Indexes:

```text
0 → Контакты
1 → Пространства
2 → Профиль
```

Back behavior:

```text
Контакты → Back → Пространства
Профиль → Back → Пространства
Пространства → Back → выход
```

Messenger не удалён. Он открывается как отдельное приложение:

```text
Пространства → Чаты → ChatsSpaceScreen → ChatsPage
```

Не выполнять массовый rename chat/Messenger internals только ради Spaces launcher.

---

## 6. Текущий Spaces Hub

Основные files:

```text
lib/screens/home_screen.dart
lib/screens/spaces_page.dart
lib/screens/chats_space_screen.dart
```

Для выбранной вкладки Spaces root AppBar показывает:

```text
Epistola
Пространства
```

Отдельный второй AppBar внутри `SpacesPage` удалён.

Меню `⋮` остаётся входом в будущую настройку отображаемых Spaces.

Текущие tiles:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

`"Список"` отображается с кавычками намеренно.

Рабочие modules:

```text
Чаты
"Список"
```

Остальные пока placeholders.

---

## 7. Future adaptive Spaces tiles — согласованное UX

SpacesBar имеет фиксированную высоту и не должен расти из-за количества приложений.

### До 6 active tiles

Текущий regular layout:

```text
2 columns
крупная tile
icon
title
subtitle where defined
```

### 7–8 active tiles

Compact layout:

```text
tiles ниже
subtitle скрываются
остаются icon + title
до 8 tiles должны помещаться без увеличения SpacesBar
```

Желательная архитектура:

```text
regular mode: <= 6
compact mode: >= 7
```

### Нечётное количество tiles

Последняя tile занимает ширину двух колонок. Позже можно сделать её ниже обычной full-width tile, если визуально это будет лучше.

### Более 8 active Spaces

Использовать вертикальный scroll. Возможно добавить ненавязчивый visual hint, что ниже есть продолжение: маленький chevron/arrow/icon.

### Управление tiles

Через `⋮` позже:

```text
show/hide available Spaces
possibly reorder Spaces
```

---

# PART II — SPACES ACCESS ROLES

## 8. SpacesAccessRole

Roles:

```text
member
brigadier
owner
```

`owner` — highest-priority role.

Current capability:

```text
canManageSpacesBar
member = false
brigadier = true
owner = true
```

UI permission не является security boundary. Firestore Rules независимо защищают manager writes.

`SpacesAccessService` кэширует role по UID и coalesces pending reads.

---

# PART III — SPACESBAR

## 9. Current SpacesBar foundation

Основные files:

```text
lib/domain/models/spaces_bar_message.dart
lib/domain/models/spaces_bar_board.dart
lib/domain/models/spaces_bar_publication_receipt.dart

lib/services/spaces/spaces_bar/spaces_bar_board_mapper.dart
lib/services/spaces/spaces_bar/spaces_bar_board_firestore_gateway.dart
lib/services/spaces/spaces_bar/spaces_bar_board_transaction_gateway.dart
lib/services/spaces/spaces_bar/spaces_bar_hidden_messages_preferences.dart
lib/services/spaces/spaces_bar/spaces_bar_visible_messages_resolver.dart
lib/services/spaces/spaces_bar/spaces_bar_presentation_service.dart
lib/services/spaces/spaces_bar/spaces_bar_management_service.dart
lib/services/spaces/spaces_bar/spaces_bar_dependencies.dart

lib/widgets/spaces/spaces_bar/spaces_bar_panel.dart
lib/widgets/spaces/spaces_bar/spaces_bar_editor_sheet.dart

lib/screens/spaces_page.dart
```

Current fixed height:

```text
141 px
```

Current message font:

```text
18 px
```

---

## 10. Authoritative Firestore schema

Document:

```text
spaces/spacesBar
```

Schema:

```text
schemaVersion: 1
revision: int
messages: {
  <messageId>: {
    text: string
    lifetime: oneHour | twelveHours | twentyFourHours | untilCancelled
    createdByUserId: string
    createdAt: Timestamp
  }
}
updatedAt: Timestamp
```

Max active messages:

```text
3
```

Message ID:

```text
messageId = next board revision as string
```

Не хранить в backend:

```text
Flutter Color
visual glow parameters
font size
carousel position
local hidden state
```

---

## 11. Lifetime and ordering

Lifetimes:

```text
1 hour
12 hours
24 hours
until cancelled
```

Expiry выводится из `createdAt + duration`; `untilCancelled` не имеет auto-expiry.

Presentation ordering:

```text
1h → 12h → 24h → untilCancelled
```

Внутри одинакового lifetime — более новые `createdAt` раньше, затем deterministic tie-breaker по message id/revision.

Priority/color отдельно не сохраняются.

---

## 12. Presentation states

Loading:

```text
spinner
```

Error:

```text
Не удалось загрузить закреплённые сообщения
Повторить
```

Empty:

```text
Нет новых закреплённых сообщений
```

One message:

```text
no dots
no chevrons
member → no pencil
brigadier/owner → pencil
```

Two or three:

```text
left chevron
right chevron
dots bottom-center
horizontal swipe
auto rotation
```

Current auto-rotation:

```text
15 seconds
```

Любая ручная навигация запускает новый полный 15-second interval.

---

## 13. Current carousel and deferred replacement

Current implementation:

```text
PageView
каждое сообщение — отдельная card/page
```

Это работает и вручную проверено.

Отложенное presentation improvement:

```text
одно неподвижное внешнее окно SpacesBar
меняется только внутренний content
```

Возможная реализация:

```text
horizontal gesture over whole panel
AnimatedSwitcher / slide / fade
current logical index
```

Также отложено:

```text
finite PageView → cyclic/infinite swipe
```

Пользователь хочет возможность бесконечно свайпить в одну сторону без hard boundary. Dots можно сохранить как logical modulo index.

Пока текущую finite реализацию оставить.

---

## 14. Visual style

Lifetime → accent:

```text
1h → green
12h → blue
24h → orange
untilCancelled → red
```

Цвет показывается как:

```text
чёткий внешний contour
+
мягкое inward glow
```

Цель для будущей тонкой настройки glow:

```text
примерно 7–12 px внутрь рамки
```

Карточка остаётся нейтральной.

Из message card намеренно убраны:

```text
pin icon
visible lifetime label
```

Lifetime остаётся в domain/editor и определяет border color.

---

## 15. Manager pencil and editor

Pencil в нижнем правом углу SpacesBar:

```text
brigadier → visible
owner → visible
member → hidden
```

Editor:

```text
Активные сообщения N/3
existing active messages
delete-for-all action
multiline text
max 250 chars
lifetime dropdown
Опубликовать
```

При `3/3` publisher form скрывается и показывается capacity notice. После удаления одного сообщения form снова появляется.

---

## 16. Publish and global delete

Application layer:

```text
SpacesBarManagementService
```

`member` получает `SpacesBarManagementPermissionException` до gateway call.

Authoritative write:

```text
SpacesBarBoardTransactionGateway
```

Publish transaction:

```text
read board
parse
clean expired
verify active < 3
revision + 1
id = revision
append message
rewrite board
```

Global delete:

```text
editor trash
→ confirmation
→ transaction deleteMessage
→ reload SpacesBar
```

Global delete удаляет сообщение для всех после reload/read.

---

## 17. Local hide — device-local by design

Long press:

```text
Убрать сообщение
Отмена
```

`Убрать сообщение` не делает Firestore write.

Storage:

```text
SharedPreferences
```

Key prefix:

```text
spaces_bar.hidden_message_ids.v1.<userId>
```

Semantics:

```text
per user
per device installation
persistent after restart
```

Поэтому один и тот же аккаунт может скрыть сообщение на телефоне, но видеть его в эмуляторе. Это ожидаемое поведение.

Hidden message остаётся authoritative active server message и виден manager editor, но не показывается в local presentation.

---

## 18. Firestore Rules

Exact match:

```text
match /spaces/spacesBar
```

Behavior:

```text
allow get: signed-in
allow list: false
create/update: brigadier or owner only
delete whole board document: false
```

Rules validate strict schema, max 3, text 1..250, lifetime values, createdByUserId, server timestamps, monotonic revision, new id = revision and existing-message constraints.

Checkpoint:

```text
60966a6 feat(spaces): secure spaces bar board
```

Rules deployed to production.

---

## 19. Manual verification

Emulator verified:

```text
empty state
manager pencil
publish
1/2/3 messages
lifetime colors
chevrons
dots
swipe
15-sec timer
timer reset
global delete
3/3 capacity
3/3 → 2/3 slot reopening
```

Physical phone verified:

```text
production board load
member has no pencil
local hide by long press
hidden state survives restart
local hide affects only that device
carousel interaction works
```

Accepted current limitation:

```text
PageView visually slides separate cards
```

Это отложено на отдельный UI polish stage.

---

# PART IV — SUBSTITUTION FOUNDATION

## 20. "Список" / Substitution module

Main screen:

```text
lib/screens/substitution_space_screen.dart
```

v0.8.0 уже включает foundation:

```text
participants
rotationOrder queue
availability
vacation / sick states
participant management
work display name
call participant flow
Undo window
pending call persistence
exactly-once finalization
recovery after interruption
monthly/yearly production statistics
compact statistics UI
Firestore Rules
```

Owner protections не ослаблять.

---

# PART V — EXISTING MESSENGER FOUNDATIONS

## 21. Already completed areas

Private chats:

```text
text
images
pagination
logical delete
push deep links
read receipts ✓ / ✓✓
typing indicator
active-chat push suppression
avatar/user card
notification controls
```

Group chats:

```text
roles
owner/admin protections
ownership transfer
avatars
push deep links
👍 / 👎 reactions
identity/member cards
notification controls
```

Message history:

```text
pagination 20
older-page loading
scroll preservation
realtime merge
date separators
floating date indicator
image-aware scroll behavior
```

Notifications:

```text
FCM
active-chat suppression
custom Epistola sound
vibration
image preview
Android channels
```

---

# PART VI — ROADMAP / NEXT CHAT

## 22. Immediate next SpacesBar block

Следующий functional block:

```text
push integration for SpacesBar announcements
exact SpacesBar message selection/targeting from push
```

Long-term event direction:

```text
one business event
→ push
→ SpacesBar
→ optional system notification surface
```

Не создавать независимые дубли одного business event.

---

## 23. Deferred presentation work

Later, separate presentation-only stage:

```text
PageView separate cards
→ one fixed SpacesBar window with internal transition

finite carousel
→ cyclic/infinite swipe

fine-tune inward glow
```

Keep current product decisions unless user changes them:

```text
15-second rotation
chevrons + dots when >1
same carousel behavior for member/manager
manager additionally gets pencil
```

---

## 24. Deferred Spaces Hub customization

```text
⋮ settings
show/hide Spaces
possibly reorder
<=6 regular
7–8 compact without subtitles
odd last tile spans full width
>8 scroll
optional continuation hint
```

SpacesBar height remains fixed.

---

## 25. Do not regress

Do not:

```text
store UI Color in Firestore
turn local hide into a Firestore write
show manager pencil to member
use UI role check as only security boundary
allow whole spaces/spacesBar document delete
allow >3 active messages
reintroduce pin/lifetime label without product decision
change 15 sec back to old values
shrink current six tiles without new layout decision
mass-rename Messenger internals to Spaces
```

---

## 26. New-chat startup checklist

New chat should first run:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Expected functional checkpoint before docs commit:

```text
branch = feat/v0.8.0-spaces-substitution-foundation
HEAD = 769544f
origin = 769544f
working tree = CLEAN
```

If these three docs are committed afterward, HEAD will be newer, but `769544f` remains the last functional checkpoint.

Then read:

```text
current source
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

No commit/push/deploy without explicit user approval.
