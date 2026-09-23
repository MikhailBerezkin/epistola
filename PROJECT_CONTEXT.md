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

Latest functional checkpoint:

`27cce8e — feat(calendar): add exact local reminders`

HEAD перед docs-коммитом:

`27cce8e`

Последний стабильный release до `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке.

После docs-коммита `HEAD` будет новее `27cce8e`, но latest functional checkpoint останется `27cce8e`.

В новом чате сначала проверить:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

---

# 2. Финальная проверка checkpoint `27cce8e`

Targeted CalendarEntry + local reminders:

```text
calendar_entry_test.dart → 7/7
calendar_entry_mapper_test.dart → 6/6
calendar_entry_local_store_test.dart → 7/7
calendar_entry_service_test.dart → 17/17
calendar_entry_day_markers_test.dart → 6/6
calendar_entry_reminder_service_test.dart → 10/10
```

Итого targeted Calendar local agenda + reminders:

`53/53 passed`

Targeted Vacation additions:

```text
vacation_date_parser_test.dart → 13/13
vacation_period_service_test.dart → 5/5
```

Итого targeted new Vacation layer:

`18/18 passed`

Full Flutter suite:

```text
flutter.bat test
→ 1083/1083 passed
```

Во время full suite может появляться diagnostic output:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

Если итог `All tests passed!`, это не падение suite.

Analyzer:

```text
flutter.bat analyze
→ No issues found
```

Diff перед functional commit:

```text
git.exe diff --cached --check
→ clean
```

Generated Flutter plugin files были восстановлены перед commit и в `27cce8e` не попали.

После functional commit:

```text
git status --short
→ CLEAN
```

---

# 3. Production Firestore Rules — актуальное состояние

Production всё ещё использует transition-compatible ruleset:

```text
Substitution shiftClaims contract
+
legacy-compatible users/{uid}/devices writes
+
VacationPeriod Rules
```

Legacy compatibility для старых APK разрешает authenticated user только собственный device document и только exact fields:

```text
token
platform
updatedAt
```

Delete разрешён только для собственного user path.

Важно:

```text
Vacation Rules УЖЕ DEPLOYED в production.
```

Они были безопасно добавлены поверх фактического production transition ruleset, а не через слепой deploy repository `firestore.rules`.

Проверка временной production-копии Vacation Rules:

`12/12 passed`

Deploy:

```text
firebase.cmd deploy --only firestore:rules --config firebase.production.json --project epistola-434b7
→ Deploy complete!
```

Временные файлы после deploy удалены:

```text
firebase.production.json
firestore.production.rules
test/rules/firestore/vacation_period_rules.production.test.mjs
```

---

# 4. Почему нельзя слепо деплоить repository firestore.rules

Repository `firestore.rules` содержит:

```text
shiftClaims
Vacation Foundation
self-return sick → active
strict push device ownership
```

Production transition ruleset пока намеренно отличается:

```text
shiftClaims → есть
Vacation Rules → есть
legacy device writes → временно разрешены
self-return sick → active → ещё не переносился отдельным production migration
strict device write lock → ещё не включён из-за старых APK
```

Поэтому:

```text
DO NOT blindly deploy repository firestore.rules
```

После следующего broad APK rollout:

```text
1. проверить adoption
2. прогнать Rules
3. подготовить exact production migration
4. убрать legacy device compatibility
5. включить strict device ownership
```

---

# 5. Production Substitution hotfix — 2026-09-18

Причина hotfix:

```text
новый client call transaction требовал shiftClaims
production Rules были старее contract
→ вызов отклонялся Rules
```

Atomic call transaction:

```text
spaces/substitution/pendingCalls/{callId}
spaces/substitution/shiftClaims/{claimId}
spaces/substitution/participants/{userId}
spaces/substitution
```

`shiftClaims` защищает от повторного вызова одной и той же рабочей смены.

Production manual verification:

```text
Owner вызвал bot participant
Undo window ≈ 3 sec
participant переместился вниз rotation list
statistics shifts → +1
SpacesBar notification → получено
push notification → получено
старый APK без Spaces → push получено
```

---

# 6. Push installation ownership

Invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installations allowed
```

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

New APK:

```text
auth state → claim
token refresh → claim
logout/unregister → release
```

Repository target Rules уже strict, production пока временно legacy-compatible.

