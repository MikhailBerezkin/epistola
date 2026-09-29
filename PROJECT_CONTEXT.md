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
>
> Документ должен фиксировать не только завершённые функции, но и:
>
> - последний pushed checkpoint;
> - локальный WIP после него;
> - реально выполненные проверки;
> - известные незавершённые места;
> - ближайший roadmap;
> - правила безопасного продолжения в новом чате.

---

# 1. Репозиторий / ветка / контрольная точка

Repository:

`MikhailBerezkin/epistola`

Feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Последний pushed functional checkpoint:

`7343528 — feat(calendar): add customizable calendar themes`

Parent:

`a3cbd07 — fix(substitution): return users after vacation ends`

Предыдущие важные checkpoints:

```text
83f4ad6 — feat(calendar): finalize native alarms and monthly hours
f83ee7c — wip(alarm): add full-screen alarm flow foundation
2ae2439 — feat(chat): refine chat filters and group members
ce22462 — fix(chat): restore lifecycle and image preview rules
53bf805 — feat(calendar): add shift alarm scheduling foundation
ebccbfc — docs: finalize substitution eligibility and web checkpoint
63da029 — feat(substitution): enforce shift call eligibility
```

Stable baseline before `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке и не считается merged/released.

Remote checkpoint на момент подготовки документа:

```text
origin/feat/v0.8.0-spaces-substitution-foundation
→ 7343528
```

После `7343528` есть локальные незакоммиченные изменения.
Перед docs commit обязательно использовать фактический локальный `git status`.

---

# 2. Обязательный протокол нового чата

В новом чате сначала:

```powershell
cd E:\Dev\Projects\epistola

git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Ожидаемая ветка:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Затем прочитать именно из текущей ветки:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Приоритет источников:

```text
current source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Не использовать `main` как источник текущего состояния `v0.8.0`.

---

# 3. Текущий локальный WIP после `7343528`

На момент подготовки docs локально продолжалась работа в двух направлениях:

```text
A. Calendar theme audit / visual integration
B. Native Shift Alarm visual redesign
```

Оба блока должны быть сохранены в текущем checkpoint перед переходом в новый чат, но Alarm visual redesign НЕ считать завершённым.

Вероятные реальные modified files после последних действий:

```text
lib/screens/shift_calendar_theme_screen.dart
lib/screens/shift_calendar_screen.dart
lib/screens/calendar_entry_editor_screen.dart
lib/widgets/common/time_wheel_picker_sheet.dart

android/app/src/main/kotlin/com/epistola/app/ShiftAlarmActivity.kt
android/app/src/main/res/drawable/shift_alarm_seagull_background.png
android/app/src/main/res/drawable/shift_alarm_snooze_icon.xml
android/app/src/main/res/drawable/shift_alarm_stop_icon.xml
```

Также после Flutter-команд могут появиться generated plugin files.

Перед commit фактический список определяет только:

```powershell
git.exe status --short
```

---

# 4. Последние проверки

## 4.1 Calendar Theme

После системного theme audit:

```text
flutter.bat analyze
→ No issues found!
```

Targeted preferences tests:

```text
test/services/spaces/calendar/shift_calendar_theme_preferences_test.dart
→ 6/6 passed
```

Manual phone verification:

```text
Light theme → passed
Dark theme → passed
Custom theme → passed
full Calendar → passed
compact Calendar → passed
Calendar Entry editor → passed
custom selected-day accent → passed
custom background propagation → passed
```

Release APK после theme audit:

```text
61.8 MB
```

## 4.2 Alarm UI WIP

После Kotlin/XML alarm UI изменений:

```text
flutter.bat analyze
→ No issues found!
```

Несколько release builds прошли успешно.

Последний подтверждённый build:

```text
build/app/outputs/flutter-apk/app-release.apk
→ 63.9 MB
```

Один промежуточный Kotlin compile error был исправлен:
локальный `background` конфликтовал с `View.background`.

Текущий KGP message:

```text
Future versions of Flutter will fail to build if plugins continue applying KGP.
```

Это warning, текущий build не блокирует.

## 4.3 Что НЕ нужно утверждать

После последних незакоммиченных visual changes полный:

```text
flutter.bat test
```

не запускался заново.

Поэтому старое:

```text
1161/1161 passed
```

остаётся подтверждением старого release-pass checkpoint, а не финальным тестом текущего dirty working tree.

---

# 5. Большой roadmap — актуальное положение

Текущий практический roadmap после основного Substitution/Web release-pass:

```text
1. Shift Alarm
2. Vacation return
3. Monthly hours
4. Calendar themes/customization
5. Large Text + SpaceBar layout/padding
6. Substitution Call Basket + Shift Cohort
7. Remaining polish
8. Achievements, если останется время
```

Статус:

```text
1. Shift Alarm
   functional foundation → DONE
   visual ringing-screen redesign → WIP / continue in new chat

