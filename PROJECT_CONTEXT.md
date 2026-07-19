# Epistola — Project Context

> Живой документ состояния проекта. Использовать как главный handoff между чатами и аккаунтами. При расхождении приоритет: исходный код → этот документ → ARCHITECTURE.md → README.md.

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Рабочая ветка: `fix/v0.6.2.1-security-foundation`
- Текущий HEAD перед обновлением документации: `eee5d3b`
- Готовящийся стабильный тег: `v0.6.2.1`
- Последний опубликованный стабильный тег: `v0.6.2-media-foundation`
- База ветки: `main`, commit `4fa8693` (`feat(media): create media storage foundation`)
- Следующая ветка после релиза: `feat/v0.6.3-push-notification-foundation`
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Android package: `com.epistola.app`
- Основная текущая платформа: Android.

Последние важные коммиты:

```text
eee5d3b perf: reduce message page size
6a0fc82 feat: paginate chat messages
eabb9c6 feat: send chat messages atomically
0e42c4e feat: clear private chat for current user
196f9a0 feat: create private chat on first message
e802d6d security: validate private chat creation
```

## 2. Проверенное состояние сборки

```text
flutter analyze → No issues found
flutter test → 14 tests passed
git diff --check → без ошибок, возможно предупреждение LF/CRLF для firestore.rules
flutter build apk --debug → успешно
```

Функциональность проверена на физическом Android-телефоне и на очищенной Firebase-базе.

## 3. Завершённые изменения ветки

### 3.1 Ограничения текста сообщений

Добавлен `lib/domain/value_objects/message_text.dart`.

- `trim()` по краям;
- пустые сообщения запрещены;
- максимум `4096` символов;
- UI использует `LengthLimitingTextInputFormatter`;
- поле ввода ограничено `maxLines: 5`, но пузырь сообщения может занимать больше строк;
- `lastMessage` получает нормализованный текст;
- Firestore Rules повторяют серверную валидацию текста и отправителя.

### 3.2 Private chat создаётся только по первому сообщению

Новый поток:

```text
выбор пользователя
→ детерминированный chatId из двух UID
→ существующий чат: ChatScreen
→ отсутствующий чат: PrivateChatDraftScreen
→ выход без сообщения: Firestore не изменяется
→ первое сообщение: chat + message одной транзакцией
```

Основные файлы:

```text
lib/screens/private_chat_draft_screen.dart
lib/screens/user_search_screen.dart
lib/screens/contacts_screen.dart
lib/screens/group_member_screen.dart
lib/services/chat/chat_private_service.dart
lib/services/chat_service.dart
firestore.rules
```

Новый private chat содержит:

```text
name: private_chat
type: private
memberIds: [uid1, uid2]
memberEmails
memberRoles: оба member
memberStatus: оба normal
groupSettings.messagePermission: all
lastRead: создающий пользователь
isDissolved: false
createdAt
lastMessage
lastMessageAt
firstMessageId
```

`firstMessageId` совпадает с ID первого документа сообщения. Rules используют `getAfter()` и запрещают пустой private chat.

Проверено:

- выход из черновика не создаёт чат;
- первое сообщение создаёт чат и message document;
- существующие private chats работают;
- группы по-прежнему создаются сразу после публикации названия.

### 3.3 «Удалить личный чат у себя»

Физическое удаление документов не выполняется.

```text
clearedAtByUser.{uid} = serverTimestamp
lastRead.{uid} = serverTimestamp
```

Поведение:

```text
чат скрывается только у удалившего пользователя
→ у собеседника всё остаётся
→ message documents остаются в Firestore
→ при повторном открытии сообщения до clearedAt не загружаются
→ сообщение позже clearedAt возвращает чат в список
```

Основные файлы:

```text
lib/screens/chats_page.dart
lib/screens/chat_screen.dart
lib/widgets/chat_tile.dart
lib/widgets/messages_list.dart
lib/services/chat/chat_private_service.dart
lib/services/chat/chat_messages_service.dart
lib/services/chat_service.dart
firestore.rules
```

История запрашивается с условием `createdAt > clearedAt`. Карточка возвращается, когда `lastMessageAt > clearedAt`.

Проверено на двух аккаунтах:

- чат исчезает только у одного пользователя;
- `clearedAtByUser` содержит только его UID;
- собеседник видит историю;
- новые входящие и исходящие сообщения возвращают чат;
- `lastMessage` и `lastMessageAt` обновляются;
- группы не получают действие очистки private chat.

### 3.4 Firestore Security Foundation

Rules:

- валидируют поля сообщения и отправителя;
- ограничивают текст 4096 символами;
- валидируют структуру и ID private chat;
- требуют существования обоих `users/{uid}`;
- требуют атомарного первого сообщения через `getAfter()`;
- требуют атомарной обычной отправки message + chat metadata;
- связывают `lastMessageId`, `lastMessage`, `lastMessageAt` и созданный message document;
- разрешают менять только свой ключ `clearedAtByUser` и `lastRead`;
- запрещают клиентское удаление chat/message documents;
- сохраняют проверки ролей, mute/ban, добавления участников, выхода и защиты последнего администратора.

