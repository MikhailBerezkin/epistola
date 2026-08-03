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
| Версия документа | `4.2` |
| Последняя стабильная версия | `v0.7.2` |
| Release merge commit | `7d8357a` |
| Последний завершённый этап | `v0.7.2 Chat Date Separator Foundation` |
| Текущая ветка | `main` |
| Состояние этапа | завершён и слит в `main`; release tag — `v0.7.2` |
| Последнее обновление | август 2026 |

Chat Date Separator Foundation добавляет календарные разделители в историю сообщений, плавающую дату при прокрутке и немедленное локальное скрытие сообщений из ранее загруженных страниц.

Проверено:

```text
permanent date separators
Сегодня / Вчера / calendar date formatting
floating scroll date indicator
date transition during continuous scroll
1.2 second delayed hide
pagination across multiple days
message deletion and date label rebuild
paginated message immediate local hide
```

Cloud Functions, Firestore Rules и Storage Rules на этапе `v0.7.2` не менялись.

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
- понятная история сообщений.

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

Realtime Database пока не подключена. Она запланирована для private typing indicator в `v0.7.3`.

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
- локальная optimistic presentation не заменяет server-side security.

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

Date separator presentation:

```text
message.createdAt
→ ChatDateFormatter
→ date label
→ ChatDateSeparator / ChatScrollDateIndicator
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
```

`PushDeepLinkRequest` не зависит от Flutter, Firebase или Navigator.

`ChatDateFormatter` не зависит от Firebase и Flutter UI. Он работает с календарными `DateTime` и поддерживает unit-тестирование без widget tree.

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
├── services/
└── widgets/
    └── chat/
```

Chat date files:

```text
lib/helpers/chat_date_formatter.dart
lib/widgets/chat/chat_date_separator.dart
lib/widgets/chat/chat_scroll_date_indicator.dart
lib/widgets/message_item.dart
lib/widgets/messages_list.dart

test/helpers/chat_date_formatter_test.dart
test/widgets/chat/chat_date_widgets_test.dart
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

### 8.1 Local history cache

`MessagesList` объединяет realtime snapshot последних сообщений и ранее загруженные страницы в:

```text
Map<messageId, QueryDocumentSnapshot>
```

Realtime listener не обновляет документы, которые находятся только в старой локальной странице.

Для `deleteMessageForCurrentUser` после успешной Firestore transaction используется локальный set:

```text
Set<String> locallyHiddenMessageIds
```

Он немедленно переводит presentation в `hiddenForCurrentUser`, запускает анимацию схлопывания и перестройку date labels.

Это presentation optimization, а не security boundary. После повторного открытия authoritative state загружается из Firestore.

## 9. Chat Date Separator Foundation

### 9.1 Форматирование календарной даты

`ChatDateFormatter` поддерживает:

```text
same calendar day as now → Сегодня
previous calendar day → Вчера
same year → 3 августа
different year → 28 декабря 2025
```

Сравнение выполняется по локальному календарному году, месяцу и дню.

### 9.2 Постоянный разделитель

Разделитель показывается перед первым видимым сообщением календарного дня.

При расчёте игнорируются:

```text
deletedForEveryone
hiddenForCurrentUser
locallyHiddenMessageIds
```

Если первое сообщение дня скрывается, label автоматически переходит к следующему видимому сообщению. Если видимых сообщений дня больше нет, разделитель исчезает.

### 9.3 Плавающая дата

`MessagesList` использует:

```text
ScrollController
NotificationListener<ScrollNotification>
GlobalKey для отрисованных message items
GlobalKey viewport
```

Алгоритм:

```text
scroll notification
→ schedule one post-frame update
→ calculate viewport probe line
→ inspect attached visible message RenderBox objects
→ choose first visible message crossing probe
→ format createdAt
→ update floating label
```

Высота сообщения не предполагается фиксированной. Поддерживаются длинный текст, изображения и анимированное схлопывание.

### 9.4 Lifecycle плавающего индикатора

```text
user scroll starts
→ cancel hide timer
→ show indicator

scroll update / overscroll / inertia
→ keep indicator visible
→ update current date

scroll end
→ schedule hide after 1200 ms

hide
→ AnimatedOpacity
```

