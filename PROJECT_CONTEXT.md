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
>
> **MD continuity rule:** эти три MD — накопительная история проекта. При обновлении нельзя переписывать их с нуля или массово удалять старые завершённые функциональные блоки. Сначала нужно проверить актуальность существующего текста, сохранить исторический контекст и добавить новые изменения. Допустимо умеренно сокращать дубли и устаревшие мелкие детали.

---

# 1. Репозиторий / ветка / контрольная точка

Repository:

`MikhailBerezkin/epistola`

Feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Последний pushed functional checkpoint:

`72aba3a — feat(vessel-calls): refine vessel photos and registry editing`

Непосредственно перед ним:

```text
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
ebccbfc — docs: finalize substitution eligibility and web checkpoint
63da029 — feat(substitution): enforce shift call eligibility
```

Stable baseline before `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке и не считается merged/released.

Последняя подтверждённая синхронизация:

```text
HEAD
→ 72aba3a

origin/feat/v0.8.0-spaces-substitution-foundation
→ 72aba3a

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

Обязательное правило обновления MD:

```text
не переписывать PROJECT_CONTEXT.md / ARCHITECTURE.md / README.md с нуля
→ сначала читать существующие документы
→ сохранять крупные завершённые исторические блоки
→ добавлять новые checkpoints / архитектуру / проверки
→ сокращать только дубли и устаревшие мелкие детали
```

Эти документы одновременно являются operational handoff и накопительной историей развития Epistola.

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

# 4. Последние проверки на checkpoint `50355ff`

Перед последним functional commit:

```text
dart format
→ актуальные Vessel Calls файлы format clean

flutter analyze
→ No issues found!
```

Полный Flutter suite:

```text
flutter.bat test
→ 1241 tests passed
→ All tests passed!
```

Во время тестов был diagnostic output JPEG decoder:

```text
Corrupt JPEG data
JPEG datastream contains no image
```

Но suite завершился успешно.

Release build:

```text
flutter.bat build apk --release
→ SUCCESS

build/app/outputs/flutter-apk/app-release.apk
→ 64.3 MB
```

Poco F6 manual verification:

```text
Судозаходы открываются
реальные ПКТ данные отображаются
повторный вход работает
полноэкранный календарь Судозаходов открывается
полосы и карточки отображаются
```

Vessel Calls Firestore Rules targeted suite:

```text
84/84 passed
```

Final Git checkpoint:

```text
git diff --cached --check
→ clean

HEAD
→ 50355ff

origin
→ 50355ff

git status --short
→ empty
```

Generated Flutter plugin files после последней Flutter-команды восстановлены и в commit не попали.

---

# 5. Большой roadmap — актуальное положение

Текущий практический roadmap:

```text
1. Finish Vessel Calls / Судозаходы
   - closed/archive history
   - ушедшие суда не должны исчезать из истории месяца
   - завершённые полосы/карточки вероятно серые
   - определить реальные berth / IMO / vessel type / workload поля

2. Последние Calendar changes + Vessel Calls → EpiLite Web

3. Shift Alarm visual redesign
4. Large Text / accessibility audit + SpaceBar padding
5. Substitution Call Basket + Shift Cohort
6. Private chat "Удалить у себя" bug
7. Remaining product polish / release debt
8. Achievements, если останется время
```

Статус:

```text
Shift Alarm functional foundation
→ DONE

Shift Alarm sound regression
→ FIXED at 8f41d80
→ Poco physical test passed

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

Vessel Calls Android/cache/server foundation
→ DONE through 50355ff

Vessel Calls completed/archive history
→ NEXT

Vessel Calls Web
→ after Android/archive finish

Large Text / accessibility
→ PARTIAL
   Spaces Hub Large layout done
   broader app + SpaceBar pass remains

Substitution Call Basket + Shift Cohort
→ planned

Achievements
→ optional
```

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
Vessel Calls / Судозаходы foundation
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
latest Calendar changes → fresh Web integration/check remains
Vessel Calls → not yet added to current Web checkpoint
```

Owner decision:

```text
finish Vessel Calls first
→ then add latest Calendar + Vessel Calls to Web together
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

