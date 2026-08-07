# Epistola

Корпоративный мессенджер на Flutter и Firebase.

Epistola — Android-first корпоративный мессенджер и основа будущей внутренней коммуникационной платформы компании. Проект развивается небольшими проверяемыми этапами с разделением UI, presentation, application services, domain-моделей и Firebase infrastructure.

## Статус проекта

| Параметр | Значение |
|---|---|
| Текущий release | `v0.7.4` |
| Release merge commit | `d91270c` |
| Feature commit | `526504c` |
| Post-merge architecture cleanup | `730bab0` |
| Последний завершённый этап | `v0.7.4 Avatar Interaction/Card + Notification Controls Foundation` |
| Текущая ветка | `main` |
| Основная платформа | Android |
| Backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Firestore region | `eur3` |
| Realtime Database region | `europe-west1` |
| Cloud Functions region | `europe-west1` |
| Android package | `com.epistola.app` |
| Целевая пилотная группа | около 40–50 пользователей |

`v0.7.4` создан поверх стабильного `v0.7.3 Messaging Feedback Foundation`.

Основные commits текущего этапа:

```text
526504c feat(chat): add avatar cards and notification controls
d91270c merge: release v0.7.4 Avatar Interaction and Notification Controls
730bab0 refactor(chat): move notification settings out of domain
```

Финальные проверки кода v0.7.4:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 543 tests passed

Firestore Rules
→ 65 tests passed
→ 6 suites
→ 0 failed

functions lint
→ passed

functions build
→ passed

flutter.bat build apk --release
→ успешно, 55.8 MB
```

В финальной серии v0.7.4 отдельно не перезапускались неизменённые RTDB и Storage suites. Их последний подтверждённый baseline из v0.7.3:

```text
Realtime Database Rules → 15 passed
Storage Rules → 42 passed
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Функциональность v0.7.4 проверена вручную на Android Emulator и физическом Android-устройстве.

## Что такое Epistola

Краткосрочная цель — стабильный корпоративный мессенджер для пилотной группы 40–50 пользователей.

Долгосрочная цель — коммуникационная платформа компании на 600–700 сотрудников:

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

Spaces не рассматриваются как обычный тип чата:

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
- поиск пользователей;
- экран контактов;
- пользовательские аватары;
- fallback на инициалы.

### Личные чаты

- текстовые сообщения;
- создание private chat только после первого сообщения;
- отсутствие пустых private chats;
- атомарное создание первого сообщения и metadata чата;
- изображения в существующем private chat;
- первая фотография новому контакту;
- персональная очистка private chat;
- поиск private chat по данным собеседника;
- аватар в списке и шапке;
- переход в конкретный private chat по нажатию на push;
- `✓` / `✓✓` для исходящих сообщений;
- realtime typing indicator;
- раскрывающаяся identity-card из шапки открытого чата;
- индивидуальные настройки уведомлений для чата.

### Групповые чаты

- создание групп;
- добавление участников;
- информация о группе;
- список участников;
- роли и permissions;
- передача прав;
- защита последнего администратора;
- безопасный выход и роспуск;
- групповые аватары;
- управление аватаром для owner/admin;
- переход в конкретный group chat по push;
- реакции `👍` и `👎`;
- одно значение реакции на UID;
- раскрывающаяся group identity-card из шапки;
- быстрый переход к участникам;
- быстрый переход к управлению для admin/owner;
- индивидуальные настройки уведомлений.

Image Message Foundation подтверждён для private chats. Group image sending пока не заявлен как завершённый отдельный foundation.

### История сообщений

- cursor pagination по 20 сообщений;
- дозагрузка старой истории;
- сохранение позиции прокрутки;
- realtime без потери старых страниц;
- merge по document ID;
- near-bottom-only autoscroll;
- учёт изображений переменной высоты;
- keyboard-aware scroll;
- разделители календарных дней;
- плавающий индикатор даты;
- форматы `Сегодня`, `Вчера`, `3 августа`, `28 декабря 2025`;
- корректная работа после пагинации и logical deletion.

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
- отсутствие повторного push при logical deletion;
- локальное скрытие ранее загруженного сообщения;
- перестройка date separator после удаления.

### Роли и модерация

```text
owner
admin
moderator
member
guest
```

Поддерживаются mute, ban, permissions, управление участниками, last-admin protection, передача прав и безопасный выход.

Owner сохраняет максимальный приоритет.

## Avatar Interaction/Card Foundation — v0.7.4

### Текущий scope

v0.7.4 создаёт единую identity-card основу **внутри открытого private или group chat**.

Нажатие на шапку чата:

