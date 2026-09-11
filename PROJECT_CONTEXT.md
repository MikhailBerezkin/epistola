# Epistola — Project Context

> Живой operational handoff-документ проекта.
>
> При конфликте источников:
>
> ```text
> исходный код текущей feature-ветки
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```
>
> Не использовать `main` как источник текущего состояния `v0.8.0`, пока feature-ветка не merged/released.

---

# 1. Актуальная контрольная точка

Repository:

```text
MikhailBerezkin/epistola
```

Feature branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Текущий functional checkpoint:

```text
67800f0
feat(push): add installation ownership foundation
```

Предыдущий крупный checkpoint:

```text
1ca3bcf
feat(app): add test mode and refine web avatars and spaces bar
```

Предыдущий Web checkpoint:

```text
a488c3b
feat(web): add EpiLite web client
```

Выбранные более ранние checkpoints:

```text
f0a2084
feat(spaces): add chats unread badge

85238a2
feat(spaces): add substitution list editing

e7ac582
feat(auth): clean deleted users from spaces

544fcaf
chore(android): update launcher icon

9ebf9ab
feat(spaces): add confirmed substitution call delivery

123cda1
feat(spaces): add realtime spaces bar notifications
```

Последний стабильный release до `v0.8.0`:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

`v0.8.0` всё ещё находится в feature-ветке.

Без отдельного Git-подтверждения не считать выполненными:

```text
merge в main
release declaration
release tag
```

Документационный commit после этого файла сделает `HEAD` новее `67800f0`.

В новом чате обязательно сначала проверить фактические:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

---

# 2. Финальная проверка functional checkpoint 67800f0

Flutter:

```text
flutter.bat analyze
→ No issues found
→ 6.0 s

flutter.bat test
→ 981 tests passed
```

Во время полного Flutter suite может появляться diagnostic JPEG output:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

Если итог:

```text
All tests passed!
```

это не падение suite.

Functions ownership tests:

```text
node --test
  test/push_installation_ownership.test.cjs
  test/push_installation_ownership_service.test.cjs

→ 19 tests
→ 19 passed
```

Functions quality:

```text
npm.cmd run lint
→ passed

npm.cmd run build
→ tsc passed
```

ESLint выводит существующее предупреждение совместимости:

```text
@typescript-eslint/typescript-estree
supports TypeScript <5.2
current TypeScript = 6.0.3
```

На текущем checkpoint это предупреждение не ломает lint/build.

Firestore Rules targeted:

```text
push_device_rules.test.mjs
→ 6/6 passed
```

Full Firestore Rules suite:

```text
185 tests
12 suites
185 passed
0 failed
```

Git:

```text
git diff --check
→ clean

generated Flutter plugin files
→ восстановлены после финальной Flutter-команды
→ в functional commit не попали

working tree после functional commit/push
→ clean
```

Functional commit уже отправлен:

```text
origin/feat/v0.8.0-spaces-substitution-foundation
→ 67800f0
```

---

# 3. Production deploy state на checkpoint 67800f0

Задеплоены в production только callable Functions:

```text
claimPushInstallation
releasePushInstallation
```

Команда:

```powershell
firebase.cmd deploy --only functions:claimPushInstallation,functions:releasePushInstallation
```

Deploy completed successfully.

Production registry уже мигрировал на:

```text
pushInstallations/{installationId}

schemaVersion = 2
userId = <current authenticated user uid>
platform = android
token = <FCM token>
updatedAt = server timestamp
```

Legacy field:

```text
ownerUserId
```

больше не используется в новых документах.

Schema v1 с `ownerUserId` читается только для безопасной автоматической миграции на schema v2.

Важно:

```text
Firestore Rules, закрывающие direct client writes в users/{uid}/devices,
ЕЩЁ НЕ DEPLOYED.
```

Они готовы локально, полностью протестированы, входят в commit `67800f0`, но production Rules пока оставлены старые для периода миграции пользователей на новый APK.

---

# 4. Причина push-инцидента и подтверждённый root cause

Owner Android Poco ранее использовался для создания/входа в аккаунты коллег до появления Web-клиента.