---

# 7. Web / EpiLite checkpoint

Web chats/performance checkpoint:

`764d3de — feat(web): enable chats and speed up user loading`

Platform capability:

```text
supportsChats
→ Web true
```

Manual verification:

```text
fresh Web open
→ Chats доступны
→ names load примерно <1 second
→ text message send works
```

Performance:

```text
ChatMembersService
SubstitutionUserCache
→ independent user reads через Future.wait
```

Known Web gap:

`chat avatars всё ещё могут отображаться некорректно`

Web push:

`unsupported`

Hosting:

`https://epistola-434b7.web.app`

---

# 8. Calendar base schedule

Space:

`Календарь смен`

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

Базовый shift schedule immutable/deterministic.

Exceptions должны быть overlays, а не переписыванием 8-day cycle:

```text
vacation
sick
substitution
additional shift / халтура
```

---

# 9. Calendar UI — current state through `27cce8e`

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
default = medium
```

Crew + mode загружаются до основного render, чтобы убрать flash неправильного состояния.

Разделены состояния:

```text
visibleMonth
selectedDate
compact focused/center date
```

Full/medium month swipe:

```text
меняет visible month
не переносит selected day автоматически в новый месяц
explicit selection очищается до нового выбора
```

Compact:

```text
stationary center frame
dates scroll under the frame
selection commits only after scroll settles
settle delay = 250 ms
tap side date → animate to center → commit after settle
```

Shift phase всегда считается через:

```text
ShiftScheduleCalculator.phaseFor(date, crew)
```

и не зависит от visual position.

Header:

```text
Сентябрь 2026
selected shift title: День 1 / День 2 / Ночь 1 / Ночь 2 / Отсыпной / Выходной
Today action → replay-style icon
⋮ menu
```

`ShiftCyclePhase.displayTitle` добавлен для человекочитаемого статуса.

---

# 10. Vacation UI / persistence

Authoritative collection:

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

Technical capacity:

`slots 1..6`

Slots — persistence capacity, не visual slots.

Реализованы:

```text
VacationPeriodService
Vacation date parser
VacationPeriod editor
Vacation periods list
create
update
delete
Firestore persistence
realtime watch in Calendar
pink date markers
```

Parser поддерживает:

```text
18.09.2026
18.09
18/09/2026
18/09
18 сентября
18 сентября 2026
```

No year:

`используется открытый Calendar year`

Cross-year:

```text
Calendar year = 2026
20.12 → 10.01
→ 20.12.2026 .. 10.01.2027
```

Manual persistence verification:

```text
создан VacationPeriod
→ pink markers start..end inclusive
→ exit/re-enter Calendar сохраняет
→ full app stop/restart сохраняет
```

Delete означает correction/cancellation и убирает coloring.

---

# 11. Vacation history / slot reuse

Working current/future slots:

`1..6`

Не внедрять автоматический recycle с потерей истории.

Желаемая стратегия:

```text
working current/future slots in Firebase
+
recent completed server-side history ≈ 1–2 years
+
local long-term archive if needed
```

Visible History screen сейчас не требуется.

Past Calendar months должны сохранять historical vacation projection.

---

# 12. Vacation → Substitution automation — planned

Не реализовано.

Desired behavior:

```text
VacationPeriod startDate
→ если applicable, participant status = vacation

если participant уже vacation
→ no-op

