# Epistola — Architecture

> Detailed technical handoff for the current `v0.8.0` feature branch.
>
> Source priority:
>
> current code
> → `PROJECT_CONTEXT.md`
> → `ARCHITECTURE.md`
> → `README.md`

---

# 1. Repository / branch / checkpoint

Repository:

`MikhailBerezkin/epistola`

Current feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Current functional checkpoint:

`63da029 — feat(substitution): enforce shift call eligibility`

Previous major checkpoint:

`3358bc5 — feat(substitution): integrate crew and vacation status`

Stable baseline before v0.8.0:

`v0.7.4`

`v0.8.0` is not yet considered merged/released.

---

# 2. Product topology

Epistola is one Flutter/Firebase codebase with platform-specific capability gates.

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

Platform differences are isolated through capability/runtime helpers.

---

# 3. Core layering

Preferred layering:

```text
Flutter UI
→ screen / presentation orchestration
→ application service
→ domain model/resolver
→ Firebase gateway or device-local persistence
```

Rules:

```text
UI must not be sole business/security boundary
Firebase Rules must protect server-authoritative state
local-only personal data should not be pushed to Firestore without reason
deterministic business logic should stay in pure/testable services
```

---

# 4. Firebase projects / regions

Firebase project:

`epistola-434b7`

Firestore:

`eur3`

Cloud Functions:

`europe-west1`

Android package:

`com.epistola.app`

Production Hosting:

`https://epistola-434b7.web.app`

---

# 5. Main navigation

Root product areas:

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

Some tiles remain skeleton/future product areas.

Owner remains highest-priority role.

---

# 6. Platform capability layer

Files:

```text
lib/platform/epistola_platform_capabilities.dart
lib/platform/epistola_runtime_mode.dart
```

Current semantics:

```text
isWebLite → kIsWeb

supportsPushNotifications
→ Android/native true
→ Web false

supportsChats
→ true

supportsContacts
→ Web false

supportsSpacesBarManagement
→ true

supportsSubstitutionManagement
→ true

supportsSubstitutionAvailabilityChanges
→ true
```

Web product title:

`EpiLite`

Android product title:

`Epistola`

Do not scatter raw `kIsWeb` decisions throughout business code when a platform capability belongs in the capability abstraction.

---

# 7. Authentication / user document

Authoritative user profile:

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

`assignedCrew` is optional until selected.

Valid value:

```text
1..4
```

Missing crew must remain distinguishable from any actual crew.

---

# 8. Work schedule domain

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

Anchor indexes on `14.09.2026`:

```text
crew1 → 7
crew2 → 5
crew3 → 3
crew4 → 1
```

Therefore:

```text
14.09.2026
crew4 = day2
crew3 = night1
crew1 = offAfterRecovery2
```

---

# 9. ShiftScheduleCalculator

File:

`lib/services/spaces/calendar/shift_schedule_calculator.dart`

Single authoritative application calculation:

```dart
phaseFor(date, crew)
phaseIndexFor(date, crew)
```

Anchor:

`DateTime.utc(2026, 9, 14)`

Math:

```text
dayOffset = normalizedDate - anchorDate
phaseIndex = positiveModulo(crew.anchorPhaseIndex + dayOffset, 8)
```

Do not reproduce this calculation in random UI code.

Firestore Rules contain a separate equivalent only because Rules must independently validate protected server writes.

---

# 10. Assigned crew architecture

Implemented components:

```text
UserAssignedCrewService
UserAssignedCrewReader
AssignedCrewSelector
AssignedCrewSetupScreen
SubstitutionWorkProfileService
SubstitutionWorkProfileFirestoreGateway
```

Responsibilities:

```text
UserAssignedCrewService
→ write/validation policy for own selection

UserAssignedCrewReader
→ read/watch assignedCrew

AssignedCrewSelector
→ reusable crew UI

AssignedCrewSetupScreen
→ onboarding/setup route

SubstitutionWorkProfileService
→ manager editing work display name + crew

SubstitutionWorkProfileFirestoreGateway
→ Firestore persistence
```

Calendar subscribes to authoritative assignedCrew.

Substitution manager UI displays and can update participant crew under role rules.

---

