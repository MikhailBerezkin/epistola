# Epistola — Project Context

> Живой документ состояния проекта.
>
> Использовать как основной handoff между чатами, рабочими сессиями и аккаунтами.
>
> При расхождении источников приоритет:
>
> ```text
> исходный код
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Realtime Database region: `europe-west1`
- Cloud Functions region: `europe-west1`
- Android package: `com.epistola.app`
- Основная платформа: Android
- Целевая пилотная группа: 40–50 пользователей

Последняя стабильная версия:

```text
v0.7.2 — Chat Date Separator Foundation
```

Стабильный `main` перед текущим release candidate:

```text
main documentation head: 8e6f8fe
tag: v0.7.2
release merge: 7d8357a
```

Текущая ветка:

```text
feat/v0.7.3-messaging-feedback
```

Текущий functional HEAD:

```text
60b3fef feat(chat): add private typing indicator
```

Текущий этап:

```text
v0.7.3 — Messaging Feedback Foundation
```

Состояние этапа:

```text
active chat notification suppression реализован
→ private read receipts реализованы
→ group message reactions реализованы
→ private typing indicator реализован
→ RTDB подключена
→ callable access projection развёрнут
→ Rules tests пройдены
→ full analyze пройден
→ full Flutter tests пройдены
→ release APK собран
→ ручные сценарии телефон ↔ эмулятор пройдены
→ функциональные commits отправлены в origin
→ документы подготавливаются
→ release merge и tag ещё не созданы
```

Функциональные commits:

```text
f901c06 fix(chat): suppress active chat notifications
8228f9a feat(chat): add private read receipts
d10c110 feat(chat): add group message reactions
60b3fef feat(chat): add private typing indicator
```

Итоговые проверки release candidate:

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

APK установлен на Android Emulator и физический телефон. Оба устройства использовались для двусторонних realtime-сценариев.

Generated plugin files восстановлены и не входят в functional commit.

## 2. Цель v0.7.3

Добавить пользователю обратную связь о текущем состоянии общения без изменения базовой message delivery architecture.

Этап разделён на четыре части:

```text
1. Active Chat Notification Suppression
2. Private Read Receipt Foundation
3. Group Message Reactions
4. Private Typing Indicator Foundation
```

Границы:

- read receipts только в private chats;
- reactions только в group chats;
- typing только в private chats;
- push suppression только для foreground и только для текущего chat ID;
- никаких feature flags;
- экономное использование Firebase для пилота 40–50 пользователей.

## 3. Active Chat Notification Suppression

Проблема:

```text
пользователь находится в открытом чате
→ приходит новое сообщение того же чата
→ приложение показывает foreground notification
```

Решение:

```text
lib/services/chat/active_chat_tracker.dart
lib/services/notification_service.dart
lib/screens/chat_screen.dart
```

Flow:

```text
ChatScreen.initState
→ activeChatTracker.enter(chatId)

foreground FCM
→ PushDeepLinkRequest
→ activeChatTracker.isCurrent(chatId)
→ same chat: notification suppressed
→ another chat: notification shown

ChatScreen.dispose
→ activeChatTracker.leave(registration)
```

Registration identity поддерживает вложенные routes и повторный вход в один chat ID.

Ручная проверка:

```text
сообщение в открытом чате
→ push не показывается

