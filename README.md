# Epistola

Корпоративный мессенджер на Flutter и Firebase.

Epistola — Android-first корпоративный мессенджер и основа будущей внутренней коммуникационной платформы компании. Проект развивается небольшими проверяемыми этапами с разделением UI, application services, domain-моделей и Firebase infrastructure.

## Статус проекта

| Параметр | Значение |
|---|---|
| Последний стабильный релиз | `v0.7.3` |
| Release merge commit | `81eb9f4` |
| Последний завершённый этап | `v0.7.3 Messaging Feedback Foundation` |
| Текущая ветка | `main` |
| Functional HEAD | `60b3fef` |
| Состояние этапа | завершён и слит в `main`; release tag — `v0.7.3` |
| Основная платформа | Android |
| Backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| Realtime Database region | `europe-west1` |
| Cloud Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Пилотная группа | около 40–50 пользователей |

`v0.7.3` создан поверх стабильного `v0.7.2 Chat Date Separator Foundation`.

Функциональные commits этапа:

```text
f901c06 fix(chat): suppress active chat notifications
8228f9a feat(chat): add private read receipts
d10c110 feat(chat): add group message reactions
60b3fef feat(chat): add private typing indicator
```

Финальные проверки релиза:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 535 tests passed

Realtime Database Rules
→ 15 tests passed

Firestore Rules
→ 53 tests passed

Storage Rules
→ 42 tests passed

Security Rules total
→ 110 tests passed

functions lint / build
→ passed

flutter.bat build apk --release
→ успешно, 55.7 MB
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Функциональность проверена вручную на Android Emulator и физическом Android-устройстве.

## Что такое Epistola

Краткосрочная цель — стабильный корпоративный мессенджер для пилотной группы 40–50 пользователей.

Долгосрочная цель — коммуникационная платформа для компании на 600–700 сотрудников:

- личные и групповые чаты;
- роли и модерация;
- изображения, файлы и голосовые сообщения;
- задачи;
- объявления;
- документы;
- рабочие смены;
- внутренние приложения;
- корпоративные сервисы;
- возможный собственный backend.

Spaces не рассматриваются как обычный тип чата.

```text
Spaces → внутренние приложения Epistola
```

Главный принцип проекта:

```text
Сначала надёжные архитектурные гарантии,
затем пользовательские функции поверх них.
```

## Реализованные возможности

### Пользователи и авторизация

- Firebase Authentication;
- регистрация и вход;
- постоянная сессия;
- запоминание последнего E-mail;
- профиль и редактирование профиля;
- публичный контактный E-mail;
- карточка контакта;
- поиск пользователей;
- экран контактов;
- пользовательские аватары.

### Личные чаты

- текстовые сообщения;
- создание private chat только после первого сообщения;
- отсутствие пустых private chats;
- атомарное создание первого сообщения и metadata чата;
- изображения в существующем private chat;
- первая фотография новому контакту;
- персональная очистка private chat;
- поиск private chat по данным собеседника;
- аватары в списке, поиске, draft и заголовке;
- переход в конкретный private chat по нажатию на push;
- одинарная и двойная галочка доставки/прочтения;
- realtime-индикатор `Пишет...` только для собеседника.

### Групповые чаты

- создание групп;
- добавление участников;
- информация о группе;
- список участников и карточки;
- передача прав;
- защита последнего администратора;
- безопасный выход и роспуск;
- настройки и ограничения по ролям;
- групповые аватары;
- управление аватаром для owner и admin;
- переход в конкретный group chat по нажатию на push;
- реакции `👍` и `👎` под сообщениями;
- только одно значение реакции на пользователя.

Image Message Foundation проверен для личных чатов. Отправка изображений в групповые чаты пока не заявлена завершённой.

### История сообщений

- cursor pagination по 20 сообщений;
- дозагрузка старой истории;
- сохранение позиции прокрутки;
- realtime без потери старых страниц;
- объединение по document ID;
- корректный autoscroll;
- учёт крупных изображений;
- keyboard-aware scroll;
- постоянные разделители календарных дней;
- плавающий индикатор даты при прокрутке;
- форматы `Сегодня`, `Вчера`, `3 августа`, `28 декабря 2025`;
- плавная смена плавающей даты;
- исчезновение плавающего индикатора после остановки прокрутки;
- корректная работа разделителей после пагинации и удаления сообщений.

