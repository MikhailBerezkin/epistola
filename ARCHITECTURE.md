# Epistola — Architecture

Основной технический документ проекта Epistola.

При конфликте информации:

```text
текущий исходный код feature-ветки
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` хранит operational handoff/current checkpoint.

`ARCHITECTURE.md` фиксирует устойчивые технические решения.

`README.md` предназначен для краткого обзора.

---

# 1. Status

| Параметр | Значение |
|---|---|
| Current target | `v0.8.0` |
| Stage | `Spaces / Substitution / EpiLite / Calendar / Vacation / Local Agenda` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Latest functional checkpoint | `27cce8e` |
| Web chats/performance checkpoint | `764d3de` |
| Push installation ownership | `67800f0` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Full platform | Android / `Epistola` |
| Lightweight Web/PWA | `EpiLite` |
| Pilot target | 40–50 users |

`v0.8.0` ещё не declared merged/released.

Docs-only commit may move `HEAD` beyond `27cce8e`.

---

# 2. Canonical layers

```text
Flutter UI
    ↓
Presentation / Screen orchestration
    ↓
Controllers / Application Services
    ↓
Domain Models / Contracts
    ↓
Firebase / Local persistence gateways
    ↓
Firebase or device-local storage
```

UI owns:

```text
rendering
gestures
navigation
dialogs
loading/error states
animations
local visual preferences
responsive layout
platform-specific presentation branching
```

UI must not own:

```text
Firestore transaction invariants
authoritative security
server ownership invariants
backend schema derived from visual state
role authorization copied into widgets
```

Application services own orchestration/validation.

Gateways/adapters own persistence reads/writes, mapping and transactions.

Domain must not depend on Flutter visual state.

---

# 3. Firebase infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore: eur3
Realtime Database: europe-west1
Cloud Functions: europe-west1
Functions runtime: Node.js 22
Android package: com.epistola.app
Hosting: https://epistola-434b7.web.app
```

Pilot principles:

```text
40–50 users
avoid per-widget Firestore reads
parallelize independent reads
cache reusable user/role data by UID
keep personal/local presentation data off Firestore when server authority is unnecessary
persist reorder only on Apply
reuse canonical business events for multiple projections
```

---

# 4. Platform capability boundary

Centralized in:

`lib/platform/epistola_platform_capabilities.dart`

Critical separation:

```text
platform capability
≠ business authorization
≠ Firestore security
```

Current policy:

```text
supportsPushNotifications
→ Android true
→ Web false

supportsChats
→ Android true
→ Web true
```

Known Web presentation gap:

`chat avatars may fail to render`

---

# 5. Runtime Test Mode boundary

File:

`lib/platform/epistola_runtime_mode.dart`

Enable:

```powershell
flutter.bat run --dart-define=EPISTOLA_TEST_MODE=true
```

Invariant:

```text
Test Mode != full Firebase sandbox
```

Do not assume unrelated Firebase/FCM writes are isolated unless explicitly guarded.

---

# 6. Products

```text
Epistola
→ Android full client

