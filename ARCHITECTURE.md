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
>
> **MD continuity rule:** these three MD files are cumulative project history. Update them from the existing documents, preserve large completed functional blocks and architectural history, and add new checkpoints incrementally. Do not rewrite the MD set from scratch just to refresh the latest state.

---

# 1. Repository / branch / checkpoint

Repository:

`MikhailBerezkin/epistola`

Current feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Last pushed functional checkpoint:

`72aba3a — feat(vessel-calls): refine vessel photos and registry editing`

Recent sequence:

```text
72aba3a — feat(vessel-calls): refine vessel photos and registry editing
5392b51 — feat(vessel-calls): add vessel photo foundation
fee17e7 — feat(vessel-calls): improve registry editing and live sync
cdc5329 — feat(vessel-calls): add registry schema v2 and production import
fe63edf — feat(vessel-calls): add vessel registry classification foundation
624f424 — docs: update vessel calls checkpoint and handoff
50355ff — feat(vessel-calls): add VPS ingest and revision-based cache refresh
8f41d80 — fix(alarm): restore native alarm sound channel
4fc9800 — test(vessel-calls): add firestore access rules
0cb3882 — feat(vessel-calls): add calendar cache and archive foundation
1efbcc7 — docs: update spaces checkpoint and vessel calls handoff
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
HEAD = origin = 72aba3a
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

Sound regression fix:

`8f41d80 — fix(alarm): restore native alarm sound channel`

Native alarm channel:

```text
epistola_shift_alarms_v3
AudioAttributes.USAGE_ALARM
AudioAttributes.CONTENT_TYPE_SONIFICATION
```

Reason for channel version bump:

```text
Android notification-channel sound/audio properties persist after channel creation.
A fresh native channel was required to reliably restore alarm sound semantics.
```

Physical Poco verification after fix:

```text
normal system alarm sound restored
```

Do not regress these behaviors while changing visuals.

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

Current next Web pass:

```text
latest Calendar changes
+
Vessel Calls
```

Owner decision is to finish Vessel Calls Android/archive behavior first and add both to Web together.

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
revision/hash based refresh for Vessel Calls
```

Pilot:

`40–50 users`

Avoid unnecessary Firestore listeners and duplicated projection collections.

For Vessel Calls specifically:

```text
VPS content hash suppresses unchanged publishes
device revision check TTL = 30 minutes
unchanged month revision avoids snapshot reads
```

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
Vessel Calls timeline/full-month rendering
```

---

# 40. Latest test evidence

Latest full suite at functional checkpoint `50355ff`:

```text
flutter test
→ 1241 passed
→ All tests passed!
```

Latest analyzer:

```text
flutter analyze
→ No issues found!
```

Latest release APK:

```text
64.3 MB
```

Vessel Calls phone verification:

```text
real current data displayed
repeat open works
full-month view works
timeline/cards remain visible
```

Vessel Calls Rules:

```text
84/84 passed
```

Spaces Hub manual verification from earlier checkpoint remains valid:

```text
layout selection persists after q/restart
visible tile selection works
reordering works
order persists
Grid/Large share order
```

Older Substitution Rules release-pass remains historical evidence:

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

`64.3 MB`

Web:

`build/web`

Build outputs are generated and not repository source.

---

# 44. Судозаходы / Vessel Calls architecture

Current Hub ID:

`SpacesTileId.vesselCalls`

Current presentation:

```text
title: Судозаходы
subtitle: Суда и объём работ
```

## Source boundary

Current source used for the implemented foundation:

```text
Global Ports
First Container Terminal / ПКТ
public vessel schedule frontend
```

Public page:

```text
https://www.globalports.com/ru/terminals/first-container-terminal/online-services/Vessels-fct/
```

Observed backend endpoint:

```text
https://rpt.rlisystems.ru/api/conterra/primsyb.SEAPORT/rpc/171/1710027
```

POST modes:

```text
plan
crnt
closed
```

Source credentials/authorization are secrets and must never be committed.

Known fields observed in source payloads include:

```text
line_name
ship_name
state_name
callsign
voynumber
outvoynumber
calling_id
calling_name
calling_status
calling_status_color
plan_calling_date
plan_saling_date
calling_date
saling_date
process_beg
process_end
real_process_start
real_process_finish
raid_date
load_proc_end
state_date
multiple workload/document fields
```

Current time normalization:

```text
berthFrom = calling_date ?? plan_calling_date
berthTo   = saling_date  ?? plan_saling_date
```

Temporary mappings that MUST NOT be mistaken for authoritative domain data:

```text
calling_id → vesselImo field temporarily
all vesselType → container temporarily
operationKind → cargo temporarily
lane 0..3 → visual lane only
```

The planned real berth set:

```text
83
85
86
87
```

must not be inferred from temporary lane indexes.

## Flutter/service boundary

Current files:

```text
lib/screens/vessel_calls_space_screen.dart
lib/services/spaces/vessel_calls/vessel_calls_local_cache.dart
lib/services/spaces/vessel_calls/vessel_calls_current_month_firestore_gateway.dart
lib/services/spaces/vessel_calls/vessel_calls_month_archive_firestore_gateway.dart
lib/services/spaces/vessel_calls/vessel_calls_month_cache_service.dart
```

Cached domain:

```text
CachedVesselMonth
CachedVesselCall
VesselCallCacheSource
```

Cached call fields include:

```text
id
vesselImo
vesselName
vesselType
operationKind
lane
berthFrom
berthTo
updatedAt
source
```

Presentation currently supports:

```text
5-day compact timeline
full-month vessel calendar
crew shift borders
vessel cards
arrival/departure
duration/countdown/progress
four temporary lanes
```

## Firestore projection

Document paths:

```text
spaces/vesselCalls/monthMeta/{YYYY-MM}
spaces/vesselCalls/monthSnapshots/{YYYY-MM}
spaces/vesselCalls/monthArchives/{YYYY-MM}
```

Client access:

```text
authenticated read
client write denied
```

Admin/ingest writes are intentionally server-side.

## Client cache discipline

Old 3-day refresh policy was removed.

Current device strategy:

```text
SharedPreferences local month
revision check TTL = 30 minutes
```

Flow:

```text
screen open
→ render local month immediately if present
→ if revision check not due: no Firestore read
→ if due: read monthMeta
→ same revision: mark checked and stop
→ new revision: read monthSnapshot, rebuild local month, persist, repaint
```

No local month:

```text
monthMeta
→ monthSnapshot
→ persist real month locally
```

If the remote check fails:

```text
keep local cache usable
do not mark failed revision check complete
retry on a later open
```

Preview/demo data must never be persisted as real Vessel Calls cache.

## Cloud ingest boundary

Function:

`ingestVesselCallsMonth`

Source:

```text
functions/src/vessel_calls_ingest.ts
functions/src/index.ts
```

Region:

`europe-west1`

Security:

```text
POST
Bearer secret
Firebase secret storage
Admin SDK writes
```

Writes:

```text
monthMeta
monthSnapshots
```

Client Rules remain read-only.

Local Windows fallback/dev tools:

```text
tools/vessel_calls_sync.ps1
tools/vessel_calls_publish.ps1
tools/vessel_calls_output/.gitignore
```

Raw JSON output remains ignored.

## VPS publisher boundary

Primary source fetching is intentionally outside mobile/web clients.

Architecture:

```text
ПКТ public backend
→ VPS updater.py
→ normalize/hash
→ enabled Firebase target(s)
→ ingestVesselCallsMonth
→ Firestore projection
→ Epistola/EpiLite clients
```

Current VPS foundation:

```text
Ubuntu 24.04
/opt/epistola-vessel-calls
system user epistola-vessels
```

Secrets:

```text
/etc/epistola-vessel-calls.env
root-owned
0600
never committed
```

Target config:

```text
/opt/epistola-vessel-calls/targets.json
```

Portable target matrix supports:

```text
19/1 .. 19/4
20/1 .. 20/4
```

Currently enabled:

```text
19/4
```

Updater behavior:

```text
Python standard library only
fetch plan / crnt / closed
merge plan + current by calling_id
normalize current month
calculate stable content hash
keep per-target hashes in state/
publish only when changed
per-target failures remain independent
```

Systemd:

```text
epistola-vessel-calls.service
→ oneshot

