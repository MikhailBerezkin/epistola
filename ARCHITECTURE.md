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
> `PROJECT_CONTEXT.md` is the operational checkpoint/handoff.
> `ARCHITECTURE.md` records technical invariants.
> `README.md` is the concise project overview.

---

# 1. Repository / branch / checkpoint

Repository:

`MikhailBerezkin/epistola`

Current feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Last pushed functional checkpoint:

`b8618aa — feat(spaces): add customizable hub layout`

Recent sequence:

```text
b8618aa — feat(spaces): add customizable hub layout
617bd36 — docs: update calendar alarm and roadmap handoff
17a73b7 — wip(alarm): refine ringing screen visuals
daedc9f — feat(calendar): refine themed calendar surfaces
7343528 — feat(calendar): add customizable calendar themes
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

Latest confirmed:

```text
HEAD = origin = b8618aa
working tree = CLEAN
```

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
personal presentation state should prefer local persistence
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

Spaces IDs:

```text
SpacesTileId.chats
SpacesTileId.substitution
SpacesTileId.vesselCalls
SpacesTileId.calendar
SpacesTileId.buses
SpacesTileId.safety
```

Presentation:

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

# 6. Spaces Hub customization architecture

Checkpoint:

`b8618aa`

Files:

```text
lib/domain/models/spaces_tile_id.dart
lib/screens/home_screen.dart
lib/screens/spaces_page.dart
```

Responsibilities:

```text
SpacesTileId
→ stable logical identity of Hub tiles

HomeScreen
→ presentation settings
→ SharedPreferences persistence
→ settings bottom sheets

SpacesPage
→ rendering visible tiles
→ applying saved order
→ choosing Grid vs Large layout
```

Local keys:

```text
spaces_tile_layout_mode
spaces_visible_tiles
spaces_tile_order
```

Layout modes:

```text
grid
→ 2-column SliverGrid

