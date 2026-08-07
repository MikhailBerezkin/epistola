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

`ARCHITECTURE.md` — устойчивые архитектурные решения, contracts, data flow и security boundaries.

`README.md` — обзор проекта для быстрого знакомства.

## 1. Статус документа

| Параметр | Значение |
|---|---|
| Версия документа | `4.4` |
| Текущий release | `v0.7.4` |
| Release merge commit | `d91270c` |
| Feature commit | `526504c` |
| Post-merge architecture cleanup | `730bab0` |
| Последний завершённый этап | `Avatar Interaction/Card + Notification Controls Foundation` |
| Основная ветка | `main` |
| Последнее обновление | август 2026 |

`v0.7.4` добавляет две связанные, но архитектурно разделённые возможности:

```text
Chat Identity Card Foundation
Per-chat Notification Controls
```

Дополнительно release содержит Android notification sound/vibration hardening.

Финальный кодовый HEAD перед документацией:

```text
730bab0 refactor(chat): move notification settings out of domain
```

Архитектурный cleanup выполнен после release merge, потому что `ChatNotificationSettings` использует Firestore `Timestamp` для persistence mapping и поэтому не должен находиться в pure domain.

## 2. Назначение проекта

Epistola — корпоративный мессенджер на Flutter и Firebase.

Краткосрочные цели:

- стабильное Android-приложение;
- пилотная группа 40–50 пользователей;
- контролируемые Firebase costs;
- небольшие проверяемые этапы;
- безопасные private/group chats;
- заменяемый UI;
- расширяемый media foundation;
- предсказуемая навигация;
- realtime feedback без избыточных backend operations.

Долгосрочные цели:

- коммуникационная платформа на 600–700 сотрудников;
- задачи;
- объявления;
- документы;
- рабочие смены;
- внутренние приложения;
- корпоративные сервисы;
- возможный собственный backend.

Spaces:

```text
Spaces → внутренние приложения Epistola
```

Spaces не моделируются как обычный chat type.

## 3. Infrastructure

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

Infrastructure configuration не должна находиться в UI или pure domain layer.

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

Основные правила:

- верхний слой зависит от нижнего contract;
- нижний слой не зависит от UI;
- pure domain не зависит от Flutter и Firebase;
- Firebase-aware persistence models могут находиться в `lib/models`;
- navigation adapter может зависеть от Flutter, но не переносит Firebase business logic в widgets;
- временное UI-state не должно создавать лишние backend reads;
- optimistic presentation не заменяет server-side security;
- ephemeral presence не хранится в Firestore;
- security-sensitive access projection создаётся только trusted server code;
- permissions не выводятся из внешнего вида UI;
- notification payload считается недоверенным.

### 4.1 Flutter UI

Отвечает за:

- rendering;
- gestures;
- progress;
- retry;
- локальное состояние;
- modal sheets;
- overlay state;
- navigation.

UI не должен:

- обращаться к Storage напрямую;
- выдавать upload grants;
- формировать canonical media paths;
- выполнять remote rollback;
- содержать compression policy;
- выполнять security-sensitive Firestore transaction без application service;
- доверять `chatId` из push без resolver;
- создавать RTDB access projection;
- изменять notification settings другого UID.

### 4.2 Presentation

Преобразует backend/application state в UI.

Ключевые presentation flows:

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

```text
chat document
→ ChatNotificationSettings.fromChatData
→ effective notification mode
→ identity-card action state
```

```text
chat/user avatar metadata
→ ChatIdentityBackground
→ full image / legacy URL / initials fallback
```

### 4.3 Application Services

Оркестрируют validation, ordering, transactions, debounce, upload, atomic write, rollback, cleanup и errors.

Примеры:

```text
ExistingImageMessageSendService
FirstPrivateImageMessageSendService
PrivateReadReceiptService
PrivateReadReceiptDebouncer
GroupMessageReactionService
PrivateTypingService
PrivateTypingCoordinator
ChatNotificationSettingsService
PushDeepLinkCoordinator
PushDeepLinkResolver
ChatMessagesService
```

### 4.4 Domain

Pure domain:

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

`PrivateReadCursor` хранит monotonic cursor semantics и не зависит от Flutter/Firebase.