epistola-vessel-calls.timer
→ enabled
→ automatic checks approximately every 2 hours
→ starts after reboot
```

Manual autonomous service test passed:

```text
systemd environment loaded
ПКТ fetch succeeded
snapshot normalized
unchanged hash detected
Firebase publish skipped
service exited SUCCESS
```

First real VPS publish passed:

```text
plan = 42
crnt = 0
closed = 66
normalized current-month calls = 30
19/4 published successfully
```

Immediate second run:

```text
same normalized content hash
→ Firebase publish skipped
```

This separation is deliberate:

```text
clients never call ПКТ directly
VPS secrets never enter app bundles
Firebase remains the application-facing cache/projection
```

## Security invariant

Never commit or reproduce real values of:

```text
source Basic Authorization
VESSEL_CALLS_INGEST_TOKEN
```

They belong only in secret storage / VPS environment.

Old experimental Cloud probe/source-auth secret should be reviewed and cleaned later after the production path is stable.

## Current archive gap

`closed` is fetched and counted by the updater, but is not yet merged into current snapshot/archive behavior.

Current effect:

```text
departed vessels may disappear from the visible current month
```

Next architecture task:

```text
preserve completed vessel history
archive past months
render completed/closed ranges in grey
retain active/planned color semantics
```

Before extending the domain, inspect source evidence for:

```text
true IMO
true berth
vessel type
container/bulk distinction
cargo/workload
actual processing status
```

---

# 45. Current roadmap

Immediate next block:

```text
Vessel Calls closed/archive support
→ completed vessels stay visible/reconstructable
→ grey completed strips/cards
→ past-month archive
→ inspect source fields for real berth/IMO/type/workload
```

After Vessel Calls is finished:

```text
EpiLite Web
→ integrate latest Calendar changes
→ integrate Vessel Calls
→ verify desktop/mobile browser
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
portable VPS updater copy / ops documentation
old experimental Vessel Calls cloud probe cleanup
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
50355ff
```

MD continuity rule:

```text
do not rewrite these three MD documents from scratch
preserve accumulated historical/functional blocks
update existing sections incrementally
remove only clear duplicates or obsolete small details
```

For the next chat:

```text
do not reimplement VPS updater
do not reimplement ingestVesselCallsMonth
do not restore old 3-day client refresh
do not persist preview data into real Vessel Calls cache

continue with:
closed/archive vessel history
→ grey completed presentation
→ authoritative field discovery
→ then latest Calendar + Vessel Calls Web integration
```
---

# 47. Vessel Registry v2 — update through `72aba3a`

This section extends the existing architecture without removing the historical blocks above.

Relevant sequence:

```text
fe63edf — registry classification foundation
cdc5329 — registry schema v2 and production import
fee17e7 — registry editing/live sync
5392b51 — vessel photo foundation
72aba3a — photo/UI/cache refinement + registry editing fix
```

Server collections:

```text
spaces/vesselCalls/lineRegistry/{lineId}
spaces/vesselCalls/vesselRegistry/{vesselUid}
```

Rules:

```text
signedIn → read
isSpacesManager(owner/brigadier) → create/update
delete → false
```

Registry v2 deliberately separates technical vessel type from terminal work category:

```text
VesselPhysicalType
→ container
→ bulk
→ reefer
→ multipurpose
→ generalCargo
→ other
→ unknown