сообщение из другого чата
→ push показывается и unread counter обновляется
```

Commit:

```text
f901c06 fix(chat): suppress active chat notifications
```

## 4. Private Read Receipt Foundation

Требование:

```text
✓  сообщение сохранено
✓✓ собеседник прочитал
```

Только private chats. Группы не получают галочки.

### 4.1 Domain cursor

Файл:

```text
lib/domain/models/private_read_cursor.dart
```

`PrivateReadCursor`:

- валидирует `messageId`;
- хранит UTC timestamp;
- определяет покрытие сообщения;
- не откатывается назад;
- сравнивает одинаковые timestamps по `messageId`.

### 4.2 Firestore state

В chat document:

```text
privateReadState: {
  uid: {
    messageId: string,
    messageCreatedAt: timestamp,
    readAt: timestamp
  }
}
```

Совместно обновляется `lastRead/{uid}` для unread state списка чатов.

### 4.3 Services

```text
lib/services/chat/private_read_cursor_mapper.dart
lib/services/chat/private_read_cursor_resolver.dart
lib/services/chat/private_read_receipt_service.dart
lib/services/chat/private_read_receipt_debouncer.dart
```

Flow:

```text
MessagesList resolves latest eligible visible cursor
→ ChatScreen schedules cursor
→ debouncer merges repeated progress
→ service writes lastRead + privateReadState
```

При выходе выполняется `flushNow()` best-effort.

### 4.4 UI

```text
lib/widgets/chat/private_read_receipt_indicator.dart
lib/widgets/message_bubble.dart
lib/widgets/message_item.dart
lib/widgets/messages_list.dart
```

Только исходящее private message:

```text
peer cursor does not cover message → ✓
peer cursor covers message → ✓✓
```

Text и image presentation используют одинаковую модель.

### 4.5 Rules

Файл:

```text
firestore.rules
```

Rules разрешают менять только собственный read cursor и проверяют:

- auth;
- private membership;
- неизменность members;
- schema cursor;
- существование message;
- совпадение createdAt;
- server request time;
- monotonic progression.

### 4.6 Ручная проверка

```text
sender sees ✓
recipient opens chat
sender sees ✓✓
private only
groups unchanged
```

Commit:

```text
8228f9a feat(chat): add private read receipts
```

## 5. Group Message Reactions

Требование:

```text
👍 like
👎 dislike
```

Только group chats.

### 5.1 Domain

Файл:

```text
lib/domain/models/group_message_reaction.dart
```

States:

```text
none
like
dislike
```

Transitions:

```text
none + like → like
like + like → none
like + dislike → dislike
none + dislike → dislike
dislike + dislike → none
dislike + like → like
```

### 5.2 Message data

```text
reactions: {
  uid: "like" | "dislike"
}
```

Один UID имеет максимум одно значение.

### 5.3 Services

```text
lib/services/chat/group_message_reaction_mapper.dart
lib/services/chat/group_message_reaction_service.dart
```

Transaction flow:

```text
read message
→ map reactions
→ resolve current UID state
→ set like/dislike or delete own key
```

### 5.4 UI

```text
lib/widgets/chat/group_message_reaction_bar.dart
lib/widgets/messages_list.dart
lib/widgets/message_item.dart
```

Показываются counters `👍` и `👎`. Выбранная текущим пользователем реакция выделяется.

Private chats не включают reaction UI.

### 5.5 Rules

```text
test/rules/firestore/group_message_reaction_rules.test.mjs
```

Разрешено:

- active group member;
- изменение только `reactions`;
- внутри map изменение только текущего UID;
- значение `like`, `dislike` или удаление собственного ключа.

Запрещено:

- private chat;
- чужой UID;
- произвольное значение;
- удалённое для всех сообщение;
- изменение другого поля сообщения вместе с reaction.

Reaction updates не отправляют push.

Commit:

```text
d10c110 feat(chat): add group message reactions
```

## 6. Private Typing Indicator Foundation

Требование:

```text
собеседник вводит сообщение
→ Пишет...