### 3.5 Атомарная отправка и pagination

Обычная отправка использует `WriteBatch`:

```text
message document
+ chat.lastMessage
+ chat.lastMessageAt
+ chat.lastMessageId
```

История сообщений:

- последняя страница — realtime;
- размер страницы — 20 документов;
- старые страницы — `startAfterDocument`;
- документы объединяются по ID;
- позиция прокрутки сохраняется;
- загруженная история живёт в памяти экрана до выхода из чата;
- private clear продолжает применять `createdAt > clearedAt`.

Rules опубликованы:

```powershell
firebase.cmd deploy --only firestore:rules
```

## 4. Проверенное состояние групп

На чистой базе создано 5 пользователей через приложение. Проверено:

- создание группы;
- групповые сообщения;
- добавление участника;
- назначение moderator;
- запрет выхода единственного администратора;
- передача прав;
- выход после передачи прав.

### Owner

`owner` поддерживается helpers, UI-названиями и проверками как роль максимального административного приоритета. Сейчас это заготовка для будущего развития. Роль нельзя удалять или упрощать. Основной текущий поток групп использует `admin`; расширение owner выполнять отдельно, сохраняя защиту последнего администратора.

## 5. Media Foundation и будущая Avatar Foundation

Стабильная база `v0.6.2-media-foundation` содержит:

- `MediaAsset`;
- `MediaStorageProvider`;
- `FirebaseMediaStorageProvider`;
- `MediaStorageService`;
- `MediaPaths`;
- Firebase Storage и Storage Rules.

Старый незавершённый avatar prototype сохранён в:

```text
archive/avatar-prototype-wip
```

Не возвращать его автоматически.

Чистая Avatar Foundation ещё не начата. Обязательная схема:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

avatarProvider
avatarThumbUrl
avatarFullUrl
avatarThumbStoragePath
avatarFullStoragePath
avatarVersion
avatarUpdatedAt
```

Private chat получает аватар только через другого участника:

```text
chat.memberIds → otherUserId → users/{otherUserId}
```

Общий `avatarUrl` в private chat запрещён.

Перед Avatar Foundation договорено проверить и при необходимости очистить тестовые Firebase-данные.

## 6. Известный технический долг

### Высокий приоритет

1. **Push Notification Foundation.** Подключить FCM на Android, хранение устройств пользователя, foreground/background handling и Cloud Function на создание сообщения.
2. **Rules emulator tests.** Firestore Rules задеплоены и проверены вручную, но требуют автоматизированных тестов.
3. **Оптимизация Firestore reads.** Убрать отдельный listener вибрации и пересмотреть подсчёт unread без загрузки всех непрочитанных message documents.

### Средний приоритет

- README.md и ARCHITECTURE.md частично устарели относительно ветки.
- ARCHITECTURE.md нужно позже разделить на отдельные документы.
- Нужны тесты одновременного первого сообщения с двух устройств.
- Нужно определить будущий UX удаления отдельных сообщений.
- Для тяжёлых медиа нужны лимиты, сжатие, превью и кэш.

## 7. Неприкосновенные функции

Нельзя ломать:

- соответствие Firebase Auth UID документу `users/{uid}`;
- private/group сообщения;
- создание private chat только при первом сообщении;
- отсутствие пустых private chats;
- `firstMessageId` и атомарное первое сообщение;
- персональную очистку без физического удаления;
- возврат скрытого чата после нового сообщения;
- поиск пользователей и контактов;
- роли, mute/ban и permissions;
- добавление участников;
- защиту последнего администратора;
- передачу прав и безопасный выход;
- Media Foundation abstractions;
- будущую роль owner максимального приоритета.

## 8. Рекомендуемый порядок продолжения

1. Обновить README.md, ARCHITECTURE.md и PROJECT_CONTEXT.md.
2. Выполнить финальные analyze/test/build проверки.
3. Merge в `main` и создать тег `v0.6.2.1`.
4. Создать ветку `feat/v0.6.3-push-notification-foundation`.
5. Подключить FCM на физическом Android-телефоне и проверить тестовое уведомление из Firebase Console.
6. Добавить регистрацию устройств и Cloud Function для новых сообщений.
7. После Push Foundation реализовать удаление сообщений у себя/у всех.
8. Затем перейти к чистой Avatar Foundation.

## 9. Команды Windows

```powershell
dart format lib test
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug

firebase.cmd use
firebase.cmd deploy --only firestore:rules
firebase.cmd deploy --only storage

git status
git log --oneline --decorate --graph -n 30
git tag
```

APK:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 10. Сопровождение контекста

После каждого крупного этапа обновлять этот файл. Если его станет недостаточно, заранее предупредить владельца проекта и создать дополнительные документы, не теряя контрольную точку.