EpiLite
→ Flutter Web / PWA
```

Shared backend:

```text
Firebase Auth
Firestore
Firebase Storage where supported
Cloud Functions where applicable
```

Do not create separate business collections only for Web presentation.

Web push remains unsupported.

---

# 7. Web user loading

Current optimization:

```text
ChatMembersService
SubstitutionUserCache
→ independent user fetches use Future.wait
```

Goal:

```text
reduce perceived latency
avoid serialized network round trips
keep same data contract
```

---

# 8. Root navigation

Root:

`lib/screens/home_screen.dart`

Indexes:

```text
0 Contacts
1 Spaces
2 Profile
```

Default:

`Spaces`

Back:

```text
Contacts → Spaces
Profile → Spaces
Spaces → exit
```

Messenger:

`Spaces → Чаты`

---

# 9. Spaces roles

Roles:

```text
member
brigadier
owner
```

`owner` remains highest priority.

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

UI visibility is not a security boundary.

---

# 10. SpacesBar domain/backend

Authoritative document:

`spaces/spacesBar`

Schema v1:

```text
revision
messages
updatedAt
```

Capacity:

`3 active general messages`

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Do not persist presentation-only state:

```text
Color
glow
carousel page
local hide state
```

Local hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

---

# 11. SpacesBar presentation

Current UI contract:

```text
stationary neutral outer frame
colored inner glow near frame
neutral center
true cyclic/infinite PageView
manual drag interpolates glow
auto rotation uses same PageController
```

Timing:

```text
dwell = 10 sec
slide = 1000 ms
```

Personal substitution items merge into same presentation model but do not consume general `3/3`.

---

# 12. Substitution participant model

Path:

`spaces/substitution/participants/{userId}`

Statuses:

```text
active
vacation
sick
removed
```

Canonical rotation contains active and inactive participants.

Inactive states retain hidden `rotationOrder` anchors.

`removed` is soft membership removal.

---

# 13. Substitution gateway separation

Keep separate write contracts:

```text
SubstitutionParticipantStateFirestoreGateway
SubstitutionRotationMembershipFirestoreGateway
SubstitutionRotationEditFirestoreGateway
SubstitutionCallFirestoreGateway
```

Do not merge distinct transaction invariants into one generic gateway.

---

# 14. Rotation editor

Editing local until Apply.

Apply:

```text
read canonical state
validate revision/conflict
normalize rotationOrder
persist atomically
```

Conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# 15. Call transaction with shiftClaims

Path:

`spaces/substitution/shiftClaims/{claimId}`

Purpose:

```text
one concrete work shift
→ cannot be called twice
```

Atomic call transaction:

```text
pendingCalls/{callId}
shiftClaims/{claimId}
participants/{userId}.rotationOrder
spaces/substitution revision/lastCall/nextRotationOrder
```

Standalone pendingCall/shiftClaim is invalid.

---

# 16. Undo / finalize

Undo window:

`3 seconds`

Undo atomic operation:

```text
delete pendingCall
delete shiftClaim
restore participant rotation
restore allowed module state
```

Finalize transaction:

```text
read pendingCall
validate expiry
calculate statistics
write/update statistics
write immutable confirmedCall
delete pendingCall
```

Confirmed event:

`spaces/substitution/confirmedCalls/{callId}`

Exactly-once protected by pendingCall deletion in same transaction.

---

# 17. Self-return from sick

Repository behavior:

```text
ordinary participant:
own sick → active
```

Cannot change:

```text
rotationOrder
another participant
unrelated fields
```

Vacation remains separate.

This repository change is not yet part of the production transition migration.

---

# 18. Push deep links

Types:

```text
chat
spacesBar
```

Unified field:

`spacesBarPresentationId`

Values:

```text
general:<messageId>
substitution:<callId>
```

Legacy internal `*MessageId` names remain technical debt.

---

# 19. Push installation ownership

Stable identity:

`SharedPreferences → push_installation_id`

Format:

```text
16 secure random bytes
→ 32 lowercase hex
```

Invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installationIds
```

FCM token is delivery address, not installation identity.

Registry:

`pushInstallations/{installationId}`

Schema v2:

```text
schemaVersion
userId
token
platform
updatedAt
```

Callables:

```text
claimPushInstallation
releasePushInstallation
```

Region:

`europe-west1`

---

# 20. Production Rules migration state

Repository target:

```text
users/{uid}/devices/{deviceId}
read own → allowed
client create/update/delete → denied
```

Production transition currently contains:

```text
shiftClaims
VacationPeriod Rules
legacy old-APK own device writes
```

Legacy write schema:

```text
token
platform
updatedAt
```

Production intentionally does not yet equal repository rules.

Do not blindly deploy repository `firestore.rules`.

---

# 21. Calendar base schedule

Base model:

```text
4 crews
8-day repeating cycle
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

Base schedule is immutable/deterministic.

Exceptions = overlays.

---

# 22. ShiftCyclePhase presentation

`ShiftCyclePhase` keeps compact `displayLabel` for tiles.

Added human-readable `displayTitle` for selected-day header:

```text
day1 → День 1
day2 → День 2
night1 → Ночь 1
night2 → Ночь 2
recovery → Отсыпной
all off variants → Выходной
```

Business phase identity remains unchanged.

---

# 23. Calendar presentation modes

Modes:

```text
full
medium
compact
```

Persistence:

```text
SharedPreferences
shift_calendar_view_mode
```

Default:

`medium`

Crew + mode load before render.

Selected digit is red.

Selected shift title is emphasized in header.

---

# 24. Calendar selection/navigation model

State separation:

```text
visibleMonth
selectedDate
compact focused/center date
```

Full/medium month change:

```text
visible month changes
explicit selected date is cleared
same day number is not auto-carried into next month
```

Compact:

```text
stationary central frame
PageView scroll underneath
scroll start cancels pending commit
scroll end schedules commit
settle delay = 250 ms
tap side day animates to center
```

Phase is always computed by:

`ShiftScheduleCalculator.phaseFor(date, crew)`

Never infer shift phase from visual position.

---

# 25. Calendar header/menu

Header:

```text
Month Year
selected shift title
Today/replay action
⋮
```

Menu:

```text
current crew
Отпуска
Будильники
Темы календаря
```

Vacation action is implemented.

Other menu actions remain future orchestration.

---

# 26. Calendar overlay architecture

Effective work-day concept:

```text
baseShift
+ vacationOverlay
+ sickOverlay
+ substitutionOverlay
+ additionalShiftOverlay
```

Never rewrite base 8-day schedule for exceptions.

Personal local entries are a separate presentation layer and do not change work-schedule truth.

---

# 27. VacationPeriod domain

Persistence:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Schema v1:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Date storage:

`YYYYMMDD integer`

Document ID:

`<userId>__<slot>`

Technical capacity:

`1..6`

Slots are persistence capacity only.

---

# 28. Vacation ownership Rules

Signed-in:

```text
get/list vacationPeriods → allowed
```

Write:

```text
user create/update/delete only own vacation period
```

No manager override.

Validation:

```text
exact field set
schemaVersion = 1
valid userId
slot 1..6
valid YYYYMMDD
endDay >= startDay
updatedAt timestamp
updatedAt == request.time
document ID matches userId + slot
```

Vacation Rules are deployed in production on top of transition compatibility.

---

# 29. Vacation parser/service/UI

Implemented:

```text
VacationDateParser
VacationPeriodService
VacationPeriodEditorScreen
VacationPeriodsScreen
```

Accepted input:

```text
18.09.2026
18.09
18/09/2026
18/09
18 сентября
18 сентября 2026
```

No year:

`use current Calendar year`

Cross-year:

```text
20.12 → 10.01
Calendar year 2026
→ 20.12.2026 .. 10.01.2027
```

UI:

```text
show actual saved periods
+ Добавить отпуск
edit pencil
delete in editor
```

Calendar watches current user's periods and draws pink inclusive markers.

---

# 30. Vacation history invariant

Do not auto-recycle slots with data loss.

Desired future model:

```text
working current/future slots
+
recent server history ≈ 1–2 years
+
optional local long-term archive
```

Historical Calendar coloring must remain reconstructable.

Visible History screen is not required now.

---

# 31. Vacation → Substitution automation

Not implemented.

Desired:

```text
startDate → if applicable status = vacation
already vacation → no-op
day after endDate → if still vacation, status = active
```

Sick automation must remain untouched.

Known pilot limitation: user-owned VacationPeriod dates can influence auto-return until stronger manager-confirmation semantics are introduced.

---

# 32. Personal CalendarEntry domain

Personal entries are device-local only.

No Firestore collection is used or planned for first version.

Model:

```text
CalendarEntry
```

Kinds:

```text
task
note
```

Fields:

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

Date is normalized to day-only.

Time values are minutes from midnight.

Reminder time is independent from task time.

---

# 33. Personal entry persistence

Persistence:

`SharedPreferences`

Storage is namespaced by authenticated `uid`.

Components:

```text
CalendarEntryMapper
CalendarEntryLocalStore
CalendarEntryService
```

Service owns:

```text
create
update
delete
loadForUser
loadForDay
setCompleted
sorting
```

Duplicate `id` save updates existing entry.

Different users on one device are isolated.

---

# 34. Personal entry sorting

For selected day:

```text
active entries first
completed tasks below active
timed active entries sorted ascending by time
entries without time after timed
```

Completed tasks may be returned to active state.

Notes cannot be completed.

---

# 35. Personal entry editor

Screen:

`lib/screens/calendar_entry_editor_screen.dart`

Create/edit uses same screen.

Supports:

```text
title
optional scheduled time
priority
description / note text
bell switch
optional independent reminder time
delete with confirmation in edit mode
```

Edit preserves existing completed state when service update remains task.

---

# 36. Time wheel architecture

Time input uses:

`CupertinoPicker`

Two wheels:

```text
hours 00..23
minutes 00..59
```

Both:

`looping: true`

This replaces circular Material clock selection.

---

# 37. Agenda panel architecture

Selected date opens agenda panel.

Bottom action bar:

```text
[ Дело ]   Добавить   [ Заметка ]
```

No intermediate “Что добавить?” sheet.

Entries render in scrollable list.

Bottom Add bar remains fixed.

Task checkbox completion and row tap are independent interactions.

Row tap opens editor.

---

# 38. CalendarEntry day markers

Derived helper:

`CalendarEntryDayMarkers`

Active-entry projection:

```text
plain entry without reminder → note icon
entry with reminder → bell icon
highest active priority → priority dot
completed task → ignored
```

Priority order:

```text
none < low < medium < high
```

Current visual colors:

```text
low → green
medium → amber
high → red
```

Full/medium marker integration is present.

Compact final marker layout still needs tuning.

---

# 39. Local reminder scheduling architecture

Implemented at:

`27cce8e — feat(calendar): add exact local reminders`

Ownership:

```text
CalendarEntryService
→ entry persistence lifecycle
→ delegates reminder lifecycle

