# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних рабочих приложений.

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
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Current functional checkpoint | `63da029` |
| Checkpoint message | `feat(substitution): enforce shift call eligibility` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Production Hosting | `https://epistola-434b7.web.app` |
| Release APK | `61.0 MB` |

`v0.8.0` remains in feature branch and is not yet declared merged/released.

---

# Current verification

Flutter:

```text
flutter.bat test
→ 1161/1161 passed

flutter.bat analyze
→ No issues found!
```

Substitution targeted:

```text
eligibility resolver → 24/24
Firestore gateway → 22/22
dependencies → 10/10
```

Firestore Rules:

```text
Substitution Rules → 74/74
```

Production:

```text
Firestore Rules deploy → passed
Android allowed/blocked call flow → passed
Calendar additional-shift marker → passed
push → passed
SpacesBar → passed
flutter build web → passed
Firebase Hosting deploy → passed
desktop Web → passed
mobile Web → passed
```

---

# Architecture

Core layering:

```text
Flutter UI
→ screen/presentation orchestration
→ application services
→ domain
→ Firebase gateways or device-local persistence
```

Principles:

```text
server-authoritative work state → Firebase + Rules
personal local agenda → local persistence
pure deterministic business rules → isolated/testable resolver
UI is not the security boundary
```

---

# Products

## Epistola / Android

Current scope:

```text
Auth
Contacts
Spaces
Chats
Profile
avatars/media
push notifications
SpacesBar
Substitution
Calendar
Vacation
Personal Calendar Agenda
Exact local reminders
```

## EpiLite / Web

Production:

`https://epistola-434b7.web.app`

Verified current scope:

```text
Firebase Auth
Spaces
SpacesBar
Substitution
Calendar
Profile/logout
desktop browser
mobile browser
PWA/Hosting
```

Earlier Web work also verified text chats.

Not supported on Web:

```text
Android exact local alarms
Web push
```

---

# Spaces

Root navigation:

```text
Контакты | Пространства | Профиль
```

Spaces tiles include:

```text
Чаты
Список / Подсменка
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Owner remains highest-priority role.

---

# Work schedule identity

Authoritative crew:

`users/{uid}.assignedCrew`

Valid:

```text
1..4
```

Calendar and Substitution use this field.

Missing crew is not silently defaulted.

UI prompts user to choose crew.

Manager can correct crew for Substitution participant.

---

# Base shift cycle

Four crews, repeating 8-day cycle:

```text
День 1
День 2
Вых
Ночь 1
Ночь 2
Отсыпной
Вых
Вых
```

Anchor:

```text
14.09.2026
crew4 = День 2
crew3 = Ночь 1
crew1 = последний выходной before next День 1
```

Authoritative calculator:

`ShiftScheduleCalculator`

---

# Substitution / Список

Current foundation includes:

```text
participants
canonical rotation
availability
vacation/sick/removed states
participant management
rotation editor
call flow
3-second Undo
pending calls
shiftClaims
duplicate-shift protection
exactly-once finalization
statistics
confirmed call history
personal SpacesBar
push
assigned crew
Vacation integration
shift eligibility
Firestore Rules
```

---

# Substitution eligibility

Reasons:

```text
missingCrew
vacation
workShift
```

Messages:

```text
Недоступно: не указано звено
Недоступно: отпуск
Недоступно: рабочая смена
```

Allowed extra shifts:

| Own phase | Day | Night |
|---|---:|---:|
| day1 | ❌ | ❌ |
| day2 | ❌ | ❌ |
| offBeforeNight | ✅ | ✅ |
| night1 | ❌ | ❌ |
| night2 | ❌ | ❌ |
| recovery | ❌ | ✅ |
| offAfterRecovery1 | ✅ | ✅ |
| offAfterRecovery2 | ✅ | ❌ |

Night shift also checks next calendar day for Vacation overlap.

---

# Call protection

Layers:

```text
UI resolver
→ transaction resolver
→ Firestore Rules
```

Current new-call claim:

```text
shiftClaim schemaVersion = 2
```

Production Rules require v2 and validate assignedCrew + work-cycle eligibility.

Old APK new-call protocol using v1 is rejected after the 2026-09-24 Rules deploy.

---

# Vacation

Persistence:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Slots:

`1..6`

Implemented:

```text
friendly parser
editor/list
create/update/delete
Firestore persistence
realtime Calendar watch
pink markers
Substitution effective Vacation status
manager editing
call eligibility overlap checks
```

Deleting current VacationPeriod returns participant to ordinary list while preserving canonical queue position.

History-safe archive/reuse remains future work.

---

# Calendar

Base schedule is immutable.

Presentation layers:

```text
base 8-day shift
Vacation
additional Substitution shift
personal local agenda markers
```

Authoritative crew comes from user profile.

Modes:

```text
full
medium
compact
```

---

# Additional shift / халтура

Implemented from structured Substitution data.

Components:

```text
CalendarAdditionalShiftEvent
CalendarAdditionalShiftProjection
CalendarAdditionalShiftService
```

Presentation:

```text
violet day marker/frame
```

Production manual verification:

```text
successful call for 25th
→ violet frame appeared on 25th
```

Do not parse free-form SpacesBar text when structured Substitution data exists.

---

# Personal Calendar Agenda

Personal:

```text
Дело
Заметка
```

Storage:

`SharedPreferences`, namespaced by `uid`.

Not stored in Firestore.

Implemented:

```text
create
edit
delete
task completion
active/completed sorting
time sorting
priority
description
separate reminder time
local day markers
```

---

# Exact local Calendar reminders

Android architecture:

```text
CalendarEntryService
→ CalendarEntryReminderService
→ NotificationService
→ flutter_local_notifications
```

Uses:

```text
SCHEDULE_EXACT_ALARM
RECEIVE_BOOT_COMPLETED
AndroidScheduleMode.alarmClock
```

Manual checks passed:

```text
exact requested minute
system sound
reschedule
bell-off cancel
completion cancel
delete cancel
app close/reopen
```

Exact local reminders are Android-only in current product.

---

# Firestore Rules production state

Current repository Rules were tested and deployed on 2026-09-24.

This supersedes older transition-Rules notes.

Current call protection includes:

```text
manager role
atomic module/participant/pendingCall/shiftClaim relationships
shiftClaim v2
assignedCrew validation
8-day cycle eligibility
duplicate protection
```

Recent Substitution Rules suite:

`74/74 passed`

---

# EpiLite Hosting

Build:

```powershell
flutter.bat build web
```

Deploy:

```powershell
firebase.cmd deploy --only hosting
```

Production URL:

`https://epistola-434b7.web.app`

`firebase.json` serves:

`build/web`

with SPA rewrite to:

`/index.html`

Local Hosting cache:

`.firebase/`

should be ignored by Git:

```text
/.firebase/
```

---

# Build commands

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
firebase.cmd deploy --only firestore:rules
firebase.cmd deploy --only hosting
```

Rules test:

```powershell
firebase.cmd emulators:exec --only firestore "node --test test/rules/firestore/substitution_space_rules.test.mjs"
```

Git:

```powershell
git.exe status --short
git.exe diff --check
```

---

# Generated files workflow

After the last Flutter command before commit, restore once:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Do not commit these incidental changes.

---

# Known backlog

Current candidates:

```text
finish v0.8.0 release/merge/tag
private chat "Удалить у себя" bug
Attachment Composer Foundation
voice messages
small file transfer
Calendar compact marker/UI polish
Calendar themes
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
legacy *MessageId cleanup
pushInstallations cleanup for deleted users
Bus schedule after authoritative new timetable
```

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

Expected functional checkpoint before docs commit:

`63da029`

Expected source priority:

```text
current code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

If docs and `.gitignore` are still only local changes, commit/push that documentation checkpoint before starting the next feature block.