```text
ChatAppBarTitle
→ ChatScreen
→ ChatIdentityOverlay
→ ChatIdentityBackground
→ ChatIdentityCardContent
```

Панель открывается сверху примерно на 64% высоты экрана.

Свойства:

- плавное раскрытие;
- нижняя часть чата остаётся видимой;
- тап по затемнённой части закрывает карточку;
- системный Back сначала закрывает карточку;
- draft сообщения и состояние чата не пересоздаются;
- в карточке используется full avatar;
- path-first загрузка через существующий avatar pipeline;
- legacy URL fallback;
- при отсутствии изображения — стабильный gradient + инициалы;
- поверх фотографии используется gradient для читаемости текста.

### Private identity-card

Показывает:

```text
имя
about
телефон
```

Действие:

```text
Уведомления
```

### Group identity-card

Показывает:

```text
название группы
количество участников
```

Действия:

```text
Уведомления
Участники
Управление   // только admin / owner
```

`Участники` открывает `GroupInfoScreen(membersOnly: true)`.

`Управление` использует существующий `GroupInfoScreen` и остаётся доступным только admin/owner.

### Что ещё не входит в v0.7.4

v0.7.4 не утверждает, что все аватары приложения уже кликабельны.

Дальнейшая унификация требуется для:

- списка чатов;
- поиска чатов;
- Contacts;
- User Search / New Message;
- Create Group;
- Add Members;
- group member list;
- group member screen;
- профиля и других avatar contexts.

## Per-chat Notification Controls — v0.7.4

Настройки хранятся в документе чата отдельно для каждого пользователя:

```text
notificationSettingsByUser: {
  uid: {
    mode: "sound" | "silent" | "disabled",
    expiresAt?: timestamp,
    permanent?: true
  }
}
```

Отсутствующая, повреждённая или истёкшая настройка трактуется как:

```text
sound
```

### Режим «Со звуком»

```text
push
+ custom sound
+ vibration
```

Стандартный звук Epistola:

```text
android/app/src/main/res/raw/seagull_notification.mp3
```

Android channel:

```text
epistola_messages_seagull_v3
```

Вибрационный pattern для background/terminated FCM:

```text
0 ms
250 ms vibration
100 ms pause
250 ms vibration
```

### Режим «Без звука»

Push остаётся, но:

```text
sound = off
vibration = off
```

Доступные сроки:

```text
На 1 час
На 24 часа
Навсегда
```

Silent Android channel:

```text
epistola_messages_silent
```

### Режим «Отключить уведомления»

Для выбранного чата сервер не отправляет push текущему пользователю.

При этом:

- сообщение сохраняется;
- realtime chat state работает;
- unread counter продолжает обновляться;
- другие чаты не затрагиваются.

### Security

Пользователь может менять только собственный ключ:

```text
notificationSettingsByUser.{auth.uid}
```

Даже admin/owner группы не может менять notification settings другого участника.

Firestore Rules валидируют mode и допустимую форму silent-настройки.

### Server delivery

`sendMessageNotification`:

```text
new message
→ read chat once
→ exclude sender
→ resolve notification mode for each recipient
→ disabled: skip recipient before device-token read
→ sound/silent: read recipient devices
→ split by delivery mode
→ send FCM batches
→ delete invalid tokens
```

FCM multicast остаётся ограничен 500 tokens на batch.

### Foreground / active chat

Если приложение открыто, но пользователь находится не в целевом чате:

```text
sound mode → local push + seagull + vibration
silent mode → local push only
```

Если открыт именно целевой chat:

```text
local push suppressed
```

Дополнительно `ChatScreen` делает короткую in-chat vibration только в effective `sound` mode.

Таким образом:

```text
active target chat + sound → без push, без чайки, с vibration
active target chat + silent → без push, без sound, без vibration
active target chat + disabled → без push, без sound, без vibration
```

### Android resource protection

`epistola_keep.xml` защищает custom sound и launcher icon от resource shrinking:

```xml
tools:keep="@raw/seagull_notification,@mipmap/ic_launcher"
```

`AndroidManifest.xml` использует финальный fallback channel:

```text
epistola_messages_seagull_v3
```

### Что пока не реализовано

Пункт `Звук уведомлений` отображается в UI, но выбор мелодии пока является placeholder:

```text
Пока в разработке
```

Глобальный пользовательский контроль громкости внутри Epistola также пока не реализован. Фактическая громкость notification channel зависит от системных настроек Android; будущий UI управления звуком требует отдельного Android-specific design.

## Messaging Feedback Foundation — v0.7.3