day after endDate
→ если status всё ещё vacation
→ active
```

Manual `vacation` без дат фактически остаётся indefinite.

Если есть релевантный VacationPeriod, его конец может вернуть `vacation → active`.

Known pilot limitation:

```text
participant может изменить собственный VacationPeriod
и тем самым влиять на auto-return
```

Пока это допустимо.

Sick automation:

`НЕ делать`

---

# 13. Local Calendar Agenda — личные Дела / Заметки

Ключевое решение:

```text
личные Calendar entries НИКОГДА не сохраняются в Firestore
```

Storage:

`SharedPreferences`

Данные разделены по authenticated `uid`, чтобы аккаунты на одном устройстве не смешивались.

Foundation:

```text
CalendarEntry
CalendarEntryMapper
CalendarEntryLocalStore
CalendarEntryService
CalendarEntryDayMarkers
```

Entry kinds:

```text
task
note
```

Properties:

```text
date
title
description
scheduledMinutes?
reminderMinutes?
priority: none / low / medium / high
colorValue? reserved for future
isCompleted
completedAt?
createdAt
updatedAt
```

Время дела и время reminder независимы.

---

# 14. Local Agenda UI

Flow:

```text
selected date
→ agenda panel
→ bottom fixed Add bar
→ left oval: Дело
→ center label: Добавить
→ right oval: Заметка
```

Промежуточный bottom sheet `Что добавить?` удалён.

Agenda:

```text
active entries above completed
timed active entries sorted by time
entries without time after timed
completed tasks below active
scrollable list
fixed bottom Add bar
```

Task:

```text
checkbox completion
completed item → strikethrough
completed item does not participate in day markers
```

Tap existing entry:

```text
open same editor prefilled
edit
save
delete with confirmation
```

Note cannot be completed.

---

# 15. CalendarEntry editor

Create/edit supports:

```text
title
optional scheduled time
priority
description / note text
bell switch
optional separate reminder time
delete when editing
```

Time picker:

```text
two Cupertino wheel pickers
hours 00..23
minutes 00..59
looping = true
```

Priority UI:

```text
Нет
Низкий
Средний
Высокий
```

all four in one line.

User color/category remains in domain model for future UI but is not exposed yet.

---

# 16. Calendar day markers

For active local entries:

```text
plain entry without reminder → note icon
entry with reminder → bell icon
highest active priority → priority dot
completed tasks → ignored
```

Priority dot:

```text
low → green
medium → amber
high → red
none → no dot
```

Full/medium integration started and manually visible.

Compact marker presentation still needs final tuning; do not overload stationary center frame.

---

# 17. Real local Calendar reminders — implemented

Checkpoint:

`27cce8e — feat(calendar): add exact local reminders`

Architecture:

```text
CalendarEntry editor / ShiftCalendarScreen
→ CalendarEntryService
→ CalendarEntryReminderService
→ NotificationService
→ flutter_local_notifications
```

Dependencies added:

```text
timezone: ^0.11.1
flutter_timezone: ^5.1.0
```

Android manifest additions:

```text
RECEIVE_BOOT_COMPLETED
SCHEDULE_EXACT_ALARM
ScheduledNotificationReceiver
ScheduledNotificationBootReceiver
```

Timezone initialization:

```text
flutter_timezone
→ current timezone identifier
→ timezone package tz.local
```

Reminder lifecycle:

```text
create entry with reminder → schedule
edit date/reminder → reschedule using same stable notification identity
disable bell → cancel
delete entry → cancel
complete task → cancel pending reminder
restore completed task to active → schedule again when applicable
Calendar load → reconcile persisted local entries with scheduled reminders
```

Stable Android notification ID is derived from `CalendarEntry.id` via deterministic 32-bit hash and kept in positive signed range.

Scheduling mode:

```text
AndroidScheduleMode.alarmClock
```

Why `alarmClock`:

```text
exactAllowWhileIdle on real devices
→ observed delay around 1–2 minutes

alarmClock on real device
→ notification arrived in the requested minute
→ ordinary system notification sound worked
```

Calendar reminders intentionally use the normal system notification sound, not the Epistola seagull sound used by messaging/SpacesBar notifications.

Permission behavior:

```text
reminder enabled
→ check exact-alarm permission
→ request if missing

