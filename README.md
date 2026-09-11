# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Проект имеет два клиентских представления одной платформы:

```text
Epistola
→ полноценное Android-приложение

EpiLite
→ облегчённая Flutter Web / PWA версия
```

Pilot target:

```text
40–50 users
```

---

# Current development status

| Параметр | Значение |
|---|---|
| Target | `v0.8.0` |
| Stage | `Spaces / Substitution / EpiLite / Push Ownership` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `67800f0` |
| Push installation ownership | `67800f0` |
| Test Mode + Web avatars + final SpacesBar UI | `1ca3bcf` |
| EpiLite Web Lite foundation | `a488c3b` |
| Chats unread summary | `f0a2084` |
| Substitution list editor | `85238a2` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Hosting | `https://epistola-434b7.web.app` |

`v0.8.0` is still a feature-branch target and has not yet been declared merged/released.

A later docs-only commit may make `HEAD` newer than `67800f0`.

---

# Architecture

Core layering:

```text
Flutter UI
→ presentation / screen orchestration
→ controllers / application services
→ domain
→ Firebase gateways / adapters
```

Business transaction invariants stay below UI.

UI role visibility is not the security boundary.

Presentation-only state should not be persisted as authoritative backend data.

Platform availability is centralized through:

```text
lib/platform/epistola_platform_capabilities.dart
```

Runtime Test Mode is centralized through:

```text
lib/platform/epistola_runtime_mode.dart
```

---

# Products

## Epistola

Full Android application.

Current Android scope includes:

```text
Contacts
Spaces
Chats
Profile
push notifications
avatars/media
Substitution
SpacesBar
technical history
```

## EpiLite

Lightweight Web/PWA client built from the same Flutter/Firebase codebase.

Public URL:

```text
https://epistola-434b7.web.app
```

Verified Web scope includes:

```text
Firebase Auth
Spaces root
SpacesBar
Список
Profile/logout path
PWA install
Web avatar replacement
```

Web avatar replacement is manually verified on iPhone.

Web push remains intentionally disabled.

Private chats were found to work through:

```text
Contacts → user card → Написать
```

so Web chats are currently presentation-gated rather than backend-blocked.

They are not yet declared an official fully supported Web feature.

---

# Current root navigation

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Android Chats remain an internal Space:

```text
Пространства
→ Чаты
→ existing Messenger
```

---

# Current Spaces Hub

Tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Working Android applications:

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

# Chats unread badge

Unread state is centralized in:

```text
ChatUnreadSummaryController
```

It owns a shared user-chat stream and avoids one Firestore unread query per tile.

Manual scenario previously verified:

```text
0 → 1 → 2 → 1 → 0
```

---

# "Список" / Substitution

Current foundation includes:

```text
participants
canonical rotation queue
availability
vacation/sick hidden slots
removed hidden membership slots
participant management
new-participant one-time top priority
restore at saved hidden anchor
work display name
call flow
Undo
pending-call persistence
recovery
exactly-once finalization
monthly/yearly statistics
confirmedCall event
personal SpacesBar
Epistola technical history
confirmed-call push
atomic list editor
Firestore Rules
```

Owner remains highest priority.

---

# Participant membership semantics

Statuses:

```text
active
vacation
sick
removed
```

Vacation, sick and removed participants remain in the canonical rotation.

Normal:

```text
Удалить из списка
```

means:

```text
status = removed
```

not physical participant-document deletion.

A truly new participant receives one-time priority at the top.

A previously removed participant restores at the current hidden canonical anchor and does not regain top priority.

---

# Rotation list editor

Available to:

```text
brigadier
owner
```

Entry:

```text
Список
→ Настройки
→ Режим редактирования списка
```

Editing is local until Apply.

Apply performs an atomic Firestore transaction and normalizes canonical `rotationOrder`.

Exact conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# General SpacesBar

Authoritative board:

```text
spaces/spacesBar
```

Manager roles:

```text
brigadier
owner
```

General capacity:

```text
3 active messages
```

Lifetimes / accents:

```text
1h → green
12h → blue
24h → orange
until cancelled → red
```

Local hide:

```text
spaces_bar.hidden_message_ids.v1.<uid>
```

No Firestore write is performed for local hide.

---

# Final SpacesBar UI

Current SpacesBar presentation is completed:

```text
stationary neutral outer frame
colored inner glow near frame
neutral center
true cyclic/infinite swipe in both directions
manual drag interpolates glow continuously
auto rotation uses same PageController motion
no fade-to-dark transition
```

Timing:

```text
auto dwell = 10 sec
slide = 1000 ms
```

Current glow checkpoint:

```text
edge alpha ≈ 45
inner alpha ≈ 10
```

---

# Test Mode

For SpacesBar visual/animation testing:

```powershell
flutter.bat run --dart-define=EPISTOLA_TEST_MODE=true
```

Titles:

```text
Epistola Test
EpiLite Test
```

Current Test Mode protects SpacesBar publication/watch/management only.

It is NOT a complete Firebase sandbox.

Android Test Mode may still initialize unrelated production FCM/Firebase paths.

---

# Personal substitution SpacesBar

Successful call finalization creates:

```text
spaces/substitution/confirmedCalls/{callId}
```

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Personal calls do not consume general `3/3` capacity.

Personal call expires visually at shift start:

```text
day → 08:00 local
night → 20:00 local
```

Confirmed-call history remains.

---

# Push deep-link

Typed push model supports:

```text
chat
spacesBar
```

Unified field:

```text
spacesBarPresentationId
```

Values:

```text
general:<messageId>
substitution:<callId>
```

Some legacy internal `*MessageId` names remain and should be cleaned in a dedicated technical block.

---

# Push installation ownership

Checkpoint:

```text
67800f0
feat(push): add installation ownership foundation
```

Root cause of the earlier wrong-recipient push incident was stale duplicated device ownership: the same Poco installation/token had been stored under multiple users.

New invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installations allowed
```

Canonical registry:

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

`userId` means current authenticated account and is unrelated to the application `owner` role.

---

# Push ownership callables

Cloud Functions:

```text
claimPushInstallation
releasePushInstallation
```

Region:

```text
europe-west1
```

Client source:

```text
lib/services/push_token_service.dart
```

Client behavior:

```text
auth state → claim current token
FCM token refresh → claim
logout/unregister → release
```

Claim transaction atomically removes the same installation from the previous user and attaches it to the current authenticated user.

Stale old-user release cannot remove the current user's ownership.

Multi-device accounts remain supported.

---

# Push ownership production verification

Real production roundtrip passed:

```text
Owner
→ Alex Born
→ Owner
```

The Poco installation moved between accounts correctly.

Alex's separate genuine second installation remained intact throughout.

Legacy schema v1 registry using `ownerUserId` successfully migrated to:

```text
schemaVersion = 2
userId = ...
```

---

# Device Firestore Rules rollout

Local Rules now deny direct client writes:

```text
users/{uid}/devices/{deviceId}
create/update/delete → false
```

Own device reads remain allowed.

Targeted Rules tests:

```text
6/6 passed
```

Full Firestore Rules suite:

```text
185/185 passed
```

Important:

```text
these restrictive Rules are NOT deployed yet
```

Reason:

```text
legacy APKs still use direct device writes
```

Rollout plan:

```text
distribute new APK
→ allow ~5–7 day migration window
→ verify adoption
→ deploy restrictive Rules only when safe
```

If many users remain on old APK, delay Rules deploy.

---

# Deleted-user cleanup follow-up

Existing Auth-delete cleanup predates the new canonical registry.

It already removes:

```text
users/{uid}
users/{uid}/devices/*
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

A future hardening task must audit/update cleanup for:

```text
pushInstallations/{installationId}
```

Do not assume registry cleanup is already implemented.

---

# Web avatar replacement

Current Web path:

```text
ImagePicker
→ ImageCropper Web
→ bytes
→ FlutterImageCompress
→ Firebase Storage putData
→ avatar metadata
```

Cropper.js support is integrated in:

```text
web/index.html
```

Manual iPhone Web/PWA test passed.

---

# Buses foundation planning

`Автобусы` is still unimplemented.

Known current naming:

```text
Трамвай → Автово
Порт → Управление
Быт блок 1 → Медпункт
Быт блок 2 → Раздевалка
```

There are two buses running cyclically between terminal points with intermediate stops.

Weekday/weekend schedule differs.

The old schedule document is not authoritative enough for implementation; obtain a newer schedule first.

---

# Development / test commands

Flutter:

```powershell
dart.bat format <files>
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat build web
```

Functions:

```powershell
cd functions
npm.cmd run lint
npm.cmd run build
node --test <tests>
cd ..
```

Firestore emulator on Windows may require:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Git:

```powershell
git status --short
git diff --check
```

Generated plugin files should be restored once after the final Flutter command in a series.

---

# Latest verification

Checkpoint:

```text
67800f0
feat(push): add installation ownership foundation
```

Flutter:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 981 tests passed
```

Functions:

```text
ownership tests → 19/19
lint → passed
build → passed
```

Rules:

```text
push device targeted → 6/6
full Firestore Rules → 185/185
```

Git:

```text
git diff --check → clean
functional commit pushed to feature branch
```

---

# Roadmap

Completed in current sequence:

```text
Chats unread summary
EpiLite Web Lite / PWA foundation
Web avatar replacement
SpacesBar stationary frame + true cyclic swipe + glow tuning
SpacesBar Test Mode foundation
Push installation ownership foundation
```

Immediate rollout:

```text
1. distribute/test new Android APK
2. wait for user migration
3. after ~5–7 days evaluate deploy of restrictive device Rules
```

Security follow-up:

```text
pushInstallations cleanup on deleted Auth user
```

Next UI/product unless reprioritized:

```text
Spaces Hub ⋮
show/hide Spaces
regular/compact layout
>8 behavior
odd final tile
```

Technical cleanup:

```text
legacy *MessageId → presentationId names
```

Later foundations:

```text
official Web Chats
Web push
Calendar
Buses
```

---

# Documentation workflow

Current source of truth priority:

```text
source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

For the three root docs:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

preferred replacement workflow:

```text
assistant prepares all three full files
→ packs exactly them into one ZIP
→ user extracts ZIP
→ root copies replace existing files
→ inspect diff
→ commit docs separately
```

---

# New-chat checklist

Before continuing work:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Expected latest functional checkpoint:

```text
67800f0
feat(push): add installation ownership foundation
```

Do not use `main` as the current `v0.8.0` state until merge/release is explicitly verified.
