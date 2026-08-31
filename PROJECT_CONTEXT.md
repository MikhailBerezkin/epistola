# Epistola — Project Context

> Живой handoff-документ проекта.
>
> Использовать при переходе между чатами и рабочими сессиями.
>
> При расхождении источников приоритет всегда такой:
>
> ```text
> исходный код текущей ветки
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```

## 1. Текущая контрольная точка

Репозиторий:

```text
MikhailBerezkin/epistola
```

Текущая ветка разработки:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Функциональный checkpoint перед финальным обновлением документации:

```text
63c405e feat(spaces): finalize substitution statistics foundation
```

На этой точке:

```text
HEAD == origin/feat/v0.8.0-spaces-substitution-foundation
working tree == CLEAN
```

Текущий release target:

```text
v0.8.0 — Spaces / Substitution Foundation
```

Последний стабильный release до начала v0.8.0:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

Важно: на момент подготовки этого документа v0.8.0 ещё находится в feature-ветке. Merge в `main` и release tag не считать выполненными, пока это не подтверждено отдельными Git-командами.

## 2. Infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Android package: com.epistola.app
Primary platform: Android
Pilot target: 40–50 users
```

Используемые Firebase-компоненты проекта:

```text
Firebase Authentication
Cloud Firestore
Realtime Database
Cloud Storage
Cloud Messaging
Cloud Functions
Security Rules
```

Главный принцип стоимости для пилота:

```text
избегать лишних Firestore reads/writes
не создавать per-widget listeners
кэшировать повторно используемые данные пользователей по UID
не переносить временный UI-state в backend без необходимости
```

## 3. Что сделано в v0.8.0

v0.8.0 создаёт основу внутренних приложений Epistola — Spaces — и первый полноценно развиваемый модуль очереди подмен.

Основной scope:

```text
1. Spaces Hub
2. Spaces access roles
3. "Список" / Substitution participant foundation
4. rotationOrder queue
5. availability states
6. vacation / sick states
7. participant management
8. work display name
9. call participant flow
10. Undo window
11. pending call persistence
12. exactly-once finalization
13. recovery after app close / interrupted session
14. production monthly/yearly statistics
15. compact statistics UI
16. Firestore Rules for substitution data
17. final cleanup of obsolete TEST statistics layer
```

## 4. Spaces Hub

Основной экран:

```text
lib/screens/spaces_page.dart
```

Spaces — отдельный application area, а не разновидность чата.

Текущие плитки:

```text
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

На данном этапе рабочим модулем является только `"Список"`.

Остальные плитки пока являются placeholders и показывают сообщение:

```text
Раздел пока в разработке.
```

Плитка `"Список"` специально оставлена без subtitle.

Название `"Список"` сейчас используется с кавычками в UI намеренно. Не удалять кавычки без отдельного решения пользователя.

## 5. Spaces access roles

Domain:

```text
lib/domain/models/spaces_access_role.dart
```

Роли:

```text
member
brigadier
owner
```

Права:

```text
member
→ обычное использование Spaces

brigadier
→ canManageSubstitution == true

owner
→ canManageSubstitution == true
→ canManageSpacesRoles == true
```

Owner сохраняет максимальный приоритет.

В текущем модуле manager-level действия — это:

```text
brigadier
owner
```

Обычный `member` не получает административные действия только потому, что UI их может отрисовать.

## 6. Экран "Список"

Основной экран:

```text
lib/screens/substitution_space_screen.dart
```

AppBar:

```text
title: "Список"
settings tooltip: Настройки списка
```

Tabs:

```text
Список N
Отпуск N
Больничный N
```

`N` — текущее количество участников соответствующего состояния.

Поведение Back:

```text
если открыта карточка участника
→ закрыть карточку

иначе если открыт не первый tab
→ вернуться на tab Список

иначе
→ выйти из пространства
```

## 7. Participant model

Файл:

```text
lib/domain/models/substitution_participant.dart
```

Основные поля:

```text
userId
rotationOrder
availability
status
```

Availability:

```text
green
yellow
red
```

UI labels:

```text
green  → Всегда готов!
yellow → Только в день
red    → Занят
```

Participant status:

```text
active
vacation
sick
```

