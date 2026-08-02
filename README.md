# Epistola

Корпоративный мессенджер на Flutter и Firebase.

Epistola — Android-first корпоративный мессенджер и основа для будущей внутренней коммуникационной платформы компании. Проект развивается небольшими проверяемыми этапами с разделением UI, application services, domain-моделей и Firebase infrastructure.

## Статус проекта

| Параметр | Значение |
|---|---|
| Последний стабильный релиз | `v0.7.0` |
| Последний стабильный commit `main` | `192f565` |
| Текущий функциональный этап | `v0.7.1 Push Deep Link Foundation` |
| Рабочая ветка | `feat/v0.7.1-push-deep-link-foundation` |
| Состояние этапа | функциональность реализована и вручную проверена; документация обновляется перед релизом |
| Основная платформа | Android |
| Backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| Cloud Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Пилотная группа | около 40–50 пользователей |

Текущая ветка создана от стабильного `v0.7.0 Image Message Foundation`.

Последние итоговые проверки функциональной ветки:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 409 tests passed

flutter.bat build apk --release
→ успешно, 55.3 MB
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

APK установлен и проверен на физическом Android-телефоне и Android Emulator.

Cloud Functions, Firestore Rules и Storage Rules на этапе `v0.7.1` не изменялись. Повторный Firebase deploy не требуется.

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

Spaces больше не рассматриваются как обычный тип чата.

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
- переход в конкретный private chat по нажатию на push.

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
- переход в конкретный group chat по нажатию на push.

Image Message Foundation проверен для личных чатов. Отправка изображений в групповые чаты пока не заявлена завершённой.

### История сообщений

- cursor pagination по 20 сообщений;
- дозагрузка старой истории;
- сохранение позиции прокрутки;
- realtime без потери старых страниц;
- объединение по document ID;
- корректный autoscroll;
- учёт крупных изображений;
- keyboard-aware scroll.

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
- отсутствие повторного push при логическом удалении.

### Роли и модерация

```text
owner
admin
moderator
member
guest
```

Поддерживаются mute, ban, permissions, управление участниками, last-admin protection, передача прав и безопасный выход. Owner сохраняет максимальный приоритет.

## Push Deep Link Foundation — v0.7.1

### Назначение

Push Deep Link Foundation переводит пользователя из системного или локального уведомления непосредственно в нужный личный или групповой чат.

Серверный payload уже содержал:

```text
data.chatId
```

Поэтому изменение и повторный deploy Cloud Function `sendMessageNotification` не потребовались.

### Клиентский поток

```text
RemoteMessage или local notification payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkNavigation
→ ChatScreen
```

### Реализовано

- проверка и нормализация `chatId`;
- отказ от пустого, нестрокового или содержащего `/` идентификатора;
- `FirebaseMessaging.onMessageOpenedApp`;
- `FirebaseMessaging.getInitialMessage()`;
- foreground local notification;
- передача `chatId` в payload локального уведомления;
- ожидание готовности Flutter Navigator;
- очередь запросов во время запуска;
- дедупликация одинакового `chatId`;
- защита от двойного открытия route;
- повторное открытие после закрытия предыдущего route;
- загрузка chat document;
- проверка auth и membership;
- отказ для отсутствующего, чужого или неподдерживаемого chat;
- разрешение private peer и загрузка `AppUser`;
- поддержка private и group chats;
- безопасный fallback без падения;
- единый `navigatorKey` в `MaterialApp`.

### Проверенные сценарии v0.7.1

На физическом Android-телефоне и Android Emulator проверено:

- private chat при свёрнутом приложении;
- private chat после удаления приложения из последних задач;
- cold start;
- group chat;
- foreground local notification;
- переход из другого открытого чата;
- delayed notification tap;
- правильные имя и текст уведомления;
- открытие правильного chat;
- отсутствие двойного route;
- возврат кнопкой «Назад».

### Автоматические проверки v0.7.1

```text
test/domain/models/push_deep_link_request_test.dart
test/services/push/push_deep_link_resolver_test.dart
test/services/push/push_deep_link_coordinator_test.dart
```

```text
23 профильных теста passed
409 тестов полного проекта passed
```

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

Viewer поддерживает progress, retry, pinch-to-zoom, перемещение, 5x, double-tap и системный back.

## Push Notification Foundation — v0.6.3

Реализованы Firebase Cloud Messaging, локальные Android-уведомления, foreground/background/terminated, регистрация и обновление tokens, удаление token при logout, sender exclusion, private/group push, cleanup невалидных tokens и представление image message как `Фотография`.

Начиная с `v0.7.1`, notification tap открывает конкретный chat.

## Message Deletion Foundation — v0.6.4

```text
Firestore message state
→ MessagePresentation
→ MessageItem
→ MessageBubble
```

Image messages используют ту же logical deletion модель. Assets не удаляются немедленно; retention cleanup проектируется отдельно.

## Avatar Foundation — v0.6.5

User avatar paths:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Group avatar paths:

```text
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

Push deep-link flow:

```text
NotificationService
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkNavigation
→ ChatScreen
```

## Структура проекта

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

## Сборка и проверки

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

```powershell
npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
```

На этапе `v0.7.1` Firebase deploy не требуется.

Generated plugin files после серии Flutter-команд восстанавливаются один раз:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

## Известные ограничения

- Group image messages не завершены.
- Files и voice messages не реализованы.
- Geolocation и contact sharing отложены.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Release signing требует отдельной настройки.
- Firebase Storage usage и Firestore reads требуют наблюдения.

## Roadmap

После выпуска `v0.7.1`:

1. Стабилизация Push Deep Link и Image Message Foundation.
2. Group Image Message Foundation.
3. File Message Foundation.
4. Voice Message Foundation.
5. Media Retention Cleanup Foundation.
6. App Check / Production Hardening.
7. Release Signing.
8. UI customization.
9. Внутренние приложения Epistola вместо обычного типа чата Spaces.

## Рабочий процесс

- Общение на русском языке.
- PowerShell-команды с явными executable-именами.
- Используются `flutter.bat`, `dart.bat`, `firebase.cmd`, `npm.cmd`, `git.exe`.
- Изменения делаются небольшими проверяемыми шагами.
- Перед commit выполняются analyze, профильные tests и `diff --check`.
- Перед релизом выполняются полный test suite и release APK build.
- Изменённый пользовательский сценарий проверяется вручную.
- Generated plugin files не включаются в feature commits.
- Учитывается Firebase free-tier и пилотная группа 40–50 пользователей.

## Лицензия

Проект является внутренним продуктом и не публикуется в pub.dev.