2. Vacation return
   → DONE

3. Monthly hours
   → DONE

4. Calendar themes/customization
   base feature → DONE
   systemic theme audit → DONE and phone-tested
   RGB ±1 controls → added
   possible final polish → minor

5. Large Text + SpaceBar layout/padding
   → NEXT after alarm/theme checkpoint

6. Substitution Call Basket + Shift Cohort
   → planned

7. Remaining polish
   → planned

8. Achievements
   → optional
```

До merge/tag `v0.8.0` нужен отдельный release decision после завершения текущих WIP-блоков.

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
Personal Calendar Agenda
Shift alarms
Exact local reminders
Monthly hours
Calendar themes
```

## EpiLite — Flutter Web / PWA

Production Hosting:

`https://epistola-434b7.web.app`

Verified scope:

```text
Firebase Auth
Spaces
SpacesBar
Substitution
Calendar
Profile/logout
text chat flow from earlier Web checkpoint
desktop browser
mobile browser
PWA / Firebase Hosting
```

Current platform boundaries:

```text
Web push → not connected
native Android exact/full-screen alarm → not supported on Web
```

---

# 7. Substitution / work identity — stable foundation

Authoritative personal crew:

`users/{uid}.assignedCrew`

Valid values:

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

Implemented components:

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
manager/owner can correct participant crew
Calendar uses assignedCrew as authoritative schedule source
Substitution participant UI displays crew
missing crew remains a real business state
```

Missing crew:

```text
assignedCrew == null
→ Substitution call unavailable
```

UI:

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

Phases:

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

Do not duplicate cycle math in random Flutter UI code.

---

# 9. Substitution eligibility

Pure resolver:

`lib/services/spaces/substitution/substitution_call_eligibility_resolver.dart`

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

Eligibility:

| Own phase | Day 08–20 | Night 20–08 |
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
recovery + night → allowed as third night
offAfterRecovery2 + day → allowed as zero day
offAfterRecovery2 + night → forbidden because it enters next Day1
```

Night shift checks Vacation overlap on both calendar dates.

---

# 10. Substitution security layers

The same decision is protected by:

```text
UI pre-check
→ Firestore transaction re-check
→ Firestore Rules
```

Current new shift claim:

```text
schemaVersion = 2
```

Production Rules require:

```text
manager role
atomic participant/module/pendingCall/shiftClaim relationship
valid assignedCrew
allowed 8-day cycle phase
duplicate protection
```

Old APK attempting new v1 shiftClaim is intentionally rejected.

Vacation overlap remains transaction-enforced to avoid excessive Rules access calls.

---

# 11. Production Substitution/Web checkpoint

Repository Rules were tested and deployed on 2026-09-24.

Production manual chain passed:

```text
assignedCrew
→ eligibility
→ transaction
→ shiftClaim v2
→ production Rules
→ queue mutation
→ Calendar additional-shift marker
→ push
→ SpacesBar
```

EpiLite production also passed:

```text
Auth
Spaces
SpacesBar
Calendar
Substitution
desktop
mobile browser
Hosting deploy
```

Older notes about transition-compatible Substitution Rules are obsolete.

---

# 12. Vacation integration

Collection:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Slots:

`1..6`

Data:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Substitution effective state uses:

`SubstitutionEffectiveStatusResolver`

Current intended behavior:

```text
inside current VacationPeriod
→ appears as Vacation

period ends/deleted/no longer current
→ returns to ordinary list
```

Important fix:

`a3cbd07 — fix(substitution): return users after vacation ends`

The resolver no longer keeps legacy raw `vacation` status active after no current VacationPeriod exists.

Targeted effective-status suite at that checkpoint:

```text
30/30 passed
```

Real manual test:

```text
vacation ended/deleted
→ participant returned to Список
```

Canonical queue position remains preserved.

---

# 13. Vacation history invariant

Do not auto-recycle slots with data loss.

Preferred future direction:

```text
working current/future slots
+
recent server history ~1–2 years
+
optional local long-term archive
```