Одна физическая установка имела стабильный:

```text
installationId = ba4a84ff3faf57cadce0db0e9f8ba269
```

и один FCM token, но этот token оказался сохранён под несколькими пользователями:

```text
users/{uid}/devices/{installationId}
```

Server push рассылал уведомления всем token-документам получателя.

App role `owner` здесь не имела специального значения.

Root cause:

```text
stale duplicated device ownership
```

а не:

```text
owner role
chat memberIds
push deep-link routing
```

Ручная очистка старых Poco device-документов у чужих пользователей подтвердила диагноз:

```text
сообщения Андриенко / Яковец
→ больше не создавали push на Owner Poco
```

---

# 5. Новый invariant Push Installation Ownership

Основное правило:

```text
one Epistola installation / installationId
→ one current authenticated account
```

При этом:

```text
one account
→ any number of its own installations/devices
```

FCM token — адрес доставки, а не постоянная identity физической установки.

Стабильная локальная identity:

```text
installationId
```

Генерация клиента:

```text
16 random secure bytes
→ 32 lowercase hex chars
→ SharedPreferences key: push_installation_id
```

---

# 6. Canonical push installation registry

Authoritative registry:

```text
pushInstallations/{installationId}
```

Schema v2:

```text
schemaVersion
userId
token
platform
updatedAt
```

Терминология:

```text
userId
```

означает текущего authenticated user, которому принадлежит installation.

Это НЕ связано с app role:

```text
member
brigadier
owner
```

Именно поэтому legacy поле `ownerUserId` переименовано в `userId`.

---

# 7. Callable ownership API

Functions region:

```text
europe-west1
```

Callables:

```text
claimPushInstallation
releasePushInstallation
```

Client никогда не передаёт `userId`.

Backend использует:

```text
callableRequest.auth.uid
```

Claim exact request:

```text
installationId
token
platform
```

Release exact request:

```text
installationId
```

Validation:

```text
installationId
→ exactly 32 lowercase hex

token
→ non-empty
→ trimmed
→ <= 4096 chars

platform
→ android only
```

Web push пока отключён, поэтому Web не участвует в ownership registry.

---

# 8. Claim transaction semantics

`claimPushInstallationOwnership` выполняет atomic Firestore transaction.

Flow:

```text
read pushInstallations/{installationId}
→ determine previous user
→ if previous user differs, delete old users/{previousUid}/devices/{installationId}
→ set users/{currentUid}/devices/{installationId}
→ set pushInstallations/{installationId}
```

Properties:

```text
same installation + same user
→ idempotent claim
→ token refresh updates token

same installation + another user
→ previous user's device doc removed atomically
→ current user receives same installation

same user + another physical installation
→ both device docs remain
→ multi-device supported
```

Release semantics:

```text
if caller == registry.userId
→ delete registry
→ delete caller device doc

if caller is stale old user
→ delete only caller stale device doc
→ never delete current owner's registry/device

if registry missing
→ cleanup caller stale device doc
```

---

# 9. Production ownership manual verification

Real production roundtrip was checked on Poco:

```text
Owner
→ Alex Born
→ Owner
```

When switching Owner → Alex:

```text
pushInstallations/ba4...
→ userId changed to Alex UID

Owner users/{uid}/devices/ba4...
→ removed

Alex users/{uid}/devices/ba4...
→ created
```

Alex already had another genuine installation:

```text
d000b7204fb83ce7b636ee0e7b4fe688
```

After Poco moved to Alex, both Alex devices coexisted.

When switching Alex → Owner:

```text
registry userId
→ Owner UID

Owner ba4...
→ restored

Alex ba4...
→ removed

Alex d000...
→ preserved
```

This confirms:

```text
one installation → one user
one user → multiple installations
stale logout cannot steal/remove current ownership
```

---

# 10. PushTokenService client behavior

File:

```text
lib/services/push_token_service.dart
```

Current client no longer writes device ownership directly to Firestore.

Instead:

```text
authStateChanges()
→ authenticated user
→ FirebaseMessaging.getToken()
→ claimPushInstallation

FirebaseMessaging.onTokenRefresh
→ claimPushInstallation

unregisterCurrentDevice()
→ releasePushInstallation
```

