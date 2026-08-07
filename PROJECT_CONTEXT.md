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

Текущий release:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

Текущий code HEAD:

```text
Текущий code HEAD:

```text
7f12f40 perf(chat): lazy-load identity card content
```

Release merge:

```text
d91270c merge: release v0.7.4 Avatar Interaction and Notification Controls
```

Feature commit:

```text
526504c feat(chat): add avatar cards and notification controls
```

Feature branch:

```text
feat/v0.7.4-avatar-interaction-card-foundation
```

Feature branch отправлена в origin.

`main` синхронизирован с `origin/main` на commit `7f12f40`.

Release tag: `v0.7.4`. Tag создаётся на финальном release state после синхронизации документации.

Целевой tag:

```text
v0.7.4
```

## 2. Что завершено в v0.7.4

Этап включает:

```text
1. Chat Identity Card Foundation
2. Group card actions
3. Per-chat Notification Settings
4. Firestore security for notification settings
5. Server notification delivery modes
6. Custom Epistola seagull notification sound
7. Android background/lock-screen vibration hardening
8. Final architecture cleanup
9. Image message push preview fix
10. Lazy identity-card content / full-avatar loading
```

Важное ограничение scope:

```text
identity-card foundation завершён для header открытого private/group chat
```

Не заявлять:

```text
все аватары во всём приложении уже кликабельны
```

Оставшиеся avatar contexts находятся в roadmap.

## 3. Chat Identity Card Foundation

### 3.1 Entry point

Файлы:

```text
lib/widgets/chat_app_bar_title.dart
lib/widgets/chat/chat_app_bar.dart
lib/screens/chat_screen.dart
```

`ChatAppBarTitle` получил optional `onTap`.

В открытом private/group chat нажатие по title area открывает identity overlay.

### 3.2 Overlay

Новые файлы:

```text
lib/widgets/chat/chat_identity_overlay.dart
lib/widgets/chat/chat_identity_background.dart
lib/widgets/chat/chat_identity_card_content.dart
lib/widgets/chat/chat_identity_action_button.dart
```

Параметры:

```text
panel height ≈ 64%
animation 340 ms
bottom radius 28
dim scrim
```

Закрытие:

```text
tap lower chat
back arrow
system Back
```

При system Back:

```text
overlay open
→ close overlay
→ stay in chat
```

Следующий Back выполняет обычный leave lifecycle.

### 3.3 Avatar background

Приоритет:

```text
full Storage path + version
→ existing AvatarImageLoader
→ legacy URL
→ gradient + initials fallback
```

Rendering:

```text
BoxFit.cover
```

Поверх изображения добавлен gradient.
Identity-card content монтируется лениво:

```text
chat opened
→ identity-card content not mounted
→ full avatar not requested

first identity-card open
→ content mounted
→ full avatar load starts
→ fallback visible while loading

next opens in the same chat route
→ mounted content reused
→ loaded avatar reused

### 3.4 Private card

Показывает:

```text
name
about
phone
```

Action:

```text
Уведомления
```

### 3.5 Group card

Показывает:

```text
group name
member count
```

Actions для member:

```text
Уведомления
Участники
```

Actions для admin/owner:

```text
Уведомления
Участники
Управление
```

Owner сохраняет максимальный приоритет.

### 3.6 Members-only screen

`GroupInfoScreen` получил:

```text
membersOnly = false
```

При:

```text
membersOnly: true
```

screen title:

```text
Участники
```

и body содержит только `GroupMembersSection`.

### 3.7 Manual identity-card scenarios

Проверены:

- private avatar;
- private initials fallback;
- group avatar;
- group fallback;
- opening from chat header;
- closing by Back;
- closing by tap outside;
- draft remains;
- chat remains on same route;
- participants navigation;
- management navigation;
- admin vs ordinary member action set.
- first open starts full-avatar loading only when identity-card is actually opened;
- fallback is shown during first full-avatar load;
- repeated opening reuses already loaded identity-card content.

## 4. Per-chat Notification Settings

### 4.1 Data

Chat document:

```text
notificationSettingsByUser: {
  uid: {
    mode: "sound" | "silent" | "disabled",
    expiresAt?: timestamp,
    permanent?: true
  }
}
```

### 4.2 Final model location

Файл:

```text
lib/models/chat_notification_settings.dart
```

Важно:

```text
НЕ lib/domain/models/
```

Причина: model содержит Firestore mapping и `Timestamp`.

Post-merge cleanup:

```text
730bab0 refactor(chat): move notification settings out of domain
```