нет typing state
→ личный чат
```

Только private chats через Firebase Realtime Database.

### 6.1 Realtime Database

Создана default RTDB:

```text
https://epistola-434b7-default-rtdb.europe-west1.firebasedatabase.app
```

Region:

```text
europe-west1
```

FlutterFire configuration обновлена для Android, iOS, macOS, Web и Windows.

Зависимость:

```text
firebase_database
```

### 6.2 Paths

```text
privateChatAccess/{chatId}/{uid} = true
privateTyping/{chatId}/{uid} = server timestamp
```

`privateChatAccess` — server-owned projection. Клиент не имеет права писать или читать access tree напрямую.

### 6.3 Cloud Function

Файл:

```text
functions/src/index.ts
```

Callable:

```text
ensurePrivateTypingAccess
```

Проверки:

- authenticated caller;
- непустой безопасный `chatId`;
- Firestore chat существует;
- `type == private`;
- `isDissolved != true`;
- ровно два уникальных valid member IDs;
- caller является member.

После проверки функция записывает двух участников в `privateChatAccess/{chatId}`.

Function развёрнута в:

```text
europe-west1
nodejs22
```

### 6.4 RTDB Rules

Файл:

```text
database.rules.json
```

Разрешения:

```text
read typing only when privateChatAccess/{chatId}/{auth.uid} == true
write only privateTyping/{chatId}/{auth.uid}
value must be numeric current-like timestamp
own node deletion allowed
foreign UID write denied
access projection client read/write denied
```

Тесты:

```text
test/rules/database/private_typing_rules.test.mjs
15 tests passed
```

Rules развёрнуты в Firebase project `epistola-434b7`.

### 6.5 PrivateTypingService

Файл:

```text
lib/services/chat/private_typing_service.dart
```

Ответственность:

- callable preparation;
- session cache;
- `onDisconnect().remove()`;
- `ServerValue.timestamp`;
- own state remove;
- exact peer path subscription;
- identifier validation;
- injectable delegates для unit tests.

Тесты:

```text
test/services/chat/private_typing_service_test.dart
15 tests passed
```

### 6.6 PrivateTypingCoordinator

Файл:

```text
lib/services/chat/private_typing_coordinator.dart
```

Timing:

```text
initial debounce: 450 ms
heartbeat: 3 s
inactivity stop: 4 s
```

Operation queue сериализует remote operations.

Immediate stop:

```text
empty field
text send
image send success
leave chat
dispose
```

Тесты:

```text
test/services/chat/private_typing_coordinator_test.dart
15 tests passed
```

### 6.7 Peer freshness

В `ChatScreen`:

```text
peer timestamp freshness: 6 s
future skew rejection: approximately 10 s
```

Даже если network disconnect cleanup задержался, stale UI скрывается локальным timer.

### 6.8 UI

Файлы:

```text
lib/screens/chat_screen.dart
lib/widgets/chat/chat_app_bar.dart
```

Private header:

```text
peerIsTyping == true → Пишет...
peerIsTyping == false → личный чат
```

Group header остаётся:

```text
N участников
```

### 6.9 Ручная проверка

Проверено в обоих направлениях телефон ↔ эмулятор:

- индикатор появляется при вводе;
- не исчезает при длительном активном вводе;
- исчезает после idle;
- исчезает при clear;
- исчезает после send;
- исчезает при выходе;
- stale state не возвращается при повторном входе;
- после force close исчезает по disconnect/freshness timer;
- в group chat не появляется.

Commit:

```text
60b3fef feat(chat): add private typing indicator
```

## 7. Автоматические проверки

### Flutter

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 535 tests passed
```

Ожидаемый diagnostic output image tests:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это не ошибка suite.

### Security Rules

```text
Realtime Database Rules → 15 passed
Firestore Rules → 53 passed
Storage Rules → 42 passed
Total → 110 passed
```

### Functions

```text
lint → passed
build → passed
```

Существующее TypeScript/ESLint compatibility warning не блокирует build.

### Release APK

```text
flutter.bat build apk --release
→ built build\app\outputs\flutter-apk\app-release.apk
→ 55.7 MB
```

Build warnings:

- Built-in Kotlin migration warning от Firebase/image plugins;
- deprecated/unchecked Java API notes.

Они не блокируют release build и не исправляются внутри `v0.7.3`.

## 8. Security invariants

Сохранены:

- Auth UID == `users/{uid}`;
- deterministic private chat ID;
- отсутствие пустых private chats;
- atomic first message;
- pagination по 20;
- realtime merge;
- scroll position;
- near-bottom-only autoscroll;
- logical deletion;
- sender-only delete for everyone;
- private clear только для текущего пользователя;
- роли и permissions;
- last-admin protection;
- push sender exclusion;
- image metadata и upload grant;
- avatar paths;
- Firebase free-tier controls.

Добавлены:

- active chat foreground notification suppression;
- private monotonic read cursor;
- own read-state update only;
- one reaction per UID;
- group-only reaction rule;
- server-owned RTDB access projection;
- own typing node only;
- onDisconnect cleanup;
- stale peer timestamp guard.