Historical Calendar coloring should remain reconstructable.

---

# 14. Calendar base architecture

Base schedule is deterministic and immutable.

Presentation layers:

```text
base 8-day shift
+
Vacation overlay
+
additional Substitution shift
+
personal local agenda
+
theme/presentation layer
```

Do not mutate the base cycle to encode exceptions.

Authoritative crew source:

```text
users/{uid}.assignedCrew
→ UserAssignedCrewReader
→ ShiftCalendarScreen
→ ShiftScheduleCalculator
```

---

# 15. Calendar interaction modes

Earlier UI had:

```text
full
medium
compact
```

Later interaction simplification reduced practical focus to full + compact behavior.
Current source code is authority if old docs mention medium details.

Important user decisions:

```text
full Calendar remains primary month view
compact view opened by day interaction / swipe flow
compact has fixed visible Add area
Today action appears when needed
return from compact/full follows current-date behavior rules
```

State separates:

```text
visibleMonth
selectedDate
compact focused/center date
```

Compact central selection uses stationary frame with moving date strip.

---

# 16. Personal Calendar Agenda

Personal:

```text
Дело
Заметка
```

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

Properties include:

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

No Firestore collection is used for private Calendar entries.

UI supports:

```text
create
edit
delete
completion
active/completed sorting
time sorting
priority
description
separate reminder time
```

---

# 17. Exact local Calendar reminders

Original checkpoint:

`27cce8e — feat(calendar): add exact local reminders`

Architecture:

```text
CalendarEntryService
→ CalendarEntryReminderService
→ NotificationService
→ flutter_local_notifications
```

Android config includes:

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
→ observed real-device delay ~1–2 min

alarmClock
→ notification arrived in requested minute
```

Lifecycle:

```text
create → schedule
edit date/time → reschedule
bell off → cancel
complete → cancel
delete → cancel
restore active → schedule when applicable
Calendar load → reconcile
```

Manual checks passed.

---

# 18. Shift Alarm scheduling foundation

Checkpoint:

`53bf805 — feat(calendar): add shift alarm scheduling foundation`

Added domain/services:

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

Added screens:

```text
ShiftAlarmEditorScreen
ShiftAlarmSettingsScreen
```

Calendar integrates alarm settings.

Shared time picker:

`lib/widgets/common/time_wheel_picker_sheet.dart`

Shift alarms are separate from one-off personal CalendarEntry reminders.

---

# 19. Native full-screen Shift Alarm

Functional native foundation finalized in:

`83f4ad6 — feat(calendar): finalize native alarms and monthly hours`

Native architecture:

```text
Dart NotificationService
→ ShiftAlarmNativeBridge
→ MethodChannel
→ MainActivity
→ ShiftAlarmNativeScheduler.schedule()
→ AlarmManager.setAlarmClock()
→ ShiftAlarmReceiver
→ full-screen notification PendingIntent
→ ShiftAlarmActivity
```

Files:

```text
android/app/src/main/kotlin/com/epistola/app/MainActivity.kt
android/app/src/main/kotlin/com/epistola/app/ShiftAlarmActivity.kt
android/app/src/main/kotlin/com/epistola/app/ShiftAlarmNativeScheduler.kt
android/app/src/main/kotlin/com/epistola/app/ShiftAlarmReceiver.kt
lib/services/spaces/calendar/shift_alarm_native_bridge.dart
```

Manual Poco verification of functional behavior passed:

```text
special full-screen alarm appears
+10 minute snooze works
Stop works
swipe up → +10 minutes
swipe down → stop
Power button stops current alarm
screen does not linger
returns to previous phone state instead of opening Epistola
```

This behavior is stable and must not regress during visual redesign.

---

# 20. Shift Alarm visual redesign — CURRENT WIP

User-approved design direction:

```text
dark navy / ocean visual
Epistola white seagull centered between actions
+10 минут button at ~25% height
Отключить button at ~75% height
same button size
blue snooze button
red stop button
white outline alarm-clock icon
responsive layout on different Android phones
```

Brand files:

```text
design/branding/Аватар Чайки.png
design/branding/Аватар Чайки трафарет.png
```

Runtime resource created:

```text
android/app/src/main/res/drawable/shift_alarm_seagull_background.png
```

Vector icons created:

```text
android/app/src/main/res/drawable/shift_alarm_snooze_icon.xml
android/app/src/main/res/drawable/shift_alarm_stop_icon.xml
```

Current problem:

```text
Аватар Чайки.png is a square composed image:
ocean + seagull + 19/4 mark.
Trying to use it as one universal portrait background produced:
- crop problems with CENTER_CROP
- side/empty bands with scaling
- isolated square panel with FIT_CENTER/gradient
- 19/4 still faintly visible
```

Latest visual result was explicitly NOT accepted.

Decision:

```text
leave current code/resources as WIP
continue in new chat
do not call alarm visual design finished
```

Preferred next technical direction:

```text
inspect/use Аватар Чайки трафарет.png as separate seagull layer if alpha allows
or prepare a clean transparent seagull asset

