# Epistola — Architecture

> Detailed technical handoff for the current `v0.8.0` feature branch.
>
> Source priority:
>
> current code
> → `PROJECT_CONTEXT.md`
> → `ARCHITECTURE.md`
> → `README.md`
>
> This document describes architectural invariants and the latest implementation state.
> `PROJECT_CONTEXT.md` is the operational checkpoint/handoff.
> `README.md` is the concise project overview.

---

# 1. Repository / branch / checkpoint

Repository:

`MikhailBerezkin/epistola`

Current feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Last pushed functional checkpoint:

`7343528 — feat(calendar): add customizable calendar themes`

Previous major checkpoints:

```text
a3cbd07 — fix(substitution): return users after vacation ends
83f4ad6 — feat(calendar): finalize native alarms and monthly hours
f83ee7c — wip(alarm): add full-screen alarm flow foundation
2ae2439 — feat(chat): refine chat filters and group members
ce22462 — fix(chat): restore lifecycle and image preview rules
53bf805 — feat(calendar): add shift alarm scheduling foundation
63da029 — feat(substitution): enforce shift call eligibility
```

Stable baseline before `v0.8.0`:

`v0.7.4`

`v0.8.0` is not yet considered merged/released.

Local work after `7343528` includes Calendar theme audit and Shift Alarm visual WIP.

---

# 2. Product topology

One Flutter/Firebase codebase with platform-specific capability gates.

Products:

```text
Epistola
→ Android full client

EpiLite
→ Flutter Web / PWA
```

Shared:

```text
Firebase Auth
Firestore
Realtime Database where already used
Cloud Functions
Storage
domain models
application services
business rules
most Spaces UI
```

Platform-specific native code is isolated behind service/bridge boundaries.

---

# 3. Core layering

Preferred layering:

```text
Flutter UI
→ screen / presentation orchestration
→ application service
→ domain model / pure resolver
→ Firebase gateway or device-local persistence
```

Rules:

```text
UI must not be sole security boundary
Firebase Rules protect server-authoritative state
deterministic business logic should be testable outside UI
personal local-only state should not be pushed to Firestore without product reason
platform-native behavior should remain behind explicit bridge/service boundaries
```

---

# 4. Firebase / platform

Firebase project:

`epistola-434b7`

Firestore region:

`eur3`

Cloud Functions region:

`europe-west1`

Android package:

`com.epistola.app`

Production Hosting:

`https://epistola-434b7.web.app`

---

# 5. Main product navigation

Root areas:

```text
Контакты
Пространства
Профиль
```

Current Home starts on:

`Пространства`

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

# 6. Platform capabilities

Files:

```text
lib/platform/epistola_platform_capabilities.dart
lib/platform/epistola_runtime_mode.dart
```

Semantics include:

```text
isWebLite → kIsWeb

supportsPushNotifications
Android/native → true
Web → false

supportsChats → true
supportsContacts → Web false

supportsSpacesBarManagement → true
supportsSubstitutionManagement → true
supportsSubstitutionAvailabilityChanges → true
```

Do not scatter raw platform checks where a capability belongs in this abstraction.

---

# 7. User/work identity

Authoritative user document:

`users/{uid}`

Relevant fields include:

```text
uid
email
name
phone
about
avatar metadata
workDisplayName?
assignedCrew?
```

`assignedCrew`:

```text
1..4
```

Missing crew remains distinct from real crew.

Implemented components:

```text
UserAssignedCrewService
UserAssignedCrewReader
AssignedCrewSelector
AssignedCrewSetupScreen
SubstitutionWorkProfileService
SubstitutionWorkProfileFirestoreGateway
```

Calendar and Substitution consume authoritative assignedCrew.

---

# 8. Shift schedule domain

File:

`lib/domain/models/shift_cycle.dart`

Phases:

```text
day1
day2
offBeforeNight
night1
night2
recovery
offAfterRecovery1
offAfterRecovery2
```

Cycle length:

`8`

