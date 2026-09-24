# Epistola — Project Context

> Живой operational handoff-документ проекта.
>
> При конфликте источников:
>
> текущий исходный код feature-ветки
> → `PROJECT_CONTEXT.md`
> → `ARCHITECTURE.md`
> → `README.md`
>
> Не использовать `main` как источник текущего состояния `v0.8.0`, пока feature-ветка не merged/released.

---

# 1. Актуальная контрольная точка

Repository:

`MikhailBerezkin/epistola`

Feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Current functional checkpoint:

`63da029 — feat(substitution): enforce shift call eligibility`

Parent checkpoint:

`3358bc5 — feat(substitution): integrate crew and vacation status`

Последний стабильный release до `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке и не считается merged/released.

Контрольное состояние после push:

```text
HEAD:
63da029

origin/feat/v0.8.0-spaces-substitution-foundation:
63da029

working tree:
CLEAN
```

Перед переходом в новый чат локально был добавлен `.firebase/` в `.gitignore`; это изменение ещё нужно закоммитить вместе с docs-update.

В новом чате сначала проверить:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Ожидаемая ветка:

```text
feat/v0.8.0-spaces-substitution-foundation
```

---

# 2. Финальная проверка checkpoint `63da029`

Targeted Substitution eligibility:

```text
substitution_call_eligibility_resolver_test.dart
→ 24/24 passed

substitution_call_firestore_gateway_test.dart
→ 22/22 passed

substitution_dependencies_test.dart
→ 10/10 passed
```

Firestore Rules:

```text
substitution_space_rules.test.mjs
→ 74/74 passed
```

Full Flutter suite:

```text
flutter.bat test
→ 1161/1161 passed
```

Во время suite может появляться diagnostic output:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

Если итог `All tests passed!`, это не падение suite.

Analyzer:

```text
flutter.bat analyze
→ No issues found!
```

Diff:

```text
git.exe diff --cached --check
→ clean
```

Functional commit:

```text
63da029
feat(substitution): enforce shift call eligibility

10 files changed
1106 insertions
58 deletions
```

Generated Flutter plugin files были восстановлены перед commit и не вошли в checkpoint.

---

# 3. Production state на 2026-09-24

## Firestore Rules

Current repository `firestore.rules` был реально задеплоен:

```powershell
firebase.cmd deploy --only firestore:rules
```

Result:

```text
Deploy complete!
```

То есть прежнее предупреждение про transition-compatible production ruleset больше не является актуальным для текущей контрольной точки.

Production теперь использует актуальный repository ruleset.

Ключевой новый security boundary:

```text
новый Substitution shiftClaim
→ schemaVersion = 2
```

Rules:

```text
historical shiftClaim v1 documents могут оставаться валидными
new create требует schemaVersion = 2
```

Старый APK, который пытается создать новый shiftClaim v1, после deploy Rules не сможет выполнить новый Substitution call.

## Firebase Hosting / EpiLite

Production Hosting:

`https://epistola-434b7.web.app`

Deploy:

```powershell
flutter.bat build web
firebase.cmd deploy --only hosting
```

Result:

```text
Built build\web
Deploy complete!
```

Manual verification:

```text
desktop Chrome → works
mobile phone browser → works
Auth → works
Spaces → works
SpacesBar → works
Calendar → works
Substitution → works
mobile layout → works
```

Web push и Android exact local alarms в EpiLite не входят.

## Android APK

Release APK:

```text
build/app/outputs/flutter-apk/app-release.apk
61.0 MB
```

Built from current checkpoint before production verification.

---

# 4. Stage / roadmap position

Большой текущий roadmap `v0.8.0`:

```text
1. Calendar Additional Shift projection
2. Work Schedule Identity
3. Registration/Profile crew onboarding
4. Calendar authoritative assignedCrew
5. Substitution + Vacation integration
6. Substitution eligibility
7. Rules + release pass
```

Current state:

```text
1 → completed
2 → completed
3 → completed
4 → completed
5 → completed
6 → completed
7 → production pass substantially completed
```

Production release-pass evidence already includes:

```text
Firestore Rules deploy
release APK build
Android production call verification
Calendar additional-shift projection verification
push verification
SpacesBar verification
Web build
Web Hosting deploy
desktop Web verification
mobile Web verification
```

Remaining release work is mostly documentation/checkpoint/cleanup and product decisions for the next feature block.

---

