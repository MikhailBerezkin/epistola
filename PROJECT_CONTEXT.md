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
> Документ фиксирует:
>
> - последний pushed checkpoint;
> - реально выполненные проверки;
> - production data checkpoints;
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

`b8618aa — feat(spaces): add customizable hub layout`

Непосредственно перед ним:

```text
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
ebccbfc — docs: finalize substitution eligibility and web checkpoint
63da029 — feat(substitution): enforce shift call eligibility
```

Stable baseline before `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке и не считается merged/released.

Последняя подтверждённая синхронизация:

```text
HEAD
→ b8618aa

origin/feat/v0.8.0-spaces-substitution-foundation
→ b8618aa

working tree
→ CLEAN
```

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

После этого прочитать именно из текущей ветки:

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

# 3. Последний завершённый блок — Spaces Hub customization

Checkpoint:

`b8618aa — feat(spaces): add customizable hub layout`

Изменены:

```text
lib/domain/models/spaces_tile_id.dart
lib/screens/home_screen.dart
lib/screens/spaces_page.dart
```

Добавлено:

```text
Настройка пространств через ⋮

Вид плиток:
- Сетка
- Крупные плитки

Показывать плитки:
- выбор видимых Spaces
- минимум одна плитка должна оставаться

Порядок плиток:
- drag-and-drop
- скрытые плитки сохраняют своё место

Persistence:
- SharedPreferences
```

Крупный режим:

```text
одна широкая горизонтальная карточка
иконка слева
название + описание справа
увеличенная зона чтения/нажатия
вертикальный scroll
```

Обычный режим:

```text
2 плитки в ряд
единая геометрия текста
зарезервированная зона subtitle
```

SharedPreferences keys:

```text
spaces_tile_layout_mode
spaces_visible_tiles
spaces_tile_order
```

Manual verification:

```text
Сетка / Крупные плитки → переключаются
выбранный layout → сохраняется после q/restart
видимые плитки → сохраняются
порядок → сохраняется
одинаковый порядок применяется к Grid и Large
скрытая плитка сохраняет своё место и возвращается туда после включения
```

Этот блок считать завершённым функционально.

Остаётся phone/workplace visual check при реальном использовании.

---

# 4. Последние проверки на checkpoint `b8618aa`

Перед commit:

```text
dart format
→ 0 changed

flutter analyze
→ No issues found!
```

Полный suite:

```text
flutter test
→ 1241 tests passed
```

Во время тестов был diagnostic output JPEG decoder:

```text
Corrupt JPEG data
JPEG datastream contains no image
```

Но suite завершился успешно:

```text
All tests passed!
```

Release build:

```text
flutter.bat build apk --release
→ SUCCESS

build/app/outputs/flutter-apk/app-release.apk
→ 64.1 MB
```

Kotlin Gradle Plugin warning остаётся future-migration warning и текущую сборку не блокирует.

Generated plugin files после последней Flutter-команды восстановлены один раз.

Final:

```text
git diff --check
→ clean

git status --short
→ empty

HEAD
→ b8618aa

origin
→ b8618aa
```

---

# 5. Большой roadmap — актуальное положение

Текущий практический roadmap:

```text
1. Shift Alarm visual redesign
2. Large Text / accessibility audit
3. Substitution Call Basket + Shift Cohort
4. Remaining product polish
5. Release debt / docs / release decision
6. Achievements, если останется время
```

Статус:

```text
Shift Alarm functional foundation
→ DONE

Shift Alarm ringing-screen visual
→ WIP / NOT accepted yet

Vacation return
→ DONE

Monthly hours
→ DONE

Calendar themes/customization
→ DONE

Calendar systemic theme audit
→ DONE

Spaces Hub customization
→ DONE at b8618aa

Large Text / accessibility
→ PARTIAL
   Spaces Hub Large layout done
   broader app + SpaceBar pass remains

Substitution Call Basket + Shift Cohort
→ planned

Achievements
→ optional
```

Новый ближайший продуктовый разговор по решению владельца:

```text
Судозаходы
→ next-chat discovery / requirements discussion
→ do not implement blindly before agreeing data model and workflow
```

Shift Alarm visual WIP не отменён и остаётся в roadmap.

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
Spaces Hub customization
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

# 7. Main product navigation / Spaces Hub

Root areas:

```text
Контакты
Пространства
Профиль
```

Home starts on:

`Пространства`

Current Spaces IDs:

```text
chats
substitution
vesselCalls
calendar
buses
safety
```

Current visible product names:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Current `Судозаходы`, `Автобусы`, `ОТ и ТБ` may still be placeholder/under-development entry points depending on current source.

Owner remains highest-priority role.

---

# 8. Substitution / work identity — stable foundation

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

# 9. Shift cycle

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

# 10. Substitution eligibility

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

# 11. Substitution security layers

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

# 12. Production Substitution/Web checkpoint

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

# 13. Production data cleanup — 2026-09-30

Перед началом октября выполнена контролируемая очистка production Firebase от старой тестовой истории.

Удалено:

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

Recursive `chats` cleanup завершился на:

```text
950 deleted docs
```

Намеренно сохранено:

```text
Firebase Auth users