`GroupMessageReaction.resolveTap` задаёт взаимоисключающее состояние:

```text
none
like
dislike
```

### 4.5 Firebase-aware application models

`ChatNotificationSettings` находится в:

```text
lib/models/chat_notification_settings.dart
```

Причина:

```text
toFirestore()
fromChatData()
Firestore Timestamp
```

Это persistence-aware model, а не pure domain object.

Перенос из `lib/domain/models` выполнен отдельным cleanup commit:

```text
730bab0 refactor(chat): move notification settings out of domain
```

### 4.6 Infrastructure

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
ChatNotificationSettingsService.firebase()
```

## 5. Структура проекта

```text
lib/
├── domain/
│   └── models/
├── helpers/
├── models/
│   └── chat_notification_settings.dart
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
```

Ключевые файлы v0.7.4:

```text
lib/models/chat_notification_settings.dart
lib/services/chat/chat_notification_settings_service.dart
lib/services/notification_service.dart

lib/widgets/chat/chat_identity_action_button.dart
lib/widgets/chat/chat_identity_background.dart
lib/widgets/chat/chat_identity_card_content.dart
lib/widgets/chat/chat_identity_overlay.dart
lib/widgets/chat/chat_notification_settings_sheet.dart

lib/widgets/chat/chat_app_bar.dart
lib/widgets/chat_app_bar_title.dart
lib/screens/chat_screen.dart
lib/screens/group_info_screen.dart

android/app/src/main/AndroidManifest.xml
android/app/src/main/res/raw/seagull_notification.mp3
android/app/src/main/res/raw/epistola_keep.xml

functions/src/index.ts
firestore.rules

test/rules/firestore/chat_notification_settings_rules.test.mjs
test/services/chat/chat_notification_settings_service_test.dart
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
notificationSettingsByUser
```

## 7. Chat architecture

`ChatService` исторически является facade.

Внутренние обязанности разделены:

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

Private chat использует deterministic canonical ID.

Выбор пользователя и выход назад не создают chat.

Chat создаётся только после успешного первого сообщения.

Group chat содержит:

```text
title
members
roles
permissions
metadata
optional avatar
notificationSettingsByUser
```

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

Delete for everyone доступен только sender.

Firestore message document физически не удаляется.

### 8.1 Local history cache

`MessagesList` объединяет realtime snapshot и ранее загруженные страницы по message ID.

Для немедленного UI-скрытия успешно удалённого старого сообщения используется локальное presentation state.

Это optimization, а не security boundary.

## 9. Chat Identity Card Foundation — v0.7.4

### 9.1 Scope

Identity-card foundation подключён к шапке открытого:

```text
private chat
group chat
```

Он пока не является глобальной avatar-card системой для всех списков приложения.

### 9.2 Entry point

`ChatAppBarTitle` получает optional `onTap`.

При наличии callback:

- весь title area становится `InkWell`;
- `Semantics.button == true`;
- accessibility label: `Открыть информацию о чате`.

Flow:

```text
ChatAppBarTitle
→ onIdentityTap
→ ChatScreen._openIdentityOverlay()
```

### 9.3 Overlay mechanics

`ChatIdentityOverlay`:

```text
heightFactor: 0.64
animation: 340 ms
curve: easeOutCubic
bottom radius: 28
scrim alpha: 0.16
```

Structure:

```text
Stack
├── chat Scaffold
└── ChatIdentityOverlay
    ├── dim scrim
    └── animated top panel