Смена label выполняется через `AnimatedSwitcher`.

### 9.5 Пагинация

При подгрузке старой страницы сохраняется:

```text
previous maxScrollExtent
previous pixels
```

После layout вычисляется added extent, и scroll position сдвигается на его величину.

Date labels строятся по всей локально загруженной и отсортированной истории, поэтому граница страницы не создаёт отдельный календарный день.

### 9.6 Overlay coordination

`MessagesList` использует верхний `Stack`:

```text
ListView
loading older indicator
floating date indicator
```

Если плавающая дата видима, loading indicator смещается ниже и не перекрывает её.

## 10. Image Message Foundation

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

## 11. Avatar architecture

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

## 12. Push Notification architecture

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

## 13. Push Deep Link Foundation

```text
RemoteMessage.data или local payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkDestination
→ PushDeepLinkNavigation
→ ChatScreen
```

Resolver проверяет auth, существование chat, membership, supported type и private peer.

Coordinator поддерживает pending queue, readiness gate, deduplication, sequential resolve и duplicate route suppression.

Notification payload считается недоверенным. Firestore Rules остаются последней server-side защитой.

## 14. Android Toolchain Foundation

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

## 15. Testing strategy

Chat date targeted tests:

```text
ChatDateFormatter: 10
ChatDate widgets: 4
Total targeted: 14
```

Manual Android tests:

- permanent separators across several days;
- `Сегодня`, `Вчера`, ordinary date;
- slow scroll;
- fast inertial scroll;
- floating date transition;
- delayed hide;
- images in the same list;
- pagination through several days;
- delete own message for self;
- delete own message for everyone;
- delete peer message for self;
- immediate hide of old paginated messages;
- date separator transfer after deletion.

Финальные результаты:

```text
flutter.bat analyze → No issues found
flutter.bat test → 423 tests passed
flutter.bat build apk --release → 55.3 MB
```

Ожидаемый диагностический вывод image tests:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это не падение suite, а тест обработки повреждённых JPEG.

## 16. Проверки и deploy

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

Deploy выполняется только в `epistola-434b7`.

Для `v0.7.2` deploy не требуется:

```text
functions/src/index.ts unchanged
firestore.rules unchanged
storage.rules unchanged
```

## 17. Cost controls

Chat Date Separator Foundation выполняется локально поверх уже загруженных сообщений.

Не добавлены:

```text
Firestore reads
Firestore writes
polling
Cloud Function invocations
Storage operations
```

Локальное скрытие после успешного удаления также не добавляет backend operations. Оно только немедленно отражает уже выполненную Firestore transaction в UI.

## 18. Security principles

- UI не является security boundary.
- UID, membership и role проверяются Rules.
- Notification payload недоверенный.
- Deep link не открывает chat без membership.
- Canonical paths проверяются Rules.
- First-private upload требует server-side grant.
- Локально скрытое сообщение не изменяет authoritative server state.
- App Check остаётся отдельным hardening этапом.

## 19. Неприкосновенные invariants

Нельзя ломать:

- `Auth UID == users/{uid}`;
- отсутствие пустых private chats;
- first message atomicity;
- deterministic private chat ID;
- pagination по 20;
- сохранение старых страниц;
- сохранение scroll position;
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

## 20. Следующий этап — v0.7.3 Messaging Feedback Foundation

### 20.1 Private Read Receipt Foundation

Только private chats:

```text
✓  saved
✓✓ peer read
```

Позиция чтения должна обновляться экономно и не создавать write на каждое сообщение.

### 20.2 Group Message Reactions

Только group chats:

```text
👍 like
👎 dislike
```

На один UID допускается только одно взаимоисключающее значение.

### 20.3 Private Typing Indicator Foundation

Только private chats через Firebase Realtime Database:

```text
peer starts typing
→ typing state appears

idle / send / leave / disconnect
→ state removed
```

Функция включается сразу, без feature flag.

## 21. Технический долг

- group image messages;
- production retention cleanup;
- App Check;
- release signing;
- дополнительные concurrent tests;
- мониторинг Firestore reads, Storage usage и будущего RTDB traffic;
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