## 9. Cost model v0.7.3

### Active chat suppression

```text
0 additional backend operations
```

### Read receipts

- debounce объединяет cursor writes;
- final flush выполняется один раз при выходе;
- никаких writes на каждое сообщение.

### Reactions

- один Firestore transaction на toggle;
- counters вычисляются из существующего snapshot;
- push не создаётся.

### Typing

- RTDB вместо Firestore;
- 450 ms initial debounce;
- heartbeat раз в 3 секунды только при активности;
- stop после 4 секунд idle;
- один exact peer listener;
- access callable кэшируется на session.

## 10. Generated files

После последних Flutter-команд один раз восстановлены:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Команда:

```powershell
git restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugins.cmake
```

Не восстанавливались, потому что являются необходимыми изменениями feature:

```text
pubspec.yaml
pubspec.lock
lib/firebase_options.dart
android/app/google-services.json
firebase.json
database.rules.json
```

## 11. Deploy state

Подтверждено:

```text
Realtime Database создана
Realtime Database Rules deployed
ensurePrivateTypingAccess deployed
```

Callable configuration:

```text
region: europe-west1
runtime: nodejs22
```

Firestore Rules содержат private read receipt и group reaction boundaries и проверены emulator tests и ручными сценариями.

Перед release merge не выполнять ненужный полный Functions deploy. Использовать targeted deploy только при реальном изменении backend-кода.

## 12. Git state

Feature branch:

```text
feat/v0.7.3-messaging-feedback
```

Remote sync после functional commit:

```text
60b3fef pushed to origin/feat/v0.7.3-messaging-feedback
```

Рабочее дерево перед документами было чистым.

Следующий expected commit:

```text
docs: prepare v0.7.3 release
```

После него:

```text
push feature branch
→ switch main
→ pull/verify main
→ merge --no-ff feature branch
→ create tag v0.7.3
→ push main and tag
→ final documentation update with actual merge SHA
```

Коммит и merge выполнять только маленькими проверяемыми шагами.

## 13. Следующий непосредственный шаг

1. Заменить `README.md`, `ARCHITECTURE.md`, `PROJECT_CONTEXT.md` полными версиями `v0.7.3`.
2. Проверить:

```powershell
git status --short
git diff --check
git diff --stat
```

3. Создать документационный commit.
4. Отправить feature branch.
5. Выполнить release merge в `main`.
6. Создать tag `v0.7.3`.
7. Обновить документы фактическим release merge SHA и финальным состоянием.

## 14. Roadmap после v0.7.3

### Attachment Composer Foundation

Цель — общий attachment draft вместо временной подписи только к фотографии.

```text
selected image/file
+ optional caption
+ validation
+ send orchestration
```

Photo caption должен стать первым consumer общего composer contract.

### File Message Foundation

- file picker;
- metadata;
- size/type policy;
- upload lifecycle;
- preview;
- caption support;
- security rules;
- cleanup.

### Voice Message Foundation

- запись;
- permission lifecycle;
- duration;
- waveform/preview;
- upload;
- playback;
- cleanup.

### Clickable Avatar and Profile Card Foundation

Аватары и имена должны открывать единый профиль/карточку во всех ключевых местах:

- private chat header;
- group member list;
- contacts;
- chat list;
- reaction/member contexts.

### Production hardening

- retention cleanup;
- App Check;
- release signing;
- observability;
- Firebase cost monitoring.

## 15. Правила совместной работы

- Язык работы — русский.
- Windows + PowerShell + VS Code.
- Команды: `flutter.bat`, `dart.bat`, `firebase.cmd`, `npm.cmd`, обычный `git`.
- Делать маленькие проверяемые шаги.
- После каждого шага ждать вывод или скриншот пользователя.
- Большие изменения давать полными файлами.
- Не создавать commit до ручной проверки функционального сценария.
- Generated plugin files восстанавливать один раз после последних Flutter-команд.
- Приоритет owner в group logic сохраняется.
- Firestore pagination page size остаётся 20.
- Не добавлять временные feature flags без отдельного решения.