Crews:

```text
crew1
crew2
crew3
crew4
```

Anchor `14.09.2026`:

```text
crew1 → index 7
crew2 → index 5
crew3 → index 3
crew4 → index 1
```

Authoritative calculator:

`lib/services/spaces/calendar/shift_schedule_calculator.dart`

Do not reproduce phase math in arbitrary UI code.

---

# 9. Substitution root model

Firestore root:

`spaces/substitution`

Module fields include:

```text
nextRotationOrder
revision
lastCall?
```

Participants:

`spaces/substitution/participants/{uid}`

State includes:

```text
rotationOrder
availability
status
```

Availability:

```text
green
yellow
red
```

Status:

```text
active
vacation
sick
removed
```

Effective Vacation state can be derived rather than blindly persisted.

---

# 10. Canonical rotation

`rotationOrder` is authoritative.

Hidden/non-active participants preserve canonical queue anchors where required.

Manager edits remain atomic with module metadata.

Never rebuild authoritative order from current UI list index.

---

# 11. Vacation persistence

Collection:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Slots:

`1..6`

Schema:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Services:

```text
VacationPeriodService
VacationPeriodFirestoreGateway
VacationPeriodMapper
VacationDateParser
```

Substitution effective state:

`SubstitutionEffectiveStatusResolver`

Important current invariant:

```text
no active VacationPeriod
→ do not keep participant effectively in vacation merely because legacy raw status says vacation
```

This was fixed in:

`a3cbd07`

---

# 12. Vacation parser

Friendly input examples:

```text
18.09.2026
18.09
18/09/2026
18/09
18 сентября
18 сентября 2026
```

Cross-year resolution follows Calendar year/context logic.

Do not recycle vacation slots destructively; history must remain reconstructable.

---

# 13. Substitution shift model

Kinds:

```text
day
night
```

Time semantics:

```text
day: 08:00 → 20:00 same date
night: 20:00 → 08:00 next date
```

Night eligibility/vacation overlap must account for next day.

---

# 14. Substitution eligibility resolver

File:

`lib/services/spaces/substitution/substitution_call_eligibility_resolver.dart`

Output:

`SubstitutionCallEligibility`

Unavailable reasons:

```text
missingCrew
vacation
workShift
```

Exception:

`SubstitutionCallUnavailableException`

Priority:

```text
1 missingCrew
2 vacation overlap
3 own work phase
4 eligible
```

Allowed table:

| Own phase | Day | Night |
|---|---:|---:|
| day1 | no | no |
| day2 | no | no |
| offBeforeNight | yes | yes |
| night1 | no | no |
| night2 | no | no |
| recovery | no | yes |
| offAfterRecovery1 | yes | yes |
| offAfterRecovery2 | yes | no |

---

# 15. Call protection layers

Flow:

```text
UI resolver
→ transaction resolver
→ Firestore Rules
```

Transaction reads are intentionally completed before writes.

Bounded vacation reads:

```text
{uid}__1
...
{uid}__6
```

New shiftClaim schema:

```text
schemaVersion = 2
```

Rules validate:

```text
actor role
shape
server timestamp
participant/module relationship
pendingCall relationship
assignedCrew
8-day phase
duplicate exact-shift protection
```

Vacation overlap is transaction-protected rather than duplicated with six Rules reads.

---

# 16. Atomic Substitution call documents

Call coordinates:

```text
spaces/substitution
spaces/substitution/participants/{uid}
spaces/substitution/pendingCalls/{callId}
spaces/substitution/shiftClaims/{claimId}
```

Claim ID:

```text
{uid}__{year}_{month}_{day}__{kind}
```

Purpose:

```text
exactly one active call per participant per exact shift
```

Undo window:

~3 seconds.

Undo restores rotation and removes current call artifacts under Rules contract.

Finalization owns confirmed history/statistics.

---

# 17. Production Rules state

Repository Rules were tested/deployed on 2026-09-24.

Current truth:

```text
production Rules = current repository ruleset at release-pass checkpoint
new Substitution calls require shiftClaim v2
old v1 new-call protocol is rejected
```

Do not reuse older transition-compatible assumptions.

---

# 18. Calendar architecture

Calendar composition:

```text
base shift
+
Vacation overlay
+
additional Substitution shift
+
personal local agenda
+
theme/presentation layer
```

Each layer has separate ownership/source.

Do not mutate base cycle to encode overlays.

---

# 19. Calendar state / interaction

Key state concepts:

```text
visibleMonth
selectedDate
compactFocusedDate
hasSelectedDate
viewMode
```

Historical docs may mention full/medium/compact.
Later UI simplification focused interaction around full + compact.
Current source is authoritative.

Month paging and selected-date state remain separate.

Compact mode uses stationary selector / moving dates.

---

# 20. Additional shift projection

Domain:

`CalendarAdditionalShiftEvent`

Service:

`CalendarAdditionalShiftService`

Projection:

`CalendarAdditionalShiftProjection`

Source:
structured Substitution data.

No additional generic Calendar events Firestore collection is needed if authoritative Substitution data can be projected.

Presentation:

```text
violet frame/marker
```

---

# 21. Personal CalendarEntry

Model:

`CalendarEntry`

Kinds:

```text
task
note
```

Storage:

`SharedPreferences`

Namespace:

```text
calendar_entries_v1_<uid>
```

Fields include:

```text
id
kind
date
title
description?
scheduledMinutes?
reminderMinutes?
priority
colorValue?
isCompleted
completedAt?
createdAt
updatedAt
```

Personal agenda remains local-only.

---

# 22. CalendarEntry service

Owns:

```text
loadForUser
loadForDay
create
update
setCompleted
delete
reconcileReminders
```

Sorting:

```text
active before completed
timed active by time
untimed after timed
completed by completion timestamp where applicable
```

---

# 23. One-off Calendar reminders

Service:

`CalendarEntryReminderService`

Native integration:

`NotificationService`

Stable notification ID:

```text
CalendarEntry.id
→ deterministic FNV-style 32-bit hash
→ positive signed ID
```

Android:

```text
SCHEDULE_EXACT_ALARM
RECEIVE_BOOT_COMPLETED
AndroidScheduleMode.alarmClock
```

Web:
unsupported.

---

# 24. Shift Alarm scheduling domain

Added at `53bf805`.

Domain/services:

```text
ShiftAlarm
ShiftAlarmOccurrence
ShiftAlarmLocalStore
ShiftAlarmMapper
ShiftAlarmOccurrenceResolver
ShiftAlarmSchedulePlanner
ShiftAlarmScheduleReconciler
ShiftAlarmScheduleRegistry
ShiftAlarmSchedulingService
```

UI:

```text
ShiftAlarmEditorScreen
ShiftAlarmSettingsScreen
```

Shared time picker:

`TimeWheelPickerSheet`

The shift alarm model/schedule planner is separate from personal CalendarEntry reminders.

---

# 25. Native Shift Alarm bridge

Functional architecture finalized at `83f4ad6`:

```text
NotificationService
→ ShiftAlarmNativeBridge
→ MethodChannel
→ MainActivity
→ ShiftAlarmNativeScheduler
→ AlarmManager.setAlarmClock()
→ ShiftAlarmReceiver
→ full-screen notification
→ ShiftAlarmActivity
```

Native files:

```text
MainActivity.kt
ShiftAlarmActivity.kt
ShiftAlarmNativeScheduler.kt
ShiftAlarmReceiver.kt
```

The native screen is used because full-screen ringing behavior must remain reliable while device is locked.

Functional invariants:

```text
exact trigger
full-screen presentation
snooze +10m
stop
swipe up/down actions
Power button stop
return to previous phone state
```

Do not regress these while changing visuals.

---

# 26. Shift Alarm visual composition — WIP architecture

Current WIP attempted to use:

`design/branding/Аватар Чайки.png`