Current state:

```text
Судозаходы
→ active real-data implementation
→ Android / Firestore / VPS foundation working
→ completed/archive refinement remains

Автобусы
→ under development
→ authoritative current timetable still needed

ОТ и ТБ
→ under development
```

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

Sound regression fix:

`8f41d80 — fix(alarm): restore native alarm sound channel`

Fix:

```text
native ShiftAlarmReceiver channel
→ epistola_shift_alarms_v3
→ AudioAttributes.USAGE_ALARM
→ AudioAttributes.CONTENT_TYPE_SONIFICATION
```

Physical Poco test after fix:

```text
normal system alarm sound restored
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

Latest Calendar refinements and Vessel Calls still need a fresh Web integration/verification pass.

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
Vessel Calls revision/hash caches
```

Avoid:

```text
unbounded queries
decorative Firestore listeners per widget
duplicating authoritative data into unnecessary collections
publishing unchanged Vessel Calls snapshots
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

MD workflow:

```text
read existing MD first
preserve accumulated project history
update incrementally
full-file replacement for user convenience is allowed
but full-file replacement must still be based on the existing document
```

---

# 33. Судозаходы / Vessel Calls — implemented foundation

Hub identity:

```text
SpacesTileId.vesselCalls

title:
Судозаходы

subtitle:
Суда и объём работ
```

Official data source currently used:

```text
Global Ports
First Container Terminal / ПКТ
public vessel schedule
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
plan   → Планируемые
crnt   → Текущие
closed → Закрытые
```

Known source fields include:

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
mw_direct_unloading
mw_direct_loading
mw_terminal_unloading
mw_terminal_loading
mw_total_unloading
mw_total_loading
bayplan_in
bayplan_out
inbill_number
mw_relorder_number
mw_cglist_total
mw_cglist_arvl
mw_loadlist_total
mw_loadlist_arvl
mw_loadlist_not_empty
mw_vgm_number
mw_exprequest_total
mw_exprequest_gout
mw_inbill_on_terminal
calling_docs
calling_mw_docs
```

Current effective date mapping:

```text
berthFrom
→ calling_date if present
→ otherwise plan_calling_date

berthTo
→ saling_date if present
→ otherwise plan_saling_date
```

Important temporary mappings:

```text
vesselImo = calling_id
→ NOT a real IMO yet

vesselType = container
→ temporary until authoritative source field is identified

operationKind = cargo
→ temporary

lane = 0..3
→ temporary visual lane
→ NOT a real berth number
```

User product direction for real berths:

```text
83
85
86
87
```

Do not map temporary lane indexes to those berth numbers without source evidence.

Android screen:

`lib/screens/vessel_calls_space_screen.dart`

Current presentation:

```text
compact 5-day vessel timeline
fullscreen month calendar
user shift borders
vessel cards
arrival/departure
duration
live countdown/progress
temporary 4-lane presentation
```

Manual phone verification passed.

## Firestore cache model

Current documents:

```text
spaces/vesselCalls/monthMeta/{YYYY-MM}
spaces/vesselCalls/monthSnapshots/{YYYY-MM}
spaces/vesselCalls/monthArchives/{YYYY-MM}
```

Current client policy:

```text
signed-in users may read monthMeta
signed-in users may read monthSnapshots
signed-in users may read monthArchives

client writes → false
```

Current gateway/services:

```text
VesselCallsCurrentMonthFirestoreGateway
VesselCallsMonthArchiveFirestoreGateway
VesselCallsMonthCacheService
VesselCallsLocalCache
```

Cached structures:

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

## Revision-based device cache

Old 3-day full-calendar refresh policy was removed.

Current local revision policy:

```text
revision check interval = 30 minutes
```

Screen flow:

```text
open Судозаходы
→ read local CachedVesselMonth
→ if present, show immediately

if last revision check < 30 min
→ 0 Firestore reads

if revision check due
→ read monthMeta once

same revision
→ mark revision checked
→ no snapshot read

new revision
→ read monthSnapshot
→ rebuild local month
→ persist to SharedPreferences
→ update UI
```

First install / no local month:

```text
read monthMeta
→ read monthSnapshot
→ save real snapshot locally
```

If meta/snapshot read fails:

```text
do not mark revision check complete
→ next open may retry
→ existing local month remains usable
```

Preview/demo Vessel Calls data is no longer written into real local cache.

## Cloud ingest

Cloud Function:

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
POST only
Bearer ingest token stored as Firebase secret
Admin SDK performs Firestore writes
client Firestore write rules remain closed
```

Current writes:

```text
monthMeta/{YYYY-MM}
monthSnapshots/{YYYY-MM}
```

Local Windows fallback/dev tooling:

```text
tools/vessel_calls_sync.ps1
tools/vessel_calls_publish.ps1
tools/vessel_calls_output/.gitignore
```

Raw output JSON is intentionally ignored and must not be committed.

## VPS updater

Production updater runs independently of the developer PC.

Current VPS foundation:

```text
Ubuntu 24.04
system user: epistola-vessels
working directory: /opt/epistola-vessel-calls
secrets env: /etc/epistola-vessel-calls.env
targets config: /opt/epistola-vessel-calls/targets.json
updater: /opt/epistola-vessel-calls/updater.py
```

Secrets file:

```text
root:root
mode 600
not stored in Git
```

Target model supports:

```text
19/1
19/2
19/3
19/4
20/1
20/2
20/3
20/4
```

Current enabled target:

```text
19/4 only
```

Updater behavior:

```text
fetch plan / crnt / closed
merge plan + crnt by calling_id
normalize current month
calculate stable content hash
keep per-target hash in state/
publish only when normalized content changed
independent target failures
```

`closed` is fetched/logged but not yet merged into the active operational snapshot.

The updater uses Python standard library only.

Systemd:

```text
epistola-vessel-calls.service
→ Type=oneshot

epistola-vessel-calls.timer
→ enabled
→ automatic checks approximately every 2 hours
→ starts after reboot
```

Manual autonomous service verification passed:

```text
systemd loaded env
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
target 19-4 published successfully
```

Immediate next run:

```text
same stable hash
→ Firebase publish skipped
```

This hash gate is intentional quota protection.

## Security invariant

Never store or repeat source Basic Authorization or Firebase ingest token in:

```text
Git
MD files
screenshots intended for sharing
app bundle
client Firestore documents
```

Both values appeared during setup and should be treated as secrets.

Old experimental source-auth secret/function should be reviewed later after Vessel Calls stabilizes.

## Current unfinished Vessel Calls work

Current visible issue:

```text
departed/closed ships disappear from the current operational list
because closed is not yet merged into current history/archive behavior
```

Owner direction:

```text
keep completed vessel history
show completed/closed timeline strips in grey
possibly grey completed cards/status
archive past months
```

Next source inspection should identify authoritative values for:

```text
real IMO
real berth
vessel type
container / bulk distinction
cargo / workload amount
actual processing status
```

After Android/archive behavior is finished:

```text
latest Calendar changes + Vessel Calls
→ add to EpiLite Web together
```

---

# 34. Immediate roadmap after current Vessel Calls foundation

Next implementation block:

```text
Vessel Calls closed/archive support
→ departed vessels remain reconstructable
→ completed strips/cards grey
→ archive old months
→ inspect authoritative source fields
```

Then:

```text
EpiLite Web
→ bring latest Calendar changes
→ add Vessel Calls
→ verify desktop/mobile browser
```

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
portable VPS updater copy in repository / ops docs
old experimental Vessel Calls cloud probe cleanup
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

For docs-only update after a previously verified functional checkpoint:

```text
no Flutter rebuild is required unless source code changed
Git diff/status checks are still required
```

---

# 37. Final new-chat handoff summary

```text
Repository:
MikhailBerezkin/epistola

Branch:
feat/v0.8.0-spaces-substitution-foundation

Last pushed functional checkpoint:
50355ff — feat(vessel-calls): add VPS ingest and revision-based cache refresh

Recent important commits:
0cb3882 — feat(vessel-calls): add calendar cache and archive foundation
4fc9800 — test(vessel-calls): add firestore access rules
8f41d80 — fix(alarm): restore native alarm sound channel
50355ff — feat(vessel-calls): add VPS ingest and revision-based cache refresh