```

Panel закрывается:

```text
tap outside
back arrow
system Back
```

`PopScope` сначала закрывает identity overlay и только следующий Back запускает leave-chat lifecycle.

Overlay является локальным presentation state и не создаёт новый chat route.

### 9.4 Preserving chat state

Overlay располагается поверх существующего `Scaffold`.

Поэтому при открытии/закрытии:

- message list не заменяется отдельным screen;
- draft controller остаётся тем же;
- текущий chat document listener остаётся тем же;
- scroll state не должен сбрасываться из-за отдельной navigation route.

### 9.5 Identity source

`ChatScreen` уже имеет один top-level:

```text
StreamBuilder<DocumentSnapshot>
chats/{chatId}
```

Из этого snapshot выводятся:

- chat type;
- group name;
- member count;
- roles;
- group avatar;
- notification settings.

Для private identity используются данные `peerUser`, уже переданные/разрешённые для экрана.

Foundation не добавляет второй Firestore listener только ради карточки.

### 9.6 Avatar background

`ChatIdentityBackground` использует path-first strategy:

```text
storagePath + version
→ AvatarImageLoader
→ Image.memory
```

Для legacy data:

```text
imageUrl
→ CachedNetworkImage
```

При отсутствии/ошибке изображения:

```text
stableKey
→ stable palette
→ initials
→ gradient fallback
```

Full avatar отображается с:

```text
BoxFit.cover
```

Поверх фона применяется вертикальный gradient для читаемости текста.

### 9.7 Private card data

Private identity:

```text
title = peer name / chat fallback
details:
  about
  phone
```

Пустые details не отображаются.

### 9.8 Group card data

Group identity:

```text
title = group name
details:
  localized member count
```

### 9.9 Actions

Общие:

```text
Уведомления
```

Group-only:

```text
Участники
```

Admin/owner group-only:

```text
Управление
```

Owner priority сохраняется.

### 9.10 Group navigation

`Участники`:

```text
GroupInfoScreen(
  chatId,
  membersOnly: true
)
```

`membersOnly` screen не дублирует management controls и показывает только `GroupMembersSection`.

`Управление` открывает обычный `GroupInfoScreen`.

### 9.11 Out-of-scope avatar contexts

Отдельная будущая подфаза должна унифицировать:

```text
chat list
chat search
contacts
user search / new message
create group
add members
group member list
group member screen
profile and other avatar contexts
```

## 10. Per-chat Notification Settings — v0.7.4

### 10.1 Data model

В chat document:

```text
notificationSettingsByUser: {
  uid: {
    mode: "sound"
  }
}
```

или:

```text
notificationSettingsByUser: {
  uid: {
    mode: "disabled"
  }
}
```

или temporary silent:

```text
notificationSettingsByUser: {
  uid: {
    mode: "silent",
    expiresAt: timestamp
  }
}
```

или permanent silent:

```text
notificationSettingsByUser: {
  uid: {
    mode: "silent",
    permanent: true
  }
}
```

### 10.2 Effective mode

Client и server используют безопасный fallback:

```text
missing settings
malformed settings
unknown mode
expired silent
→ sound
```

`disabled` всегда остаётся `disabled`.

`silent` effective только если:

```text
permanent == true
OR
expiresAt > now
```

### 10.3 Application model

`ChatNotificationSettings`:

- enum `sound | silent | disabled`;
- `sound()`;
- `disabled()`;
- `silentForever()`;
- `silentUntil(DateTime)`;
- `effectiveModeAt(now)`;
- `toFirestore()`;
- `fromChatData()`.

### 10.4 Service

`ChatNotificationSettingsService`:

```text
enableSound
disableNotifications
silenceForever
silenceFor
```

Application maximum temporary silence:

```text
24 hours
```

Identifiers:

- must be non-empty;
- must not contain `/`.

Unauthenticated write returns:

```text
skippedUnauthenticated
```

Firebase implementation обновляет только:

```text
notificationSettingsByUser.{currentUid}
```

### 10.5 UI

`ChatNotificationSettingsSheet`:

```text
Со звуком
Без звука
Отключить уведомления
Звук уведомлений
```

Silent submenu:

```text
На 1 час
На 24 часа
Навсегда
```

`Звук уведомлений` пока закрывает sheet и показывает:

```text
Пока в разработке
```

UI не является source of truth для permissions.

### 10.6 Firestore security

`isOwnNotificationSettingsUpdate()` требует:

- signed-in user;
- current membership;
- change только `notificationSettingsByUser`;
- изменение внутри map только текущего UID;
- допустимый mode;
- точную schema каждого mode.

Даже admin/owner не может использовать широкий group-admin update path для изменения:

```text
notificationSettingsByUser
```

другого пользователя.

Rules tests проверяют:

- sound;
- disabled;
- 1-hour silent;
- 24-hour silent;
- permanent silent;
- foreign private member denial;
- group admin changing another member denial;
- unknown mode denial;
- malformed permanent silent denial;
- expired silent denial;
- overlong temporary silent denial;
- notification settings + unrelated chat field denial.

### 10.7 Cost boundary

Notification settings читаются из уже загруженного chat document.

В `ChatScreen` не создаётся дополнительный listener только ради notification settings.

Write выполняется только при явном выборе пользователем.

## 11. Push delivery architecture — v0.7.4

### 11.1 Trigger

Cloud Function:

```text
sendMessageNotification
```

Trigger:

```text
chats/{chatId}/messages/{messageId}
```

### 11.2 Recipient resolution

```text
read chat
→ validate memberIds
→ exclude sender
→ resolve mode for each recipient
```

### 11.3 Disabled optimization

Для:

```text
mode == disabled
```

recipient исключается **до** чтения:

```text
users/{uid}/devices
```

Это одновременно semantic и cost optimization.

Если все recipients disabled:

```text
return before device reads
```

### 11.4 Device tokens

Только sound/silent recipients получают device query.

Token document:

```text
token
mode
reference
```

Invalid tokens удаляются после FCM response.

### 11.5 Batching

FCM limit:

```text
500 tokens per multicast batch
```

Tokens сначала разделяются по mode:

```text
sound
silent
```

После этого каждая группа chunked по 500.

### 11.6 Payload

Общие поля:

```text
notification.title
notification.body
data.chatId
data.notificationMode
android.priority = high
```

Sound delivery:

```text
channelId = epistola_messages_seagull_v3
sound = seagull_notification
vibrateTimingsMillis = [0, 250, 100, 250]
```

Silent delivery:

```text
channelId = epistola_messages_silent
no explicit sound
no explicit vibration pattern
```

### 11.7 Preview

```text
text → normalized text preview
image → Фотография
```

Logical deletion update не создаёт новый message document и поэтому не должен повторно запускать create-trigger.

## 12. Android notification channels

### 12.1 Sound channel

```text
ID:
epistola_messages_seagull_v3