Это сохраняет правило pure domain без Firebase dependency.

### 4.3 Effective modes

```text
sound
silent
disabled
```

Fallback:

```text
missing / invalid / expired
→ sound
```

### 4.4 Service

Файл:

```text
lib/services/chat/chat_notification_settings_service.dart
```

Methods:

```text
enableSound()
disableNotifications()
silenceFor()
silenceForever()
```

Temporary silent:

```text
1 hour
24 hours max in application service
```

Unauthenticated:

```text
skippedUnauthenticated
```

Write target:

```text
notificationSettingsByUser.{currentUid}
```

### 4.5 UI sheet

Файл:

```text
lib/widgets/chat/chat_notification_settings_sheet.dart
```

Main options:

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

Current state is indicated with check mark.

`Звук уведомлений`:

```text
Пока в разработке
```

## 5. Firestore notification security

Файл:

```text
firestore.rules
```

New boundary:

```text
isOwnNotificationSettingsUpdate()
```

Rules require:

- signed-in;
- current member;
- changed chat field only `notificationSettingsByUser`;
- changed nested UID only `request.auth.uid`;
- strict schema;
- valid mode;
- valid temporary silent expiry;
- no unrelated field mutation.

Broad admin/owner update path explicitly excludes:

```text
notificationSettingsByUser
```

Поэтому admin/owner не может менять notification settings другого group member.

New rules test:

```text
test/rules/firestore/chat_notification_settings_rules.test.mjs
```

Scenarios:

```text
12 passed
```

Full Firestore suite final:

```text
tests 65
suites 6
pass 65
fail 0
```

`PERMISSION_DENIED` lines в негативных scenarios являются ожидаемым тестовым результатом.

Rules были deployed в Firebase project:

```text
epistola-434b7
```

## 6. Server push delivery modes

Файл:

```text
functions/src/index.ts
```

Function:

```text
sendMessageNotification
```

Delivery mode type:
Push body resolution:

```text
text
→ buildPushPreview(text)

image
→ "Фотография"

unsupported / incomplete
→ safe return

```text
sound
silent
disabled
```

Flow:

```text
message created
→ chat read
→ sender excluded
→ mode resolved per recipient
→ disabled recipients skipped
→ device queries only for sound/silent
→ tokens grouped by mode
→ batches ≤ 500
→ FCM send
→ invalid token cleanup
```

Missing/malformed/expired setting:

```text
sound
```

Disabled optimization:

```text
recipient disabled
→ no users/{uid}/devices read for that recipient
```

Это важно для Firebase cost model.

Final sound FCM config:

```text
channelId: epistola_messages_seagull_v3
sound: seagull_notification
vibrateTimingsMillis: [0, 250, 100, 250]
```

Silent:

```text
channelId: epistola_messages_silent
```

Targeted deploy `sendMessageNotification` выполнен после final vibration change и повторно после исправления image message push preview.

Release-blocker fix:

```text
5313fbd fix(push): support image notification preview
```

Ручная проверка после deploy:

```text
private image message
→ push received
→ body "Фотография"
→ seagull sound
→ vibration
```

## 7. Android notification layer

### 7.1 Local notification service

Файл:

```text
lib/services/notification_service.dart
```

Sound channel:

```text
epistola_messages_seagull_v3
```

Name:

```text
Сообщения Epistola — Чайка
```

Config:

```text
Importance.high
playSound true
seagull_notification
enableVibration true
vibrationPattern [0, 250, 100, 250]
```

Silent channel:

```text
epistola_messages_silent
playSound false
enableVibration false
```

### 7.2 Raw sound

Файл:

```text
android/app/src/main/res/raw/seagull_notification.mp3
```

Final file — усиленный пользовательски проверенный вариант.

В repository resource используется имя:

```text
seagull_notification
```

### 7.3 Keep file

Файл:

```text
android/app/src/main/res/raw/epistola_keep.xml
```

Keep:

```text
@raw/seagull_notification
@mipmap/ic_launcher
```

Причина: runtime resource reference не должен быть удалён release shrinker-ом.

### 7.4 Manifest

`AndroidManifest.xml`:

```text
com.google.firebase.messaging.default_notification_channel_id
=
epistola_messages_seagull_v3
```

Старый fallback:

```text
epistola_messages
```

удалён из финальной конфигурации.

Диагностические channels и старые seagull `v1/v2` удалены из рабочего кода.

## 8. Final notification behavior

### Режим sound

Если открыт список чатов / другой экран приложения:

```text
push
+ seagull
+ vibration
```

Android home:

```text
push
+ seagull
+ vibration
```

Locked screen:

```text
push
+ seagull
+ vibration
```

Active target chat:

```text
local push suppressed
seagull not played
short direct vibration
```

### Режим silent

Неактивный target:

```text
push only
```

Active target:

```text
no local push
no sound
no vibration
```

### Режим disabled

```text
no push
no sound
no vibration
```

При этом:

```text
message delivered
unread counter changes
chat data remains realtime
```

### Persistence

Notification mode сохраняется в Firestore и переживает navigation/reopen.

Temporary silent автоматически становится effective `sound` после expiry без обязательного cleanup write.

## 9. Active chat interaction

`ActiveChatTracker` из v0.7.3 сохранён.

Foreground local notification для открытого target chat подавляется.

Дополнительный incoming-message listener в `ChatScreen`:

```text
new peer message
→ current notification effective mode
→ sound only
→ NotificationService.vibrate()
```

Silent/disabled direct vibration не получают.

## 10. Финальные automated checks v0.7.4

### Flutter

```text
dart.bat format
→ final refactor files: 0 formatting changes

