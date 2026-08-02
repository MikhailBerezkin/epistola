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
| Версия документа | `4.1` |
| Последняя стабильная версия | `v0.7.0` |
| Стабильный commit `main` | `192f565` |
| Текущий этап | `v0.7.1 Push Deep Link Foundation` |
| Рабочая ветка | `feat/v0.7.1-push-deep-link-foundation` |
| Состояние этапа | функциональность реализована и вручную проверена; документация обновляется перед релизом |
| Последнее обновление | август 2026 |

Push Deep Link Foundation добавляет безопасный переход из remote или local notification в конкретный личный либо групповой чат.

Проверено:

```text
background notification tap
terminated application tap
cold start
foreground local notification tap
private chat resolution
group chat resolution
membership validation
duplicate route protection
navigation from another open chat
delayed notification tap
```

Cloud Functions и Firebase Rules на этапе `v0.7.1` не менялись.

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
- предсказуемая навигация из уведомлений.

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
Cloud Functions region: europe-west1
Android package: com.epistola.app
Storage bucket: gs://epistola-434b7.firebasestorage.app
```

Используются Firebase Authentication, Cloud Firestore, Security Rules, Storage, Cloud Messaging и Cloud Functions.

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
- navigation adapter может зависеть от Flutter, но не переносит Firebase business logic в widgets.

### 4.1 Flutter UI

Отвечает за отображение, пользовательские события, progress, retry, локальное состояние и navigation.

UI не должен:

- обращаться к Storage напрямую;
- выполнять Firestore transactions;
- выдавать upload grants;
- вычислять permissions;
- формировать canonical paths;
- выполнять remote rollback;
- содержать compression policy;
- доверять `chatId` из notification без resolver;
- читать chat document из notification callback.

### 4.2 Presentation

Преобразует backend/domain state в UI-модели.

Ключевые модели:

```text
MessagePresentation
MessageVisibilityState
```

### 4.3 Application Services

Оркестрируют use case: порядок операций, validation, upload, atomic write, rollback, cleanup и errors.

Примеры:

```text
ImageMessageImagePreparationService
ImageMessageUploadService
ExistingImageMessageSendService
FirstPrivateImageMessageSendService
PushDeepLinkCoordinator
PushDeepLinkResolver
```

### 4.4 Domain

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
```

`PushDeepLinkRequest` не зависит от Flutter, Firebase или Navigator.

### 4.5 Infrastructure

Реализует contracts через Firebase:

```text
FirebaseImageMessageStorageAdapter
FirebaseMediaStorageProvider
Firestore gateways
Cloud Functions callable gateway
PushDeepLinkResolver.firebase()
```

## 5. Структура проекта

```text
lib/
├── domain/
│   └── models/
├── models/
├── screens/
├── services/
│   ├── avatar/
│   ├── chat/
│   ├── media/
│   └── push/
├── theme/
├── widgets/
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
├── services/
└── widgets/
```

Push deep-link files:

```text
lib/domain/models/push_deep_link_request.dart
lib/services/push/push_deep_link_resolver.dart
lib/services/push/push_deep_link_coordinator.dart
lib/services/push/push_deep_link_navigation.dart

test/domain/models/push_deep_link_request_test.dart
test/services/push/push_deep_link_resolver_test.dart
test/services/push/push_deep_link_coordinator_test.dart
```

## 6. Пользовательская идентичность

```text
FirebaseAuth.currentUser.uid
==
users/{uid}
```

Firebase UID является главным application identifier.

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

## 9. Image Message Foundation

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

Thumbnail используется в ленте. Full — только по явному открытию. Оригинал не загружается.

```text
thumbnail: max 128 KB, max side 480 px
full: target 512 KB, absolute max 1 MB, max side 1920 px
```

First private image upload защищён `createFirstPrivateImageUploadGrant`. Chat, message и preview записываются атомарно. Partial uploads очищаются best-effort.

## 10. Avatar architecture

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

## 11. Push Notification architecture

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

`data.chatId` — контракт между Cloud Function и клиентским deep-link pipeline.

## 12. Push Deep Link Foundation

### 12.1 Общий поток

```text
RemoteMessage.data или local payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkDestination
→ PushDeepLinkNavigation
→ ChatScreen
```

Источники:

```text
FirebaseMessaging.onMessageOpenedApp
FirebaseMessaging.getInitialMessage()
FlutterLocalNotificationsPlugin notification response
```

### 12.2 PushDeepLinkRequest

Ответственность:

- извлечь `chatId`;
- принять только String;
- выполнить `trim()`;
- отвергнуть empty;
- отвергнуть `/`;
- value equality.

Модель не проверяет Firestore membership и не определяет тип chat.

### 12.3 PushDeepLinkResolver

Dependencies:

```text
currentUserIdProvider
loadChat
loadUser
```

Firebase factory использует `FirebaseAuth.instance` и `FirebaseFirestore.instance`.

```text
current UID
→ chats/{chatId}
→ memberIds
→ type
→ private: peer UID + AppUser
→ group: name
→ destination
```