Because auth stream reacts to account switches, the same installation migrates even when creating/logging into another account without a conventional logout path.

Existing logout flows call `unregisterCurrentDevice()` before sign-out.

---

# 11. Device Rules migration state

Local `firestore.rules` now contains:

```text
match /devices/{deviceId} {
  allow get, list: if signedIn()
      && request.auth.uid == userId;

  allow create, update, delete: if false;
}
```

Reason:

```text
all push token ownership writes should go only through trusted Cloud Functions
```

Admin SDK in Cloud Functions bypasses client Firestore Rules, so callable ownership continues working.

However these restrictive Rules are intentionally NOT deployed yet.

Migration strategy:

```text
1. release/distribute new APK with callable ownership
2. give users migration window
3. verify most active Android users updated
4. only then deploy restrictive Firestore Rules
```

Planned window:

```text
approximately 5–7 days
```

A reminder/checkpoint was scheduled for this rollout.

If many users still run the legacy APK, defer Rules deploy.

Why:

```text
old APK still writes users/{uid}/devices directly
```

If restrictive Rules are deployed too early, old clients can lose ability to register/update/delete their FCM token documents.

---

# 12. Deleted Auth user cleanup — important remaining gap

Current Auth-delete cleanup removes:

```text
users/{uid}
device token documents
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Historical/business records remain:

```text
confirmedCalls
statistics
chats
messages
```

New top-level registry:

```text
pushInstallations/{installationId}
```

was added after the existing deleted-user cleanup foundation.

Therefore a future hardening task should explicitly audit/update deleted-user cleanup so stale registry docs owned by a deleted UID cannot remain indefinitely.

Do NOT assume this was already implemented.

Normal re-claim by another authenticated user can migrate the installation, but deleted-user cleanup should still gain an explicit registry path.

---

# 13. Development workflow

Environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Studio JBR
Java 21.0.10
Node 22
Firebase CLI
```

Preferred commands:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git
```

For Firebase emulator in a fresh PowerShell session, Java may need:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Workflow:

```text
small verifiable steps
risky actions separately
manual test before commit
commit / push / deploy only after explicit approval
large edit → full file
small edit → precise replacement
```

Generated Flutter plugin files:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Policy:

```text
leave dirty during Flutter command series
restore once after the last Flutter command
never repeatedly restore between Flutter commands
```

---

# 14. Special root docs workflow

Files:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Preferred workflow:

```text
assistant prepares all three complete files
→ packs exactly these three files into one ZIP
→ user extracts to temp
→ Copy-Item -Force to repository root
→ inspect diff
→ commit docs separately
```

Do not patch these three docs section-by-section unless explicitly requested.

---

# 15. Platform products

Full client:

```text
Android / Epistola
```

Lightweight Web/PWA:

```text
EpiLite
```

Shared backend:

```text
Firebase Auth
Firestore
Firebase Storage
Cloud Functions where applicable
```

Platform capability boundary:

```text
lib/platform/epistola_platform_capabilities.dart
```

Current broad policy still includes:

```text
supportsPushNotifications
→ Android true
→ Web false