### Уведомления

- Firebase Cloud Messaging;
- foreground/background/terminated;
- переход из push в конкретный private или group chat;
- sender exclusion;
- удаление невалидных tokens;
- подавление foreground-уведомления, если пользователь уже находится в этом чате;
- уведомления из других чатов не подавляются.

### Удаление сообщений

Поддерживаемые состояния:

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

Реализовано:

- удалить у себя;
- удалить собственное сообщение у всех;
- sender-only delete for everyone;
- logical deletion;
- поиск предыдущего видимого preview;
- отсутствие повторного push при логическом удалении;
- немедленное локальное скрытие сообщений из ранее загруженных страниц;
- перестройка разделителя даты после удаления.

### Роли и модерация

```text
owner
admin
moderator
member
guest
```

Поддерживаются mute, ban, permissions, управление участниками, last-admin protection, передача прав и безопасный выход. Owner сохраняет максимальный приоритет.

## Messaging Feedback Foundation — v0.7.3

### Подавление уведомлений активного чата

`ActiveChatTracker` хранит текущий открытый chat route.

```text
foreground FCM received
→ payload converted to PushDeepLinkRequest
→ activeChatTracker checks chatId
→ same active chat: local notification suppressed
→ another chat: notification shown normally
```

Подавление действует только для активного чата. Background и terminated delivery не отключаются.

### Private Read Receipt Foundation

Только в личных чатах:

```text
✓  сообщение сохранено
✓✓ собеседник прочитал
```

Read cursor хранится в документе чата и содержит:

```text
privateReadState/{uid}
  messageId
  messageCreatedAt
  readAt
```

Свойства решения:

- только private chats;
- только исходящие сообщения получают галочки;
- text и image используют один read cursor;
- cursor монотонный и не откатывается назад;
- запись объединяется debounce-механизмом;
- финальная запись запускается при выходе из чата;
- группы не получают read receipt UI;
- Firestore Rules разрешают пользователю менять только собственный cursor.

### Group Message Reactions

Только в групповых чатах:

```text
👍 like
👎 dislike
```

В сообщении хранится map:

```text
reactions/{uid} = like | dislike
```

Один пользователь не может одновременно иметь `like` и `dislike`.

```text
none + like → like
like + like → none
like + dislike → dislike
none + dislike → dislike
dislike + dislike → none
dislike + like → like
```

Свойства решения:

- transaction-based toggle;
- optimistic UI;
- counters под сообщением;
- выбранная пользователем реакция визуально выделяется;
- поддерживаются text и image presentation;
- private chats не получают реакции;
- реакции не создают push-уведомления;
- Firestore Rules разрешают менять только ключ текущего UID.

### Private Typing Indicator Foundation

Только в личных чатах через Firebase Realtime Database.

```text
пользователь вводит текст
→ в шапке собеседника появляется «Пишет...»

нет активности / поле очищено / сообщение отправлено / выход
→ снова «личный чат»
```

RTDB paths:

```text
privateChatAccess/{chatId}/{uid} = true
privateTyping/{chatId}/{uid} = server timestamp
```

`privateChatAccess` создаётся только серверной callable-функцией `ensurePrivateTypingAccess`, которая проверяет Firestore chat, тип чата, membership и состояние роспуска.

Client lifecycle:

```text
450 ms initial debounce
3 s heartbeat while typing
4 s inactivity stop
6 s peer timestamp freshness guard
onDisconnect remove
```

Дополнительно:

- клиент слушает только точный путь текущего собеседника;
- пользователь пишет только собственный typing node;
- очистка выполняется при send, clear, leave и dispose;
- stale timestamp автоматически скрывается;
- групповые чаты не создают typing state;
- feature flags не используются.

## Chat Date Separator Foundation — v0.7.2

Первое видимое сообщение каждого календарного дня получает разделитель:

```text
Сегодня
Вчера
3 августа
28 декабря 2025
```

Во время прокрутки показывается плавающая дата верхнего видимого сообщения. Пагинация, удаление и элементы переменной высоты поддерживаются без дополнительных Firestore reads.

## Push Deep Link Foundation — v0.7.1

Notification tap открывает конкретный private или group chat.