# 11. Registration / onboarding

Current registration/profile flow supports assigned crew selection.

Business policy:

```text
ordinary user
→ can select own crew under allowed initial-selection semantics

manager/owner
→ can correct participant crew for active Substitution participants
```

Direct UI prompts exist where missing crew blocks work features.

Spaces prompt:

```text
Вам необходимо выбрать звено!
```

Calendar has direct crew setup action.

---

# 12. Substitution root model

Firestore root:

`spaces/substitution`

Module state:

```text
nextRotationOrder
revision
lastCall?
```

Participant collection:

`spaces/substitution/participants/{uid}`

Participant state fields:

```text
rotationOrder
availability
status
```

Typical availability:

```text
green
yellow
red
```

Status values include:

```text
active
vacation
sick
removed
```

Some visible effective status is derived from VacationPeriod rather than blindly persisted.

---

# 13. Canonical rotation

`rotationOrder` is the authoritative queue position.

Hidden/non-active participants preserve queue anchors where appropriate.

Manager rotation edits are atomic with module metadata required by Rules.

Do not rebuild queue order from UI list index.

---

# 14. Effective Vacation status

Service:

`SubstitutionEffectiveStatusResolver`

Purpose:

```text
participant stored state
+
current date
+
VacationPeriods
→ effective presentation status
```

Current VacationPeriod can project user into Vacation UI/state.

Deleting/ending the effective period returns participant to ordinary list while preserving canonical rotation.

Sick behavior remains separate; do not auto-conflate sick and vacation.

---

# 15. Vacation persistence

Collection:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Slot range:

`1..6`

Schema v1:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Dates are day-based UTC-oriented encoded values as defined by the existing mapper/service.

Services:

```text
VacationPeriodService
VacationPeriodFirestoreGateway
VacationPeriodMapper
VacationDateParser
```

UI:

```text
VacationPeriodsScreen
VacationPeriod editor
```

Calendar watches only current user's periods.

Substitution can watch all relevant participant periods for manager presentation.

---

# 16. Vacation parser

Friendly input supports examples:

```text
18.09.2026
18.09
18/09/2026
18/09
18 сентября
18 сентября 2026
```

Missing year uses current Calendar year.

Cross-year example:

```text
Calendar year = 2026
20.12 → 10.01
→ 20.12.2026 .. 10.01.2027
```

---

# 17. Vacation history invariant

Slots are persistence capacity, not visual history model.

Do not auto-recycle completed slots in a way that destroys calendar history.

Preferred future model:

```text
current/future working slots
+
recent server history
+
optional local long-term archive
```

---

# 18. Substitution shift model

File:

`lib/domain/models/substitution_shift.dart`

Kinds:

```text
day
night
```

Time semantics:

```text
day
08:00 → 20:00
same calendar day

night
20:00 → 08:00
ends next calendar day
```

Important helpers:

```text
startHour
endHour
endsOnNextCalendarDay
calendarDateUtc
```

---

# 19. Substitution call eligibility resolver

File:

`lib/services/spaces/substitution/substitution_call_eligibility_resolver.dart`

Output:

```text
SubstitutionCallEligibility
```

Unavailable reasons:

```text
missingCrew
vacation
workShift
```

Exception used by transaction:

```text
SubstitutionCallUnavailableException
```

Reason priority:

```text
1. missingCrew
2. vacation overlap
3. own work phase
4. eligible
```

---

# 20. Eligibility table

Allowed additional call by own cycle:

| Own phase | Day 08–20 | Night 20–08 |
|---|---:|---:|
| day1 | no | no |
| day2 | no | no |
| offBeforeNight | yes | yes |
| night1 | no | no |
| night2 | no | no |
| recovery | no | yes |
| offAfterRecovery1 | yes | yes |
| offAfterRecovery2 | yes | no |

Business meaning:

```text
recovery night
→ third night allowed

offAfterRecovery2 day
→ zero day allowed

offAfterRecovery2 night
→ forbidden because it enters next Day1
```

---

# 21. Vacation overlap semantics

Resolver compares user-specific VacationPeriods.

Day:

```text
check shift date
```

Night:

```text
check shift start date
check next date because night crosses midnight
```

