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
| Last pushed functional checkpoint | `50355ff` |
| Checkpoint message | `feat(vessel-calls): add VPS ingest and revision-based cache refresh` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Production Hosting | `https://epistola-434b7.web.app` |
| Latest release APK build | `64.3 MB` |
| Latest full Flutter test | `1241 passed` |
| Latest analyzer | `No issues found!` |

`v0.8.0` remains in the feature branch and is not yet declared merged/released.

---

# Source priority

When docs disagree:

```text
current code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Do not use `main` as source of current `v0.8.0` state before merge.

**MD continuity rule:** `PROJECT_CONTEXT.md`, `ARCHITECTURE.md` and `README.md` are cumulative project history. Update them from the existing files; do not rewrite them from scratch or drop large completed historical blocks. Full-file replacement is only a delivery method after the existing content has been preserved and updated.

---

# Latest commit sequence

```text
53bf805 — feat(calendar): add shift alarm scheduling foundation
ce22462 — fix(chat): restore lifecycle and image preview rules
2ae2439 — feat(chat): refine chat filters and group members
f83ee7c — wip(alarm): add full-screen alarm flow foundation
83f4ad6 — feat(calendar): finalize native alarms and monthly hours
a3cbd07 — fix(substitution): return users after vacation ends
7343528 — feat(calendar): add customizable calendar themes
daedc9f — feat(calendar): refine themed calendar surfaces
17a73b7 — wip(alarm): refine ringing screen visuals
617bd36 — docs: update calendar alarm and roadmap handoff
b8618aa — feat(spaces): add customizable hub layout
1efbcc7 — docs: update spaces checkpoint and vessel calls handoff
0cb3882 — feat(vessel-calls): add calendar cache and archive foundation
4fc9800 — test(vessel-calls): add firestore access rules
8f41d80 — fix(alarm): restore native alarm sound channel
50355ff — feat(vessel-calls): add VPS ingest and revision-based cache refresh
```

---

# Latest completed blocks

## Substitution + work identity

Implemented:

```text
assignedCrew
crew onboarding
Calendar authoritative crew
Vacation integration
shift eligibility
transaction re-check
shiftClaim v2
Firestore Rules protection
production call verification
```

Production Rules were deployed on 2026-09-24.

## EpiLite

Production Web/PWA:

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

Latest Calendar refinements and Vessel Calls still need a new Web integration pass.

## Calendar / Agenda

Implemented:

```text
base shift Calendar
Vacation
additional Substitution shift marker
personal local tasks/notes
local reminders
shift alarms
monthly hours
Calendar themes
systemic Calendar theme integration
```

## Spaces Hub customization

Checkpoint:

`b8618aa`

Implemented:

```text
⋮ Настройка пространств

Вид:
- Сетка
- Крупные плитки

Показывать плитки:
- выбор видимых Spaces

Порядок плиток:
- drag-and-drop

Persistence:
- layout
- visibility
- order
→ SharedPreferences
```

Large layout:

```text
one wide tile per row
icon left
title/subtitle right
```

Manual restart verification passed.

## Vessel Calls / Судозаходы

Implemented through `50355ff`:

```text
real ПКТ source integration
5-day + full-month Android presentation
Firestore monthMeta/monthSnapshots/monthArchives foundation
signed-in read-only client Rules
Cloud Function ingestVesselCallsMonth
VPS automatic publisher
hash-based publish suppression
30-minute revision-based device cache
real snapshot persistence on device
```

VPS:

```text
systemd timer
approximately 2-hour source checks
publish only when normalized content changes
19/4 currently enabled
target structure supports 19/1..19/4 and 20/1..20/4
```

Current unfinished:

```text
closed vessels are fetched but not yet kept in visible history
archive/completed grey presentation
real IMO/berth/type/workload field discovery
Web integration
```

---

# Spaces Hub

Current tile IDs:

```text
chats
substitution
vesselCalls
calendar
buses
safety
```

Current titles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Current state:

```text
Судозаходы
→ active real-data implementation
→ Android/VPS/Firestore foundation working
→ completed/archive history remains

Автобусы
→ under development
→ authoritative current timetable still needed

ОТ и ТБ
→ under development
```

---

# Native Shift Alarm

Functional native alarm is implemented.

Architecture:

```text
NotificationService
→ ShiftAlarmNativeBridge
→ MainActivity MethodChannel
→ ShiftAlarmNativeScheduler
→ AlarmManager.setAlarmClock()
→ ShiftAlarmReceiver
→ ShiftAlarmActivity
```

Manual Poco tests passed:

```text
full-screen ring
+10 minute snooze
stop
swipe up/down
Power button stop
returns to previous phone state
```

Sound regression fix:

```text
8f41d80
→ native alarm channel epistola_shift_alarms_v3
→ USAGE_ALARM + CONTENT_TYPE_SONIFICATION
→ normal system alarm sound restored on Poco
```

These functional behaviors are stable.

---

# Shift Alarm visual redesign — current WIP

Desired screen:

```text
dark navy/ocean background
white Epistola seagull between controls
+10 минут at ~25% height
Отключить at ~75% height
same button size
blue snooze button
red stop button
white outline alarm-clock icon
responsive layout
```

Important:

```text
current visual implementation is NOT accepted as finished
```

The square `Аватар Чайки.png` does not scale cleanly to portrait screens.

Preferred direction:

```text
adaptive full-screen background
+
separate transparent seagull layer
+
independent buttons
```

Candidate bird asset:

`design/branding/Аватар Чайки трафарет.png`

---

# Monthly hours

Calculator:

`ShiftMonthHoursCalculator`

Accounting:

```text
12h physical shift → 11.5 accounted
day → 11.5
night → 4h on start date/month + 7.5h next date/month
additional shifts follow same accounting
```

UI:

```text
Основные
Халтуры
Всего
```

---

# Vacation return fix

Checkpoint:

`a3cbd07`

Behavior:

```text
current VacationPeriod ended/disappeared
→ user returns from Vacation to ordinary Substitution list
```

Manual real-user verification passed.

---

# Calendar themes

Base:

`7343528`

Systemic refinement:

`daedc9f`

Theme tabs:

```text
Светлая
Тёмная
Своя
```

Custom slots:

```text
Своя 1
Своя 2
```

Configurable:

```text
8 cycle tile colors
background
Vacation
additional-shift border
selected day
monthly-hours bar
text scale
```

Color editor:

```text
HEX
RGB sliders
RGB +/-1
```

Calendar agenda/editor/time picker follow the selected Calendar theme.

Phone visual test passed.

---

# Chat refinements

Relevant checkpoints:

```text
ce22462
→ Rules lifecycle/image preview fix