CalendarEntryReminderService
→ stable notification identity
→ permission orchestration
→ schedule/cancel/reconcile policy

NotificationService
→ Android notification plugin integration
→ timezone initialization
→ exact scheduling/cancel operations
```

The editor UI does not own Android scheduling directly.

Stable identity:

```text
CalendarEntry.id
→ deterministic 32-bit FNV-style hash
→ positive signed Android notification ID
```

Lifecycle contract:

```text
create with reminder → schedule
edit reminder/date → reschedule same notification identity
bell off → cancel
delete → cancel
complete task → cancel
restore completed task → schedule again when applicable
Calendar load → reconcile persisted local entries
```

Local persistence remains authoritative for personal Calendar entries. Firestore is not involved.

Timezone stack:

```text
flutter_timezone
→ device timezone identifier
→ timezone package
→ tz.local
```

Android dependencies/configuration:

```text
flutter_local_notifications
timezone ^0.11.1
flutter_timezone ^5.1.0
RECEIVE_BOOT_COMPLETED
SCHEDULE_EXACT_ALARM
ScheduledNotificationReceiver
ScheduledNotificationBootReceiver
```

Scheduling mode:

```text
AndroidScheduleMode.alarmClock
```

Reason for mode choice:

```text
exactAllowWhileIdle
→ real-device delay observed around 1–2 minutes

