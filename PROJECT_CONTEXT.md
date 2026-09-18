# Epistola — Project Context

> Живой operational handoff-документ проекта.
>
> При конфликте источников:
>
> исходный код текущей feature-ветки
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
>
> Не использовать `main` как источник текущего состояния `v0.8.0`, пока feature-ветка не merged/released.

---

# 1. Актуальная контрольная точка

Repository:

`MikhailBerezkin/epistola`

Feature branch:

`feat/v0.8.0-spaces-substitution-foundation`

Последний functional checkpoint:

`f172ef1 — feat(calendar): add vacation foundation and calendar settings`

Предыдущий functional checkpoint текущей сессии:

`764d3de — feat(web): enable chats and speed up user loading`

Важный более ранний checkpoint:

`67800f0 — feat(push): add installation ownership foundation`

Последний стабильный release до `v0.8.0`:

`v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation`

`v0.8.0` всё ещё находится в feature-ветке.

После docs-коммита `HEAD` станет новее `f172ef1`, но latest functional checkpoint останется `f172ef1`.

В новом чате сначала проверить:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

---

# 2. Финальная проверка functional checkpoint

Flutter:

```text
dart.bat format
→ final changed Dart set formatted

flutter.bat analyze
→ No issues found
→ 6.0 s

flutter.bat test
→ 1012/1012 passed
```

Во время full suite может появляться:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

Если итог `All tests passed!`, это diagnostic output, не падение suite.

Targeted Vacation Dart:

```text
VacationPeriod
VacationPeriodMapper
VacationPeriodFirestoreGateway
→ 20/20 passed
```

Substitution confirmed-call mapper после синхронизации с 3-second undo window:

```text
→ 12/12 passed
```

Final Firestore Rules group:

```text
substitution_space_rules.test.mjs
substitution_finalize_rules.test.mjs
vacation_period_rules.test.mjs
push_device_rules.test.mjs
→ 91/91 passed
```

Vacation Rules отдельно:

```text
→ 12/12 passed
```

Generated Flutter plugin files после последней Flutter-команды восстановлены один раз и не попали в functional commit.

После `f172ef1`:

```text
git status --short
→ CLEAN
```

---

# 3. Production Firestore Rules hotfix — 2026-09-18

Production bug:

```text
Список / Подсменка
→ owner/brigadier вызывает активного участника
→ UI: "Не удалось выполнить вызов"
```

Root cause:

```text
новый client call transaction уже требует shiftClaims
production Firestore Rules были старее этого contract
→ Firestore transaction отклонялся Rules
```

Новый call transaction атомарно затрагивает:

```text
spaces/substitution/pendingCalls/{callId}
spaces/substitution/shiftClaims/{claimId}
spaces/substitution/participants/{userId}
spaces/substitution
```

`shiftClaims` защищает от повторного вызова одной и той же рабочей смены.

---

# 4. Почему не деплоили текущий firestore.rules напрямую

Текущий repository `firestore.rules` содержит:

```text
shiftClaims
self-return sick → active
Vacation Foundation
strict push device ownership
```

Но часть пользователей всё ещё использует старый Android APK, который напрямую пишет:

```text
users/{uid}/devices/{installationId}
```

Новые APK используют:

```text
claimPushInstallation
releasePushInstallation
```

Если бы сразу задеплоили strict:

```text
allow create, update, delete: if false;
```

старые APK могли бы потерять регистрацию/refresh/delete push token.

Поэтому был создан временный `firestore.transition.rules`.

Файл использовался только для тестирования/deploy и после deploy удалён. В repository он не должен попадать.

---

# 5. Production transition Rules — текущее состояние

Production сейчас содержит:

```text
новый Substitution shiftClaims contract
+
legacy-compatible users/{uid}/devices writes
```

Legacy compatibility разрешает authenticated user только собственный device document и только exact fields:

```text
token
platform
updatedAt
```

Delete разрешён только для собственного user path.

Важно:

```text
Vacation Rules на production НЕ DEPLOYED
self-return sick → active из текущего repository Rules не входил в transition hotfix
```

То есть production Rules и repository `firestore.rules` намеренно различаются.

---

# 6. Проверки transition Rules

Перед deploy:

```text
call / shiftClaims → 23/23
undo → 5/5
finalize → 11/11
legacy push compatibility → 6/6
```