as a full visual background.

Problem:

```text
source is square and already composited:
dark/ocean texture
+
white seagull
+
19/4 corner mark
```

This cannot be reliably mapped to all tall Android screens with one ImageView:
- `CENTER_CROP` cuts composition;
- scaling creates edge/position issues;
- `FIT_CENTER` exposes square boundaries.

Correct architectural direction:

```text
Root full-screen adaptive background
+
independent seagull layer
+
independent buttons
```

Prefer:

```text
transparent seagull asset
or verified `Аватар Чайки трафарет.png` if it has useful alpha/background separation
```

Use normalized layout:

```text
snooze centerY ~ 0.25 * usableHeight
seagull centerY ~ 0.55–0.60 * usableHeight
stop centerY ~ 0.75 * usableHeight
button width derived from screen width with min/max bounds
bird size derived from screen width with min/max bounds
```

The background may use dark navy gradient/ocean texture independent of seagull.

Avoid embedding essential composition into one square bitmap.

---

# 27. Alarm visual resources currently present

WIP runtime bitmap:

```text
android/app/src/main/res/drawable/shift_alarm_seagull_background.png
```

Vector icons:

```text
shift_alarm_snooze_icon.xml
shift_alarm_stop_icon.xml
```

The snooze vector replaced system emoji so the UI can use a consistent white outline alarm icon.

Latest screen is not accepted and must be treated as WIP.

---

# 28. Monthly shift-hours calculator

File:

`lib/services/spaces/calendar/shift_month_hours_calculator.dart`

Tests:

`test/services/spaces/calendar/shift_month_hours_calculator_test.dart`

Accounting:

```text
physical 12h shift → 11.5 accounted hours
day → 11.5
night start month → 4h
night next date/month → 7.5h
additional shift follows same accounting
```

Calendar displays:

```text
Основные
Халтуры
Всего
```

Keep calculation out of widget code.

---

# 29. Calendar theme domain

Model:

`lib/domain/models/shift_calendar_theme.dart`

Preferences:

`lib/services/spaces/calendar/shift_calendar_theme_preferences.dart`

Screen:

`lib/screens/shift_calendar_theme_screen.dart`

Built-in themes:

```text
Light
Dark
```

Custom slots:

```text
Custom 1
Custom 2
```

Configurable properties include:

```text
8 cycle tile colors
background
vacation
additional-shift border
selected day
monthly-hours bar
text scale
```

Derived automatically:

```text
grid line
text contrast
```

Themes are Calendar-local and independent from global application theme.

---

# 30. Calendar theme persistence

Custom slots are saved independently.

Reset is slot-local.

Preferences tests:

```text
6/6 passed
```

Color editor:

```text
HEX input
RGB sliders
RGB +/-1
```

Do not introduce Firestore for this; it is presentation preference.

---

# 31. Systemic Calendar theme audit

Local post-`7343528` audit applies theme beyond day tiles.

Affected:

```text
ShiftCalendarScreen
CalendarEntryEditorScreen
TimeWheelPickerSheet
```

Purpose:

```text
remove accidental Material/global-theme leakage
make agenda/editor/picker visually belong to selected Calendar theme
```

Phone visual verification passed.

---

# 32. Chat lifecycle / Rules refinement

`ce22462` modified:

```text
firestore.rules
group_admin_lifecycle_rules.test.mjs
```

Purpose:
restore expected group-admin lifecycle and image-preview authorization behavior.

Do not overwrite these Rules with pre-fix versions.

---

# 33. Chat presentation refinement

`2ae2439` changed:

```text
ChatsPage
GroupMembersSection
```

Purpose:
refine filters and group member presentation.

Known bug still pending:

```text
private peer message
→ Удалить у себя
→ may fail
```

---

# 34. SpacesBar

Realtime presentation for:

```text
general manager messages
Substitution call events
chat unread integration
```

User can hide relevant items under existing rules.

Manager publish/edit paths remain role-gated.