### Active Chat Notification Suppression

`ActiveChatTracker` хранит текущий открытый chat route.

```text
foreground FCM
→ PushDeepLinkRequest
→ activeChatTracker
→ same target chat: local push suppressed
→ another chat: local push shown
```

### Private Read Receipt Foundation

Только private chats:

```text
✓  сообщение сохранено
✓✓ собеседник прочитал
```

Read state:

```text
privateReadState: {
  uid: {
    messageId
    messageCreatedAt
    readAt
  }
}
```

Cursor монотонный, debounce уменьшает число writes.

### Group Message Reactions

Только group chats:

```text
reactions.{uid} = like | dislike
```

Один UID имеет максимум одно значение.

### Private Typing Indicator

Только private chats через Realtime Database:

```text
privateChatAccess/{chatId}/{uid}
privateTyping/{chatId}/{uid}
```

`privateChatAccess` создаётся trusted callable-функцией `ensurePrivateTypingAccess`.

Typing использует debounce, heartbeat, inactivity stop, `onDisconnect` и local freshness guard.

## Chat Date Separator Foundation — v0.7.2

Первое видимое сообщение календарного дня получает separator:

```text
Сегодня
Вчера
3 августа
28 декабря 2025
```

Floating date indicator вычисляется по реальным позициям сообщений и не создаёт дополнительных Firestore reads.

## Push Deep Link Foundation — v0.7.1

```text
RemoteMessage / local payload
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ PushDeepLinkResolver
→ PushDeepLinkNavigation
→ ChatScreen
```

Notification payload считается недоверенным до resolver validation.

## Image Message Foundation — v0.7.0

Поддерживаются gallery, camera, crop, resize и fullscreen viewer.

```text
thumbnail: max 128 KB, max side 480 px
full: target 512 KB, absolute max 1 MB, max side 1920 px
```

Canonical paths:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Для первой фотографии новому private peer используется trusted upload grant.

## Avatar Foundation — v0.6.5

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Поддерживаются gallery, camera, crop, compression, versioned replacement, rollback, cleanup и cache key `path@version`.

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

Built-in Kotlin warning связан с plugin internals и пока не блокирует release build.

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

`ChatNotificationSettings` находится в `lib/models`, а не в `lib/domain`, потому что persistence mapping использует Firestore `Timestamp`. Это сохраняет правило: pure domain не зависит от Firebase.

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
Firebase Authentication
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

Flutter:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

Firestore Rules:

```powershell
firebase.cmd emulators:exec --only firestore `
  "npm.cmd --prefix test/rules run test:firestore"
```

Functions:

```powershell
npm.cmd --prefix functions run lint
npm.cmd --prefix functions run build
```

RTDB и Storage suites при изменении соответствующих rules:

```powershell
firebase.cmd emulators:exec --only database --project epistola-434b7 `
  "npm.cmd --prefix test/rules run test:database"

firebase.cmd emulators:exec --only firestore,storage --project epistola-434b7 `
  "npm.cmd --prefix test/rules run test:storage"
```

Generated plugin files после последней серии Flutter-команд восстанавливаются один раз:

```powershell
git restore `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugins.cmake
```

## Известные ограничения

- Group image sending не завершён как отдельный foundation.
- Caption к изображению отсутствует.
- File messages не реализованы.
- Voice messages не реализованы.
- Clickable identity-card сейчас унифицирована только для шапки открытого private/group chat.
- Аватары в User Search / New Message / Create Group / Add Members / member contexts требуют отдельного аудита и унификации.
- Выбор собственного notification sound пока не реализован.
- Глобальный in-app volume control пока не реализован.
- Production retention cleanup отсутствует.
- App Check не завершён.
- Release signing требует отдельной production-настройки.
- Built-in Kotlin warning остаётся предупреждением plugin internals.
- Существующее TypeScript/ESLint compatibility warning не блокирует Functions build.

## Roadmap после v0.7.4

1. Attachment Composer Foundation: общий attachment draft и optional caption.
2. File Message Foundation поверх общего attachment contract.
3. Voice Message Foundation.
4. Avatar Interaction/Card expansion: сделать аватары кликабельными во всех оставшихся ключевых местах.
5. Branding pass: фирменная иконка чайки вместо текущей иконки отправки сообщения.
6. Notification sound UX: выбор звука и отдельный Android-specific дизайн глобального управления звуком.
7. Retention cleanup, App Check, release signing и production hardening.

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

После последней серии Flutter-команд generated plugin files восстанавливаются один раз.

Release merge и tag выполняются только после зелёных автоматических проверок и ручного Android-сценария.
