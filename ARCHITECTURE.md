# Epistola — Architecture

Основной технический документ проекта Epistola.

При расхождении информации используется следующий приоритет:

```text
исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` — handoff текущего состояния.

`ARCHITECTURE.md` — устойчивые архитектурные решения и границы.

`README.md` — обзор проекта для быстрого знакомства.

## 1. Статус документа

| Параметр | Значение |
|---|---|
| Версия документа | `4.3` |
| Последний стабильный релиз | `v0.7.2` |
| Текущий release candidate | `v0.7.3 Messaging Feedback Foundation` |
| Текущая ветка | `feat/v0.7.3-messaging-feedback` |
| Functional HEAD | `60b3fef` |
| Состояние | функциональность завершена и отправлена в feature branch; release merge и tag ещё не созданы |
| Последнее обновление | август 2026 |

`v0.7.3` добавляет четыре независимые границы messaging feedback:

```text
active chat notification suppression
private read receipts
group message reactions
private typing indicator
```

Функциональные commits:

```text
f901c06 fix(chat): suppress active chat notifications
8228f9a feat(chat): add private read receipts
d10c110 feat(chat): add group message reactions
60b3fef feat(chat): add private typing indicator
```

## 2. Назначение проекта

Epistola — корпоративный мессенджер на Flutter и Firebase.

Краткосрочные цели:

- стабильное Android-приложение;
- пилотная группа 40–50 пользователей;
- контролируемые Firebase costs;
- небольшие проверяемые этапы;
- безопасные private и group chats;
- заменяемый UI;
- расширяемый media foundation;
- предсказуемая навигация;
- понятная история сообщений;
- realtime feedback без избыточных writes.

Долгосрочные цели:

- коммуникационная платформа на 600–700 сотрудников;
- задачи, объявления, документы и смены;
- внутренние приложения;
- корпоративные сервисы;
- возможный собственный backend.

Spaces не моделируются как обычный тип чата:

```text
Spaces → внутренние приложения Epistola
```

## 3. Инфраструктура

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Android package: com.epistola.app
Storage bucket: gs://epistola-434b7.firebasestorage.app
```

Realtime Database URL:

```text
https://epistola-434b7-default-rtdb.europe-west1.firebasedatabase.app
```

Используются:

```text
Firebase Authentication
Cloud Firestore
Realtime Database
Security Rules
Cloud Storage
Cloud Messaging
Cloud Functions
```

Infrastructure configuration не должна находиться в UI или domain layer.

## 4. Архитектурные слои

```text
Flutter UI
    ↓
Presentation / Controllers
    ↓
Application Services
    ↓
Domain Models and Contracts
    ↓
Infrastructure Gateways / Adapters
    ↓