Upcoming roadmap includes Large Text / SpaceBar layout/padding pass.

---

# 35. Push notifications

Foundation:

```text
Firebase Messaging
NotificationService
PushTokenService
```

Cloud Function region:

`europe-west1`

Features:

```text
chat deep links
active-chat suppression
image message custom sound/vibration
Substitution call push
```

Installation ownership:

`pushInstallations/{installationId}`

Invariant:

```text
one installation → one current user
one user → many installations possible
```

---

# 36. EpiLite Web

Config:

```text
web/index.html
web/manifest.json
lib/firebase_options.dart
firebase.json
```

Hosting:

```text
build/web
SPA rewrite → /index.html
```

Production URL:

`https://epistola-434b7.web.app`

Verified:

```text
Auth
Spaces
SpacesBar
Calendar
Substitution
desktop browser
mobile browser
earlier text chat flow
```

Unsupported:

```text
Web push
Android native exact/full-screen alarms
```

---

# 37. Avatars / media

Existing foundation:

```text
UserAvatar
AvatarView
UserAvatarView
GroupAvatarView
ChatAvatarView
```

Storage uses versioned thumb/full resources.

Known Web avatar polish remains backlog.

Do not regress Android caching.

---

# 38. Messaging foundation

Existing v0.7.x features:

```text
private/group chat
pagination = 20
image messages
push deep link
date separators
private read receipts
group reactions
private typing
message deletion states
```

Attachment Composer, voice and general file transfer remain future blocks.

---

# 39. Performance discipline

Prefer:

```text
pagination
bounded reads
cache
parallel independent reads
central summaries
local preferences for presentation
local storage for personal agenda
```

Pilot:

`40–50 users`

Avoid unnecessary Firestore listeners and duplicated projection collections.

---

# 40. Testing layers

Pure domain/service tests:

```text
fast
deterministic
no emulator
```

Gateway tests:

```text
fake transaction context
verify reads/writes/exceptions
```

Rules tests:

```text
Firebase Emulator
assertSucceeds/assertFails
```

Manual native/device tests remain required for:
- full-screen alarm;
- lock-screen behavior;
- Power button;
- Android visual scaling.

---

# 41. Latest test evidence

Stable prior release-pass:

```text
flutter test → 1161/1161
flutter analyze → clean
Substitution Rules → 74/74
```

Calendar theme local:

```text
theme preferences → 6/6
flutter analyze → clean
manual phone visual → passed
```

Native Alarm visual WIP:

```text
release APK build → passed
latest APK size → 63.9 MB
visual composition → NOT accepted
```

Do not conflate build success with visual acceptance.

---

# 42. Generated files discipline

After last Flutter command before commit restore once:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Restore once at the end, not after every command.

---

# 43. Firebase Hosting cache

`.firebase/` is local deploy cache.

Must remain ignored:

```text
/.firebase/
```

---

# 44. Build outputs

Android:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Latest WIP build:

`63.9 MB`

Web:

`build/web`

Build outputs are generated and not repository source.

---

# 45. Current roadmap

Immediate:

```text
1. Finish Shift Alarm visual composition.
2. Re-verify native alarm behavior on phone.
3. Finalize/commit Calendar theme audit + RGB ±1 if still local.
4. Run targeted tests + analyze.
5. Restore generated plugin files.
6. Commit/push checkpoint.
7. Large Text + SpaceBar layout/padding.
8. Substitution Call Basket + Shift Cohort.
9. Remaining product polish.
10. v0.8.0 release/merge/tag decision.
11. Achievements if time.
```

Backlog:

```text
private chat delete bug
Attachment Composer
voice messages
file transfer
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
legacy *MessageId cleanup
pushInstallations cleanup
Bus timetable
```

---

# 46. New-chat protocol

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

Do not start by reimplementing completed foundations.

For current next block:
inspect exact current `ShiftAlarmActivity.kt` and alarm drawable resources before editing.

Preserve functional native alarm invariants while replacing visual composition.
