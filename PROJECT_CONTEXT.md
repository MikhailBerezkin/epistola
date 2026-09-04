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
123cda1 feat(spaces): add realtime spaces bar notifications
```

Предыдущие важные SpacesBar checkpoints:

```text
769544f feat(spaces): add spaces bar presentation and management
60966a6 feat(spaces): secure spaces bar board
```

Состояние после functional push:

```text
HEAD = 123cda1
origin/feat/v0.8.0-spaces-substitution-foundation = 123cda1
working tree = CLEAN
```

`v0.8.0` всё ещё находится в feature-ветке. Merge в `main` и release tag не считать выполненными без отдельного подтверждения Git-командами.

Последний стабильный release до v0.8.0:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

---

## 2. Проверки functional checkpoint 123cda1

Финальные Flutter-проверки после exact-target regression fix:

```text
flutter.bat test
→ 849 tests passed

flutter.bat analyze
→ No issues found

git diff --cached --check
→ clean
```

Во время полного Flutter suite может появляться диагностический вывод JPEG decoder:

```text
Corrupt JPEG data...
JPEG datastream contains no image
```

Если итог `All tests passed`, это не считать падением suite.

Последний записанный release APK checkpoint:

```text
flutter.bat build apk --release
→ SUCCESS
→ 57.5 MB
```

После финального exact-target fix свежий release APK был также собран, установлен на физический телефон и использован для ручной проверки exact-target; размер повторно не фиксировался в логе.

Cloud Functions:

```text
npm.cmd run test:spaces-bar-notification
→ 7/7 passed

npm.cmd run lint
→ no errors
→ только существующее предупреждение совместимости TypeScript/@typescript-eslint
```

Firestore Rules:

```text
SpacesBar targeted Rules suite → 22/22
Full Firestore Rules suite → 155/155
```

SpacesBar Rules задеплоены в production.

Cloud Function:

```text
sendSpacesBarNotification
region: europe-west1
runtime: Node.js 22
generation: 2nd Gen
status: deployed to production
```

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
git
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

Root Back behavior:

```text
Контакты → Back → Пространства
Профиль → Back → Пространства
Пространства → Back → выход
```

Messenger не удалён. Он открывается как отдельное внутреннее приложение:

```text
Пространства → Чаты → ChatsSpaceScreen → ChatsPage
```

Не выполнять массовый rename chat/Messenger internals только ради Spaces launcher.

Push navigation для SpacesBar использует временный `HomeScreen` route с `allowRoutePop: true`, чтобы push-route можно было снять со стека без изменения обычного root Back contract.

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

```text
2 columns
крупная tile
icon
title
subtitle where defined
```

### 7–8 active tiles

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

Использовать вертикальный scroll. Возможно добавить ненавязчивый visual hint, что ниже есть продолжение.

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

functions/src/spaces_bar_notification.ts
functions/src/index.ts
functions/test/spaces_bar_notification.test.cjs
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

## 11. Lifetime, expiry and presentation ordering

Lifetimes:

```text
1 hour
12 hours
24 hours
until cancelled
```

Expiry выводится из `createdAt + duration`; `untilCancelled` не имеет auto-expiry.

Актуальный presentation order после checkpoint `123cda1`:

```text
все visible active сообщения сортируются newest-first
lifetime НЕ определяет порядок
```

Comparator:

```text
createdAt descending
→ deterministic id/revision descending tie-breaker
```

Lifetime остаётся semantic expiry + visual accent, но не priority.

---

## 12. Realtime read path

`SpacesPage` больше не полагается только на one-shot reload.

Current flow:

```text
SpacesPage
→ SpacesBarPresentationService.watch(userId)
→ SpacesBarBoardFirestoreGateway.watch()
→ snapshots() одного документа spaces/spacesBar
```

Каждый board snapshot:

```text
→ загрузить current local hidden ids
→ resolve active messages
→ remove local hidden
→ newest-first order
→ emit SpacesBarPresentationState
```

Это даёт realtime sync между устройствами без per-message queries.

Publish/delete не требуют ручного reload для обновления основного SpacesBar — listener получает изменение автоматически.

Manual two-device verification passed:

```text
manager device publishes/deletes
→ member phone already open on Spaces
→ SpacesBar updates automatically
→ no re-enter / pull-to-refresh required
```

Новое объявление появляется первым сразу после realtime update.

---

## 13. Presentation states and carousel

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

Current implementation:

```text
finite PageView
каждое сообщение — отдельная card/page
```

Deferred presentation-only work:

```text
одно неподвижное внешнее окно SpacesBar
меняется только внутренний content
finite → cyclic/infinite swipe
fine-tune inward glow
```

---

## 14. Exact target behavior

`SpacesBarPanel` поддерживает:

```text
targetMessageId
```

При открытии по push panel должен показать именно requested message, даже если более новое сообщение уже существует.

Regression, найденный manual test:

```text
есть push №9
есть push №10
нажимаем push №9
раньше мог открыться №10 после realtime snapshot
```

Fix в checkpoint `123cda1`:

```text
explicit target имеет приоритет над newly-added realtime message,
пока пользователь остаётся на target message
```

После ручного swipe пользователя обычная carousel/realtime логика снова действует.

Regression widget test добавлен.

Manual verification passed:

```text
два одновременно висящих push
→ tap по более старому
→ открывается именно выбранное объявление
```

Local hide остаётся сильнее push-target: скрытое на данном устройстве сообщение push не должен насильно показывать.

---

## 15. Visual style

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

Карточка остаётся нейтральной.

Из message card намеренно убраны:

```text
pin icon
visible lifetime label
```

Lifetime остаётся в domain/editor и определяет expiry + border color.

---

## 16. Manager pencil and editor

Pencil:

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

## 17. Publish and global delete

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
```