permission denied
→ CalendarEntry is still saved
→ reminder is disabled for that save
→ Snackbar explains that exact reminder permission was not granted
```

Important boundaries:

```text
personal CalendarEntry data remains local-only
no Firestore collection is used for reminders
reminder time is independent from task scheduled time
completed task does not participate in active markers and has no pending reminder
local notification tap currently has no Calendar deep-link payload
```

Manual Android verification:

```text
exact requested time → passed
system sound → passed
reschedule → old time silent, new time exactly one notification
bell off → cancelled
complete task → cancelled
delete task → cancelled
close/reopen Epistola → reminder still delivered exactly once
```

Not manually verified yet:

```text
full physical phone reboot → reminder delivery after reboot
```

Boot receiver support is configured, but do not describe reboot survival as manually confirmed until tested.

---

# 18. Additional shift / халтура calendar event — planned

Personal tasks and work events are separate concepts.

Desired source:

```text
existing Substitution call / confirmed-call / SpacesBar event
```

Do not parse free-form text if structured call/date/shift data already exists.

Desired calendar behavior:

```text
call received roughly 12–20h before shift
→ calendar work event appears immediately
→ day tile gets violet border
→ agenda gets system row/card with violet vertical strip
→ once shift start time arrives, status becomes occurred
→ historical violet marker remains
```

Status should preferably be derived from `startAt`, not rewritten by timer:

```text
now < startAt → upcoming
now >= startAt → occurred
```

Dedupe by stable source/call ID.

Compact:

```text
do not add extra visual frame over stationary center selector if cluttered
```

---

# 19. Calendar overlay composition

Concept:

```text
baseShift(date, crew)
+
vacationOverlay
+
sickOverlay
+
substitutionOverlay
+
additionalShiftOverlay
=
effective day presentation
```

Personal local entries are a separate presentation layer and do not change effective work schedule.

---

# 20. Calendar roadmap

## Immediate

```text
Real local reminder scheduling → CLOSED at 27cce8e

Next available Calendar blocks:
1. Final compact markers
2. Calendar UI polish
3. Additional shift / халтура work event projection
```

The order of these remaining blocks is not mandatory. If business value is preferred over cosmetic polish, additional shift / халтура projection can be started before compact/UI polish.

## Local Agenda later

```text
user colors/categories
repeating local entries
templates tied to shift-cycle positions 1..8
optional validFrom / validUntil
optional time + reminder
```

Do not materialize hundreds of repeated copies unless required.

## Vacation later

```text
Vacation → Substitution status automation
history-safe slot reuse/archive
recent server history ≈ 1–2 years
```

## Themes

Future palette should support separate roles:

```text
8 cycle positions/phases
vacation
additional shift/substitution
selection/focus
grid/background
priority markers
```

Presets:

```text
Standard
Dark
Contrast
Custom/advanced later
```

## Web Calendar

Plan:

```text
connect Calendar tile to EpiLite
reuse deterministic ShiftScheduleCalculator
Vacation Firestore data can be shared
personal entries remain local-only
Web personal storage should use browser-local persistence / IndexedDB style approach, not Firestore
```

---

# 21. Calendar UI polish backlog

```text
final compact marker layout
possible Today icon replacement
month transition/presentation tuning
compact selector frame tuning
agenda/date typography tuning if needed
```

Current agenda date is kept on one line and allowed to use available width.

---

# 22. Build / APK state

Release APK after local-reminder implementation:

```text
flutter.bat build apk --release
→ build/app/outputs/flutter-apk/app-release.apk
→ 60.7 MB
```

The APK was installed and used for real-device reminder lifecycle verification.

Rebuild command:

```powershell
flutter.bat build apk --release
```

---

# 23. Development workflow

Environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Emulator + Poco F6
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

Small verifiable steps.

Do not commit/push/deploy until explicit checkpoint approval.

Generated files:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Policy:

```text
оставлять dirty в серии Flutter-команд
восстанавливать один раз после последней Flutter-команды
не коммитить случайные generated changes
```

---

# 24. Encoding warning

PowerShell `Set-Content -Encoding utf8` может добавить BOM:

`EF-BB-BF`

Для source/rules files при необходимости использовать UTF-8 without BOM:

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

---

# 25. Other backlog

Web:

```text
chat avatar rendering
Web push later
```

Push/security:

```text
remove production legacy device writes after broad rollout
deploy exact strict migration
pushInstallations cleanup for deleted Auth users
```

Spaces Hub:

```text
⋮ settings
show/hide Spaces
regular/compact layout
>8 behavior
odd final tile behavior
```

Buses:

```text
waiting for current authoritative schedule
```

Technical cleanup:

```text
legacy *MessageId → presentationId
```

---

# 26. New-chat start

Goal:

```text
continue Calendar after completed exact local reminders
choose next block explicitly:
- final compact markers
- Calendar UI polish
- additional shift / халтура projection
```

First run:

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

Expected after docs commit + push:

```text
latest functional checkpoint = 27cce8e
working tree = CLEAN
origin feature branch = same as local docs HEAD
```

If Git says otherwise, trust Git.

Do not use `main` as current `v0.8.0` source.

Do not deploy full repository `firestore.rules` blindly.