Firebase
```

Правила:

- верхний слой зависит от нижнего контракта;
- нижний слой не зависит от UI;
- domain не зависит от Flutter и Firebase;
- navigation adapter может зависеть от Flutter, но не переносит Firebase business logic в widgets;
- временное UI-состояние не должно создавать лишние backend reads;
- локальная optimistic presentation не заменяет server-side security;
- ephemeral presence не хранится в Firestore;
- security-sensitive access projection создаётся только trusted server code.

### 4.1 Flutter UI

Отвечает за отображение, пользовательские события, progress, retry, локальное состояние и navigation.

UI не должен:

- обращаться к Storage напрямую;
- выполнять Firestore transactions без application service;
- выдавать upload grants;
- вычислять permissions;
- формировать canonical media paths;
- выполнять remote rollback;
- содержать compression policy;
- доверять `chatId` из notification без resolver;
- самостоятельно создавать RTDB access grants;
- писать typing state другого пользователя.

### 4.2 Presentation

Преобразует backend/domain state в UI-модели.

Ключевые модели:

```text
MessagePresentation
MessageVisibilityState
PrivateReadCursor
GroupMessageReaction
```

Presentation flows:

```text
message.createdAt
→ ChatDateFormatter
→ ChatDateSeparator / ChatScrollDateIndicator
```

```text
peer privateReadState
→ PrivateReadCursorMapper
→ PrivateReadCursorResolver
→ PrivateReadReceiptIndicator
```

```text
message.reactions
→ GroupMessageReactionMapper
→ GroupMessageReactionBar
```

```text
peer RTDB timestamp
→ freshness validation
→ ChatAppBar subtitle
```

### 4.3 Application Services

Оркестрируют use case: validation, ordering, transactions, debounce, upload, atomic write, rollback, cleanup и errors.

Примеры:

```text
ExistingImageMessageSendService
FirstPrivateImageMessageSendService
PrivateReadReceiptService
PrivateReadReceiptDebouncer
GroupMessageReactionService
PrivateTypingService
PrivateTypingCoordinator
PushDeepLinkCoordinator
PushDeepLinkResolver
ChatMessagesService
```

### 4.4 Domain и helpers

Независимые правила и модели:

```text
MessageType
MessageContent
MessagePreview
MessagePushRepresentation
ImageMessageMetadata
ImageMessageLimits
ImageMessageSendState
ImageMessageDeletionPolicy
MediaAsset
UserAvatar
GroupAvatar
PushDeepLinkRequest
ChatDateFormatter
PrivateReadCursor
GroupMessageReaction
```

`PrivateReadCursor` содержит только monotonic cursor semantics и не зависит от Flutter/Firebase.

`GroupMessageReaction.resolveTap` задаёт XOR-подобное состояние `none | like | dislike`.

### 4.5 Infrastructure

Реализует contracts через Firebase:

```text
FirebaseImageMessageStorageAdapter
FirebaseMediaStorageProvider
Firestore gateways
Cloud Functions callable gateway
PushDeepLinkResolver.firebase()
PrivateReadReceiptService.firebase()
GroupMessageReactionService.firebase()
PrivateTypingService.firebase()
```

## 5. Структура проекта

```text
lib/
├── domain/
│   └── models/
├── helpers/
├── models/
├── screens/
├── services/
│   ├── avatar/
│   ├── chat/
│   ├── media/
│   └── push/
├── theme/
├── widgets/
│   └── chat/
├── firebase_options.dart
└── main.dart

functions/
└── src/
    └── index.ts

test/
├── domain/
├── helpers/
├── models/
├── rules/
│   ├── database/
│   ├── firestore/
│   └── storage/
├── services/
└── widgets/
    └── chat/
```

Ключевые файлы `v0.7.3`:

```text
lib/domain/models/private_read_cursor.dart
lib/domain/models/group_message_reaction.dart

lib/services/chat/active_chat_tracker.dart
lib/services/chat/private_read_cursor_mapper.dart
lib/services/chat/private_read_cursor_resolver.dart
lib/services/chat/private_read_receipt_debouncer.dart
lib/services/chat/private_read_receipt_service.dart
lib/services/chat/group_message_reaction_mapper.dart
lib/services/chat/group_message_reaction_service.dart
lib/services/chat/private_typing_service.dart
lib/services/chat/private_typing_coordinator.dart

lib/widgets/chat/private_read_receipt_indicator.dart
lib/widgets/chat/group_message_reaction_bar.dart
lib/widgets/chat/chat_app_bar.dart

lib/screens/chat_screen.dart
lib/widgets/messages_list.dart
lib/widgets/message_item.dart
lib/widgets/message_bubble.dart
lib/services/notification_service.dart