Any overlap blocks additional call.

Other users' VacationPeriods are ignored.

---

# 22. UI call selection

Screen:

`lib/screens/substitution_space_screen.dart`

Before call dialog:

```text
resolve user from cache or refresh
require user data
require VacationPeriod stream not in error
construct today-night
construct tomorrow-day
resolve each independently
```

Dialog behavior:

```text
eligible option → enabled
ineligible option → disabled
red reason below disabled action
```

Current messages:

```text
Недоступно: не указано звено
Недоступно: отпуск
Недоступно: рабочая смена
```

Duplicate call has separate message:

```text
<displayName> уже вызван на эту смену
```

---

# 23. Transaction-level eligibility

File:

`lib/services/spaces/substitution/substitution_call_firestore_gateway.dart`

Transaction context now supports:

```text
readModule
readParticipant
readUser
readVacationPeriod
readPendingCall
readShiftClaim
...
```

Call order is intentional:

```text
read module
read participant
read duplicate claim
read user
read deterministic vacation documents
resolve eligibility
then writes
```

All reads before writes preserve Firestore transaction rules.

Vacation documents read:

```text
{uid}__1
...
{uid}__6
```

This is bounded/deterministic.

---

# 24. Atomic call documents

Call transaction coordinates:

```text
spaces/substitution
spaces/substitution/participants/{uid}
spaces/substitution/pendingCalls/{callId}
spaces/substitution/shiftClaims/{claimId}
```

`pendingCall` stores:

```text
callId
userId
revision
calledByUserId
calledAt
shiftYear
shiftMonth
shiftDay
shiftKind
```

`shiftClaim` stores:

```text
schemaVersion
userId
callId
calledByUserId
createdAt
shiftYear
shiftMonth
shiftDay
shiftKind
```

---

# 25. shiftClaim v2

File:

`substitution_shift_call_claim.dart`

Current create schema:

```text
schemaVersion = 2
```

Historical `v1` claim documents may remain readable/valid as historical records.

Rules for new create require:

```text
schemaVersion == 2
```

This deliberately makes old call protocol incompatible after production cutover.

---

# 26. Duplicate protection

Claim ID:

```text
{uid}__{year}_{month}_{day}__{kind}
```

If claim already exists:

```text
SubstitutionShiftAlreadyCalledException
```

Same participant can still be called for a different exact shift.

---

# 27. Firestore Rules — Substitution call security

Repository Rules now deployed to production.

New shiftClaim create requires:

```text
isSpacesManager()
valid shiftClaim shape
schemaVersion == 2
calledByUserId == request.auth.uid
server timestamp
atomic pendingCall relationship
valid participant/module relationship
valid assignedCrew
allowed work-cycle phase
```

Rules compute crew phase from the same anchor semantics:

```text
14.09.2026
8-day modulo
crew anchor index
```

Why Rules duplicate phase math:

```text
client resolver improves UX
transaction resolver protects current app races/stale UI
Rules protect Firebase from bypass/old client writes
```

Vacation overlap is not duplicated through six document reads inside Rules to avoid unnecessary access-call pressure; it remains enforced by the current transaction path.

---

# 28. Old APK boundary

After `schemaVersion = 2` Rules deploy:

```text
old APK
→ attempts new v1 shiftClaim create
→ denied
```

This is intentional for Substitution calls.

Historical content is not deleted.

Any previous documentation that says production is still transition-compatible with old Substitution calls is stale.

---

# 29. Undo

Call is temporarily undoable for roughly:

`3 seconds`

Undo contract:

```text
restore participant rotationOrder
remove module lastCall
delete pendingCall
delete shiftClaim
```

Rules enforce the atomic relationships and time window.

---

# 30. Call finalization / statistics

Existing pipeline keeps:

```text
confirmed calls
statistics
month/year call counts
shift-kind history
```

Finalization uses pending call data as source.

Do not count a call twice from SpacesBar or Calendar projection.

---

# 31. Participant overlay

Overlay shows participant details and management actions.

Recent layout change:

```text
content made scrollable
Substitution IdentityOverlay heightFactor ≈ 0.68
```

Reason:

```text
assignedCrew line increased vertical content
old fixed layout overflowed
```