# 5. Commit sequence after exact local reminders

Relevant sequence after:

`27cce8e — feat(calendar): add exact local reminders`

Key checkpoints:

```text
7c9a934 — feat(calendar): show additional substitution shifts
02c6b13 — feat(profile): add assigned crew foundation
61e8615 — feat(profile): add crew selection onboarding
f6bfa30 — feat(calendar): use assigned crew as schedule source
3358bc5 — feat(substitution): integrate crew and vacation status
63da029 — feat(substitution): enforce shift call eligibility
```

Use code as authority if a minor checkpoint name differs from historical chat notes.

---

# 6. Products

## Epistola — Android

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
Local Calendar Agenda
Exact local reminders
```

## EpiLite — Flutter Web / PWA

Current verified scope:

```text
Firebase Auth
Spaces
SpacesBar
Substitution
Calendar
Profile/logout
Chats text flow from earlier Web checkpoint
PWA / Firebase Hosting
```

Known platform boundary:

```text
Web push → not connected
exact Android local reminders → not supported on Web
```

---

# 7. Work Schedule Identity

Authoritative personal crew:

```text
users/{uid}.assignedCrew
```

Storage value:

```text
1..4
```

Domain:

```text
ShiftCrew.crew1
ShiftCrew.crew2
ShiftCrew.crew3
ShiftCrew.crew4
```

Implemented layers:

```text
UserAssignedCrewService
UserAssignedCrewReader
AssignedCrewSelector
AssignedCrewSetupScreen
SubstitutionWorkProfileService
SubstitutionWorkProfileFirestoreGateway
```

Behavior:

```text
registration/profile onboarding can set crew
user selects own crew only under allowed rules
manager/owner can correct participant crew
manager can update workDisplayName + assignedCrew atomically
Calendar reads assignedCrew as authoritative schedule source
Substitution participant overlay displays crew
```

Missing crew is a real business state, not silently defaulted.

Current policy:

```text
assignedCrew == null
→ Substitution call unavailable
```

UI message:

```text
Недоступно: не указано звено
```

---

# 8. Shift cycle

Base model:

```text
4 crews
8-day repeating cycle
```

Cycle phases:

```text
0 day1
1 day2
2 offBeforeNight
3 night1
4 night2
5 recovery
6 offAfterRecovery1
7 offAfterRecovery2
```

Human labels:

```text
День 1
День 2
Вых
Ночь 1
Ночь 2
О / Отсыпной
Вых
Вых
```

Anchor:

```text
14.09.2026
crew4 → day2
crew3 → night1
crew1 → offAfterRecovery2
```

Single authoritative calculator:

```text
ShiftScheduleCalculator.phaseFor(date, crew)
```

Do not duplicate cycle math in Flutter business code.

Firestore Rules duplicate only the minimum deterministic phase calculation required to validate Substitution calls server-side.

---

# 9. Substitution eligibility — implemented

Pure resolver:

`lib/services/spaces/substitution/substitution_call_eligibility_resolver.dart`

Reasons:

```text
missingCrew
vacation
workShift
```

User messages:

```text
Недоступно: не указано звено
Недоступно: отпуск
Недоступно: рабочая смена
```

Eligibility by own 8-day phase:

| Phase | Day 08–20 | Night 20–08 |
|---|---:|---:|
| day1 | ❌ | ❌ |
| day2 | ❌ | ❌ |
| offBeforeNight | ✅ | ✅ |
| night1 | ❌ | ❌ |
| night2 | ❌ | ❌ |
| recovery | ❌ | ✅ |
| offAfterRecovery1 | ✅ | ✅ |
| offAfterRecovery2 | ✅ | ❌ |

Meaning:

```text
recovery + night
→ allowed as "third night"

offAfterRecovery2 + day
→ allowed as "zero day"