supportsChats
→ Android true
→ Web false
```

Important current reality:

```text
Web private chats were discovered to function through
Contacts → user card → Написать
```

because that route is not gated by the same presentation capability.

Therefore:

```text
Web chats are not backend/security blocked
→ they are currently presentation-gated/incompletely exposed
```

Do not yet declare full Web Chats support.

A dedicated phase can officially open/verify Web chats after current push rollout work.

Web push remains disabled.

---

# 16. EpiLite avatar replacement

Web avatar replacement is implemented and manually verified on real iPhone Web/PWA users.

Flow:

```text
ImagePicker
→ ImageCropper Web
→ bytes
→ FlutterImageCompress
→ Firebase Storage putData
→ avatar metadata
```

Key Web support:

```text
web/index.html
→ Cropper.js integration
```

Manual iPhone verification:

```text
existing Firebase account
→ avatar selected
→ crop works
→ upload works
→ avatar visible
→ EpiLite can be pinned/installed on iPhone home screen
```

Keep Android/Web avatar implementation behind shared controllers/dependencies rather than duplicating UI behavior.

---

# 17. Epistola Test Mode

Runtime mode file:

```text
lib/platform/epistola_runtime_mode.dart
```

Enable:

```powershell
flutter.bat run --dart-define=EPISTOLA_TEST_MODE=true
```

Branding in Test Mode:

```text
Android title → Epistola Test
Web title → EpiLite Test
```

Current Test Mode protection is intentionally narrow.

It protects SpacesBar test work by avoiding production:

```text
spaces/spacesBar publication
spaces/spacesBar watch
SpacesBar management
```

and uses fake test messages for SpacesBar UI/animation work.

Critical limitation:

```text
Test Mode is NOT a full Firebase sandbox.
```

Android Test Mode can still initialize unrelated production Firebase/FCM paths.

Never assume `EPISTOLA_TEST_MODE=true` makes all backend operations safe.

Use it specifically for visual/animation/rotation SpacesBar work unless protection is explicitly expanded.

---

# 18. Spaces root and Hub

Root:

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Back:

```text
Контакты → Пространства
Профиль → Пространства
Пространства → exit
```

Current tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Working Android Spaces:

```text
Чаты
Список
```

Current Hub backlog:

```text
⋮ settings
show/hide Spaces
regular/compact layout
7–8 compact behavior
>8 behavior
odd final tile behavior
```

---

# 19. Chats unread summary

Checkpoint:

```text
f0a2084
feat(spaces): add chats unread badge
```

Architecture:

```text
ChatUnreadSummaryController
```

owns one user chat stream and derives centralized unread count.

Avoid:

```text
one Firestore unread query per ChatTile
```

Manual scenario previously verified:

```text
0 → 1 → 2 → 1 → 0
```

---

# 20. Spaces roles

Roles:

```text
member
brigadier
owner
```

`owner` remains highest-priority role.

Substitution managers:

```text
brigadier
owner
```

SpacesBar managers:

```text
brigadier
owner
```

UI visibility is not the security boundary.

Firestore Rules independently protect authoritative writes.

---

# 21. General SpacesBar backend

Authoritative document:

```text
spaces/spacesBar
```

Schema v1:

```text
revision
messages
updatedAt
```

General capacity:

```text
3 active announcements
```

Message ID:

```text
messageId = board revision
```

Lifetimes / accent semantics:

```text
1 hour → green
12 hours → blue
24 hours → orange
until cancelled → red
```

Lifetime controls expiry/accent, not priority.

Realtime source:

```text
spaces/spacesBar snapshots()
```

Local general hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

No Firestore write for local hide.

---

# 22. Final SpacesBar UI on current branch

Main widget:

```text
SpacesBarPanel
```

The previously deferred visual block is now completed.

Current behavior:

```text
stationary neutral outer frame
inner colored glow strongest near frame
glow fades inward toward neutral center
true cyclic/infinite swipe in both directions
PageView-based manual interaction
auto rotation through same PageController motion
manual swipe continuously interpolates glow color
no fade-to-dark transition
```

Current timing:

```text
auto dwell = 10 seconds
slide duration = 1000 ms
```

Current glow tuning checkpoint:

```text
strong edge alpha ≈ 45
inner alpha ≈ 10
```

Test palette used for visual verification:

```text
green
blue
orange
red
→ wraps cyclically
```

Presentation-only UI work did not change SpacesBar backend/business invariants.

Manual emulator/phone verification completed during the block.

Targeted widget tests were extended and passed before checkpoint `1ca3bcf`.

---

# 23. Personal substitution SpacesBar

Unified presentation model:

```text
SpacesBarPresentationItem
```

Sources:

```text
generalMessage
substitutionCall
```

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Substitution accent:

```text
purple
```

Combined order:

```text
publishedAt descending
→ presentationId tie-breaker
```

Personal calls do not consume general `3/3` capacity.

Active only while:

```text
nowLocal < shiftStartsAtLocal
```

Shift starts:

```text
day → 08:00 local
night → 20:00 local
```

Local hide:

```text
spaces_bar.hidden_substitution_call_ids.v1.<uid>
```

---

# 24. Canonical confirmed substitution call

Authoritative immutable event:

```text
spaces/substitution/confirmedCalls/{callId}
```

Finalization transaction:

```text
read pendingCall
→ validate
→ update statistics
→ create confirmedCall
→ delete pendingCall
```

Fields:

```text
schemaVersion
callId
userId
revision
calledByUserId
calledAt
finalizedAt
shiftYear
shiftMonth
shiftDay
shiftKind
```

Exactly-once protection comes from authoritative pendingCall deletion in the same transaction.

---

# 25. Substitution push and technical history

Function:

```text
sendSubstitutionCallNotification
```

Trigger:

```text
onDocumentCreated(
  "spaces/substitution/confirmedCalls/{callId}"
)
```

Payload target:

```text
deepLinkType = spacesBar
spacesBarPresentationId = substitution:<callId>
```

Epistola technical chat is read-only and projects canonical confirmedCalls.

Do not create fake normal chat documents for technical history.

---

# 26. Participant membership semantics

Canonical path:

```text
spaces/substitution/participants/{userId}
```

Statuses:

```text
active
vacation
sick
removed
```

Inactive statuses retain canonical rotation slot/anchor.

Normal `Удалить из списка` means:

```text
status = removed
```

not physical document deletion.

Never-before-added participant:

```text
one-time top priority
```

Previously removed participant:

```text
restore at hidden canonical anchor
no repeated top priority
```

---

# 27. Rotation editor/gateway separation

Distinct contracts:

```text
SubstitutionParticipantStateFirestoreGateway
→ state mutation