render:
full-screen adaptive dark/ocean background
+
independent seagull ImageView
+
independent action buttons

use normalized screen positions
avoid coupling seagull scale to square avatar canvas
```

Goal:
one composition on any phone aspect ratio without cropping the important bird.

---

# 21. Monthly hours

Added in:

`83f4ad6 — feat(calendar): finalize native alarms and monthly hours`

Calculator:

`lib/services/spaces/calendar/shift_month_hours_calculator.dart`

Tests:

`test/services/spaces/calendar/shift_month_hours_calculator_test.dart`

Rules:

```text
12h physical shift → 11.5 accounted hours
day shift → 11.5
night shift → split by month:
  4h start date/month
  7.5h next date/month
additional shifts use same 11.5 accounting
vacation contributes according to existing calendar-day rule
```

Calendar UI shows:

```text
Основные
Халтуры
Всего
```

Manual example accepted:

```text
September:
Основные 180 ч
Халтуры 57,5 ч
Всего 237,5 ч
```

Combined alarm/month targeted checks at checkpoint passed.

---

# 22. Calendar themes/customization

Checkpoint:

`7343528 — feat(calendar): add customizable calendar themes`

Files:

```text
lib/domain/models/shift_calendar_theme.dart
lib/services/spaces/calendar/shift_calendar_theme_preferences.dart
lib/screens/shift_calendar_theme_screen.dart
test/services/spaces/calendar/shift_calendar_theme_preferences_test.dart
```

Tabs:

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

Each custom can independently configure:

```text
day1
day2
offBeforeNight
night1
night2
recovery
offAfterRecovery1
offAfterRecovery2
background
Vacation
additional-shift border
selected day
monthly-hours bar
text scale
```

Text scale options:

```text
Compact
Normal
Large
```

Automatic derived colors:

```text
grid line
text contrast
```

Themes are independent of global app theme.

Custom themes save/reset independently.

Color editor supports:

```text
HEX input
RGB sliders
RGB +/- 1 precision buttons
```

Preferences tests:

```text
6/6 passed
```

---

# 23. Calendar theme systemic audit — local post-7343528

After base theme commit, a broader audit fixed Material-theme leakage.

Files changed:

```text
lib/screens/shift_calendar_screen.dart
lib/screens/calendar_entry_editor_screen.dart
lib/widgets/common/time_wheel_picker_sheet.dart
```

Result:

```text
custom background propagates into compact agenda panel
selected compact day uses custom selectedDay
lower action row follows calendar theme
Calendar Entry editor follows calendar theme
time picker follows calendar context
Light/Dark/Custom visual behavior became consistent
```

Analyzer:

```text
No issues found!
```

Phone visual test:

```text
passed
```

This local audit should be included in the next functional/docs checkpoint.

---

# 24. Chat fixes after release-pass docs

Checkpoint:

`ce22462 — fix(chat): restore lifecycle and image preview rules`

Changed:

```text
firestore.rules
test/rules/firestore/group_admin_lifecycle_rules.test.mjs
```

Purpose:
restore expected group admin lifecycle and image-preview Rules behavior.

Checkpoint:

`2ae2439 — feat(chat): refine chat filters and group members`

Changed:

```text
lib/screens/chats_page.dart
lib/widgets/group/group_members_section.dart
```

Purpose:
refine chat filtering/presentation and group member section.

Do not overwrite these later changes with older chat UI code.

Known chat backlog remains:

```text
private chat → peer message → Удалить у себя may still fail
```

---

# 25. Additional shift / халтура projection

Implemented from structured Substitution data.

Components:

```text
CalendarAdditionalShiftEvent
CalendarAdditionalShiftProjection
CalendarAdditionalShiftService
```

Presentation:

```text
violet day tile marker/frame
```

Manual production verification:

```text
successful Substitution call
→ violet Calendar frame appeared
```

Do not parse free-form SpacesBar text to reconstruct work events when structured data exists.

---

# 26. Push / SpacesBar

Messaging push foundation remains active.

Substitution successful call can produce:

```text
push
SpacesBar personal call message
Calendar additional-shift projection
```

Cloud Function region:

`europe-west1`

Deep links can open chats.

Active-chat suppression exists.

Image messages use existing custom sound/vibration semantics.

Push installation ownership:

```text
pushInstallations/{installationId}
```

One installation belongs to one current user; one user may own multiple installations.

---

# 27. EpiLite / Web architecture

Production URL:

`https://epistola-434b7.web.app`