Дополнительно проверено:

```text
firestore.transition.rules
→ vacationPeriods отсутствует
```

Deploy:

```text
firebase.cmd deploy --only firestore:rules --project epistola-434b7
→ Deploy complete!
```

После deploy локальный рабочий `firestore.rules` был восстановлен.

---

# 7. Production manual verification hotfix

Реальный сценарий:

```text
Owner
→ вызвал bot participant
→ вызов прошёл
```

После примерно 3 секунд:

```text
undo window закрылось
bot переместился вниз rotation list
statistics shifts → +1
```

Notification projections:

```text
SpacesBar notification → получено
push notification → получено
```

Также проверен старый APK, в котором ещё вообще нет Spaces:

```text
bot получил push
```

Это подтвердило legacy push compatibility.

Production hotfix закрыт.

---

# 8. Push installation ownership

Invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installations allowed
```

Registry:

```text
pushInstallations/{installationId}
```

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

Repository target Rules уже strict:

```text
users/{uid}/devices/{deviceId}
read own → allowed
client create/update/delete → denied
```

Production пока временно разрешает legacy own writes.

После следующего широкого APK rollout:

```text
1. проверить adoption
2. прогнать Rules
3. deploy strict repository Rules
4. убрать legacy compatibility
```

---

# 9. Web / EpiLite checkpoint

Commit:

`764d3de — feat(web): enable chats and speed up user loading`

Platform capability:

```text
supportsChats
→ Web true
```

Manual Web verification:

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
→ independent user reads переведены на Future.wait
```

Known gap:

```text
chat avatars всё ещё не отображаются корректно
```

Web push остаётся unsupported.

Hosting:

`https://epistola-434b7.web.app`

В текущей сессии успешно выполнялись:

```text
flutter.bat build web
firebase.cmd deploy --only hosting
```

---

# 10. Calendar foundation

Space:

`Календарь смен`

Base calendar:

```text
4 crews
8-day repeating cycle
```

Для crew 4 подтверждено:

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

```text
14.09.2026 = День 2
```

Базовый shift schedule считается immutable.

Будущие overlays:

```text
vacation
sick
substitution
additional shift / халтура
```

не должны переписывать 8-day cycle.

---

# 11. Calendar UI

Готово:

```text
full-screen calendar
selected/target date centering
horizontal date strip
month title корректно меняется при 30 → 1
selected date digit → red
weekday/month header обновляется
shift designation отображается
Today navigation
```

View modes:

```text
full
medium
compact
```

Persistence:

```text
ShiftCalendarViewMode
SharedPreferences key: shift_calendar_view_mode
default: medium
```

Crew + mode загружаются до render, чтобы не было flash неправильного состояния.

Today:

```text
PageController
_goToToday()
Icons.today_outlined
```

Работает в full / medium / compact.

Swipe tuning:

```text
950/920 оказалось слишком нечувствительно
возвращено примерно 550/520
```

Нужна ещё финальная оценка на телефоне.

---

# 12. Calendar overflow menu

В header добавлено `⋮`.

Пункты:

```text
Отпуска
Будильники
Темы календаря
```

Текущие handlers:

```text
placeholder / no-op
```

Следующий продуктовый блок — `Отпуска`.

---

# 13. Substitution self-return

Текущий repository checkpoint добавляет:

```text
ordinary participant:
sick → active
→ может вернуть себя сам
```

Ограничения:

```text
только собственный participant
availability не подменяется
rotationOrder не меняется
vacation → active остаётся manager-controlled
another participant → запрещено
```

UI и Firestore Rules согласованы.

Это изменение ещё не было частью production transition deploy.

---

# 14. Vacation Foundation

Новые файлы:

```text
lib/domain/models/vacation_period.dart
lib/services/spaces/calendar/vacation_period_mapper.dart
lib/services/spaces/calendar/vacation_period_firestore_gateway.dart
```

Tests:

```text
test/domain/models/vacation_period_test.dart
test/services/spaces/calendar/vacation_period_mapper_test.dart
test/services/spaces/calendar/vacation_period_firestore_gateway_test.dart
test/rules/firestore/vacation_period_rules.test.mjs
```

Authoritative collection:

```text
spaces/calendar/vacationPeriods/{userId}__{slot}
```

Schema v1:

```text
schemaVersion
userId
slot
startDay
endDay
updatedAt
```

