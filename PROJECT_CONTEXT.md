# Epistola — Project Context

> Живой документ состояния проекта. Использовать как главный handoff между чатами и аккаунтами. При расхождении приоритет: исходный код → этот документ → ARCHITECTURE.md → README.md.

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Рабочая ветка: `fix/v0.6.2.1-security-foundation`
- Текущий HEAD перед обновлением документации: `0e42c4e`
- Последний стабильный тег: `v0.6.2-media-foundation`
- База ветки: `main`, commit `4fa8693` (`feat(media): create media storage foundation`)
- Ветка опережает `main` на 6 коммитов.
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Android package: `com.epistola.app`
- Основная текущая платформа: Android.

Последние важные коммиты:

```text
0e42c4e feat: clear private chat for current user
196f9a0 feat: create private chat on first message
e802d6d security: validate private chat creation
d221d99 security: validate new chat messages
bc9cb23 feat: add message text constraints
1a5072f test: replace obsolete counter smoke test
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
- разрешают менять только свой ключ `clearedAtByUser` и `lastRead`;
- запрещают клиентское удаление chat/message documents;
- сохраняют проверки ролей, mute/ban, добавления участников, выхода и защиты последнего администратора.

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

1. **Обычная отправка сообщения не атомарна.** `ChatMessagesService.sendMessage()` создаёт сообщение и затем отдельно обновляет `lastMessage/lastMessageAt`. Следующий рекомендуемый технический этап — batch/transaction плюс усиление Rules.
2. **Пагинация сообщений.** Сейчас загружается вся доступная история либо вся история после `clearedAt`.
3. **Rules emulator tests.** Firestore Rules задеплоены и проверены вручную, но требуют автоматизированных тестов и рефакторинга форматирования.

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

1. Сделать обычную отправку message + chat metadata атомарной.
2. Добавить тесты.
3. Повторить smoke test private/group chats.
4. Обновить README.md и ARCHITECTURE.md.
5. Решить выпуск `v0.6.2.1 Security Foundation`, merge в `main` и тег.
6. После стабильной точки начать чистую `v0.6.3 Avatar Foundation`.

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