Возвращает `null`, если user не авторизован, chat отсутствует, membership отсутствует, type неизвестен или private chat не содержит peer.

Private title priority:

```text
peer.name
→ peer.email
→ stored chat name
→ Личный чат
```

Group fallback: `Без названия`.

### 12.4 PushDeepLinkCoordinator

Coordinator не зависит от Flutter Navigator.

Ответственность:

- pending queue;
- readiness gate;
- queue deduplication;
- sequential resolve;
- unavailable/error callbacks;
- duplicate route suppression;
- повторное открытие после завершения navigation future.

```text
Queue<PushDeepLinkRequest> _pendingRequests
Set<String> _queuedChatIds
Set<String> _openedChatIds
```

`clearPending()` очищает только ещё не открываемые запросы.

### 12.5 PushDeepLinkNavigation

Flutter adapter содержит `GlobalKey<NavigatorState>`, resolver и coordinator.

После первого frame вызывается `markNavigationReady()`. При dispose — `markNavigationUnavailable()`.

```text
Navigator.push
→ MaterialPageRoute
→ ChatScreen
```

Для private chat передаётся `peerUser`; для group — `null`.

### 12.6 NotificationService integration

`NotificationService.initialize()` получает coordinator до `runApp`.

`startMessaging()` подключает `onMessage`, `onMessageOpenedApp` и `getInitialMessage()`.

Foreground local notification использует:

```text
payload: request?.chatId
```

Remote и local taps проходят через одну функцию и `coordinator.handle(request)`.

NotificationService не читает Firestore chat и не создаёт `ChatScreen` напрямую.

### 12.7 Cold start

```text
getInitialMessage
→ coordinator queue
→ первый frame
→ markNavigationReady
→ flush
→ resolver
→ route
```

### 12.8 Security boundary

`chatId` из notification считается недоверенным.

Resolver проверяет auth, существование chat, membership, supported type и private peer. Подменённый payload не должен открыть чужой chat.

Firestore Rules остаются последней server-side защитой.

### 12.9 Fallback

При отсутствующем, удалённом или чужом chat:

- приложение не падает;
- текущий экран сохраняется;
- route не открывается;
- debug build может вывести diagnostic message.

### 12.10 Deploy

На `v0.7.1` не изменялись:

```text
functions/src/index.ts
firestore.rules
storage.rules
```

Firebase deploy не нужен.

## 13. Android Toolchain Foundation

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

## 14. Testing strategy

Push deep-link tests:

```text
PushDeepLinkRequest: 8
PushDeepLinkResolver: 9
PushDeepLinkCoordinator: 6
Total targeted: 23
```

Manual Android tests:

- background;
- terminated;
- cold start;
- foreground local notification;
- private chat;
- group chat;
- переход из другого chat;
- delayed tap;
- duplicate route protection;
- back navigation.

Финальные результаты:

```text
flutter.bat analyze → No issues found
flutter.bat test → 409 tests passed
flutter.bat build apk --release → 55.3 MB
```

## 15. Проверки и deploy

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
git.exe diff --check
git.exe status --short
```

Generated plugin files восстанавливаются один раз после Flutter-серии:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

Deploy выполняется только в `epistola-434b7`. Для `v0.7.1` deploy не требуется.

## 16. Cost controls

Push deep link выполняет reads только после явного tap:

```text
1 chat read
+ для private chat до 1 peer user read
```

Не добавлены polling, background listener, новая Cloud Function, дополнительный push или Storage operations.

## 17. Security principles

- UI не является security boundary.
- UID, membership и role проверяются Rules.
- Notification payload недоверенный.
- Deep link не открывает chat без membership.
- Canonical paths проверяются Rules.
- First-private upload требует server-side grant.
- App Check остаётся отдельным hardening этапом.

## 18. Неприкосновенные invariants

Нельзя ломать:

- `Auth UID == users/{uid}`;
- отсутствие пустых private chats;
- first message atomicity;
- deterministic private chat ID;
- pagination по 20;
- сохранение старых страниц;
- near-bottom-only autoscroll;
- logical deletion;
- sender-only delete for everyone;
- role permissions и last-admin protection;
- push sender exclusion;
- notification `data.chatId` contract;
- deep-link membership validation;
- duplicate route protection;
- versioned avatar paths;
- canonical image paths;
- first-image grant;
- partial upload rollback;
- original image not uploaded;
- full loaded only on demand;
- UI/Firebase separation.

## 19. Технический долг

- group image messages;
- production retention cleanup;
- App Check;
- release signing;
- дополнительные concurrent tests;
- мониторинг Firestore reads и Storage usage;
- расширение Rules tests;
- постепенное разделение документации на ADR/reference files.

Отложено:

```text
files
voice messages
geolocation
contact sharing
media captions
multi-image galleries
```

## 20. Следующие этапы

После `v0.7.1`:

1. Group Image Message Foundation.
2. File Message Foundation.
3. Voice Message Foundation.
4. Media Retention Cleanup Foundation.
5. App Check / Production Hardening.
6. Release Signing.
7. UI Customization Foundation.

Каждый этап должен сохранять существующие invariants и проходить отдельную ручную Android-проверку.
