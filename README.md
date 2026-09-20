# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Products:

```text
Epistola
→ Android full client

EpiLite
→ Flutter Web / PWA
```

Pilot target:

`40–50 users`

---

# Current development status

| Параметр | Значение |
|---|---|
| Target | `v0.8.0` |
| Stage | `Spaces / Substitution / EpiLite / Calendar / Vacation / Local Agenda` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Latest functional checkpoint | `8abe66c` |
| Web chats/performance | `764d3de` |
| Push installation ownership | `67800f0` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Hosting | `https://epistola-434b7.web.app` |

`v0.8.0` remains in feature branch and is not declared merged/released.

---

# Architecture

Core layering:

```text
Flutter UI
→ presentation / screen orchestration
→ application services
→ domain
→ Firebase gateways or device-local persistence
```

Server-authoritative business state stays in Firebase.

Personal/local UI state stays local when no server authority is needed.

---

# Products

## Epistola

Current Android scope:

```text
Contacts
Spaces
Chats
Profile
push notifications
avatars/media
Substitution
SpacesBar
Calendar
Vacation
Local Calendar Agenda
```

## EpiLite

Verified Web scope:

```text
Firebase Auth
Spaces
SpacesBar
Список
Profile/logout
Web avatar replacement
Chats text flow
PWA install
```

Web push:

`not supported`

Known Web gap:

`chat avatars may still fail to render`

---

# Spaces

Root navigation:

```text
Контакты | Пространства | Профиль
```

Spaces tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Owner remains highest-priority role.

---

# Substitution / Список

Current foundation includes:

```text
participants
canonical rotation
availability
vacation/sick/removed hidden anchors
participant management
call flow
3-second Undo
pending calls
shiftClaims duplicate-shift protection
exactly-once finalization
statistics
confirmedCall history
personal SpacesBar
push
rotation editor
Firestore Rules
```

Repository also supports:

```text
ordinary participant own sick → active
```

This self-return change has not yet been separately migrated into production transition Rules.

---

# Production Rules state

Production currently uses transition-compatible Rules:

```text
shiftClaims
VacationPeriod Rules
legacy-compatible old-APK own device writes
```

Vacation Rules are already deployed.

Repository `firestore.rules` is stricter and additionally contains strict device ownership and self-return changes.

Do not blindly deploy full repository Rules.

---

# Push installation ownership

Invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installations allowed
```

Registry:

`pushInstallations/{installationId}`

Callables:

```text
claimPushInstallation
releasePushInstallation
```

After broad APK rollout, remove legacy device compatibility through an explicit production migration.

---

# Calendar

Base schedule:

```text
4 crews
8-day cycle
```

Crew 4:

```text
День 1
День 2
Вых
Ночь 1
Ночь 2
О
Вых
Вых
```

Anchor:

`14.09.2026 = День 2`

Base schedule is immutable.

Exceptions are overlays.

---

# Calendar UI

Modes:

```text
full
medium
compact
```

Mode persists locally.

Current behavior:

```text
month swipe does not auto-carry selected day
selected shift status shown in header
Today/replay navigation
compact stationary center frame
compact selection commits after 250 ms settle
cyclic compact date scrolling
```

Selected shift titles:

```text
День 1
День 2
Ночь 1
Ночь 2
Отсыпной
Выходной
```

---

# Vacation

Persistence:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Technical slots:

`1..6`

Implemented:

```text
VacationPeriodService
friendly date parser
Vacation editor
Vacation list
create/update/delete
Firestore persistence
realtime Calendar watch
pink inclusive date markers
```

Accepted inputs:

```text
18.09.2026
18.09
18/09
18 сентября
18 сентября 2026
```

Cross-year supported.

Vacation Rules are deployed in production.

History-safe slot reuse remains future work.

---

# Personal Calendar Agenda

Personal `Дело / Заметка` data is local-only.

It is intentionally not stored in Firestore.

Persistence:

`SharedPreferences`, namespaced by `uid`.

Implemented:

```text
create
edit
delete
task completion
active/completed sorting
time sorting
scrollable agenda
fixed bottom Add bar
```

Bottom bar:

```text
[ Дело ]   Добавить   [ Заметка ]
```

Editor supports:

```text
title
optional task/note time
priority
description/note text
bell switch
separate reminder time
delete in edit mode
```

Time picker uses looping wheels:

```text
hours 00..23
minutes 00..59
```

---

# Calendar entry markers

Active local entries can project:

```text
note icon
bell icon
highest-priority dot
```

Completed tasks are excluded from markers.

Priority:

```text
none
low
medium
high
```

Full/medium marker integration is present.

Compact marker layout still needs final tuning.

---

# Important reminder gap

Current bell UI is not yet a real alarm.

Implemented:

```text
reminderMinutes stored locally
bell state persists
bell marker shown
```

Not implemented:

```text
actual Android local notification scheduling
```

Project already depends on:

`flutter_local_notifications`

This is the immediate next Calendar task.

---

# Calendar work-event roadmap

Additional shift / халтура should be separate from personal tasks.

Planned:

```text
use existing structured Substitution call data
dedupe by call/source ID
violet tile border
violet vertical strip in agenda
upcoming/occurred derived from shift startAt
historical marker remains
```

Avoid creating a new Firestore collection only for Calendar projection if existing authoritative Substitution data is sufficient.

---

# Calendar roadmap

Immediate:

```text
1. Real local reminder scheduling
2. Compact marker polish
3. Calendar UI polish
4. Additional shift / халтура projection
```

Later:

```text
repeating local entries tied to cycle positions 1..8
optional validity period
user colors/categories
Vacation → Substitution automation
history-safe Vacation archive/slot reuse
Calendar themes
Web Calendar
```

Personal entries remain local-only on Android.

Web personal Calendar data should also remain browser-local rather than move to Firestore.

---

# Verification

Functional checkpoint:

`8abe66c — feat(calendar): add local agenda and vacation UI`

Flutter:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 1064/1064 passed
```

Targeted:

```text
CalendarEntry → 34/34
Vacation parser/service → 18/18
```

Vacation production Rules:

`12/12 before deploy`

Generated Flutter plugin files were restored and excluded from functional commit.

---

# Development commands

Flutter:

```powershell
dart.bat format <files>
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat build web
```

Firebase:

```powershell
firebase.cmd
```

Git:

```powershell
git.exe status --short
git.exe diff --check
```

Generated plugin files:

`restore once after final Flutter command`

---

# New-chat checklist

First:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Expected latest functional checkpoint:

`8abe66c`

Do not use `main` as current `v0.8.0` source until merge/release is explicitly verified.

Immediate new-chat goal:

`real local Calendar reminder scheduling`