offAfterRecovery2 + night
→ forbidden because night runs into next Day1
```

---

# 10. Vacation overlap rule for calls

Day shift:

```text
08:00–20:00
→ checks shift calendar date
```

Night shift:

```text
20:00–08:00
→ checks start date
→ also checks next calendar date
```

Any overlapping VacationPeriod makes call unavailable.

Vacation check has priority over work-phase result in resolver.

---

# 11. Substitution call protection layers

The same business decision is protected in multiple layers.

## UI pre-check

`SubstitutionSpaceScreen`

Before showing enabled call choice:

```text
load user/assignedCrew
verify VacationPeriod listener state
resolve today-night
resolve tomorrow-day
disable each option independently
show exact reason under disabled option
```

UI convenience is not treated as the security boundary.

## Firestore transaction re-check

`SubstitutionCallFirestoreGateway`

Inside transaction:

```text
read module
read participant
read duplicate shiftClaim
read users/{uid}
read vacationPeriods {uid}__1 ... {uid}__6
resolve eligibility
only then perform writes
```

All reads are intentionally completed before writes.

Transaction throws:

```text
SubstitutionCallUnavailableException
```

Screen catches it and shows exact business reason.

This protects against stale UI/races in the current client.

## Firestore Rules

New call requires:

```text
shiftClaim.schemaVersion == 2
valid assignedCrew
allowed 8-day phase for requested shift
existing atomic call contract
manager role
valid pending call / participant / module changes
```

Old APK shiftClaim v1 create is rejected.

Rules do not duplicate six VacationPeriod reads for every batch; vacation is rechecked in the transaction layer.

---

# 12. Substitution atomic call contract

Relevant documents:

```text
spaces/substitution
spaces/substitution/participants/{userId}
spaces/substitution/pendingCalls/{callId}
spaces/substitution/shiftClaims/{claimId}
```

Claim ID:

```text
{userId}__{year}_{month}_{day}__{kind}
```

Purpose:

```text
exactly one active call per participant per exact shift
```

Call updates atomically:

```text
participant rotationOrder
module nextRotationOrder
module revision
module lastCall
pendingCall
shiftClaim
```

Undo window:

```text
≈ 3 seconds
```

Undo restores participant rotation and removes pending call / claim as required by Rules.

Finalization updates statistics and confirmed history using the established call pipeline.

---

# 13. Production manual Substitution verification — 2026-09-24

Real new APK + production Rules:

```text
participant own schedule:
today night → blocked
message → Недоступно: рабочая смена

tomorrow day → allowed
```

Successful allowed call:

```text
call passed production Rules
participant moved to queue end
Calendar marked 25th with violet additional-shift frame
push notification received
SpacesBar message received
```

This verifies the chain:

```text
assignedCrew
→ UI eligibility
→ transaction eligibility
→ shiftClaim v2
→ production Firestore Rules
→ queue mutation
→ Calendar projection
→ push
→ SpacesBar
```

---

# 14. Vacation → Substitution integration

Vacation collection:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Slots:

`1..6`

VacationPeriod data:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Substitution uses realtime VacationPeriod data.

Effective participant status:

```text
current date inside VacationPeriod
→ participant appears in Vacation tab/state