VesselWorkType
→ container
→ bulk
→ other
→ unknown
```

Vessel registry classification fields:

```text
physicalType
defaultWorkType
allowedWorkTypes
workTypeOverride
```

Effective work type:

```text
workTypeOverride ?? defaultWorkType ?? legacy workType ?? unknown
```

Compatibility field `workType` remains available to older code while the mapper writes schema v2.

Identity boundary:

```text
calling_id
→ vessel-call identity in the monthly source projection

vesselUid
→ stable Epistola registry document identity

IMO
→ optional real physical-vessel identifier/property
```

A vessel that already exists under a stable manual `vesselUid` does not automatically migrate document/photo identity when an IMO is later entered.

The `72aba3a` stale-registry fix re-resolves the latest registry entry before editing/saving/displaying IMO, preventing the card/editor from continuing to show a stale `vessel.registryEntry`.

---

# 48. Vessel photo architecture — current stable foundation

Storage:

```text
vessel_photos/<stableVesselKey>/v<version>/thumb.jpg
vessel_photos/<stableVesselKey>/v<version>/full.jpg
```

Registry metadata:

```text
photoPath
photoThumbPath
photoFullPath
photoVersion
```

Presentation reads:

```text
list → effectivePhotoThumbPath
expanded card → effectivePhotoFullPath
```

`photoPath` remains a legacy/fallback compatibility field.

Preparation:

```text
ImagePicker
→ fixed 16:9 crop
→ VesselPhotoProcessor
→ thumb + full JPEG
```

Limits:

```text
thumb:
maxDimension = 640
hard max = 192 KiB

full:
maxDimension = 2560
target = 1024 KiB
hard max = 2048 KiB
```

Storage Rules enforce the supported JPEG/photo metadata contract and 2 MiB full-file ceiling.

Replacement transaction ordering:

```text
upload new version
→ update Firestore photo metadata
→ delete old version
```

Rollback:

```text
Firestore update failure
→ delete newly uploaded files
```

Client image cache:

```text
VesselPhotoUrlCache
→ memory URL cache
→ in-flight dedupe
→ selected-day thumb preload, max parallel 10

VesselPhotoImage
→ CachedNetworkImage
→ disk cache
→ cacheKey = storagePath + photoVersion
```

The cache key intentionally includes `photoVersion` so replacing a photo does not reuse an old cached bitmap.

---

# 49. Vessel Calls UI state after `72aba3a`

List card:

```text
photo column width = 112
photo = 112×63
ratio = 16:9
thumb only
Где судно button below photo
name centered in right content area
```

Expanded card:

```text
bottom sheet begins with full-width 16:9 hero
full photo
custom drag handle overlays hero
vessel name + physical/work type overlays lower image
small blur + class-color gradient blend into details
no duplicate lower Где судно button
```

Do not reintroduce the earlier `OverflowBox` approach for the hero: it caused the modal to appear stuck behind the dim overlay. `SizedBox(width: double.infinity) + AspectRatio(16/9)` is the accepted stable structure.

Current class tint tuning is accepted for now; do not spend the next block retuning colors.

---

# 50. Approved monthly archive architecture

The Firestore month boundary stays authoritative for client caching:

```text
monthMeta/{YYYY-MM}
monthSnapshots/{YYYY-MM}
monthArchives/{YYYY-MM}
```

Lifecycle invariant:

```text
one calling_id
→ one logical call
→ may appear in plan, crnt and closed source modes
→ source mode changes must update the same call, not clone it
```

For an active/future month:

```text
monthSnapshot
→ mutable monthly projection
→ includes planned/current calls
→ after next block also keeps completed/closed calls for the month
```

For a finished month:

```text
monthArchive
→ final monthly projection
→ isArchived = true
→ one Firestore document contains the complete archived month
```

Media/registry separation:

```text
month archive
→ schedule/history fields only