functions/src/index.ts
firestore.rules
database.rules.json
firebase.json
```

## 6. Пользовательская идентичность

```text
FirebaseAuth.currentUser.uid
==
users/{uid}
```

Firebase UID является главным application identifier.

Один UID используется как ключ:

```text
chat membership
privateReadState
message reactions
privateTyping
privateChatAccess
```

## 7. Chat architecture

`ChatService` исторически является facade. Внутренние обязанности разделены:

```text
ChatBaseService
ChatMessagesService
ChatPrivateService
ChatGroupsService
ChatMembersService
ChatPermissionsService
ChatSearchService
ChatPeerResolver
ChatPeerUserCache
```

Private chat использует deterministic canonical ID. Выбор пользователя и выход назад не создают chat. Chat создаётся только после успешного первого сообщения.

Group chat содержит title, members, roles, permissions, metadata и optional avatar.

## 8. Message model и история

Поддерживаемые типы:

```text
text
image
```

Pagination invariants:

- page size 20;
- merge по document ID;
- chronological order;
- сохранение scroll position;
- realtime не удаляет старые страницы;
- один page request одновременно;
- near-bottom-only autoscroll.

Logical deletion:

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

Delete for everyone доступен только sender. Firestore document физически не удаляется.

### 8.1 Local history cache

`MessagesList` объединяет realtime snapshot последних сообщений и ранее загруженные страницы в:

```text
Map<messageId, QueryDocumentSnapshot>
```

Для успешного удаления старого сообщения используется локальный set:

```text
Set<String> locallyHiddenMessageIds
```

Это presentation optimization, а не security boundary.

## 9. Active Chat Notification Suppression

### 9.1 Active route tracking

Singleton:

```text
activeChatTracker
```

`ChatScreen` регистрирует route:

```text
initState → activeChatTracker.enter(chatId)
dispose → activeChatTracker.leave(registration)
```

Tracker использует registration identity, поэтому вложенные и повторные регистрации одного chat ID корректно восстанавливают предыдущий active route.

### 9.2 Notification decision

```text
foreground RemoteMessage
→ PushDeepLinkRequest.fromRemoteData
→ activeChatTracker.isCurrent(chatId)
```

Результат:

```text
same active chat → do not show local notification
another chat → show local notification
```

Это presentation decision. Cloud Function и FCM delivery не отключаются. Background/terminated flow сохраняется.

## 10. Private Read Receipt Foundation

### 10.1 Data model

В private chat document:

```text
privateReadState: {
  uid: {
    messageId: string,
    messageCreatedAt: timestamp,
    readAt: timestamp
  }
}
```

Legacy/общий `lastRead` обновляется совместно для совместимости chat list unread state.

### 10.2 Cursor semantics

`PrivateReadCursor`:

- требует непустой `messageId` без `/`;
- хранит UTC `messageCreatedAt`;
- определяет, покрывает ли cursor конкретное сообщение;
- не разрешает логический откат назад;
- при одинаковом timestamp требует совпадение `messageId`.

### 10.3 Read detection

```text
visible sorted messages
→ select latest eligible cursor
→ PrivateReadReceiptDebouncer.schedule(cursor)
→ debounce
→ PrivateReadReceiptService.markRead
```

При выходе:

```text
flushNow
→ final read write best-effort
→ route pop
```

### 10.4 Sender UI

```text
outgoing private message
→ peer cursor does not cover message → ✓
→ peer cursor covers message → ✓✓
```

Групповые сообщения не получают read receipt indicator.

### 10.5 Firestore security

Rules проверяют:

- authenticated member;
- private chat type;
- неизменность member IDs;
- изменение только собственного UID;
- обязательные keys `messageId`, `messageCreatedAt`, `readAt`;
- существование message document;
- совпадение message timestamp;
- `readAt == request.time`;
- monotonic progression.

## 11. Group Message Reactions

### 11.1 Data model

В message document:

```text
reactions: {
  uid: "like" | "dislike"
}
```

Отсутствие ключа означает `none`.

### 11.2 Domain transition

```text
current == tapped → remove reaction
current != tapped → set tapped reaction
```

Это гарантирует только одно значение на UID.

### 11.3 Transaction

`GroupMessageReactionService`:

```text
read message in Firestore transaction
→ map current reactions
→ resolve next state
→ update reactions.{uid}
```

Удаление реакции использует `FieldValue.delete()`.

### 11.4 UI

`GroupMessageReactionBar` отображает:

```text
👍 count
👎 count
```

Выбранная текущим пользователем реакция выделяется. Private chats не включают reaction layer.

### 11.5 Firestore security

Rules разрешают update только если:

- пользователь является участником группы;
- chat type — `group`;
- сообщение не удалено для всех;
- affected key сообщения — только `reactions`;
- affected key map — только текущий UID;
- новое значение отсутствует, `like` или `dislike`.

Reaction update не изменяет chat preview и не создаёт push.

## 12. Private Typing Indicator Foundation

### 12.1 Почему Realtime Database

Typing state является ephemeral presence data:

- высокая частота;
- короткий TTL;
- не требуется history;
- нужен `onDisconnect`;
- Firestore writes для каждого heartbeat нежелательны.

Поэтому typing state хранится только в Realtime Database.

### 12.2 Paths

```text
privateChatAccess/{chatId}/{uid} = true
privateTyping/{chatId}/{uid} = timestamp
```

`privateChatAccess` — server-owned projection. Client не может создавать или изменять access nodes.

### 12.3 Callable access projection

Cloud Function:

```text
ensurePrivateTypingAccess
```

Алгоритм:

```text
auth required
→ validate chatId
→ read chats/{chatId} from Firestore
→ require type == private
→ require isDissolved != true
→ require exactly two valid unique members
→ require caller membership
→ write privateChatAccess/{chatId}
```

Access projection содержит только двух участников private chat.

### 12.4 Client service

`PrivateTypingService`:

- вызывает `ensurePrivateTypingAccess` один раз на session;
- регистрирует `onDisconnect().remove()`;
- пишет `ServerValue.timestamp` только в собственный path;
- удаляет собственный state при stop;
- слушает точный peer path;
- валидирует RTDB identifiers;
- предоставляет injectable delegates для unit tests.

### 12.5 Coordinator timing

`PrivateTypingCoordinator`:

```text
initial debounce: 450 ms
heartbeat: 3 s
inactivity stop: 4 s
```

Operation queue сериализует writes и предотвращает race между start/heartbeat/stop.

Immediate stop вызывается при:

```text
controller becomes empty
text send
image send success
leave chat
dispose
```

### 12.6 Peer freshness

`ChatScreen` принимает timestamp только если он:

- numeric;
- не находится более чем примерно на 10 секунд в будущем;
- моложе 6 секунд.

Локальный expiry timer скрывает stale state даже при задержке сетевого `onDisconnect`.

### 12.7 Header presentation

Private chat:

```text
peer typing → Пишет...
otherwise → личный чат
```

Group chat:

```text
N участников
```

Typing flow в группах не запускается.

### 12.8 RTDB security

Rules:

- `.read` typing data только для UID с `privateChatAccess == true`;
- client не читает и не пишет access projection;
- пользователь пишет только `privateTyping/{chatId}/{auth.uid}`;
- значение — numeric server-like timestamp;
- удаление собственного state разрешено;
- запись чужого UID запрещена.

## 13. Chat Date Separator Foundation

`ChatDateFormatter` поддерживает:

```text
same calendar day as now → Сегодня
previous calendar day → Вчера
same year → 3 августа
different year → 28 декабря 2025
```

Разделитель показывается перед первым видимым сообщением календарного дня. Floating indicator вычисляется по реальным RenderBox positions и поддерживает элементы переменной высоты.

## 14. Image Message Foundation

Согласованная пара:

```text
thumbnail
full
```

Canonical paths:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

```text
thumbnail: max 128 KB, max side 480 px
full: target 512 KB, absolute max 1 MB, max side 1920 px
```

First private image upload защищён `createFirstPrivateImageUploadGrant`. Chat, message и preview записываются атомарно. Partial uploads очищаются best-effort.

## 15. Avatar architecture

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Replacement:

```text
prepare new version
→ upload
→ atomic metadata update
→ best-effort old version cleanup
```

Cache key: `path@version`.

## 16. Push architecture

Cloud Function:

```text
sendMessageNotification
```

Trigger:

```text
chats/{chatId}/messages/{messageId}
```

Функция исключает sender, определяет recipients, получает tokens, формирует title/body, добавляет `data.chatId`, отправляет FCM и удаляет невалидные tokens.

```text
text → текст
image → Фотография
```

Deep link flow:

```text
RemoteMessage.data или local payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkDestination
→ PushDeepLinkNavigation
→ ChatScreen
```

Notification payload считается недоверенным. Firestore Rules остаются последней server-side защитой.

## 17. Android Toolchain Foundation

```text
Flutter: 3.44.1
Dart: 3.12.1
Java: 21.0.10
Gradle: 9.1.0
AGP: 9.0.1
Kotlin: 2.3.20
Google Services Plugin: 4.3.15
compileSdk: 36
targetSdk: 36
minSdk: 24
JVM target: 17
```

```text
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
```

Built-in Kotlin warning относится к plugin internals и не блокирует release APK.

## 18. Testing strategy

### 18.1 Flutter

```text
flutter.bat analyze → No issues found
flutter.bat test → 535 passed
flutter.bat build apk --release → 55.7 MB
```

### 18.2 Security Rules

```text
Realtime Database Rules → 15 passed
Firestore Rules → 53 passed
Storage Rules → 42 passed
Total → 110 passed
```

### 18.3 Functions

```text
npm lint → passed
TypeScript build → passed
```

Существующее предупреждение TypeScript/ESLint version compatibility не блокирует build и не изменяется внутри feature release.

### 18.4 Manual Android scenarios

Проверены:

- push не показывается поверх открытого целевого чата;
- push другого чата показывается;
- private `✓` и `✓✓` работают;
- group `👍`/`👎` переключаются по одному значению на UID;
- private `Пишет...` работает в обоих направлениях;
- typing исчезает после idle, clear, send, leave и force close;
- typing не появляется в group chat.

### 18.5 Diagnostic JPEG output

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это ожидаемый вывод тестов повреждённых JPEG, а не падение suite.

## 19. Cost model

### Read receipts

- cursor writes объединяются debounce;
- нет write на каждое отображённое сообщение;
- peer UI читает chat document, который уже нужен экрану.

### Reactions

- один transaction на пользовательский toggle;
- counters вычисляются из уже загруженного message snapshot;
- push не создаётся.

### Typing

- ephemeral writes находятся в RTDB, не Firestore;
- initial debounce предотвращает write при коротком случайном вводе;
- heartbeat ограничен 3 секундами;
- listener подписан только на одного peer;
- access projection создаётся callable-функцией и переиспользуется.

## 20. Security boundaries

Сохранены:

```text
auth
membership
role permissions
sender-only delete for everyone
private clear isolation
canonical image paths
upload grants
push payload validation
private read cursor ownership
group reaction UID ownership
server-owned typing access projection
own typing node only
```

UI state, optimistic updates, local active-chat tracking и timestamp freshness не являются server-side authorization.

## 21. Generated files policy

После последней серии Flutter-команд один раз восстанавливаются:

```powershell
git restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugins.cmake
```

`pubspec.yaml`, `pubspec.lock`, Firebase options и Android Google Services config не восстанавливаются, если их изменения требуются feature.

## 22. Известные ограничения

- Group image sending не завершён как отдельный foundation.
- Caption к изображению отсутствует.
- File и voice messages отсутствуют.
- Единая clickable avatar/profile card navigation реализована не во всех точках.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Release signing требует отдельной production-настройки.

## 23. Следующие архитектурные этапы

```text
Attachment Composer Foundation
→ Image Caption
→ File Message Foundation
→ Voice Message Foundation
```

Attachment composer должен создать единый draft contract для media/file payload и optional caption. Временный отдельный hack только для подписи к фотографии не допускается.

Отдельно планируется:

```text
Clickable Avatar and Profile Card Foundation
Retention Cleanup
App Check
Production Hardening
```

## 24. Release gate v0.7.3

До merge в `main` требуется:

```text
functional commits pushed
→ documentation updated
→ docs commit pushed
→ feature branch clean
→ merge into main
→ tag v0.7.3
→ push main and tag
```

Release merge commit и финальный documentation commit должны быть внесены в документы после их создания.