Смысл:

```text
active   → находится в основной очереди
vacation → находится на вкладке Отпуск
sick     → находится на вкладке Больничный
```

Default availability:

```text
green
```

## 8. Очередь и rotationOrder

Очередь хранится через persisted `rotationOrder`.

UI не должен вычислять canonical порядок только локально.

После успешного вызова участника очередь перестраивается через application/service layer и Firestore transaction.

Ключевой принцип:

```text
UI показывает текущее состояние
backend transaction определяет canonical новое состояние
```

Нельзя вводить альтернативный локальный счётчик очереди, расходящийся с Firestore.

## 9. Participant card / overlay

Основные файлы:

```text
lib/widgets/spaces/substitution/substitution_participant_overlay.dart
lib/widgets/spaces/substitution/substitution_participant_row.dart
lib/widgets/spaces/substitution/substitution_queue_badge.dart
```

Карточка участника открывается поверх текущего экрана.

Manager может:

```text
изменить рабочее имя
перевести в Отпуск
перевести в Больничный
вернуть в Список
удалить участника
вызвать active участника
```

Обычный пользователь может менять только собственную availability.

Критичное UI/permission правило:

```text
manager открывает карточку другого пользователя
→ availability selector для изменения недоступен

пользователь открывает собственную active карточку
→ availability можно менять
```

То есть бригадир не выставляет пользователю его "светофор" от своего имени.

## 10. Work display name

Work display name используется для рабочего пространства независимо от обычного имени пользователя.

Relevant files:

```text
lib/services/spaces/substitution/substitution_work_display_name_service.dart
lib/screens/substitution_space_screen.dart
```

Manager может задать рабочее имя.

Пустое значение возвращает обычное имя пользователя.

Display fallback:

```text
effectiveWorkDisplayName
→ email
→ uid
```

## 11. Настройки списка

UI:

```text
lib/widgets/spaces/substitution/substitution_settings_sheet.dart
```

Заголовок:

```text
Настройки списка
```

Доступные локальные настройки:

```text
отображение очереди:
- Аватар
- Номер

Показывать статистику:
- on/off
```

Настройки хранятся локально через:

```text
lib/services/spaces/substitution/substitution_ui_preferences.dart
```

Это presentation preference, а не Firestore business state.

Для manager дополнительно показывается:

```text
Управление
→ Добавить участников
```

У обычного member management section отсутствует.

## 12. Call participant flow

Вызов доступен только role с:

```text
canManageSubstitution == true
```

И только для:

```text
participant.isActive == true
```

Диалог выбора смены максимально простой:

```text
Сегодня в ночь
Завтра в день
Отмена
```

Domain shift:

```text
lib/domain/models/substitution_shift.dart
```

Shift kinds:

```text
day
night
```

Время, зафиксированное domain model:

```text
day:
08:00 → 20:00

night:
20:00 → 08:00 следующего календарного дня
```

Важно для статистики:

```text
смена целиком относится к дате её начала
```

Пример:

```text
31 августа, night
→ статистика августа

1 сентября, day
→ статистика сентября
```

Даже если ночная смена заканчивается уже следующим календарным днём, её statisticsMonth/statisticsYear определяются датой начала.

## 13. Undo window

После успешного call UI показывает SnackBar:

```text
<Имя> вызван
[Отменить]
```

Undo window:

```text
6 секунд
```

После 6 секунд UI пытается финализировать pending call.

Undo — это не только скрытие SnackBar.

Он должен вернуть состояние очереди только при соблюдении server-side условий и удалить соответствующий pending call так, чтобы статистика не была начислена.

Если очередь уже изменилась и Undo небезопасен:

```text
Отмена недоступна: очередь уже изменилась
```

## 14. Pending call foundation

Production pending path:

```text
spaces/substitution/pendingCalls/{callId}
```

`callId` — canonical positive integer string, основанный на monotonic revision вызовов.

Pending call содержит данные, достаточные для будущей финализации статистики, включая:

```text
callId
userId
calledByUserId
shift
created/finalization timing data
```

Главная идея:

```text
вызов и перестановка очереди
→ создаётся pendingCall
→ 6 секунд можно Undo
→ после окна pendingCall превращается в статистику
```