Config:

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

Platform helpers:

```text
EpistolaRuntimeMode
EpistolaPlatformCapabilities
```

Current Web boundaries:

```text
supportsPushNotifications → false
exact Android alarms → false
Chats → supported
Spaces/Substitution/Calendar → supported
```

Personal Calendar entries remain browser-local; do not silently move them to Firestore.

---

# 28. Performance / quota discipline

Pilot target:

`40–50 users`

Keep free-tier friendly.

Established patterns:

```text
message page size 20
UID caches
central unread summary
Future.wait for independent reads
local-only presentation preferences
local-only personal agenda
bounded deterministic transaction reads
```

Avoid:

```text
unbounded queries
decorative Firestore listeners per widget
duplicating authoritative data into unnecessary collections
```

---

# 29. Generated Flutter files

After the final Flutter command before commit restore once:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Do not repeatedly restore between every Flutter command.

Do not accidentally commit generated noise.

---

# 30. Firebase Hosting cache

`.firebase/` is deploy cache.

It should remain ignored:

```text
/.firebase/
```

Do not commit cache contents.

---

# 31. Development environment

Typical environment:

```text
Windows
PowerShell
VS Code
Android Emulator
Poco F6
Flutter
Java 21 / Android Studio JBR
Node 22
Firebase CLI
```

Prefer explicit executables:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git.exe
```

User workflow:

```text
small verifiable steps
state stage + approximate time
small/medium files with several edits → full replacement
sensitive XML/YAML/Gradle/config → full file
large systematic refactor → ZIP acceptable/preferred
generated plugin files restored once at the end
no commit/push without separate agreement
```

---

# 32. Immediate next-chat roadmap

Start from current checkpoint, not from redesigning completed foundations.

Order:

```text
1. Verify branch/status/HEAD/origin.
2. Read three docs.
3. Inspect current ShiftAlarmActivity/resources.
4. Finish Shift Alarm visual composition correctly:
   - separate background and seagull layers
   - responsive scaling
   - preserve native functional behavior
5. Run build + phone test.
6. Finalize Calendar theme local audit / ± controls if still dirty.
7. Run targeted tests + analyze.
8. Restore generated plugin files.
9. Commit/push checkpoint.
10. Continue Large Text + SpaceBar layout/padding.
11. Substitution Call Basket + Shift Cohort.
12. Remaining polish.
13. Release/merge/tag v0.8.0 decision.
```

---

# 33. Broader backlog

After the immediate roadmap:

```text
private chat "Удалить у себя" bug
Attachment Composer Foundation
voice messages
file transfer
Vacation history/archive
repeating cycle-linked local entries
Web chat avatar polish
legacy *MessageId cleanup
pushInstallations cleanup for deleted Auth users
Bus schedule after authoritative timetable
Achievements
```

---

# 34. Commit/push preparation

Before commit:

```powershell
git.exe status --short
git.exe diff --check
```

After final Flutter commands restore generated plugin files once.

Recommended checkpoint structure:

```text
functional changes commit
→ docs checkpoint commit
→ push
```

If current user prefers one combined checkpoint, inspect staged diff carefully before commit.

Never claim working tree clean until checked.

---

# 35. Final new-chat handoff summary

New chat must know:

```text
Branch:
feat/v0.8.0-spaces-substitution-foundation

Last pushed checkpoint before current local work:
7343528

Completed:
- Substitution eligibility + production Rules
- EpiLite deploy
- Calendar agenda/reminders
- Shift Alarm functional native flow
- Monthly hours
- vacation return fix
- base Calendar themes
- systemic theme audit phone-tested

Current unfinished:
- visual design of native ringing Shift Alarm screen

Important:
Do not regress alarm scheduling/stop/snooze/swipe/Power behavior while fixing visual layers.

Next:
finish alarm visual composition
→ verify
→ commit/push
→ continue roadmap.
```