Firestore:
users/*
users/*/devices/*
pushInstallations/*
spaces_access/*
spaces/substitution/participants/*
spaces/substitution.nextRotationOrder
spaces/substitution.revision
spaces/calendar/vacationPeriods/*
spaces/spacesBar

Storage:
user_avatars/*
```

Причины сохранения:

```text
participants
→ это текущая рабочая очередь, не история

vacationPeriods
→ нужны текущие/будущие и исторические Calendar overlays

pushInstallations + users/*/devices
→ активная ownership/token инфраструктура push

spaces_access
→ owner/brigadier permissions

spacesBar
→ оставлены актуальные сообщения

user_avatars
→ рабочие пользовательские аватары
```

Сразу после cleanup Substitution baseline:

```text
nextRotationOrder = 278
revision = 173
lastCall = absent
```

Затем вручную повторно вызваны 8 участников на:

```text
2026-10-01
day shift
```

После повторных вызовов:

```text
8 new shiftClaims created
confirmedCalls recreated
statistics recreated
lastCall recreated

revision:
173 → 181

nextRotationOrder:
278 → 286
```

Это подтвердило post-cleanup chain:

```text
call
→ pending/finalization
→ confirmedCall
→ shiftClaim
→ statistics
→ queue mutation
→ push
```

Operational invariant:

```text
старые test/history records, удалённые 2026-09-30,
не должны использоваться для объяснения текущего production state.

Current production call history begins from post-cleanup October calls.

participants rotation/order was intentionally preserved.
Vacation periods were intentionally preserved.
Push ownership/device registry was intentionally preserved.
```

---

# 14. Vacation integration

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

Behavior:

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

# 15. Vacation history invariant

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

# 16. Calendar base architecture

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

# 17. Calendar interaction modes

Historical UI had:

```text
full
medium
compact
```

Current practical interaction focuses on full + compact.

Current source code is authority if old notes mention medium details.

State separates:

```text
visibleMonth
selectedDate
compact focused/center date
```

Compact central selection uses stationary frame with moving date strip.

---

# 18. Personal Calendar Agenda

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

# 19. Exact local Calendar reminders

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

Observed reason:

```text
exactAllowWhileIdle
→ real-device delay ~1–2 min

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

# 20. Shift Alarm scheduling foundation

Checkpoint:

`53bf805 — feat(calendar): add shift alarm scheduling foundation`

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

Screens:

```text
ShiftAlarmEditorScreen
ShiftAlarmSettingsScreen
```

Calendar integrates alarm settings.

Shared time picker:

`lib/widgets/common/time_wheel_picker_sheet.dart`

Shift alarms are separate from one-off personal CalendarEntry reminders.

---

# 21. Native full-screen Shift Alarm

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

Manual Poco verification passed:

```text
full-screen alarm appears
+10 minute snooze works
Stop works
swipe up → +10 minutes
swipe down → stop
Power button stops current alarm
screen does not linger
returns to previous phone state instead of opening Epistola
```

This behavior is stable and must not regress.

---

# 22. Shift Alarm visual redesign — CURRENT WIP

Latest visual work includes:

```text
17a73b7 — wip(alarm): refine ringing screen visuals
```

User-approved direction remains:

```text
dark navy / ocean visual
Epistola white seagull centered between actions
+10 минут at ~25% height
Отключить at ~75% height
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

Important finding:

```text
Аватар Чайки.png
→ square composed image
→ ocean + seagull + 19/4
→ unsuitable as one universal portrait background
```

Preferred direction:

```text
full-screen adaptive background
+
independent transparent seagull layer
+
independent action buttons
```

`Аватар Чайки трафарет.png` was visually identified as the better candidate for a separate bird layer.

Current visual result is NOT accepted as finished.

Do not regress functional alarm behavior while continuing visual work.

---

# 23. Monthly hours

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
```

Calendar UI:

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

---

# 24. Calendar themes/customization

Base checkpoint:

`7343528 — feat(calendar): add customizable calendar themes`