Name:
Сообщения Epistola — Чайка
```

Settings:

```text
Importance.high
playSound = true
RawResourceAndroidNotificationSound("seagull_notification")
enableVibration = true
vibrationPattern = [0, 250, 100, 250]
```

### 12.2 Silent channel

```text
ID:
epistola_messages_silent

Name:
Тихие сообщения Epistola
```

Settings:

```text
Importance.high
playSound = false
enableVibration = false
```

### 12.3 Channel immutability

Android notification channel configuration является системно сохраняемым состоянием.

Изменение sound/vibration policy существующего channel ID не считается надёжным способом миграции.

Поэтому при разработке custom sound был создан новый sound channel ID:

```text
epistola_messages_seagull_v3
```

### 12.4 Manifest fallback

`AndroidManifest.xml`:

```text
com.google.firebase.messaging.default_notification_channel_id
→ epistola_messages_seagull_v3
```

Это fallback для FCM notification, если payload не задаёт иной channel.

### 12.5 Raw resource

```text
android/app/src/main/res/raw/seagull_notification.mp3
```

Resource name без extension в Android API:

```text
seagull_notification
```

### 12.6 Resource shrink protection

```text
android/app/src/main/res/raw/epistola_keep.xml
```

содержит:

```text
@raw/seagull_notification
@mipmap/ic_launcher
```

Это предотвращает удаление runtime-referenced resources release shrinker-ом.

## 13. Foreground and active-chat notification behavior

### 13.1 FCM foreground

```text
FirebaseMessaging.onMessage
→ NotificationService.showForegroundMessage
```

Если payload содержит текущий active chat:

```text
activeChatTracker.isCurrent(chatId)
→ return
```

Local push не показывается.

### 13.2 Foreground another chat

Sound:

```text
flutter_local_notifications
→ sound channel
→ seagull sound
→ vibration enabled
→ explicit short Vibration.vibrate()
```

Silent:

```text
flutter_local_notifications
→ silent channel
→ no sound
→ no vibration
```

### 13.3 Open target chat in-chat vibration

`ChatScreen` имеет listener последнего сообщения.

Для нового incoming message:

```text
effective notification mode == sound
→ NotificationService.vibrate()
```

Для:

```text
silent
disabled
```

direct vibration пропускается.

Это специально отделено от local notification, потому что local push текущего active chat подавляется.

## 14. Active Chat Notification Suppression — v0.7.3

Singleton:

```text
activeChatTracker
```

Lifecycle:

```text
ChatScreen.initState
→ enter(chatId)