period deleted or no longer current
→ participant returns to ordinary list
```

Implemented resolver:

```text
SubstitutionEffectiveStatusResolver
```

Manager Vacation UI can be opened directly from participant context.

Vacation row:

```text
shows current vacation dates
hides call statistics
```

Sick row:

```text
hides call statistics
```

Participant overlay can still show relevant detail.

Production manual check:

```text
delete current VacationPeriod
→ participant returned to List
→ original queue position preserved
```

---

# 15. Vacation history invariant

Do not auto-recycle slots with data loss.

Preferred long-term direction:

```text
working current/future slots
+
recent server history ≈ 1–2 years
+
optional local long-term archive
```

Historical Calendar coloring should remain reconstructable.

Visible History screen is not required now.

---

# 16. Calendar base schedule

Space:

`Календарь смен`

Base schedule is deterministic and immutable.

Exceptions are overlays:

```text
vacation
sick
substitution/additional shift
personal local agenda markers
```

Do not rewrite the 8-day schedule to represent exceptions.

---

# 17. Calendar UI

Current modes:

```text
full
medium
compact
```

Preference is stored locally.

Calendar state separates:

```text
visible month
selected date
compact focused/center date
```

Full/medium:

```text
month swipe changes visibleMonth
explicit selected day is not blindly copied into next month
```

Compact:

```text
stationary center selector
dates move underneath it
selection commits after settle
```

Today action exists; icon may be polished later.

---

# 18. Calendar assignedCrew behavior

Calendar no longer uses a hardcoded crew as authoritative user schedule.

Source:

```text
users/{uid}.assignedCrew
→ UserAssignedCrewReader
→ ShiftCalendarScreen
→ ShiftScheduleCalculator
```

Missing crew:

```text
Calendar shows setup state
direct action → Выбрать звено
```

Spaces home also shows direct crew setup banner:

```text
Вам необходимо выбрать звено!
```

Crew settings can still preview another crew without changing authoritative assignment until explicit profile/setup action.

---

# 19. Additional shift / халтура projection — implemented

This is no longer only roadmap.

Domain:

```text
CalendarAdditionalShiftEvent
```

Projection/services:

```text
CalendarAdditionalShiftProjection
CalendarAdditionalShiftService
```

Source:

```text
structured Substitution call data
```

Calendar watches additional-shift events for current user.

Presentation:

```text
violet marker/frame on day tile
work event appears independently from base shift
history remains visible from structured call source
```

Vacation date can suppress conflicting additional-shift agenda presentation where appropriate.

Manual production verification on 2026-09-24:

```text
successful Substitution call for 25th
→ violet frame appeared on 25th in Calendar
```

Do not parse SpacesBar/free-form text to reconstruct work events if structured call data exists.

---

# 20. Personal Calendar Agenda

Personal:

```text
Дело
Заметка
```

Data is intentionally local-only.

Storage:

`SharedPreferences`

Namespaced by authenticated `uid`.

Foundation:

```text
CalendarEntry
CalendarEntryMapper
CalendarEntryLocalStore
CalendarEntryService
CalendarEntryDayMarkers
```

Properties:

```text
date
title
description
scheduledMinutes?
reminderMinutes?
priority
colorValue?
isCompleted
completedAt?
createdAt
updatedAt
```

No Firestore collection is used for personal Calendar entries.

---

# 21. Local Agenda UI

Selected date:

```text
agenda panel
fixed Add bar
[ Дело ]   Добавить   [ Заметка ]
```

Supports:

```text
create
edit
delete
task completion
active/completed sorting
time sorting
scrollable list
```

Time input uses looping Cupertino wheels:

```text
hours 00..23
minutes 00..59
```

Priority:

```text
none
low
medium
high
```

---

# 22. Calendar day markers

Active local entries can project:

```text
note icon
bell icon
highest-priority dot
```

Completed tasks are ignored.

Priority visual semantics:

```text
low → green
medium → amber
high → red
```

Additional-shift violet marker is a separate work-schedule layer.

Compact marker polish remains possible future UI work.

---

# 23. Exact local Calendar reminders — Android

Checkpoint origin:

`27cce8e — feat(calendar): add exact local reminders`

Architecture:

```text
CalendarEntryService
→ CalendarEntryReminderService
→ NotificationService
→ flutter_local_notifications
```

Dependencies:

```text
timezone
flutter_timezone
flutter_local_notifications
```

Android config:

```text
RECEIVE_BOOT_COMPLETED
SCHEDULE_EXACT_ALARM
ScheduledNotificationReceiver
ScheduledNotificationBootReceiver
```

Scheduling mode:

```text
AndroidScheduleMode.alarmClock
```

Reason:

```text
exactAllowWhileIdle
→ observed real-device delay around 1–2 minutes

alarmClock
→ notification arrived in requested minute
```

Reminder lifecycle:

```text
create → schedule
edit date/time → reschedule
bell off → cancel
complete task → cancel
delete → cancel
restore active → schedule when applicable
Calendar load → reconcile
```

Manual Android checks passed:

```text
exact requested time
system sound
reschedule
cancel
completed task
deleted task
transfer to new time → one notification only
app close/reopen
```

Physical full-device reboot survival is supported by receiver configuration but should not be called manually verified unless separately tested.

---

# 24. Web / EpiLite

Flutter Web is not a future-only direction anymore; it is deployed.

Production URL:

`https://epistola-434b7.web.app`

Web config exists in:

```text
lib/firebase_options.dart
web/index.html
web/manifest.json
firebase.json
```

Hosting:

```text
public = build/web
rewrite ** → /index.html
```

Runtime/platform helpers:

```text
EpistolaRuntimeMode
EpistolaPlatformCapabilities
```

Current capabilities:

```text
supportsPushNotifications → false on Web
supportsChats → true
supportsContacts → false on Web
supportsSpacesBarManagement → true
supportsSubstitutionManagement → true
supportsSubstitutionAvailabilityChanges → true
```

Verified current Web:

```text
Auth
Spaces
SpacesBar
Calendar
Substitution
mobile browser layout
desktop Chrome
```

Earlier Web checkpoint also verified text chat flow.