Delete-only Firestore writes не должны запускать SpacesBar push.

---

## 18. Local hide — device-local by design

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

Один и тот же аккаунт может скрыть сообщение на телефоне, но видеть его в эмуляторе. Это ожидаемое поведение.

Hidden message остаётся authoritative active server message и виден manager editor, но не показывается в local presentation.

---

## 19. Firestore Rules

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

# PART IV — SPACESBAR PUSH

## 20. Typed push deep links

`PushDeepLinkRequest` теперь поддерживает target type:

```text
chat
spacesBar
```

SpacesBar remote payload:

```text
deepLinkType: spacesBar
spacesBarMessageId: <messageId>
```

Chat backward compatibility сохранена:

```text
legacy chatId payload still supported
typed chat payload supported
```

Local notification payload сериализуется typed JSON через `toLocalPayload()`.

Deduplication key type-aware:

```text
chat:<id>
spacesBar:<id>
```

---

## 21. Push coordinator / resolver / navigation

Coordinator:

```text
chat target
→ existing chat resolve/open flow

spacesBar target
→ no chat Firestore load
→ validate authenticated user
→ open Spaces route with target message id
```

Navigation:

```text
PushDeepLinkNavigation
→ HomeScreen(
     spacesBarTargetMessageId: messageId,
     allowRoutePop: true,
   )
```

Обычный root `HomeScreen` остаётся `allowRoutePop: false`.

Это разделяет root navigation и временный push route.

---

## 22. SpacesBar notification channel

Android channel:

```text
id: epistola_spaces_bar_v1
name: Объявления Epistola
importance: high
sound: seagull_notification
vibration enabled
pattern: [0, 250, 100, 250]
```

Foreground local notification для SpacesBar использует этот channel.

Background/system-rendered FCM notification также получает тот же channel id, sound и vibration timings.

---

## 23. Cloud Function sendSpacesBarNotification

Trigger:

```text
onDocumentWritten("spaces/spacesBar")
```

Helper:

```text
detectSpacesBarPublication(beforeData, afterData)
```

Push создаётся только когда write содержит ровно одно новое валидное сообщение.

Не считается публикацией:

```text
delete-only
update existing message
multi-add malformed write
malformed added message
```

Сценарий:

```text
one new message + expired old messages removed
```

считается одной корректной публикацией.

Recipients:

```text
collectionGroup("devices").get()
→ normalize/dedupe tokens
→ exclude all tokens belonging to createdByUserId
→ multicast chunks <= 500
→ cleanup invalid/unregistered FCM token documents
```

Для pilot 40–50 пользователей это принятный cost profile:

```text
1 collection-group devices read per SpacesBar publication
no per-recipient user document reads
```

Author exclusion идёт по `createdByUserId`, а не по роли, поэтому одинаково работает для `brigadier` и `owner`.

---

## 24. Production deploy and manual push verification

Function deployed:

```text
sendSpacesBarNotification(europe-west1)
Node.js 22
2nd Gen
```

Manual member verification on physical Android phone:

```text
new SpacesBar publication
→ push received
→ seagull sound
→ vibration
→ works with screen off
→ notification body contains announcement preview
→ tap opens Spaces
→ exact selected announcement shown
```

Ранее отсутствие vibration на Poco F6 оказалось настройкой конкретного телефона, а не ошибкой Epistola. На другом Android устройстве member push с выключенным экраном дал:

```text
push + seagull + vibration
```

Несколько одновременно висящих SpacesBar push вручную проверены: tap по старому push открывает его собственный message target, а не newest message.

Важно для backward compatibility:

```text
старые установленные версии Epistola,
которые ещё не знают SpacesBar,
могут всё равно получать новый FCM push,
потому что их device token зарегистрирован в backend.
```

Перед массовым rollout при необходимости добавить version/capability filtering. Для текущего pilot это не блокирует checkpoint.

---

# PART V — SUBSTITUTION FOUNDATION

## 25. "Список" / Substitution module

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

# PART VI — EXISTING MESSENGER FOUNDATIONS

## 26. Already completed areas

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

# PART VII — ROADMAP / NEXT CHAT

## 27. Completed SpacesBar block

Следующий блок из предыдущего handoff закрыт:

```text
realtime SpacesBar sync
newest-first ordering
SpacesBar push integration
typed deep links
exact message targeting
production Cloud Function deploy
physical-device manual verification
```

Functional checkpoint:

```text
123cda1 feat(spaces): add realtime spaces bar notifications
```

---

## 28. Deferred presentation work

Separate presentation-only stage:

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

## 29. Deferred Spaces Hub customization

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

## 30. Do not regress

Do not:

```text
store UI Color in Firestore
turn local hide into a Firestore write
show manager pencil to member
use UI role check as only security boundary
allow whole spaces/spacesBar document delete
allow >3 active messages
reintroduce lifetime ordering as presentation priority
reintroduce pin/lifetime label without product decision
change 15 sec without product decision
shrink current six tiles without new layout decision
mass-rename Messenger internals to Spaces
break legacy chat deep-link payload support
make SpacesBar push perform a chat Firestore lookup
let a newer realtime message override an explicit push target
```

---

## 31. New-chat startup checklist

New chat should first run:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Expected after functional push and before/after docs commit:

```text
branch = feat/v0.8.0-spaces-substitution-foundation
last functional checkpoint = 123cda1
working tree = CLEAN after docs are committed
```

После документационного commit HEAD будет новее `123cda1`, но `123cda1` остаётся last functional checkpoint.

Then read:

```text
current source
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Не начинать работу из `main` и не считать старые handoff-файлы более приоритетными, чем код текущей feature-ветки.

No commit/push/deploy without explicit user approval.