ChatScreen.dispose
→ leave(registration)
```

Registration identity корректно обрабатывает повторные/вложенные route registrations.

## 15. Private Read Receipt Foundation

Data:

```text
privateReadState: {
  uid: {
    messageId
    messageCreatedAt
    readAt
  }
}
```

`lastRead` обновляется совместно для unread list compatibility.

Cursor requirements:

- valid message ID;
- UTC timestamp;
- no backward movement;
- existing message validation;
- createdAt match;
- own UID only.

Sender UI:

```text
peer cursor not covering message → ✓
peer cursor covering message → ✓✓
```

Только private chats.

## 16. Group Message Reactions

Data:

```text
reactions: {
  uid: "like" | "dislike"
}
```

Transition:

```text
current == tapped → remove
current != tapped → replace with tapped
```

Rules:

- group only;
- active member;
- own UID only;
- message not deleted for everyone;
- no unrelated message mutation.

Reaction update не меняет chat preview и не создаёт push.

## 17. Private Typing Indicator

Typing state является ephemeral presence data и хранится в Realtime Database.

Paths:

```text
privateChatAccess/{chatId}/{uid} = true
privateTyping/{chatId}/{uid} = timestamp
```

Server-owned access projection создаёт:

```text
ensurePrivateTypingAccess
```

Coordinator timing:

```text
initial debounce: 450 ms
heartbeat: 3 s
inactivity stop: 4 s
peer freshness: 6 s
```

Header presentation:

```text
typing → "<peer> пишет…"
fallback without effective peer name → "Пишет…"
otherwise → "личный чат"
```

Group typing flow не запускается.

## 18. Chat Date Separator Foundation

```text
same calendar day → Сегодня
previous calendar day → Вчера
same year → 3 августа
different year → 28 декабря 2025
```

Floating indicator вычисляется по реальным RenderBox positions.

## 19. Image Message Foundation

Pair:

```text
thumbnail
full
```

Canonical paths:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Limits:

```text
thumbnail: max 128 KB, max side 480 px
full: target 512 KB, absolute max 1 MB, max side 1920 px
```

First private image защищён trusted upload grant.

Chat, message и preview записываются атомарно.

Partial upload cleanup — best-effort.

## 20. Avatar architecture

Paths:

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

Cache key:

```text
path@version
```

Identity-card использует существующий full-avatar pipeline, а не отдельную media architecture.

## 21. Push deep-link architecture

```text
RemoteMessage.data / local payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkDestination
→ PushDeepLinkNavigation
→ ChatScreen
```

Notification payload не является authorization proof.

Membership/security проверяется downstream.

## 22. Android Toolchain Foundation

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

Built-in Kotlin warning относится к plugin internals и пока не блокирует release APK.

## 23. Testing strategy

### 23.1 Flutter final v0.7.4 gate

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 543 passed

flutter.bat build apk --release
→ 55.8 MB
```

Diagnostic JPEG output может включать:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это ожидаемый output негативных image tests, а не падение suite.

### 23.2 Firestore Rules final v0.7.4 gate

```text
tests: 65
suites: 6
pass: 65
fail: 0
```

Notification settings добавили отдельный suite из 12 security scenarios.

### 23.3 Unchanged Rules baseline

RTDB и Storage rules в v0.7.4 не изменялись и в финальном gate отдельно не перезапускались.

Последний подтверждённый baseline v0.7.3:

```text
Realtime Database Rules → 15 passed
Storage Rules → 42 passed
```

Не суммировать эти значения с текущими Firestore 65 как будто это один свежий full-suite run.

### 23.4 Functions

```text
npm.cmd --prefix functions run lint
→ no lint errors

npm.cmd --prefix functions run build
→ TypeScript build passed
```