Manual UI verification passed after change.

---

# 32. Calendar architecture

Calendar composition:

```text
base shift
+
Vacation overlay
+
additional shift projection
+
personal local agenda markers
```

Each layer has separate source/ownership.

Do not mutate base cycle to encode overlays.

---

# 33. Calendar authoritative crew

Current user schedule source:

```text
users/{uid}.assignedCrew
```

Reader:

`UserAssignedCrewReader`

Calendar can have temporary preview crew for settings UX, but preview is not authoritative profile state.

---

# 34. Calendar UI state

Modes:

```text
full
medium
compact
```

State concepts:

```text
baseMonth
visibleMonth
selectedDate
compactFocusedDate
hasSelectedDate
viewMode
```

Month paging and selected-day state are intentionally separate.

Compact central selection uses a stationary frame with moving date strip.

---

# 35. Additional shift domain

Model:

`CalendarAdditionalShiftEvent`

Service:

`CalendarAdditionalShiftService`

Projection:

`CalendarAdditionalShiftProjection`

Source should be existing structured Substitution data.

No extra "calendar events" Firestore collection is required if authoritative Substitution source can be projected directly.

---

# 36. Additional shift presentation

Calendar day presentation:

```text
violet marker/frame
```

Agenda/system row can represent structured additional shift separately from personal `CalendarEntry`.

Historical marker remains tied to authoritative call history.

Current production manual check:

```text
call for 25th
→ violet frame visible on 25th
```

---

# 37. Personal CalendarEntry

Personal data is local-only.

Model:

`CalendarEntry`

Kinds:

```text
task
note
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

Do not persist this domain to Firestore in current product architecture.

---

# 38. CalendarEntry persistence

Store:

`CalendarEntryLocalStore`

Backend:

`SharedPreferences`

Key namespace:

```text
calendar_entries_v1_<uid>
```

Payload includes:

```text
schemaVersion
entries[]
```

This prevents different accounts on same device/browser profile from mixing personal entries.

---

# 39. CalendarEntry service

`CalendarEntryService` owns:

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
timed active sorted by time
untimed after timed
completed ordered by completion timestamp where applicable
```

---

# 40. Calendar local reminders

Service:

`CalendarEntryReminderService`

Native integration:

`NotificationService`

Stable Android notification ID:

```text
CalendarEntry.id
→ deterministic FNV-style 32-bit hash
→ positive signed ID
```

Lifecycle:

```text
create with reminder → schedule
update → resync
bell off → cancel
completion → cancel
delete → cancel
reopen Calendar → reconcile
```

---

# 41. Exact reminder platform boundary

Android configuration:

```text
SCHEDULE_EXACT_ALARM
RECEIVE_BOOT_COMPLETED
ScheduledNotificationReceiver
ScheduledNotificationBootReceiver
AndroidScheduleMode.alarmClock
```

Web:

```text
exact local Android reminders are unsupported
```

`NotificationService` native code must remain behind platform-safe call paths.

---

# 42. Why alarmClock mode

Manual device observation:

```text
exactAllowWhileIdle
→ roughly 1–2 minute delay

alarmClock
→ delivered in requested minute
```

Calendar reminder uses ordinary system notification sound, not custom seagull messaging sound.

---

# 43. EpiLite Web architecture

Web config:

```text
web/index.html
web/manifest.json
lib/firebase_options.dart
firebase.json
```

Firebase Web app already configured.

`firebase.json` Hosting:

```json
{
  "public": "build/web",
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ]
}
```

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

---

# 44. EpiLite verification

Current production checks:

```text
desktop Chrome
→ Auth works
→ Spaces works
→ SpacesBar works
→ Calendar works
→ Substitution works

mobile browser
→ same core flow works
→ layout usable
```

Earlier Web checkpoint verified text chat flow and improved parallel user loading.

Web push remains unsupported.

---

# 45. Web local data semantics

Personal Calendar entries still use local platform persistence.

On Web this is browser-local persistence through the plugin/platform implementation.

Do not interpret this as cross-device sync.

If future product requires cross-device personal Calendar sync, that is a new privacy/product decision, not a hidden migration.

---

# 46. SpacesBar