```text
RemoteMessage или local notification payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkNavigation
→ ChatScreen
```

Поддерживаются foreground, background, terminated, cold start, membership validation, private/group resolution и duplicate route protection.

## Image Message Foundation — v0.7.0

Изображение можно отправить в существующий private chat или как первое сообщение новому контакту, из галереи или камеры.

Поддерживаются crop, поворот, сброс, отмена и варианты пропорций. Приложение создаёт `thumbnail` и `full`, но не загружает исходный оригинал.

```text
thumbnail: до 128 KB, до 480 px
full: target 512 KB, absolute max 1 MB, до 1920 px
```

Canonical paths:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Для первой фотографии используется `createFirstPrivateImageUploadGrant`. Chat и первое image message создаются атомарно. Partial uploads очищаются best-effort.

## Push Notification Foundation — v0.6.3

Реализованы Firebase Cloud Messaging, локальные Android-уведомления, foreground/background/terminated, регистрация и обновление tokens, удаление token при logout, sender exclusion, private/group push и cleanup невалидных tokens.

Начиная с `v0.7.1`, notification tap открывает конкретный chat. Начиная с `v0.7.3`, foreground notification не показывается поверх уже открытого целевого чата.

## Message Deletion Foundation — v0.6.4

```text
Firestore message state
→ MessagePresentation
→ MessageItem
→ MessageBubble
```

Image messages используют ту же logical deletion модель. Assets не удаляются немедленно; retention cleanup проектируется отдельно.

## Avatar Foundation — v0.6.5

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Поддерживаются gallery, camera, crop, compression, versioned paths, atomic replacement, rollback, cleanup и cache key `path@version`.

## Android Toolchain Foundation — v0.6.6

```text
Flutter: 3.44.1 stable
Dart: 3.12.1
Java: OpenJDK 21.0.10
Gradle Wrapper: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
Google Services Plugin: 4.3.15
compileSdk: 36
targetSdk: 36
minSdk: 24
JVM target: 17
```

Compatibility flags:

```text
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
```

Built-in Kotlin warning связан с plugin internals и не блокирует release build.

## Архитектура

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

## Структура проекта

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

Приоритет документов:

```text
исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

## Firebase infrastructure

```text
Authentication
Cloud Firestore
Realtime Database
Cloud Storage
Cloud Functions
Cloud Messaging
```

Realtime Database URL:

```text
https://epistola-434b7-default-rtdb.europe-west1.firebasedatabase.app
```

Основные Cloud Functions:

```text
sendMessageNotification
createFirstPrivateImageUploadGrant
ensurePrivateTypingAccess
```

## Сборка и проверки

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

Rules:

```powershell
firebase.cmd emulators:exec --only database --project epistola-434b7 `
  "npm.cmd --prefix test/rules run test:database"

firebase.cmd emulators:exec --only firestore --project epistola-434b7 `
  "npm.cmd --prefix test/rules run test:firestore"

firebase.cmd emulators:exec --only firestore,storage --project epistola-434b7 `
  "npm.cmd --prefix test/rules run test:storage"
```

Generated plugin files после последней серии Flutter-команд восстанавливаются один раз:

```powershell
git restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugins.cmake
```

## Известные ограничения

- Group image sending не заявлен завершённым.
- Подписи к фотографиям ещё не реализованы.
- File messages не реализованы.
- Voice messages не реализованы.
- Кликабельные аватары и единая profile card навигация реализованы не во всех точках UI.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Release signing требует отдельной настройки.
- Built-in Kotlin warning остаётся предупреждением plugin internals и не блокирует APK.

## Roadmap после v0.7.3

1. Attachment Composer Foundation: единый draft вложения и подпись к фотографии без временного обходного решения.
2. File Message Foundation поверх общего attachment contract.
3. Voice Message Foundation.
4. Clickable Avatar and Profile Card Foundation во всех ключевых списках и экранах.
5. Retention cleanup, App Check и production hardening.

## Git workflow

```text
main
└── feat/vX.Y.Z-short-name
```

Перед commit:

```powershell
git status --short
git diff --check
```

После commit:

```powershell
git push origin <feature-branch>
```

Release merge и tag выполняются только после зелёных автоматических проверок и ручного Android-сценария.