Существующее TypeScript/ESLint version compatibility warning остаётся non-blocking.

### 23.5 Manual Android v0.7.4

Identity-card:

- private avatar/photo;
- private initials fallback;
- group avatar/photo;
- group initials fallback;
- tap header opens overlay;
- tap lower chat closes;
- back closes overlay before leaving chat;
- participants navigation;
- management navigation for admin/owner;
- draft/chat state preserved.

Notification modes:

- sound;
- silent 1 hour;
- silent 24 hours;
- silent forever;
- disabled;
- state survives navigation/reopen.

Sound mode:

```text
chat list / app foreground on another route
→ push + seagull + vibration

Android home screen
→ push + seagull + vibration

locked screen
→ push + seagull + vibration

active target chat
→ no push
→ no seagull
→ direct short vibration
```

Silent:

```text
non-active target
→ push only

active target
→ no local push
→ no sound
→ no vibration
```

Disabled:

```text
no push
unread counter still changes
message delivery remains intact
```

## 24. Cost model

### Identity-card

- no dedicated Firestore listener;
- reuses `ChatScreen` chat snapshot;
- full avatar may require Storage-backed avatar image load;
- overlay state is local.

### Notification settings

- one Firestore write on explicit mode change;
- no heartbeat/background write;
- expired temporary silent requires no cleanup write to become effectively sound.

### Push

- chat document read already required by function;
- disabled recipients excluded before device-token reads;
- sound/silent batching shares one function invocation;
- invalid token cleanup retained.

### Read receipts

- debounce merges writes;
- no write for each rendered message.

### Reactions

- one Firestore transaction per toggle;
- no push.

### Typing

- RTDB instead of Firestore;
- debounce;
- 3 s heartbeat while active;
- one exact peer listener.

## 25. Security boundaries

Сохранены и расширены:

```text
auth
membership
role permissions
owner priority
sender-only delete for everyone
private clear isolation
canonical image paths
upload grants
push payload validation
private read cursor ownership
group reaction UID ownership
server-owned typing access projection
own typing node only
own notification-settings UID only
admin cannot edit another member notification settings
```

UI appearance, identity-card buttons, local active-chat tracking и optimistic state не являются server-side authorization.

## 26. Generated files policy

После последней серии Flutter-команд один раз восстанавливаются:

```powershell
git restore `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugins.cmake
```

Generated plugin files не должны попадать в feature/release commit, если их изменение не является осознанной частью задачи.

## 27. Known limitations

- Group image sending не завершён отдельным foundation.
- Image caption отсутствует.
- File messages отсутствуют.
- Voice messages отсутствуют.
- Identity-card подключена только к header открытого chat.
- Search/contact/group-member avatar contexts ещё не унифицированы.
- Notification sound selector пока placeholder.
- In-app global notification-volume UI отсутствует.
- Android notification volume остаётся системной настройкой.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Production release signing требует отдельной настройки.
- Built-in Kotlin plugin warning остаётся.
- TypeScript/ESLint compatibility warning остаётся non-blocking.

## 28. Next architecture stages

Primary messaging roadmap:

```text
Attachment Composer Foundation
→ Image Caption
→ File Message Foundation
→ Voice Message Foundation
```

Attachment composer должен создать общий draft contract:

```text
selected attachment
+ optional caption
+ validation
+ send orchestration
```

Avatar expansion:

```text
Chat Identity Card Foundation
→ remaining clickable avatar contexts
→ unified user/group identity actions
```

Branding backlog:

```text
current send icon
→ custom Epistola seagull vector icon
```

Notification UX backlog:

```text
sound selector
system/channel settings entry point
possible global sound preset / Android-specific control design
```

Production hardening:

```text
Retention Cleanup
App Check
Release Signing
Observability
Firebase Cost Monitoring
```

## 29. Release gate v0.7.4

Перед публикацией:

```text
feature committed and pushed
→ release merged locally into main
→ architecture cleanup committed
→ documentation replaced
→ diff checked
→ docs commit
→ tag v0.7.4
→ push main
→ push tag
→ verify remote refs
```

Функциональные проверки уже пройдены до документационной замены.

После docs-only changes повторный полный Flutter suite не требуется, если application code не меняется.