Expected before docs update:
HEAD = origin = 50355ff
working tree CLEAN

Latest verification:
flutter analyze → No issues found!
flutter test → 1241 passed
release APK → 64.3 MB
Poco Vessel Calls verification → passed
Vessel Calls Rules → 84/84 passed

VPS:
automatic systemd updater active
approximately 2-hour checks
hash-based publish suppression working
developer PC no longer required

Vessel Calls:
real ПКТ source connected
Firestore read-only client cache foundation complete
Cloud Function ingest deployed
revision-based 30-minute device cache complete
closed/archive history still unfinished

Important:
temporary lane 0..3 is NOT berth 83/85/86/87
calling_id is NOT a real IMO
closed is fetched but not yet merged into current snapshot/history

Next implementation:
1. Vessel Calls closed/archive + grey completed history
2. inspect authoritative source fields for berth/IMO/type/workload
3. finish Vessel Calls Android behavior
4. then add latest Calendar + Vessel Calls to EpiLite Web

Existing unfinished:
- Shift Alarm visual composition
- broader Large Text / SpaceBar padding
- Substitution Call Basket + Shift Cohort
- private chat delete bug

MD continuity rule:
do not rewrite PROJECT_CONTEXT.md / ARCHITECTURE.md / README.md from scratch.
Preserve their accumulated project history and add new context incrementally.

Start new chat:
verify branch/status/HEAD/origin
→ read PROJECT_CONTEXT.md / ARCHITECTURE.md / README.md
→ continue from the latest docs checkpoint
→ do not reimplement the already working VPS/ingest/cache foundation.
```
---

# 38. Update 2026-10-06 — Vessel Registry / photos / current checkpoint

This section is an additive update to the accumulated history above. It does not replace earlier completed blocks.

Current pushed functional checkpoint:

```text
72aba3a — feat(vessel-calls): refine vessel photos and registry editing
```

Recent Vessel Calls sequence after the previous `50355ff` server/cache checkpoint:

```text
624f424 — docs: update vessel calls checkpoint and handoff
fe63edf — feat(vessel-calls): add vessel registry classification foundation
cdc5329 — feat(vessel-calls): add registry schema v2 and production import
fee17e7 — feat(vessel-calls): improve registry editing and live sync
5392b51 — feat(vessel-calls): add vessel photo foundation
72aba3a — feat(vessel-calls): refine vessel photos and registry editing
```

Current repository synchronization confirmed immediately after push:

```text
branch:
feat/v0.8.0-spaces-substitution-foundation

HEAD:
72aba3a

origin/feat/v0.8.0-spaces-substitution-foundation:
72aba3a

working tree:
CLEAN
```

Latest checks for the `72aba3a` block:

```text
flutter.bat analyze
→ No issues found!

flutter.bat test test/services/spaces/vessel_calls
→ 25/25 passed
→ All tests passed!

git diff --check / git diff --cached --check
→ no whitespace errors
→ only ordinary LF→CRLF warnings appeared before generated files were restored
```

Phone verification on Poco F6:

```text
Vessel Calls screen opens with real data
registry classifications are visible
manual vessel photo flow works
16:9 crop works
thumb/full photo rendering works
expanded hero card works
IMO entered for a vessel that previously had no IMO now persists after Save
```

The full historical Flutter suite `1241 passed` and the earlier release APK evidence remain valid evidence for the preceding server/cache checkpoint; they were not rerun as a full-suite release pass for `72aba3a`.

## Vessel Registry / classification

The registry now separates call identity from stable vessel metadata.

Firestore:

```text
spaces/vesselCalls/lineRegistry/{lineId}
spaces/vesselCalls/vesselRegistry/{vesselUid}
```

Access:

```text
signed-in users → read
owner / brigadier → create/update
delete → false
```

Registry v2 can represent:

```text
vesselUid
name
lineId
physicalType
defaultWorkType
allowedWorkTypes
workTypeOverride
isVerified
imo
lengthMeters
deadweightTons
teuCapacity
marineTrafficUrl
photoPath
photoThumbPath
photoFullPath
photoVersion
updatedAt
updatedBy
```

Important identity invariant:

```text
calling_id
→ stable identity of a particular PKT call in the monthly source projection