Day storage:

```text
YYYYMMDD integer
```

Document ID:

```text
<userId>__<slot>
```

---

# 15. Vacation slots

Окончательный technical capacity текущего foundation:

```text
1..6
```

Tests:

```text
slot 6 → valid
slot 7 → rejected
```

Проверено в:

```text
domain
mapper
gateway
Firestore Rules
```

UI НЕ должен показывать шесть пустых слотов.

Будущий UI:

```text
реальные current/future vacations
+
"+ Добавить отпуск"
```

Slots — persistence capacity, не visual structure.

---

# 16. Vacation ownership / security

User может:

```text
create/update/delete только свои vacation periods
```

Other signed-in users:

```text
могут read vacationPeriods
```

Manager special edit:

```text
НЕ предусмотрен
```

Delete означает:

```text
отмена / ошибочная запись
→ period удаляется
→ vacation coloring исчезает
```

Естественно завершившийся отпуск не должен физически удаляться только потому, что стал прошлым.

---

# 17. Vacation Calendar semantics

Calendar — source of truth.

Vacation — overlay поверх immutable base schedule.

Planned display:

```text
весь startDay..endDay inclusive
→ vacation color
```

Editable list:

```text
до последнего vacation day включительно → editable
со следующего дня → не показывать как current/future item
```

Но past Calendar months должны сохранять historical vacation coloring.

Visible History screen/editor сейчас не нужен.

Unresolved architecture task:

```text
как безопасно переиспользовать 6 slots,
не теряя historical vacation projection
```

Не внедрять автоматический slot reuse с потерей истории.

---

# 18. Planned Vacation input UX

Желаемые форматы:

```text
18.09.2026
18.09
18 сентября
18 сентября 2026
```

Если год отсутствует:

```text
использовать год, открытый сейчас в Calendar
```

Cross-year:

```text
Calendar year = 2026
start = 20.12
end = 10.01
→ 20.12.2026 .. 10.01.2027
```

Placeholders:

```text
18.09
02.10
```

Parser/editor UI ещё не реализован.

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

Нельзя кодировать exceptions переписыванием базового 8-day schedule.

---

# 20. Build notes

Ранее в текущей сессии успешно собран:

```text
release APK → 58.5 MB
```

После последних Vacation 1..6 code/test изменений отдельный новый release APK не пересобирался.

Это допустимо: Vacation UI ещё не подключён, checkpoint закрывался анализом и тестами.

---

# 21. Development workflow

Environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Studio JBR
Java 21.0.10
Node 22
Firebase CLI
```

Commands:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git.exe
```

В новой PowerShell session для emulator:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

---

# 22. Encoding warning

Windows PowerShell:

```powershell
Set-Content -Encoding utf8
```

может добавить BOM:

```text
EF-BB-BF
```

Firestore Rules compiler может упасть:

```text
L1:1 token recognition error
```

Для source/rules files использовать UTF-8 without BOM:

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

---

# 23. Generated Flutter files policy

Files:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Policy:

```text
оставлять dirty во время серии Flutter-команд
восстанавливать один раз после последней Flutter-команды
не коммитить случайные generated changes
```

---

# 24. Что ещё НЕ сделано

Vacation:

```text
Vacation editor screen
friendly date parser
Calendar vacation coloring
effective Vacation overlay
history-safe slot reuse
production Vacation Rules deploy
```

Calendar:

```text
real handlers for Отпуска / Будильники / Темы календаря
additional shift / халтура
final phone gesture tuning
```

Web:

```text
chat avatar rendering
Web push
```

Push/security:

```text
remove production transition legacy device writes after rollout
deploy strict repository Rules
deleted-user cleanup for pushInstallations
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

# 25. New-chat start

Цель:

```text
continue Calendar / Vacation
```

Сначала:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Потом прочитать:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Expected after docs commit + push:

```text
latest functional checkpoint: f172ef1
working tree: CLEAN
origin: same as local docs HEAD
```

Если Git говорит иначе — доверять Git.

Recommended next sequence:

```text
1. Vacation editor orchestration
2. friendly date parser
3. Calendar vacation overlay
4. history/slot-reuse strategy
5. additional shift / халтура
6. Calendar polish
```

Не деплоить локальный полный `firestore.rules` без отдельного решения о production transition migration.