PendingCalls также нужны для recovery, если приложение было закрыто до завершения таймера.

## 15. Exactly-once finalization

Ключевой gateway:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Finalization выполняется одной Firestore transaction:

```text
1. read pendingCalls/{callId}
2. если документа нет → return false
3. strict map → SubstitutionPendingCall
4. определить statisticsYear из shift
5. read statistics/year_YYYY
6. strict map текущей статистики
7. apply confirmed call
8. write statistics/year_YYYY
9. delete pendingCalls/{callId}
10. commit
```

Главная exactly-once защита:

```text
pending document существует
→ transaction может применить call

pending document уже удалён
→ повторный finalize возвращает false
→ статистика второй раз не увеличивается
```

Firestore transaction conflict/retry обеспечивает согласованность при конкурентных попытках.

Finalization не должна быть перенесена в widget code.

## 16. Recovery / reconciliation

Relevant files:

```text
lib/services/spaces/substitution/substitution_call_reconciliation_service.dart
lib/services/spaces/substitution/substitution_pending_call_firestore_gateway.dart
```

При открытии `"Списка"` manager-level пользователем:

```text
load SpacesAccessRole
→ если canManageSubstitution
→ one-shot recovery expired pending calls
```

Recovery:

```text
1. one-shot list pendingCalls
2. sort by revision / callId
3. локально определить expired
4. sequential finalize
5. Rules + transaction остаются authoritative
```

Recovery не использует постоянный listener.

Это сознательно экономит Firestore reads для пилота 40–50 пользователей.

Если recovery падает:

```text
экран всё равно открывается
pendingCall остаётся
следующий manager/open повторит попытку
```

Если recovery реально финализировал хотя бы один call:

```text
statistics UI reload
```

Если ничего не финализировано:

```text
лишний statistics read не выполняется
```

## 17. Production statistics model

Domain:

```text
lib/domain/models/substitution_statistics.dart
```

Statistics document:

```text
spaces/substitution/statistics/year_YYYY
```

Пример:

```text
spaces/substitution/statistics/year_2026
```

Основные поля:

```text
year
monthCallCounts
monthShifts
yearCallCounts
lastFinalizedCallId
updatedAt
```

Semantics:

```text
monthCallCounts["8"][uid]
→ количество подтверждённых вызовов UID в августе

monthShifts["8"][uid]
→ ordered list: day/night/day/...

yearCallCounts[uid]
→ подтверждённые вызовы UID за весь год
```

`lastFinalizedCallId` — техническое поле, не UI-field.

`updatedAt` — server timestamp последнего изменения агрегата.

Модель делает вложенные collections immutable/unmodifiable.

Public domain helpers:

```text
callsForMonth(month, userId)
shiftsForMonth(month, userId)
callsForYear(userId)
```

Invalid input возвращает безопасный empty/zero result.

## 18. Statistics mapper invariants

Relevant files:

```text
lib/services/spaces/substitution/substitution_statistics_mapper.dart
lib/services/spaces/substitution/substitution_statistics_accumulator.dart
```

Strict data consistency:

```text
для каждого month + uid:
monthCallCounts == monthShifts.length
```

Year consistency:

```text
yearCallCounts[uid]
==
sum(monthCallCounts[*][uid])
```

Malformed statistics document не должен молча использоваться как корректный агрегат.

## 19. Statistics read-side

Gateway:

```text
lib/services/spaces/substitution/substitution_statistics_firestore_gateway.dart
```

Service:

```text
lib/services/spaces/substitution/substitution_statistics_service.dart
```

Read pattern:

```text
statistics/year_$year
→ one document get
```

Нет per-participant reads.

UI загружает текущий год только когда:

```text
showStatistics == true
```

Cached screen state:

```text
_statistics
_statisticsLoaded
_isStatisticsLoading
_statisticsError
_statisticsYear
```

После успешной finalization:

```text
finalizePendingCall == true
→ reload current statistics
```

После Undo:

```text
finalizePendingCall == false
→ дополнительный statistics reload не нужен
```

## 20. Statistics UI

Summary widget:

```text
lib/widgets/spaces/substitution/substitution_statistics_summary.dart
```

Participant overlay показывает:

```text
Статистика
Август                     4
[compact shift segments]
За год                     7
```

Month label — только название месяца.

Segment meaning:

```text
day   → amber/yellow
night → dark blue
empty → muted background
```

Количество сегментов:

```text
0–5 calls  → 5 slots
6–9 calls  → 9 slots
10–12+     → 12 slots
```

Domain хранит только semantic shift kind:

```text
day
night
```

Цвета остаются presentation concern.

Это важно для будущей смены темы/дизайна.

## 21. Availability UI

Relevant files:

```text
lib/widgets/spaces/substitution/substitution_availability_selector.dart
lib/widgets/spaces/substitution/substitution_availability_style.dart
```

Три варианта показываются рядом.

Каждый вариант содержит:

```text
цветной круг
текстовую подпись
selected state
Semantics / Tooltip
```

Текущие labels:

```text
Всегда готов!
Только в день
Занят
```

Manual UI check был выполнен: подписи помещаются, выбранное состояние отображается корректно.

## 22. Удаление старого TEST statistics layer

Старый временный statistics prototype полностью удалён.

Удалённые production/test files включают:

```text
lib/domain/models/substitution_test_statistics.dart
lib/services/spaces/substitution/substitution_test_statistics_firestore_gateway.dart
lib/services/spaces/substitution/substitution_test_statistics_mapper.dart
lib/services/spaces/substitution/substitution_test_statistics_service.dart

test/domain/models/substitution_test_statistics_test.dart
test/rules/firestore/substitution_test_statistics_rules.test.mjs
test/services/spaces/substitution/substitution_test_statistics_firestore_gateway_test.dart
test/services/spaces/substitution/substitution_test_statistics_mapper_test.dart
test/services/spaces/substitution/substitution_test_statistics_service_test.dart
```

Production statistics replacement теперь является единственным актуальным путём.

Не восстанавливать TEST statistics files в новом чате.

## 23. Firestore Rules

Файл:

```text
firestore.rules
```

Добавлены/обновлены boundaries для:

```text
spaces/substitution
participants
pendingCalls
statistics/year_YYYY
call finalization
manager recovery/list
```

Manager access основан на Spaces role, а не на UI.

Old TEST statistics exception удалена/закрыта, чтобы generic statistics rule случайно не оставлял доступ к устаревшему `statistics/test`.

Firestore Rules текущей ветки были deployed в:

```text
epistola-434b7
```

Последний deploy завершился:

```text
Deploy complete!
```

Functions и Storage в этом deploy не затрагивались.

## 24. Manual scenarios, которые уже прошли

Проверены реальные сценарии поведения.

### 24.1 Обычная finalization

```text
manager вызывает участника
→ очередь меняется
→ pendingCall создаётся
→ Undo window проходит
→ statistics year document обновляется
→ pendingCall удаляется
```

### 24.2 Undo до 6 секунд

```text
call
→ Undo
→ очередь возвращается
→ pendingCall отсутствует
→ statistics не увеличивается
```

Monotonic revision при этом может уже увеличиться — это ожидаемо.

### 24.3 App close до finalization

```text
call
→ закрыть приложение до 6 секунд
→ открыть снова manager-ом
→ recovery находит expired pendingCall
→ statistics обновляется
→ pendingCall удаляется
```

### 24.4 Remove / reinvite

```text
participant имеет накопленную статистику
→ participant удалён
→ позже добавлен снова
→ statistics сохраняется по UID
```

Participant entry может получить новый порядок, но статистика не теряется.

### 24.5 Immediate statistics refresh

На уже открытом экране:

```text
successful finalize
→ statistics summary обновляется без повторного открытия пространства
```

### 24.6 Month boundary

Проверено:

```text
31 августа → Сегодня в ночь
→ August statistics

31 августа → Завтра в день
→ shift date = 1 September
→ не входит в August monthly count
→ входит в yearly count
```

Не менять этот принцип ради визуального расположения полосы.

## 25. Automated checks

Последний зафиксированный Flutter gate перед документацией:

```text
targeted statistics summary widget tests
→ 5/5 passed

flutter.bat analyze
→ No issues found

flutter.bat test
→ 751 tests passed
```

