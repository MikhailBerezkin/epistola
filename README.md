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
| Last pushed functional checkpoint | `7343528` |
| Checkpoint message | `feat(calendar): add customizable calendar themes` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Production Hosting | `https://epistola-434b7.web.app` |
| Latest local release APK build | `63.9 MB` |

`v0.8.0` remains in the feature branch and is not yet declared merged/released.

There is local post-`7343528` WIP that should be committed before the next feature block.

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

# Latest completed blocks

## Substitution + Work Schedule Identity

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
```

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
responsive layout on different Android phones
```

Current WIP resources:

```text
android/app/src/main/res/drawable/shift_alarm_seagull_background.png
android/app/src/main/res/drawable/shift_alarm_snooze_icon.xml
android/app/src/main/res/drawable/shift_alarm_stop_icon.xml
android/app/src/main/kotlin/com/epistola/app/ShiftAlarmActivity.kt
```

Important:

```text
current visual implementation is NOT accepted as finished
```

Problem:
the original `Аватар Чайки.png` is a square composed image and does not scale cleanly to all portrait screens.

Next attempt should use:

```text
adaptive full-screen background
+
separate transparent seagull layer
+
independent buttons
```

Prefer checking:

`design/branding/Аватар Чайки трафарет.png`

as a possible separate bird asset.

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

Manual September example accepted:

```text
180 ч
57,5 ч
237,5 ч
```

---

# Vacation return fix

Checkpoint:

`a3cbd07`

Fix:

```text
user is no longer kept in Vacation state
after current VacationPeriod ends/disappears
because of legacy raw vacation status
```

Manual real-user verification passed.

---

# Calendar themes

Checkpoint:

`7343528`

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

Text scale:

```text
Compact
Normal
Large
```

Color editor:

```text
HEX
RGB sliders
RGB +/-1 precision
```

Preferences tests:

```text
6/6 passed
```

A post-commit systemic theme audit also updated Calendar agenda/editor/time picker so custom Calendar themes propagate consistently.
Phone visual test passed.

---

# Chat refinements

Latest chat checkpoints:

```text
ce22462
→ Rules lifecycle/image preview fix

2ae2439
→ chat filters and group-member presentation refinement
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

Messages:

```text
Недоступно: не указано звено
Недоступно: отпуск
Недоступно: рабочая смена
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

One-off Calendar reminders use:

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

Web exact Android reminders are unsupported.

---

# Firestore production state

Current Substitution Rules production state:

```text
repository ruleset deployed
new calls require shiftClaim v2
assignedCrew + cycle eligibility validated
duplicate exact-shift calls protected
```

Older transition-compatible notes are obsolete.

---

# Build / verification

Latest local:

```text
flutter analyze
→ No issues found

Calendar theme preferences
→ 6/6 passed

release APK
→ 63.9 MB
```

Older full-suite release checkpoint:

```text
flutter test
→ 1161/1161 passed

Substitution Rules
→ 74/74 passed
```

Do not claim 1161/1161 as a fresh test after the current dirty visual WIP unless the full suite is run again.

---

# Roadmap

Immediate:

```text
1. Finish Shift Alarm visual layout correctly.
2. Re-test on phone.
3. Finalize/commit Calendar theme audit + RGB +/-1.
4. Run targeted tests + analyze.
5. Restore generated plugin files.
6. Commit/push.
7. Large Text + SpaceBar layout/padding.
8. Substitution Call Basket + Shift Cohort.
9. Remaining polish.
10. v0.8.0 release/merge/tag decision.
11. Achievements if time.
```

Backlog:

```text
private chat "Удалить у себя"
Attachment Composer
voice messages
file transfer
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
legacy *MessageId cleanup
pushInstallations cleanup
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

Expected last pushed checkpoint before current local changes:

`7343528`

Next work:
finish the Shift Alarm visual screen without regressing its already-passed native behavior.