alarmClock
→ delivered in requested minute during manual testing
```

Calendar channel uses ordinary system notification sound and vibration. It intentionally does not reuse the custom Epistola seagull sound.

Permission policy:

```text
check exact-alarm permission
→ request when absent
→ if denied, preserve/save CalendarEntry but disable that reminder and inform user
```

Reconciliation boundary:

```text
native scheduled alarms survive app process restart
Calendar screen load reconciles reminders from local CalendarEntry storage
```

Do not overstate this as a global application-start reconciliation.

Boot receiver infrastructure is present, but full physical-device reboot survival has not yet been manually verified.

Current notification tap behavior:

```text
Calendar reminder has no Calendar deep-link payload
```

---

# 40. Additional shift / халтура projection

Future system work event is separate from personal entry.

Preferred source:

```text
authoritative Substitution call / confirmed-call structured data
```

Avoid parsing display text if structured fields exist.

Desired presentation:

```text
violet day-tile border
violet vertical strip in agenda
upcoming/occurred derived from startAt
historical marker remains
```

Dedupe by stable source/call ID.

Compact should not render a second conflicting frame over central selector.

---

# 41. Repeating local entries — future

Do not create hundreds of physical copies by default.

Preferred concept:

`CalendarEntryTemplate`

Potential fields:

```text
cycle position 1..8
validFrom?
validUntil?
title
time?
reminder?
priority?
```

Calendar derives matching dates through `ShiftScheduleCalculator`.

Occurrence-specific completion should be stored separately from template.

---

# 42. Calendar themes — future

Theme roles should remain separate:

```text
8 shift cycle positions
vacation marker
additional shift marker
selection/focus
grid/background
priority marker roles
```

Suggested presets:

```text
Standard
Dark
Contrast
Custom/Advanced
```

Do not encode business phase by UI position.

---

# 43. Web Calendar direction

Reuse:

```text
ShiftScheduleCalculator
Vacation Firestore data
```

Personal tasks stay local-only.

For Web, use browser-local persistence rather than Firestore for personal entries.

Web push remains unsupported unless separately designed.

---

# 44. Performance/read discipline

Examples:

```text
pagination page size = 20
central unread summary
UID caches
Future.wait for independent user loads
local-only presentation preferences
local-only personal agenda
```

Avoid:

```text
one Firestore stream per decorative widget
serial independent reads
server writes for local personal state
```

---

# 45. Deleted Auth user cleanup

Existing cleanup includes:

```text
users/{uid}
users/{uid}/devices/*
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Follow-up:

`pushInstallations/{installationId}`

whose `userId` points to deleted user.

---

# 46. Buses boundary

Known names:

```text
Управление
Медпункт
Раздевалка
Автово
```

Two buses run cyclically.

Weekday/weekend service differs.

Wait for newer authoritative schedule before implementation.

---

# 47. Verification discipline

Flutter:

```text
dart.bat format
flutter.bat analyze
targeted tests
full flutter.bat test at checkpoint
```

Rules:

```text
targeted emulator tests
relevant full group before deploy
```

Production Rules:

```text
identify exact production ruleset
verify transition compatibility
deploy only intended delta
```

Generated plugin files:

`restore once after final Flutter command`

---

# 48. Windows encoding discipline

`Set-Content -Encoding utf8` may prepend BOM:

`EF-BB-BF`

Preferred no-BOM write:

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

---

# 49. Current verification evidence

Functional checkpoint:

`27cce8e — feat(calendar): add exact local reminders`

Flutter:

```text
analyze → No issues found
full test → 1083/1083
Calendar local agenda + reminders targeted → 53/53
Vacation parser/service targeted → 18/18
```

Manual Android reminder lifecycle:

```text
exact time → passed
system sound → passed
reschedule → passed
bell off cancel → passed
completion cancel → passed
delete cancel → passed
app close/reopen survival → passed
```

Release APK:

`60.7 MB`

Vacation production Rules:

`12/12 before deploy`

Earlier relevant Rules group:

```text
Substitution / Vacation / Push targeted group → 91/91
```

Generated files excluded from functional commit.

---

# 50. Next architecture focus

Completed:

```text
real local reminder scheduling → 27cce8e
```

Next Calendar blocks:

```text
compact marker polish
Calendar UI polish
additional shift / халтура projection
```

Their order is a product decision; additional shift / халтура may be taken before cosmetic polish.

Then:

```text
Vacation → Substitution automation
history-safe Vacation archive/slot reuse
Calendar themes
Web Calendar
```

Security migration:

```text
after broad APK rollout
→ remove legacy production device writes
→ deploy exact strict migration
```

Technical debt:

```text
Web chat avatars
pushInstallations cleanup
legacy *MessageId names
```