large
→ 1-column SliverList
→ horizontal cards
→ icon left
→ title/subtitle right
```

Visible tiles:

```text
stored as SpacesTileId names
at least one tile remains visible
```

Order:

```text
stored as ordered SpacesTileId names
ReorderableListView in settings
hidden tiles remain in the full canonical order
when re-enabled they return to their saved place
```

Rendering invariant:

```text
tileOrder
→ filter by visibleTileIds
→ render same result order in Grid and Large
```

This is presentation-only local state and must not be moved to Firestore without a product reason.

---

# 7. Platform capabilities

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

# 8. User/work identity

Authoritative user document:

`users/{uid}`

Relevant fields:

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

Components:

```text
UserAssignedCrewService
UserAssignedCrewReader
AssignedCrewSelector
AssignedCrewSetupScreen
SubstitutionWorkProfileService
SubstitutionWorkProfileFirestoreGateway
```

Calendar and Substitution consume authoritative `assignedCrew`.

---

# 9. Shift schedule domain

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

# 10. Substitution root model

Firestore root:

`spaces/substitution`

Module fields:

```text
nextRotationOrder
revision
lastCall?
```

Participants:

`spaces/substitution/participants/{uid}`

State:

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

# 11. Canonical rotation

`rotationOrder` is authoritative.

Hidden/non-active participants preserve canonical queue anchors where required.

Manager edits remain atomic with module metadata.

Never rebuild authoritative order from current UI list index.

---

# 12. Vacation persistence

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

Invariant:

```text
no active VacationPeriod
→ do not keep participant effectively in vacation merely because legacy raw status says vacation
```

Fixed in:

`a3cbd07`

Do not recycle vacation slots destructively; history should remain reconstructable.

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

# 18. Production data reset checkpoint — 2026-09-30

A controlled history cleanup was performed before October.

Deleted:

```text
Firestore:
chats/* recursively
spaces/substitution/statistics/*
spaces/substitution/confirmedCalls/*
spaces/substitution/shiftClaims/*
spaces/substitution.lastCall

Storage:
chat_media/*
group_avatars/*
```

Recursive chat deletion reported:

```text
950 docs
```

Intentionally retained:

```text
Firebase Auth users
users/*
users/*/devices/*
pushInstallations/*
spaces_access/*
spaces/substitution/participants/*
spaces/substitution.nextRotationOrder
spaces/substitution.revision
spaces/calendar/vacationPeriods/*
spaces/spacesBar
user_avatars/*
```

Substitution module after cleanup:

```text
nextRotationOrder = 278
revision = 173
lastCall absent
```

Then 8 real participants were called for:

```text
2026-10-01 day
```

Result:

```text
shiftClaims recreated
confirmedCalls recreated
statistics recreated
lastCall recreated
revision 173 → 181
nextRotationOrder 278 → 286
```

Architectural meaning:

```text
participants = current queue state
confirmedCalls/statistics = rebuildable operational history
shiftClaims = current additional-shift claims
module revision/order counters = monotonic infrastructure state
```

Do not infer current production history from records deleted before this checkpoint.

---

# 19. Calendar architecture

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

# 20. Calendar state / interaction

Key state:

```text
visibleMonth
selectedDate
compactFocusedDate
hasSelectedDate
viewMode
```

Historical docs may mention full/medium/compact.

Current practical UI focuses on full + compact.

Compact mode uses stationary selector / moving dates.

---

# 21. Additional shift projection

Domain:

`CalendarAdditionalShiftEvent`

Service:

`CalendarAdditionalShiftService`

Projection:

`CalendarAdditionalShiftProjection`

Source:

structured Substitution data.

Presentation:

```text
violet frame/marker
```

Do not create duplicate generic Calendar event collections when authoritative Substitution data can be projected.

---

# 22. Personal CalendarEntry

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

# 23. CalendarEntry service

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

# 24. One-off Calendar reminders

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

# 25. Shift Alarm scheduling domain

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

Shift alarms are separate from personal CalendarEntry reminders.

---

# 26. Native Shift Alarm bridge

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

# 27. Shift Alarm visual composition — WIP

Latest relevant commit:

`17a73b7 — wip(alarm): refine ringing screen visuals`

Problem source:

```text
design/branding/Аватар Чайки.png
→ square composed image
→ ocean + seagull + 19/4
```

One square bitmap cannot map cleanly to all tall Android screens.

Rejected behaviors included:

```text
CENTER_CROP composition loss
FIT_CENTER square panel
edge/band artifacts
19/4 still visible
```

Correct direction:

```text
adaptive root background
+
independent seagull layer
+
independent buttons
```

Preferred bird source:

`design/branding/Аватар Чайки трафарет.png`

Normalized target geometry:

```text
snooze centerY ~ 25%
bird centerY ~ 55–60%
stop centerY ~ 75%
```

Current visual must remain marked WIP / not accepted.

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

Calendar:

```text
Основные
Халтуры
Всего
```

Keep calculation out of widget code.

---

# 29. Calendar theme domain

Base:

`7343528`

Refinement:

`daedc9f`

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

Configurable:

```text
8 cycle tile colors
background
vacation
additional-shift border
selected day
monthly-hours bar
text scale
```

Derived:

```text
grid line
text contrast
```

Color editor:

```text
HEX
RGB sliders
RGB +/-1
```

Calendar theme is presentation state, not Firestore state.

---

# 30. Systemic Calendar theme integration

Affected:

```text
ShiftCalendarScreen
CalendarEntryEditorScreen
TimeWheelPickerSheet
```

Purpose:

```text
remove accidental global Material-theme leakage
agenda/editor/picker follow Calendar-local theme
```

Manual phone visual verification passed.

---

# 31. Chat lifecycle / Rules refinement

`ce22462` modified:

```text
firestore.rules
group_admin_lifecycle_rules.test.mjs
```

Purpose:

restore expected group-admin lifecycle and image-preview authorization behavior.

Do not overwrite these Rules with pre-fix versions.

---

# 32. Chat presentation refinement / known bug

`2ae2439` changed:

```text
ChatsPage
GroupMembersSection
```

Known bug:

```text
private peer message
→ Удалить у себя
→ may fail
```

Re-test before changing current Rules/service logic.

---

# 33. SpacesBar

Realtime presentation:

```text
general manager messages
Substitution call events
chat unread integration
```

Manager publish/edit paths remain role-gated.

The Hub Large layout does NOT complete the full accessibility roadmap.

Still pending:

```text
SpaceBar padding/readability pass
broader Large Text audit across app
```

---

# 34. Push notifications

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

Keep `pushInstallations` during data cleanups unless intentionally decommissioning tokens/installations.

---

# 35. EpiLite Web

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

# 36. Avatars / media

Existing foundation:

```text
UserAvatar
AvatarView
UserAvatarView
GroupAvatarView
ChatAvatarView
```

Storage:

```text
user_avatars/*
```

Production cleanup removed old:

```text
chat_media/*
group_avatars/*
```

`user_avatars/*` was intentionally retained.

---

# 37. Messaging foundation

Existing v0.7.x:

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

Production chat documents were intentionally cleared on 2026-09-30.

Attachment Composer, voice and general file transfer remain future blocks.

---

# 38. Performance discipline

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

# 39. Testing layers

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

Manual device tests remain important for:

```text
full-screen alarm
lock-screen behavior
Power button
Android visual scaling
Spaces Hub Large readability
```

---

# 40. Latest test evidence

Latest full suite at `b8618aa`:

```text
flutter test
→ 1241 passed
```

Latest analyzer:

```text
flutter analyze
→ No issues found!
```

Latest release APK:

```text
64.1 MB
```

Spaces Hub manual:

```text
layout selection persists after q/restart
visible tile selection works
reordering works
order persists
Grid/Large share order
```

Older Rules release-pass:

```text
Substitution Rules → 74/74
```

---

# 41. Generated files discipline

After last Flutter command before commit restore once:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Restore once at the end.

---

# 42. Firebase Hosting cache

`.firebase/` is local deploy cache.

Must remain ignored:

```text
/.firebase/
```

---

# 43. Build outputs

Android:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Latest:

`64.1 MB`

Web:

`build/web`

Build outputs are generated and not repository source.

---

# 44. Судозаходы — architecture discovery target

Current Hub ID:

`SpacesTileId.vesselCalls`

Current presentation:

```text
title: Судозаходы
subtitle: Суда и объём работ
```

Current behavior:

under-development placeholder.

No authoritative vessel-call Firestore architecture should be assumed yet.

Before implementation define:

```text
authoritative source
roles/permissions
document lifecycle
required fields
status model
history/audit requirements
notification behavior
Calendar/Substitution integration
Web requirements
read/query patterns
retention policy
```

Likely architecture should follow existing project principles:

```text
domain model
→ service
→ gateway
→ Firestore Rules
→ UI projection
```

But actual schema must come from agreed product workflow, not from placeholder text.

---

# 45. Current roadmap

Immediate new-chat topic:

```text
Судозаходы discovery / product design
```

Existing unfinished roadmap remains:

```text
Shift Alarm visual composition
Large Text / SpaceBar accessibility pass
Substitution Call Basket + Shift Cohort
private chat delete bug
remaining polish
release debt / release decision
Achievements if time
```

Backlog:

```text
Attachment Composer
voice messages
file transfer
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
legacy *MessageId cleanup
pushInstallations cleanup for deleted Auth users
Bus timetable after authoritative source
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

Expected functional checkpoint before docs update:

```text
b8618aa
```

For the next chat:

```text
do not reimplement Spaces Hub customization
do not assume a Судозаходы schema
first discuss real workplace workflow and authoritative data
then define MVP and only then code
```
