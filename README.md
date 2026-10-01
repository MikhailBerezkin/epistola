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
| Last pushed functional checkpoint | `b8618aa` |
| Checkpoint message | `feat(spaces): add customizable hub layout` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Production Hosting | `https://epistola-434b7.web.app` |
| Latest release APK build | `64.1 MB` |
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

`Судозаходы`, `Автобусы`, `ОТ и ТБ` are still under-development entry points unless current source says otherwise.

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

# Build / verification

Latest checkpoint `b8618aa`:

```text
flutter analyze
→ No issues found!

flutter test
→ 1241 passed

flutter build apk --release
→ SUCCESS
→ 64.1 MB

git diff --check
→ clean

HEAD
→ b8618aa

origin
→ b8618aa
```

Generated Flutter plugin files were restored after the final Flutter command and were not committed.

---

# Immediate next-chat topic

Owner decision:

```text
discuss the Судозаходы tile
```

Current tile:

```text
SpacesTileId.vesselCalls

title:
Судозаходы

subtitle:
Суда и объём работ
```

Current implementation is only an under-development entry point.

Before coding, define:

```text
source of vessel data
who can create/edit
required fields
status/lifecycle
planned vs actual work volume
history/audit
push/SpacesBar behavior
Calendar/Substitution relation
Web requirements
retention/query model
```

Do not invent a Firestore schema before agreeing the real workplace workflow.

---

# Roadmap

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

`b8618aa`

Next:

```text
Судозаходы
→ requirements discussion
→ agree MVP/data model
→ then implementation
```