Exact local Android alarms are not part of Web.

Personal browser Calendar entries remain browser-local through platform-local SharedPreferences implementation; do not move them to Firestore merely to synchronize Web.

---

# 25. Push / notifications

Messaging push foundation remains active.

Substitution successful call pipeline can produce:

```text
push notification
SpacesBar personal call message
Calendar additional-shift projection
```

Custom seagull sound remains associated with messaging/Spaces notifications where configured.

Calendar local reminders intentionally use ordinary system notification sound.

---

# 26. Push installation ownership

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

Region:

`europe-west1`

Repository strict device ownership rules are now part of the deployed repository ruleset after the 2026-09-24 full Rules deploy.

Old APK compatibility assumptions from earlier transition docs must not be reused as current production truth.

---

# 27. Performance / quota discipline

Pilot target:

`40–50 users`

Keep free-tier friendly.

Established patterns:

```text
message page size 20
UID caches
centralized unread summary
Future.wait for independent reads
local-only presentation preferences
local-only personal agenda
deterministic targeted reads
```

Substitution call eligibility transaction adds:

```text
1 user read
up to 6 deterministic VacationPeriod document reads
```

Only on actual call transaction, not as decorative/background streams.

Avoid:

```text
one Firestore listener per decorative widget
unbounded queries
duplicating existing authoritative data into new collections without need
```

---

# 28. Known backlog / technical debt

Important known items:

```text
private chat "Удалить у себя" on peer message may still need fix
Attachment Composer Foundation
voice messages
small file transfer
avatar/card UI polish
legacy *MessageId naming cleanup
Web chat avatar rendering gap
pushInstallations cleanup for deleted users
compact Calendar marker polish
Today icon polish
Calendar themes
Vacation history/archive strategy
repeating local entries tied to cycle positions
bus schedule implementation after authoritative timetable
```

Do not reopen completed eligibility architecture unless a real bug is observed.

---

# 29. Buses boundary

Known stop names:

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

# 30. Development environment

Typical environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Emulator
Poco F6
Android Studio JBR
Java 21
Node 22
Firebase CLI
```

Use explicit executables:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git.exe
```

Fresh PowerShell Java setup if needed:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
java -version
```

---

# 31. Generated files discipline

Flutter commands can modify generated plugin registrants.

Restore once after final Flutter command before commit:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Do not repeatedly restore between every Flutter command.

---

# 32. Firebase Hosting cache

Firebase Hosting deploy creates:

`.firebase/`

This is local cache and should not be committed.

`.gitignore` target:

```text
# Firebase Hosting cache
/.firebase/
```

The local `.gitignore` change was prepared immediately before this docs update.

---

# 33. Verification discipline

Flutter:

```powershell
dart.bat format <files>
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat build web
```

Rules:

```powershell
firebase.cmd emulators:exec --only firestore "node --test test/rules/firestore/substitution_space_rules.test.mjs"
```

Hosting:

```powershell
firebase.cmd deploy --only hosting
```

Rules:

```powershell
firebase.cmd deploy --only firestore:rules
```

Before commit:

```powershell
git.exe diff --check
git.exe status --short
```

---

# 34. Current verification evidence

Checkpoint:

`63da029`

Flutter:

```text
full test → 1161/1161
analyze → No issues found
```

Substitution targeted:

```text
eligibility resolver → 24/24
Firestore gateway → 22/22
dependencies → 10/10
```

Rules:

```text
Substitution Rules → 74/74
```

Android:

```text
release APK → 61.0 MB
production eligibility block → passed
production allowed call → passed
queue movement → passed
Calendar violet additional-shift marker → passed
push → passed
SpacesBar → passed
```

Web:

```text
flutter build web → passed
desktop Chrome → passed
Firebase Hosting deploy → passed
mobile phone browser → passed
```

---

# 35. Next-chat starting point

Do not start by redesigning completed v0.8.0 foundations.

First inspect:

```text
current branch
clean/dirty status
HEAD/origin
three docs
```

Then choose next work block.

Good next options:

```text
A. finish v0.8.0 release/docs/merge preparation
B. Calendar UI polish / compact markers
C. Private chat delete bug
D. Attachment Composer Foundation
E. Web-specific polish, especially chat avatars
F. Buses after authoritative timetable is available
```

If continuing release work, first resolve the local docs + `.gitignore` commit, then decide whether to merge/tag `v0.8.0`.