В suite может появляться диагностический JPEG output:

```text
Corrupt JPEG data...
JPEG datastream contains no image
```

Это известный test diagnostic noise, если итог suite:

```text
All tests passed!
```

Последний зафиксированный Firestore gate текущего этапа:

```text
targeted substitution/finalization Rules
→ 53/53 passed

full Firestore Rules suite
→ 133/133 passed
```

Release build:

```text
flutter.bat build apk --release
→ SUCCESS
→ build\app\outputs\flutter-apk\app-release.apk
→ 56.8 MB
```

Material Icons tree-shaking message:

```text
MaterialIcons-Regular.otf was tree-shaken...
```

является обычным release optimization message, не ошибкой.

## 26. Generated plugin files

После последней Flutter-команды были восстановлены:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Они не входят в functional checkpoint `63c405e`.

Не восстанавливать их после каждой отдельной Flutter-команды. Делать один restore после последней Flutter-команды серии, если они изменились только как generated noise.

## 27. Git checkpoint

Функциональный commit:

```text
63c405e feat(spaces): finalize substitution statistics foundation
```

После push:

```text
HEAD
==
origin/feat/v0.8.0-spaces-substitution-foundation
```

Рабочее дерево до замены этих трёх документов:

```text
CLEAN
```

Документацию планируется зафиксировать отдельным docs commit после полной замены:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Не смешивать docs update с новым функциональным кодом.

## 28. Что делать сразу после замены документов

Документационные изменения не требуют повторного Flutter build/test.

После замены трёх файлов:

```powershell
git.exe diff --check
git.exe status --short
```

Ожидаемые modified files:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

После проверки — только по явному подтверждению пользователя:

```text
docs commit
push feature branch
```

Merge в `main`, tag `v0.8.0` и release closure — отдельные state-changing действия и должны выполняться только после отдельного подтверждения.

## 29. Новый чат: обязательный стартовый протокол

Новый чат не должен полагаться только на этот документ.

Сначала проверить:

```powershell
git.exe branch --show-current
git.exe rev-parse --short HEAD
git.exe status --short
```

Затем прочитать актуальные файлы из текущей ветки, особенно:

```text
lib/screens/spaces_page.dart
lib/screens/substitution_space_screen.dart

lib/domain/models/spaces_access_role.dart
lib/domain/models/substitution_participant.dart
lib/domain/models/substitution_shift.dart
lib/domain/models/substitution_pending_call.dart
lib/domain/models/substitution_statistics.dart

lib/services/spaces/substitution/substitution_call_service.dart
lib/services/spaces/substitution/substitution_call_reconciliation_service.dart
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
lib/services/spaces/substitution/substitution_pending_call_firestore_gateway.dart
lib/services/spaces/substitution/substitution_statistics_accumulator.dart
lib/services/spaces/substitution/substitution_statistics_firestore_gateway.dart
lib/services/spaces/substitution/substitution_statistics_mapper.dart
lib/services/spaces/substitution/substitution_statistics_service.dart
lib/services/spaces/substitution/substitution_dependencies.dart

lib/widgets/spaces/substitution/substitution_availability_selector.dart
lib/widgets/spaces/substitution/substitution_participant_overlay.dart
lib/widgets/spaces/substitution/substitution_settings_sheet.dart
lib/widgets/spaces/substitution/substitution_statistics_summary.dart

firestore.rules
```

Priority:

```text
current source
→ this document
→ ARCHITECTURE.md
→ README.md
```

## 30. Development protocol to preserve

Работа с Epistola:

```text
маленькими проверяемыми шагами
```

Windows commands:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd / npx.cmd
git.exe
```

Не делать commit/push/tag/deploy без явного подтверждения пользователя.

Для нескольких строк — давать точную замену.

Для большого количества правок — давать файл целиком.

Перед functional commit:

```text
manual scenario
→ analyze
→ tests
→ release build
→ diff check
→ status
```

Для docs-only commit Flutter checks не повторять без причины.

Ключевая архитектурная граница:

```text
Flutter UI
→ controllers/presentation
→ application services
→ domain models/contracts
→ Firebase gateways/adapters
```

Не переносить Firestore transaction, security logic или statistics accumulation в widgets.