IMO
→ property/identity of the physical vessel in vesselRegistry
```

Do not replace `calling_id` with IMO in the monthly call key.

The cached monthly field historically named `vesselImo` still temporarily carries `calling_id`; this is legacy naming, not proof that the source supplied a real IMO.

Registry schema v2 separates:

```text
physicalType
→ technical type of the ship

defaultWorkType
→ normal terminal work category

allowedWorkTypes
→ categories the vessel may use

workTypeOverride
→ optional manual classification override
```

The screen resolves the latest registry entry by vessel/line data and uses registry information before legacy fallbacks.

Bug fixed in the final block:

```text
vessel without IMO
→ manager opens special/third-mode editor
→ enters IMO
→ Save
→ latest vesselRegistry entry is resolved again
→ reopened card/editor shows persisted IMO
```

The existing `vesselUid` is intentionally preserved when an already-known manual vessel later receives an IMO. This protects stable registry/photo identity instead of silently migrating Storage paths.

## Vessel photo foundation

Product decision:

```text
photos are added manually
owner / brigadier may edit
ordinary users read only
no automatic photo scraping from the web
```

Firebase Storage paths:

```text
vessel_photos/<stableVesselKey>/v<version>/thumb.jpg
vessel_photos/<stableVesselKey>/v<version>/full.jpg
```

Stable photo key:

```text
valid IMO when available for a new stable identity
otherwise vesselUid
```

For an existing registry vessel, keep its existing stable vesselUid/photo identity; do not silently move old photo trees merely because IMO was added later.

Photo metadata in vesselRegistry:

```text
photoPath          // legacy compatibility alias
photoThumbPath
photoFullPath
photoVersion
```

Current preparation:

```text
fixed crop ratio = 16:9
crop stage quality = 100; final processor controls compression

thumb:
max dimension 640
typical output ~640×360
quality ladder 86..50
hard max 192 KiB

full:
max dimension 2560
typical output ~2560×1440
quality ladder 92..56
target ~1024 KiB
hard max 2048 KiB
```

Production Storage Rules were updated/deployed for the 2 MiB full-image ceiling.

Display/cache:

```text
VesselPhotoImage
→ Firebase Storage download URL
→ CachedNetworkImage
→ persistent disk image cache

cache key:
<storagePath>#v<photoVersion>

VesselPhotoUrlCache:
→ in-memory URL cache
→ pending-request dedupe
→ selected-day thumb preload
→ max parallel preload = 10
```

Rendering:

```text
list card:
112×63 16:9 thumbnail
Где судно button under thumbnail

expanded vessel card:
full-width 16:9 hero
full image
vessel name + physical/work type over image
soft blur/fade into card body
work-type-tinted card background
custom top drag handle
duplicate lower Где судно button removed
```

Current accepted color state:

```text
container cards → dark blue tint
bulk cards → dark warm orange/brown tint
other/unknown → their existing class colors