SpacesBar is realtime presentation for work/general messages.

Sources can include:

```text
general manager messages
Substitution call events
chat unread integration
```

User can hide relevant items according to current service rules.

Manager editing/publishing is role-gated.

---

# 47. Push notifications

Cloud messaging foundation:

```text
Firebase Messaging
NotificationService
PushTokenService
```

Cloud Function region:

`europe-west1`

Deep links can open chat destinations.

Active chat suppression exists.

Image messages use expected custom notification semantics from v0.7.x.

Substitution call can produce push + SpacesBar event.

---

# 48. Push installation ownership

Registry:

`pushInstallations/{installationId}`

Schema includes:

```text
schemaVersion
userId
token
platform
updatedAt
```

Cloud callables:

```text
claimPushInstallation
releasePushInstallation
```

Invariant:

```text
installation belongs to one current authenticated user
user can own multiple installations
```

---

# 49. Avatars / media

Existing foundations remain:

```text
UserAvatar
AvatarView
UserAvatarView
GroupAvatarView
ChatAvatarView
```

Storage paths use versioned thumbnails/full images.

Known Web issue:

```text
chat avatar rendering may still require polish
```

Do not regress current Android caching behavior.

---

# 50. Messaging

Existing features from v0.7.x include:

```text
private/group chat
pagination = 20
image messages
push deep link
date separators
private read receipts
group reactions
private typing indicator
message deletion states
```

Known bug backlog:

```text
private chat
long-press peer message
Удалить у себя
may still fail
```

---

# 51. Performance discipline

Prefer:

```text
pagination
bounded reads
cache
parallel independent reads
central summaries
local persistence for private UI state
```

Examples:

```text
ChatMembersService Future.wait
SubstitutionUserCache
page size 20
deterministic six VacationPeriod reads only at call transaction
```

---

# 52. Firestore security principles

Server-authoritative state:

```text
validate shape
validate actor role
validate relationship between atomic writes
use getAfter for batch invariants
prevent standalone forged writes
```

Current Rules suite is essential before any deploy.

Recent Substitution Rules run:

`74/74 passed`

---

# 53. Testing layers

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

Full checkpoint:

```text
flutter test → 1161/1161
flutter analyze → clean
```

---

# 54. Production verification

2026-09-24:

```text
Firestore Rules deploy → success
release APK build → 61.0 MB
Android blocked-work-shift UI → success
Android allowed Substitution call → success
queue movement → success
Calendar violet marker → success
push → success
SpacesBar → success
Web build → success
Hosting deploy → success
desktop Web → success
mobile Web → success
```

This is the current strongest integration checkpoint.

---

# 55. Firebase Hosting cache

Local directory:

`.firebase/`

This is generated deploy cache.

Do not commit.

`.gitignore` should contain:

```text
# Firebase Hosting cache
/.firebase/
```

---

# 56. Generated Flutter files

Restore after last Flutter command before commit:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

This is expected workflow noise.

---

# 57. Build outputs

Android:

```text
build/app/outputs/flutter-apk/app-release.apk
61.0 MB at current release pass
```

Web:

```text
build/web
```

Build directories are generated and excluded from Git.

---

# 58. Current security state vs older docs

Older docs may mention:

```text
transition-compatible production Rules
legacy old-APK device writes
do not deploy repository firestore.rules
```

At current checkpoint these statements are obsolete because repository Rules were intentionally tested and deployed on 2026-09-24.

Current truth:

```text
production Rules = current deployed repository ruleset
new Substitution call requires shiftClaim v2
old Substitution call protocol is rejected
```

---

# 59. Current feature backlog

High-value future blocks:

```text
finish v0.8.0 release/merge/tag
private chat delete bug
Attachment Composer
voice messages
file transfer
Calendar compact marker polish
Calendar theme system
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
bus schedule when new authoritative timetable is available
```

Technical debt:

```text
legacy *MessageId naming
pushInstallations cleanup after deleted Auth users
```

---

# 60. New-chat protocol

First commands:

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

Source priority remains:

```text
code
→ PROJECT_CONTEXT
→ ARCHITECTURE
→ README
```

If docs update has just been applied locally, commit/push that docs checkpoint before starting the next feature block.