flutter.bat analyze
→ No issues found

flutter.bat test
→ 544 tests passed
```

Ожидаемый diagnostic JPEG output:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это не failure.

### Firestore Rules

```text
tests 65
suites 6
pass 65
fail 0
cancelled 0
skipped 0
```

### Functions

```text
npm.cmd --prefix functions run lint
→ no errors

npm.cmd --prefix functions run build
→ passed
```

Warning:

```text
TypeScript version compatibility with eslint parser
```

не блокирует build.

### Release APK

Последняя сборка после lazy identity-card optimization:

```text
flutter.bat build apk --release
→ build\app\outputs\flutter-apk\app-release.apk
→ 55.8 MB
```

Flutter/Kotlin plugin migration warning остаётся non-blocking.

### Unchanged Rules suites

В финальном gate v0.7.4 не перезапускались:

```text
Realtime Database Rules
Storage Rules
```

Они не изменялись текущим release.

Последний подтверждённый v0.7.3 baseline:

```text
RTDB Rules → 15 passed
Storage Rules → 42 passed
```

Не писать новый aggregate Security Rules total для v0.7.4 как будто все suites были перезапущены вместе.

## 11. Generated files

После последнего `flutter.bat build apk --release` восстановлены:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Они не входят в release code changes.

## 12. Git state

```text
feature branch:
feat/v0.7.4-avatar-interaction-card-foundation

feature commit:
526504c feat(chat): add avatar cards and notification controls

release merge:
d91270c merge: release v0.7.4 Avatar Interaction and Notification Controls

post-merge cleanup:
730bab0 refactor(chat): move notification settings out of domain

docs finalize:
a4adf4d docs: finalize v0.7.4 release

image push release-blocker fix:
5313fbd fix(push): support image notification preview

identity-card performance cleanup:
7f12f40 perf(chat): lazy-load identity card content

current branch:
main

target tag:
v0.7.4
```

На момент подготовки документации:

```text
Текущее состояние перед release tag:

```text
feature branch pushed
release merged
architecture cleanup committed
documentation committed
image push fix committed and deployed
lazy identity-card optimization committed
main synchronized with origin/main at 7f12f40
release tag: v0.7.4
```

## 13. Deploy state

Подтверждено:

sendMessageNotification deployed after image push preview fix
```

Existing infrastructure preserved:

```text
Realtime Database
RTDB Rules
ensurePrivateTypingAccess
Storage Rules
createFirstPrivateImageUploadGrant
```

Не выполнять дополнительный deploy без изменения соответствующего backend/rules файла.

## 14. Security invariants

Сохранены:

- Auth UID == `users/{uid}`;
- deterministic private chat ID;
- no empty private chats;
- atomic first message;
- pagination 20;
- realtime merge;
- scroll preservation;
- logical deletion;
- sender-only delete for everyone;
- private clear isolation;
- role/permission checks;
- owner priority;
- last-admin protection;
- image metadata validation;
- trusted first-image upload grant;
- avatar versioned paths;
- push sender exclusion;
- push deep-link validation;
- private read cursor ownership;
- group reaction UID ownership;
- server-owned private typing access projection;
- own typing node only.

Добавлены v0.7.4:

- own `notificationSettingsByUser.{uid}` update only;
- admins cannot change another member notification settings;
- `disabled` recipients receive no server push;
- silent mode has no sound/vibration;
- identity-card management action remains role-gated;
- identity overlay itself не является authorization boundary.

## 15. Cost model v0.7.4

### Identity-card

```text
0 additional chat-document listeners
```

Используется существующий `ChatScreen` snapshot.

Full avatar не загружается при простом входе в chat.

```text
chat opened
→ no identity-card mount
→ no full-avatar request