leave current tint tuning as-is for now
```

Photo replacement service order:

```text
prepare new thumb/full
→ upload new version
→ update vesselRegistry photo metadata
→ delete previous version
```

If Firestore metadata update fails after upload:

```text
rollback newly uploaded files
```

Prepared files are cleaned in the replacement service `finally`.

Known non-blocking photo debt for a later polish pass:

```text
after replacement failure, UI should explicitly clear any preparedPhoto that points to cleaned temp files
dismiss-without-save should explicitly clean prepared temp files
classification save + photo replacement is not one fully atomic cross-service transaction
```

---

# 39. Approved Vessel Calls archive model — keep this invariant

The archive design discussed and accepted before the next implementation block is monthly and server-generated.

Core identity:

```text
one calling_id = one logical vessel call
plan / crnt / closed = lifecycle views of that same call
```

Therefore:

```text
closed must not create a duplicate call
closed must not make an already-seen call disappear
```

Firestore monthly projection remains:

```text
spaces/vesselCalls/monthMeta/{YYYY-MM}
spaces/vesselCalls/monthSnapshots/{YYYY-MM}
spaces/vesselCalls/monthArchives/{YYYY-MM}
```

Current/future operational month:

```text
monthSnapshots/{YYYY-MM}
→ contains the month's planned/current calls
→ after full-list support also retains closed/completed calls for that month
→ isArchived = false
```

Finished historical month:

```text
monthArchives/{YYYY-MM}
→ one archive document for the whole month
→ final monthly projection
→ isArchived = true
```

Archive document remains lightweight schedule/history data:

```text
year
month
revision
publishedUntil
calls[]
sourceUpdatedAt
locallyUpdatedAt
isArchived = true
```

Do not duplicate vessel photos into archive documents.

Stable vessel metadata and media remain separate:

```text
vesselRegistry
lineRegistry
Firebase Storage vessel_photos/*
```

Historical read strategy is intentionally cheap:

```text
archived month already in device cache
→ 0 Firestore reads

archived month not cached
→ 1 read monthArchives/{YYYY-MM}
→ whole old month received
→ store locally
→ later opens use local copy
```

Current `VesselCallsMonthCacheService.loadArchivedMonth()` and `VesselCallsMonthArchiveFirestoreGateway` already establish this one-document-per-month client boundary.

Do not redesign archive into per-call documents unless a proven Firestore document-size limit requires a later migration.

Late corrections after a month has been finalized were NOT given a hidden polling policy. If real production data later requires archive corrections, explicitly design/version that behavior; do not silently make archived clients poll like the active month.

---

# 40. NEXT implementation block — full PKT list on VPS/server, then monthly projection/archive

This is the immediate next implementation after `72aba3a`.

## Current limitation

ПКТ already exposes:

```text
plan
crnt
closed
```

The VPS currently fetches all three, but its effective published projection is still limited:

```text
plan + crnt merged by calling_id
→ normalize
→ current-month-only projection
→ one monthMeta/monthSnapshot published
```

`closed` is fetched/logged but is not yet part of the active published monthly history.

The Windows fallback publisher also contains the explicit temporary filter:

```text
year = 2026
month = 10
```

That confirms the current publishing path is not yet a general all-month publisher.

Consequences today:

```text
completed calls can disappear after moving to closed
past months are not actually generated as monthArchives
future months returned by ПКТ are not published as independent monthly snapshots
server-side normalized history is incomplete
```

## Target server pipeline

Do NOT replace the month architecture with one huge Firestore `fullList` document.

Target:

```text
ПКТ
  plan
  crnt
  closed
    ↓
merge by calling_id
    ↓
normalize every usable call
    ↓
split normalized calls into YYYY-MM buckets
    ↓
calculate independent content hash per target + month + projection kind
    ↓
publish only changed monthly projections
    ↓
current/future month → monthMeta + monthSnapshots
finished past month → monthArchives
```

Why keep monthly documents:

```text
existing Android cache is month-based
archive gateway is month-based
one old month can be loaded in one read
Firestore document size stays bounded
hash/revision changes stay isolated to one month
future EpiLite Web can reuse the same projection
```

## Merge rule

Build one map keyed by `calling_id`.

Apply source rows in this order:

```text
plan
→ crnt overwrites same calling_id
→ closed overwrites same calling_id
```

Effective priority:

```text
closed > crnt > plan
```

The same `calling_id` appearing in several source modes remains exactly one logical call.

Before publishing, dry-run diagnostics must verify:

```text
count(plan)
count(crnt)
count(closed)
unique calling_id count
duplicate calling_id count after merge = 0
month bucket counts
```

## Month bucketing

Preserve the existing effective start rule first:

```text
effective berthFrom:
calling_date ?? plan_calling_date
```

For the first full-list migration, assign the logical call to a month from `berthFrom`, matching the existing publisher behavior.

Cross-month call invariant:

```text
one calling_id remains one logical call
```

Do not create two logical call records just because its time range crosses a month boundary.

If UI later needs the tail of a cross-month call to draw in the next month's calendar, solve that as a month/presentation projection rule while retaining one call identity.

## Cloud Function extension

Current `ingestVesselCallsMonth` validates `isArchived` but writes only:

```text
monthMeta/{YYYY-MM}
monthSnapshots/{YYYY-MM}
```

Next server change must make the write destination explicit:

```text
isArchived == false
→ set/update monthMeta/{YYYY-MM}
→ set monthSnapshots/{YYYY-MM}

isArchived == true
→ set monthArchives/{YYYY-MM}
→ archive payload is the final monthly projection
```

Mobile/web client writes remain forbidden.

Do not weaken Firestore Rules for this; Admin SDK/ingest remains the server write boundary.

## Per-month hash/revision

Today the VPS stable content hash effectively protects one target/current-month projection.

Change state to monthly projection identity, for example conceptually:

```text
target + YYYY-MM + projection kind
```

Exact filename/key can be chosen in implementation, but these invariants matter:

```text
unchanged October archive
→ no republish because November plan changed

changed November snapshot
→ only November gets a new publish/revision

unchanged month
→ no Firebase write
```

Keep the existing quota discipline.

## Lifecycle state for grey completed presentation

Important schema decision still open:

The existing cached `source` field means:

```text
monthlySnapshot
operational
archive
```

It is NOT a `plan/crnt/closed` lifecycle field.

Do not overload it.

To render closed/completed calls grey while they remain in the current month, the next implementation should deliberately add a normalized lifecycle field together across:

```text
VPS normalized payload
Cloud Function validation
CachedVesselCall
JSON mapper/cache
screen presentation
tests
```

The exact field name (`lifecycleState`, `sourceMode`, etc.) was not previously fixed; choose it explicitly in the implementation rather than silently inventing a meaning for an existing field.

## Archive finalization rule

Approved product invariant:

```text
monthArchives = final projection of a finished past month
```

Safe initial rule:

```text
do not archive the current calendar month
archive only months already in the past
archive only after full plan/crnt/closed merge for that month
```

Because archived local months currently skip active-month revision polling, avoid silently rewriting old archives after clients may have cached them.

If late official corrections become a real requirement, stop and explicitly decide archive version/refresh behavior first.

## VPS operational procedure

Do not expose secrets.

Never print/copy into chat/Git:

```text
/etc/epistola-vessel-calls.env contents
source Authorization
VESSEL_CALLS_INGEST_TOKEN
```

Before modifying `/opt/epistola-vessel-calls/updater.py`:

```text
1. inspect systemd timer/service status
2. inspect current updater.py and targets.json
3. temporarily stop the timer
4. create a timestamped updater.py backup
5. install code in dry-run mode first
6. compare source/merge/month counts and calling_id uniqueness
7. only after dry-run passes, allow Firebase publish
8. manually run one service cycle
9. inspect safe logs
10. restore/enable the ~2-hour timer
```

The pilot does not need a faster poll interval.

## Acceptance criteria

Do not mark this block complete until all of the following are true:

```text
VPS reads plan/crnt/closed
merge priority closed > crnt > plan is tested
one calling_id appears once after merge
no hardcoded current-month-only filter remains
normalized full result is split into every represented YYYY-MM
current/future monthly snapshots still publish correctly
finished past month writes monthArchives/{YYYY-MM}
archive has isArchived=true
unchanged monthly hash skips publish
changed month updates only that monthly projection
closed call no longer disappears from its month dataset
Android active month still uses monthMeta/monthSnapshot
Android past month loads one monthArchives document and caches it
client Firestore write rules remain closed
secrets remain outside Git/app/log screenshots/docs
```

Recommended tests before deployment:

```text
pure normalization:
plan only
crnt overrides plan
closed overrides plan/crnt
duplicate calling_id collapse
missing/invalid dates
month boundary

publisher:
one month
several months
unchanged monthly hash
one changed month among unchanged months
active vs archived destination

Cloud Function:
invalid token
invalid month
isArchived=false write path
isArchived=true archive write path

Flutter:
current month unchanged
archive one-read load/cache
closed lifecycle mapper once lifecycle field is added
```

The full-list/archive block is the next priority before EpiLite Web integration.