SubstitutionRotationMembershipFirestoreGateway
→ add/restore/soft remove

SubstitutionRotationEditFirestoreGateway
→ whole-list reorder transaction
```

Editor domain:

```text
SubstitutionRotationDraft
```

Editing is local until Apply.

Apply normalizes:

```text
rotationOrder = 0..N-1
```

across the complete canonical list.

Exact conflict text:

```text
Список изменился. Откройте режим редактирования заново.
```

Do not casually reword it.

---

# 28. Buses / schedule planning notes

The `Автобусы` Space is still unimplemented.

Known business description from current planning:

```text
2 buses
cyclic route
between Управление and Автово
with intermediate stops
runs during day/evening when trip is present in schedule
```

Current desired stop naming:

```text
Трамвай → Автово
Порт → Управление
Быт блок 1 → Медпункт
Быт блок 2 → Раздевалка
```

Weekend schedule differs from weekday schedule.

Current old document may no longer reflect actual weekend departures; a newer schedule should be obtained before implementation.

Do not hard-code the old weekday/weekend assumptions as authoritative business data.

---

# 29. Current backlog / next work

Immediate release/rollout:

```text
1. distribute/test new Android APK containing callable push ownership client
2. allow migration period for active users
3. in ~5–7 days verify adoption
4. only then consider deploy of restrictive users/{uid}/devices Rules
```

Security follow-up:

```text
audit/update deleted Auth user cleanup for pushInstallations registry
```

Product/UI backlog:

```text
Spaces Hub ⋮
show/hide Spaces
regular/compact layout
>8 behavior
odd final tile behavior
```

Technical cleanup:

```text
legacy *MessageId names
→ migrate deliberately toward presentationId terminology
```

Web follow-up:

```text
official Web Chats exposure/verification
Web push remains separate future foundation
```

Application foundations:

```text
Calendar
Buses
other Spaces
```

Do not mix these into push rollout work.

---

# 30. New-chat startup checklist

At the beginning of a new Epistola development chat, first verify:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read from the current feature branch:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Priority:

```text
current source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Expected functional checkpoint for this block:

```text
67800f0
feat(push): add installation ownership foundation
```

A later docs-only commit will make `HEAD` newer.

Before proposing code, audit the source files relevant to the requested block.

Do not use `main` as the current `v0.8.0` source until release/merge is explicitly verified.