identity-card opened first time
→ full-avatar load

subsequent opens on same chat route
→ mounted content / loaded avatar reused

### Notification settings

```text
1 Firestore write per explicit user change
```

Нет heartbeat/periodic writes.

Expired silent не требует cleanup write, чтобы стать effective `sound`.

### Push

Disabled recipient:

```text
mode resolve from chat data
→ skip
→ no device subcollection read
```

Sound/silent recipients используют прежний token lifecycle.

## 16. Что v0.7.4 не меняет

Не менялись фундаментальные contracts:

- private chat creation;
- message schema;
- image media paths;
- pagination;
- logical deletion;
- read receipts;
- reactions;
- RTDB typing security;
- deep-link resolver.

Не добавлялись:

- file messages;
- voice messages;
- image captions;
- group image foundation;
- global avatar-card coverage;
- sound selector;
- in-app volume slider.

## 17. Известные ограничения / backlog

### Attachment Composer

Нужен общий attachment draft:

```text
selected image/file
+ optional caption
+ validation
+ send orchestration
```

Photo caption должен быть consumer общего composer contract, а не отдельным hack.

### File Message Foundation

Будущее:

- file picker;
- metadata;
- size/type policy;
- upload lifecycle;
- preview;
- caption;
- rules;
- cleanup.

### Voice Message Foundation

Будущее:

- recording;
- permissions;
- duration;
- waveform/preview;
- upload;
- playback;
- cleanup.

### Avatar Interaction expansion

v0.7.4 завершает foundation только в chat header.

Дальше аудит/унификация:

- chat list;
- chat search;
- contacts;
- new message / user search;
- create group;
- add members;
- group member list;
- group member screen;
- profile / other avatar contexts.

### Search avatar issue

Отдельно проверить avatar presentation в:

```text
User Search
New Message
Create Group
Add Members
Members
```

Не считать это автоматически исправленным v0.7.4.

### Notification UX

Пункт выбора звука пока placeholder.

Future:

- выбор notification sound;
- возможно открытие системных channel settings;
- отдельный дизайн global sound preference.

Android system notification volume нельзя считать обычным Flutter slider contract без отдельной platform design.

### Branding

Будущее:

```text
текущая иконка отправки сообщения
→ фирменная vector-иконка чайки Epistola
```

Не использовать emoji как production send icon.

### Pending message deletion defect

Ранее отмечался private-chat сценарий:

```text
long-press peer message
→ "Удалить у себя"
→ действие может не примениться
```

Этот баг не входил в v0.7.4 и должен быть проверен/исправлен отдельным шагом, если всё ещё воспроизводится.

### Production hardening

- retention cleanup;
- App Check;
- production signing;
- observability;
- Firebase cost monitoring.

## 18. История стабильных foundation releases

```text
v0.6.2   Media Foundation
v0.6.2.1 Security Foundation
v0.6.3   Push Notification Foundation
v0.6.4   Message Deletion Foundation
v0.6.5   Avatar Foundation
v0.6.6   Android Toolchain Foundation
v0.7.0   Image Message Foundation
v0.7.1   Push Deep Link Foundation
v0.7.2   Chat Date Separator Foundation
v0.7.3   Messaging Feedback Foundation
v0.7.4   Avatar Interaction/Card + Notification Controls Foundation
```

## 19. Правила совместной работы

- Язык — русский.
- Windows + PowerShell + VS Code.
- Команды: `flutter.bat`, `dart.bat`, `firebase.cmd`, `npm.cmd`, обычный `git`.
- Работать маленькими проверяемыми шагами.
- После шага ждать вывод/скриншот.
- Большие изменения давать полными файлами.
- Не создавать functional commit до ручной проверки сценария.
- Generated plugin files восстанавливать один раз после последних Flutter-команд.
- Owner сохраняет максимальный приоритет в group logic.
- Не добавлять временные feature flags без отдельного решения.
- Не увеличивать Firebase reads без необходимости.

## 20. Следующий release flow

Сейчас:

final documentation sync
→ git diff --check
→ docs-only commit
→ push main
→ verify origin/main
→ create tag v0.7.4
→ push tag
→ verify remote tag
→ verify clean working tree
```

После публикации:

```text
git status --short
→ empty
```

Следующий продуктовый этап выбирается только после завершения release v0.7.4.
