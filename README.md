# Epistola

Корпоративный мессенджер на Flutter и Firebase.

Epistola — Android-first корпоративный мессенджер и основа будущей внутренней коммуникационной платформы компании. Проект развивается небольшими проверяемыми этапами с разделением UI, application services, domain-моделей и Firebase infrastructure.

## Статус проекта

| Параметр | Значение |
|---|---|
| Последний стабильный релиз | `v0.7.2` |
| Release merge commit | `7d8357a` |
| Последний завершённый этап | `v0.7.2 Chat Date Separator Foundation` |
| Текущая ветка | `main` |
| Состояние этапа | завершён и слит в `main`; release tag — `v0.7.2` |
| Основная платформа | Android |
| Backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| Cloud Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Пилотная группа | около 40–50 пользователей |

Релиз `v0.7.2` создан поверх `v0.7.1 Push Deep Link Foundation`.

Итоговая Git-история этапа:

```text
2d34cfc feat(chat): add date separators and scroll indicator
bffea4f fix(chat): hide paginated messages immediately
7d8357a merge: release v0.7.2 Chat Date Separator Foundation
```

Финальные проверки:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 423 tests passed

flutter.bat build apk --release
→ успешно, 55.3 MB
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Функциональность проверена на Android Emulator. Разделители дней, плавающая дата, пагинация и немедленное локальное скрытие сообщений работают.

Cloud Functions, Firestore Rules и Storage Rules на этапе `v0.7.2` не изменялись. Firebase deploy не требуется.

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
- keyboard-aware scroll;
- постоянные разделители календарных дней;
- плавающий индикатор даты при прокрутке;
- форматы `Сегодня`, `Вчера`, `3 августа`, `28 декабря 2025`;
- плавная смена плавающей даты;
- исчезновение плавающего индикатора после остановки прокрутки;
- корректная работа разделителей после пагинации и удаления сообщений.

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

## Chat Date Separator Foundation — v0.7.2

### Назначение

Этап добавляет календарную структуру истории сообщений и позволяет понимать дату сообщений при просмотре длинного чата.

### Постоянные разделители

Первое видимое сообщение каждого календарного дня получает разделитель:

```text
Сегодня
Вчера
3 августа
28 декабря 2025
```

Скрытые у текущего пользователя и удалённые у всех сообщения не участвуют в выборе первого видимого сообщения дня.

### Плавающая дата

Во время пользовательской прокрутки над лентой отображается дата верхнего видимого сообщения.

```text
scroll start
→ индикатор появляется

scroll update / inertia
→ индикатор остаётся видимым
→ дата меняется при переходе между днями

scroll end
→ индикатор остаётся примерно 1.2 секунды
→ плавно исчезает
```

Дата определяется по реальным позициям отрисованных элементов, поэтому корректно поддерживаются сообщения разной высоты, длинный текст и изображения.

### Пагинация и удаление

Сохранены invariants:

```text
page size 20
merge by document ID
chronological order
scroll position preservation
one old-page request at a time
near-bottom-only autoscroll
```

Ранее загруженные страницы не входят в realtime-listener последних 20 сообщений. Поэтому после успешного удаления добавлено локальное optimistic-состояние скрытия:

```text
Firestore update succeeded
→ messageId added to locally hidden set
→ MessageItem collapses
→ date labels rebuild
```

Это устраняет необходимость выходить из чата для обновления старого сообщения и не создаёт дополнительных Firestore reads.

### Файлы этапа

```text
lib/helpers/chat_date_formatter.dart
lib/widgets/chat/chat_date_separator.dart
lib/widgets/chat/chat_scroll_date_indicator.dart
lib/widgets/message_item.dart
lib/widgets/messages_list.dart

test/helpers/chat_date_formatter_test.dart
test/widgets/chat/chat_date_widgets_test.dart
```

### Проверки этапа

```text
10 ChatDateFormatter tests
4 date widget tests
423 tests полного проекта
flutter.bat analyze → No issues found
release APK → 55.3 MB
```

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

## Сборка и проверки

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

Generated plugin files после серии Flutter-команд восстанавливаются один раз:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

## Известные ограничения

- Group image messages не завершены.
- Private read receipts пока не реализованы.
- Group like/dislike reactions пока не реализованы.
- Private typing indicator и Realtime Database пока не подключены.
- Files и voice messages не реализованы.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Release signing требует отдельной настройки.

## Roadmap

После выпуска `v0.7.2`:

1. `v0.7.3 Messaging Feedback Foundation`:
   - Private Read Receipt Foundation — `✓ / ✓✓` только для личных чатов;
   - Group Message Reactions — `👍 / 👎`, одно взаимоисключающее состояние на пользователя;
   - Private Typing Indicator Foundation — Realtime Database только для личных чатов.
2. Group Image Message Foundation.
3. File Message Foundation.
4. Voice Message Foundation.
5. Media Retention Cleanup Foundation.
6. App Check / Production Hardening.
7. Release Signing.
8. UI customization.

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