2ae2439
→ chat filters/group-member presentation
```

Known backlog:

```text
private chat
peer message
Удалить у себя
may still fail
```

---

# Substitution eligibility

Unavailable reasons:

```text
missingCrew
vacation
workShift
```

Allowed additional shifts:

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

Protection:

```text
UI
→ transaction
→ Firestore Rules
```

New shiftClaim:

```text
schemaVersion = 2
```

---

# Production Firebase cleanup — 2026-09-30

Before October, old test/history data was intentionally cleared.

Deleted:

```text
chats/* recursively
spaces/substitution/statistics/*
spaces/substitution/confirmedCalls/*
spaces/substitution/shiftClaims/*
spaces/substitution.lastCall
Storage chat_media/*
Storage group_avatars/*
```

Preserved:

```text
Auth users
users/*
users/*/devices/*
pushInstallations/*
spaces_access/*
spaces/substitution/participants/*
vacationPeriods/*
spaces/spacesBar
user_avatars/*
```

Substitution baseline after cleanup:

```text
revision = 173
nextRotationOrder = 278
```

Then 8 participants were called for `2026-10-01 day`.

After rebuild:

```text
revision = 181
nextRotationOrder = 286
shiftClaims recreated
confirmedCalls recreated
statistics recreated
lastCall recreated
```

This is the current October production-history baseline.

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

Supports:

```text
create
edit
delete
completion
priority
description
scheduled time
separate reminder time
local markers
```

---

# Exact local reminders

One-off Calendar reminders:

```text
CalendarEntryReminderService
→ NotificationService
→ flutter_local_notifications
```

Android:

```text
SCHEDULE_EXACT_ALARM
RECEIVE_BOOT_COMPLETED
AndroidScheduleMode.alarmClock
```

---

# Vessel Calls data flow

Current production flow:

```text
ПКТ public backend
→ VPS updater
→ normalize current month
→ stable content hash
→ ingestVesselCallsMonth
→ Firestore monthMeta/monthSnapshots
→ Android local revision cache
→ Судозаходы UI
```

Firestore:

```text
spaces/vesselCalls/monthMeta/{YYYY-MM}
spaces/vesselCalls/monthSnapshots/{YYYY-MM}
spaces/vesselCalls/monthArchives/{YYYY-MM}
```

Client:

```text
signed-in read
no client writes
```

Current temporary mappings:

```text
calling_id is stored where vesselImo is expected
→ not a real IMO yet

lane 0..3
→ visual lane only
→ not berth 83/85/86/87
```

`closed` is already fetched by the VPS but is not yet merged into visible history.

---

# Build / verification

Latest functional checkpoint `50355ff`:

```text
flutter analyze
→ No issues found!

flutter test
→ 1241 passed

flutter build apk --release
→ SUCCESS
→ 64.3 MB

Poco F6 Vessel Calls check
→ passed

Vessel Calls Firestore Rules
→ 84/84 passed

git diff --check
→ clean

HEAD
→ 50355ff

origin
→ 50355ff

working tree
→ CLEAN
```

Generated Flutter plugin files were restored after the final Flutter command and were not committed.

---

# Immediate next-chat topic

Current functional foundation:

```text
Судозаходы
→ real ПКТ source connected
→ VPS updater active
→ Firebase ingest active
→ Firestore read-only client cache
→ revision-based device cache
→ Android phone check passed
```

Next block:

```text
1. preserve/include closed vessel history
2. show completed vessel timeline/cards in grey
3. archive past months
4. inspect source fields for real berth / IMO / vessel type / workload
5. finish Android Vessel Calls behavior
6. then add latest Calendar + Vessel Calls to EpiLite Web together
```

Important:

```text
lane 0..3 ≠ real berth
calling_id ≠ real IMO
closed is fetched but not yet merged into visible history
```

---

# Roadmap

Immediate:

```text
Vessel Calls closed/archive/completed presentation
latest Calendar + Vessel Calls Web integration
```

Existing unfinished work remains:

```text
Shift Alarm visual composition
Large Text / broader accessibility + SpaceBar padding
Substitution Call Basket + Shift Cohort
private chat "Удалить у себя" bug
remaining product polish
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
Bus schedule after authoritative timetable
portable VPS updater copy / ops docs
old experimental Vessel Calls probe cleanup
```

---

# Generated files workflow

After the final Flutter command before commit restore once:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Do not commit incidental generated changes.

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

Expected functional checkpoint before docs update:

`50355ff`

MD continuity:

```text
preserve the existing three documents as cumulative project history
do not rewrite them from scratch
```

Next:

```text
finish Судозаходы closed/archive history
→ inspect real source fields
→ then Web: latest Calendar + Vessel Calls
```