vesselRegistry + vessel_photos
→ persistent vessel metadata/media
```

Client read path:

```text
VesselCallsMonthCacheService.loadArchivedMonth()
→ local isArchived month first
→ otherwise VesselCallsMonthArchiveFirestoreGateway.loadMonth()
→ one document read
→ write local SharedPreferences cache
```

Archived local months are not part of the 30-minute active revision polling path.

Do not add hidden archive polling without first defining how late official corrections should invalidate an already-cached archive.

---

# 51. NEXT architecture — full ПКТ set → independent monthly projections

Current VPS source reads:

```text
plan
crnt
closed
```

Current implementation gap:

```text
plan + crnt merged
current month normalized/published
closed only fetched/count logged
```

Target normalizer:

```text
source rows
→ map keyed by calling_id

apply:
plan
then crnt
then closed

priority:
closed > crnt > plan
```

After merge:

```text
normalize all valid calls
→ bucket by YYYY-MM
→ compute stable hash for each target/month/projection-kind
→ publish only changed months
```

Do not publish one unbounded `fullList` Firestore document.

Initial bucket key should preserve current source semantics:

```text
effective berthFrom =
calling_date ?? plan_calling_date

bucket =
YYYY-MM of berthFrom
```

One cross-month call remains one logical call. Any need to draw its tail in the adjacent month's UI is a projection/presentation issue, not permission to create a second call identity.

Publisher destinations:

```text
current/future monthly projection:
monthMeta/{YYYY-MM}
monthSnapshots/{YYYY-MM}

finished past monthly projection:
monthArchives/{YYYY-MM}
```

Cloud Function `ingestVesselCallsMonth` already accepts `isArchived`; the next server implementation must make it control destination:

```text
false
→ meta + snapshot

true
→ archive
```

Keep Admin SDK as the only write route for these monthly projections.

Per-month hash/revision is required so a changed future month does not rewrite an unchanged archived month.

---

# 52. Lifecycle state and completed-grey presentation

Do not conflate two different concepts:

```text
VesselCallCacheSource
→ monthlySnapshot / operational / archive

PKT lifecycle
→ plan / crnt / closed
```

The existing cached `source` field is the first concept only.

The next block should introduce an explicit normalized lifecycle field only after choosing its name and contract, then change all of these together:

```text
VPS normalizer
Cloud Function payload interface/validation
CachedVesselCall
JSON serialization
screen model
grey completed presentation
tests
```

Desired product result:

```text
plan/crnt
→ existing work-type color semantics

closed/completed
→ remains visible
→ grey completed timeline strip
→ grey/finished card/status treatment
```

The current classification type (container/bulk/other) must remain separate from completion lifecycle.

---

# 53. Full-list/archive deployment guardrails

The VPS updater is operational production infrastructure. Changes should be reversible.

Procedure:

```text
check timer/service
→ stop timer temporarily
→ timestamped backup of updater.py
→ install all-month version
→ dry-run without Firebase writes
→ inspect safe counts:
   plan/crnt/closed
   merged unique calling_id
   per-month bucket counts
→ verify zero logical duplicates
→ run unit/local normalization checks
→ manually publish controlled target
→ verify Firestore current/archive destinations
→ run Android current + past-month checks
→ re-enable ~2-hour timer
```

Never print source Authorization or ingest secrets during diagnosis.

Minimum acceptance:

```text
no hardcoded 2026-10/current-month-only filter
closed > crnt > plan merge is deterministic
one calling_id remains one call
all represented months are bucketed
current/future snapshots publish
past finalized month archives
monthly hash suppresses unchanged writes
Android archive read stays one-document-per-month
Firestore client writes remain denied
```

---

# 54. Current verification / new-chat start

Latest functional checkpoint:

```text
72aba3a
HEAD = origin = 72aba3a
working tree CLEAN immediately after push
```

Latest targeted checks:

```text
flutter analyze
→ No issues found!

flutter test test/services/spaces/vessel_calls
→ 25 passed
→ All tests passed!
```

Physical phone:

```text
IMO persistence fix verified
photo/registry UI block verified during development
```

Next chat should NOT reimplement:

```text
VPS timer foundation
ingestVesselCallsMonth base endpoint
30-minute active month revision cache
Vessel Registry v2
photo Storage/cache foundation
```

Start directly from the full-list/month-bucketing/archive block described above.