Systemic refinement:

`daedc9f — feat(calendar): refine themed calendar surfaces`

Files include:

```text
lib/domain/models/shift_calendar_theme.dart
lib/services/spaces/calendar/shift_calendar_theme_preferences.dart
lib/screens/shift_calendar_theme_screen.dart
lib/screens/shift_calendar_screen.dart
lib/screens/calendar_entry_editor_screen.dart
lib/widgets/common/time_wheel_picker_sheet.dart
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

Configurable:

```text
8 cycle colors
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
RGB +/-1
```

Systemic audit result:

```text
compact agenda follows calendar theme
selected compact day follows selectedDay
lower action row follows theme
Calendar Entry editor follows calendar theme
time picker follows calendar context
```

Manual phone visual verification passed.

---

# 25. Chat refinements / known bug

Latest relevant checkpoints:

```text
ce22462 — Rules lifecycle/image preview fix
2ae2439 — chat filters/group-member presentation
```

Known backlog:

```text
private chat
peer message
Удалить у себя
may still fail
```

Needs re-verification on current APK before fixing.

---

# 26. Additional shift / халтура projection

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

# 27. Push / SpacesBar

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

Broader Large Text / SpaceBar padding pass remains unfinished.

---

# 28. EpiLite / Web architecture

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

Personal Calendar entries remain browser-local.

---

# 29. Performance / quota discipline

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

# 30. Generated Flutter files

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

# 31. Firebase Hosting cache

`.firebase/` is deploy cache.

It should remain ignored:

```text
/.firebase/
```

Do not commit cache contents.

---

# 32. Development environment

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

Workflow:

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

# 33. Immediate next-chat topic — Судозаходы

Owner decision:

```text
Next chat
→ discuss/design new Судозаходы tile
```

Current tile already exists in Spaces Hub as:

```text
SpacesTileId.vesselCalls
title: Судозаходы
subtitle: Суда и объём работ
```

Current entry point is still an under-development placeholder.

New chat should start with product discovery before coding.

Questions to settle:

```text
1. What is the authoritative source of vessel-call data?
2. Who creates/edits/deletes a vessel call?
3. What fields are required:
   vessel name
   ETA/arrival
   ETD/departure
   berth/location
   work type
   planned/actual volume
   status
   notes
   responsible crew/shift?
4. What lifecycle/statuses are needed?
5. Does a vessel call need history/audit?
6. Does it produce push or SpacesBar messages?
7. Does it interact with Calendar or Substitution?
8. What must be available in EpiLite Web?
9. What is the expected list/card/calendar presentation?
10. How much data/history should stay in Firestore?
```

Do not invent this workflow from the current placeholder UI.

---

# 34. Immediate roadmap after Судозаходы discussion

After requirements are agreed, choose whether to implement Vessel Calls immediately or return to the existing unfinished roadmap.

Existing unfinished priorities remain:

```text
Shift Alarm visual composition
Large Text / broader accessibility + SpaceBar padding
Substitution Call Basket + Shift Cohort
private chat "Удалить у себя" bug
remaining polish
release debt
release/merge/tag v0.8.0 decision
optional Achievements
```

---

# 35. Broader backlog

```text
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

# 36. Commit/push preparation

Before commit:

```powershell
git.exe status --short
git.exe diff --check
```

After final Flutter commands restore generated plugin files once.

Preferred:

```text
functional changes commit
→ docs checkpoint commit
→ push
```

Never claim working tree clean until checked.

---

# 37. Final new-chat handoff summary

```text
Repository:
MikhailBerezkin/epistola

Branch:
feat/v0.8.0-spaces-substitution-foundation

Last pushed functional checkpoint:
b8618aa — feat(spaces): add customizable hub layout

Expected:
HEAD = origin = b8618aa
working tree CLEAN
before applying this docs update

Latest verification:
flutter analyze → clean
flutter test → 1241 passed
release APK → 64.1 MB

Recently completed:
- Calendar theme systemic refinement
- Spaces Hub customizable Grid/Large layout
- visible tile selection
- drag-and-drop tile order
- local persistence
- production Firebase history cleanup and successful 8-call rebuild

Current unfinished:
- Shift Alarm visual composition
- broader Large Text / SpaceBar padding
- Substitution Call Basket + Shift Cohort
- private chat delete bug

Next chat topic by owner decision:
Судозаходы

Start new chat:
verify branch/status/HEAD/origin
→ read PROJECT_CONTEXT.md / ARCHITECTURE.md / README.md
→ discuss Судозаходы requirements and data model before implementation.
```
