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

Текущий HEAD перед локальными изменениями навигации/security:

```text
bf24968 docs: update v0.8.0 substitution foundation
```

На `bf24968` feature-ветка была синхронизирована с origin.

Текущий release target:

```text
v0.8.0 — Spaces / Substitution Foundation
```

Последний стабильный release до начала v0.8.0:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

Важно:

```text
v0.8.0 всё ещё находится в feature-ветке
```

Merge в `main` и release tag `v0.8.0` не считать выполненными, пока это отдельно не подтверждено Git-командами.

### 1.1 Текущее локальное состояние после bf24968

После `bf24968` выполнены и вручную проверены дополнительные изменения, которые на момент подготовки этого документа ещё не зафиксированы отдельным commit.

Текущие реальные functional changes:

```text
firestore.rules

lib/screens/home_screen.dart
lib/screens/spaces_page.dart
lib/screens/chats_space_screen.dart

test/rules/firestore/substitution_space_rules.test.mjs
```

После замены документации дополнительно изменятся:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Текущие functional изменения:

```text
LOCAL
UNCOMMITTED
```

Не делать commit/push/deploy без отдельного подтверждения пользователя.

---

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

Используемые Firebase-компоненты:

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

---

## 3. Development environment

Основная среда разработки:

```text
Windows
PowerShell
VS Code
Flutter
Android Studio JBR
```

Java:

```text
Java 21.0.10
```

JDK:

```text
C:\Program Files\Android\Android Studio\jbr
```

В новой PowerShell-сессии перед Firebase emulator/rules commands при необходимости выполнить:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Эти переменные действуют только для текущей PowerShell-сессии, если отдельно не сделаны persistent environment variables Windows.

Команды проекта в PowerShell:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git
```

Для Git использовать обычный:

```text
git
```

Не заменять команды на `.exe`-варианты без необходимости.

### 3.1 Как указывать пути в чате

По умолчанию показывать путь от корня репозитория:

```text
lib/...
test/...
firestore.rules
PROJECT_CONTEXT.md
```

Не писать каждый раз:

```text
E:\Dev\Projects\epistola\...
```

Полный Windows path использовать только если без него есть неоднозначность.

---

## 4. Что сделано в v0.8.0

v0.8.0 создаёт основу внутренних приложений Epistola — Spaces — и первый полноценно развиваемый рабочий модуль очереди подмен.

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
17. cleanup obsolete TEST statistics layer
18. Spaces-first root navigation
19. Chats exposed as a Space tile without rewriting Messenger internals
20. stricter member self-update Security Rule
```

---

# PART I — SPACES PLATFORM

## 5. Spaces is now the main application launcher

Главное UX-решение после checkpoint `bf24968`:

```text
Epistola больше не стартует непосредственно со списка чатов.
```

Новый root flow:

```text
App launch
→ Пространства
```

Bottom navigation:

```text
Контакты | Пространства | Профиль
              ↑
            default
```

Старой корневой вкладки:

```text
Чаты
```

больше нет.

Это не означает удаление Messenger.

Вместо этого:

```text
Пространства
→ плитка Чаты
→ существующий Messenger UI
```

### 5.1 Root navigation

Основной root:

```text
lib/screens/home_screen.dart
```

Текущий индекс:

```text
0 → Контакты
1 → Пространства
2 → Профиль
```

Default:

```text
selectedIndex = 1
```

То есть при входе пользователь попадает в:

```text
Пространства
```

### 5.2 Back behavior root

На root-level:

```text
Контакты
→ Back
→ Пространства

Профиль
→ Back
→ Пространства

Пространства
→ Back
→ выход из приложения
```

Это правило уже вручную проверено.

---

## 6. Spaces Hub

Основной экран:

```text
lib/screens/spaces_page.dart
```

Spaces — launcher внутренних приложений Epistola.

Текущие плитки:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

### 6.1 Чаты

Новая плитка:

```text
Чаты
Личные и групповые чаты
```

Icon:

```text
Icons.forum_outlined
```

Маршрут:

```text
Пространства
→ Чаты
→ ChatsSpaceScreen
→ ChatsPage
```

Wrapper:

```text
lib/screens/chats_space_screen.dart
```

`ChatsSpaceScreen` сохраняет старый chat UX:

```text
AppBar: Epistola
Search action
ChatsPage
FloatingActionButton +
```

Поиск:

```text
ChatSearchScreen
```

Создание нового сообщения:

```text
NewMessageScreen
```

### 6.2 Критичное архитектурное правило для Чатов

Messenger internals не переписывались и не переименовывались.

Существующие:

```text
ChatsPage
ChatScreen
ChatService
private/group chat domain
message services
Firebase schemas
push/deep links
```

остаются chat/Messenger architecture.

`Чаты` являются отдельным приложением, доступным через Spaces launcher.

Не выполнять массовый rename:

```text
chat → space
messenger → space
```

только ради новой навигации.

### 6.3 Проверенный маршрут

Manual test прошёл:

```text
Пространства
→ Чаты
→ существующий чат
→ Back
→ список чатов
→ Back
→ Пространства
```

Также проверены:

```text
Search
+
Contacts → Back → Spaces
Profile → Back → Spaces
Spaces → system Back → exit
```

### 6.4 Остальные Spaces

`"Список"` является production module.

Остальные:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

пока placeholders.

Текущее сообщение:

```text
Раздел пока в разработке.
```

Название:

```text
"Список"
```

с кавычками используется в UI намеренно.

Не удалять кавычки без отдельного решения пользователя.

### 6.5 Future Spaces customization

Архитектура Spaces не должна мешать будущей возможности пользователя:

```text
изменять порядок плиток
скрывать ненужные плитки
показывать разрешённые приложения
```

Сейчас это не реализовывать.

---

## 7. Future SpacesBar concept

Это будущий отдельный этап.

Не реализовывать вместе с текущей navigation/security фиксацией.

### 7.1 Назначение

На экране Spaces планируется persistent status/info area:

```text
SpacesBar
```

Примерное положение:

```text
верхняя часть Spaces
под основной навигационной областью
над плитками
```

Высота ориентировочно:

```text
2–4 строки
```

### 7.2 Состояния

Если активных сообщений нет:

```text
logo / neutral fallback
```

Если есть announcement:

```text
текст
стиль по типу/priority
```

Если есть substitution call:

```text
purple
maximum priority
immediate surface
```

### 7.3 Kind и priority — разные понятия

Не смешивать:

```text
kind
priority
```

Пример:

```text
kind = announcement
priority = 1 / 2 / 3
```

И отдельно:

```text
kind = substitutionCall
```

Substitution call имеет отдельную семантику и максимальный визуальный приоритет.

UI сам выбирает стиль/цвет по semantic state.

Не хранить Flutter `Color` как business data.

### 7.4 Несколько сообщений

Если одновременно активны несколько сообщений:

```text
carousel / banner rotation
```

Ориентировочная автоматическая смена:

```text
30–60 секунд
```

или около:

```text
1 минуты
```

Нужна ручная навигация:

```text
swipe
или
next / previous
```

Indicator:

```text
1/3
или dots
```

При новом high-priority substitution call:

```text
показать немедленно
```

После этого обычная carousel логика может продолжиться.

### 7.5 Read/display state

Нельзя при каждом запуске приложения показывать старое сообщение как новое.

По возможности per-user presentation state хранить локально:

```text
seen
dismissed
carousel position
```

чтобы не создавать Firestore write на каждый просмотр.

Server хранит authoritative active message state.

### 7.6 Publisher

Публикацию видят только:

```text
brigadier
owner
```

Обычный member не должен получать edit/publish UI.

Предполагаемый editor:

```text
multiline text
примерно 200–250 chars
priority 1 / 2 / 3
duration:
- 1 hour
- 12 hours
- 24 hours
- until cancelled
live preview
publish
```

Позже:

```text
active messages management
cancel
edit policy
```

Firestore Rules должны защищать publish/edit/cancel независимо от Flutter UI.

### 7.7 Предполагаемая data shape

Концептуально:

```text
id
kind
text
priority
createdByUserId
createdAt
expiresAt / null
cancelledAt / null
```

Schema не считать окончательно утверждённой до отдельного этапа проектирования.

### 7.8 Substitution integration

В будущем один substitution business event должен уметь отображаться одновременно через:

```text
push
SpacesBar
system notification area
```

Не создавать три независимых ручных события.

Желательная модель:

```text
one business event
→ multiple presentation channels
```

System notification area в Messenger вероятно должна быть отдельной сущностью, а не обычным fake/bot chat.

Это пока product/architecture direction, не готовая реализация.

### 7.9 Anti-spam / competing messages

Не решено:

```text
сколько одновременно pinned/active messages разрешать
slots
replacement
limits per publisher
priority competition
```

Не придумывать поведение автоматически.

Обсудить с пользователем перед реализацией SpacesBar.

---

# PART II — SPACES ROLES

## 8. Spaces access roles

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

Manager-level actions:

```text
brigadier
owner
```

Обычный `member` не получает административные действия только потому, что UI может их показать.

Backend authorization обеспечивают Firestore Rules.

---

# PART III — "СПИСОК" / SUBSTITUTION

## 9. Экран "Список"

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

Back behavior внутри module:

```text
если открыта карточка участника
→ закрыть карточку

иначе если открыт не первый tab
→ вернуться на tab Список

иначе
→ выйти из пространства
```

---

## 10. Participant model

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

Status:

```text
active
vacation
sick
```

Meaning:

```text
active
→ основная очередь

vacation
→ вкладка Отпуск

sick
→ вкладка Больничный
```

Default availability:

```text
green
```

---

## 11. Availability ownership

Критичное product/security правило:

```text
availability принадлежит самому пользователю
```

Member может изменить:

```text
только собственную availability
```

Member не может самостоятельно менять:

```text
status
rotationOrder
```

То есть обычный пользователь не должен иметь возможность через прямой Firestore write самостоятельно отправить себя в:

```text
vacation
sick
active
```

Status управляется manager-level business flow.

Manager при открытии карточки другого пользователя:

```text
не меняет его availability
```

То есть brigadier/owner не выставляет чужой `"светофор"` от своего имени.

UI:

```text
manager открывает другого пользователя
→ availability selector для редактирования отсутствует/недоступен

пользователь открывает свою active карточку
→ availability selector доступен
```

---

## 12. Security correction after bf24968

После `bf24968` обнаружено расхождение между:

```text
UI/product rule
и
Firestore Rules
```

Старый rule:

```text
isOwnSubstitutionParticipantStateUpdate
```

разрешал member менять собственные:

```text
availability
status
```

Это позволяло обойти UI и самостоятельно перевести себя в:

```text
vacation
sick
active
```

### 12.1 Новая локальная rule semantics

Теперь self update требует:

```text
request.auth.uid == userId
rotationOrder unchanged
status unchanged
changedKeys only availability
```

То есть member разрешено менять только:

```text
availability
```

### 12.2 Tests

Изменены Firestore Rules tests:

```text
allows member to move self to vacation
→ rejects member moving self to vacation

allows member to return self to active
→ rejects member returning self to active
```

Оба теперь используют:

```text
assertFails
```

Полный suite прошёл:

```text
133 tests
133 passed
0 failed
```

### 12.3 Deploy state

Важно:

```text
НОВАЯ security correction пока LOCAL ONLY.
```

Firestore Rules, которые ранее были deployed в production, относятся к предыдущему состоянию.

Текущий локальный `firestore.rules` после security correction:

```text
NOT DEPLOYED
```

Не писать в README/ARCHITECTURE, что эта новая correction уже deployed.

Deploy выполнять только после отдельного явного подтверждения пользователя.

---

## 13. Очередь и rotationOrder

Canonical очередь хранится через:

```text
rotationOrder
```

UI не вычисляет authoritative порядок самостоятельно.

После successful participant call очередь перестраивается через:

```text
application/service layer
→ Firestore transaction
```

Ключевой принцип:

```text
UI показывает текущее состояние

backend transaction
→ определяет canonical новое состояние
```

Нельзя вводить альтернативный локальный queue counter, расходящийся с Firestore.

---

## 14. Participant card / overlay

Основные файлы:

```text
lib/widgets/spaces/substitution/substitution_participant_overlay.dart
lib/widgets/spaces/substitution/substitution_participant_row.dart
lib/widgets/spaces/substitution/substitution_queue_badge.dart
```

Manager может:

```text
изменить рабочее имя
перевести в Отпуск
перевести в Больничный
вернуть в Список
удалить участника
вызвать active участника
```

Member:

```text
меняет только собственную availability
```

---

## 15. Work display name

Relevant:

```text
lib/services/spaces/substitution/substitution_work_display_name_service.dart
lib/screens/substitution_space_screen.dart
```

Work display name используется внутри рабочего пространства независимо от обычного имени пользователя.

Manager может задать рабочее имя.

Пустое значение возвращает regular name.

Fallback:

```text
effectiveWorkDisplayName
→ email
→ uid
```

---

## 16. Настройки списка

UI:

```text
lib/widgets/spaces/substitution/substitution_settings_sheet.dart
```

Заголовок:

```text
Настройки списка
```

Локальные настройки:

```text
отображение очереди:
- Аватар
- Номер

Показывать статистику:
- on/off
```

Storage:

```text
lib/services/spaces/substitution/substitution_ui_preferences.dart
```

Это presentation preference.

Не Firestore business state.

Для manager дополнительно:

```text
Управление
→ Добавить участников
```

Для member management section отсутствует.

---

# PART IV — SUBSTITUTION CALL FLOW

## 17. Call participant flow

Call разрешён только при:

```text
canManageSubstitution == true
```

и:

```text
participant.isActive == true
```

Shift dialog:

```text
Сегодня в ночь
Завтра в день
Отмена
```

Domain:

```text
lib/domain/models/substitution_shift.dart
```

Shift kinds:

```text
day
night
```

Times:

```text
day
08:00 → 20:00

night
20:00 → 08:00 следующего календарного дня
```

Statistics attribution:

```text
shift полностью относится к дате начала
```

Пример:

```text
31 августа night
→ August

1 сентября day
→ September
```

---

## 18. Undo window

После successful call UI показывает:

```text
<Имя> вызван
[Отменить]
```

Undo window:

```text
6 секунд
```

После окна UI пытается finalization pending call.

Undo обязан:

```text
проверить server-side условия
вернуть queue state, если безопасно
удалить pending call
не начислить statistics
```

Если очередь уже изменилась:

```text
Отмена недоступна: очередь уже изменилась
```

---

## 19. Pending Call

Production path:

```text
spaces/substitution/pendingCalls/{callId}
```

`callId`:

```text
canonical positive integer string
based on monotonic call revision
```

Pending call содержит данные для finalization:

```text
callId
userId
calledByUserId
shift
created/finalization timing data
```

Flow:

```text
call
→ queue mutation
→ pendingCall
→ 6 sec Undo
→ finalization
→ statistics
```

PendingCall также обеспечивает recovery после закрытия приложения.

---

## 20. Exactly-once finalization

Core gateway:

```text
lib/services/spaces/substitution/substitution_call_finalization_firestore_gateway.dart
```

Transaction:

```text
1. read pendingCalls/{callId}
2. missing → false
3. strict map pending
4. determine statistics year
5. read statistics/year_YYYY
6. strict map statistics
7. apply confirmed call
8. write statistics
9. delete pending
10. commit
```

Invariant:

```text
pending exists
→ call can be finalized

pending missing
→ repeated finalize == false
→ no second increment
```

Firestore transaction retry/conflict handling является частью correctness model.

Не переносить finalization в widgets.

---

## 21. Recovery / reconciliation

Relevant:

```text
lib/services/spaces/substitution/substitution_call_reconciliation_service.dart
lib/services/spaces/substitution/substitution_pending_call_firestore_gateway.dart
```

При открытии `"Списка"` manager-level пользователем:

```text
load SpacesAccessRole
→ canManageSubstitution
→ one-shot recovery expired pending calls
```

Algorithm:

```text
one-shot list pendingCalls
→ sort revision/callId
→ locally select expired
→ sequential finalize
```

Rules + transaction остаются authoritative.

Не использовать permanent listener.

Причина:

```text
меньше Firestore reads
для пилота 40–50 пользователей
```

Failure policy:

```text
recovery error
→ screen still opens
→ pending remains
→ next manager/open retries
```

Если реально finalized хотя бы один:

```text
reload statistics
```

Если no-op:

```text
не делать лишний statistics read
```

---

# PART V — STATISTICS

## 22. Production statistics model

Domain:

```text
lib/domain/models/substitution_statistics.dart
```

Document:

```text
spaces/substitution/statistics/year_YYYY
```

Example:

```text
spaces/substitution/statistics/year_2026
```

Fields:

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
→ confirmed August calls

monthShifts["8"][uid]
→ ordered day/night list

yearCallCounts[uid]
→ confirmed yearly calls
```

`lastFinalizedCallId`:

```text
technical/integrity field
not UI
```

`updatedAt`:

```text
server timestamp
```

Public helpers:

```text
callsForMonth(month, userId)
shiftsForMonth(month, userId)
callsForYear(userId)
```

Invalid input returns safe zero/empty result.

---

## 23. Statistics consistency

Relevant:

```text
lib/services/spaces/substitution/substitution_statistics_mapper.dart
lib/services/spaces/substitution/substitution_statistics_accumulator.dart
```

Invariant per month/uid:

```text
monthCallCounts
==
monthShifts.length
```

Year invariant:

```text
yearCallCounts[uid]
==
sum(monthCallCounts[*][uid])
```

Malformed aggregate must not silently become valid state.

---

## 24. Statistics read-side

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

Не использовать:

```text
one read per participant
```

Statistics UI loads current year only if:

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

After successful finalization:

```text
reload once
```

After Undo/no-op finalization:

```text
no extra statistics reload
```

---

## 25. Statistics UI

Widget:

```text
lib/widgets/spaces/substitution/substitution_statistics_summary.dart
```

Overlay:

```text
Статистика
Август                     4
[compact shift segments]
За год                     7
```

Segment semantics:

```text
day   → amber/yellow
night → dark blue
empty → muted
```

Slot capacity:

```text
0–5   → 5
6–9   → 9
10+   → 12
```

Domain stores:

```text
day
night
```

not Flutter colors.

---

## 26. Availability UI

Relevant:

```text
lib/widgets/spaces/substitution/substitution_availability_selector.dart
lib/widgets/spaces/substitution/substitution_availability_style.dart
```

Three options:

```text
colored circle
label
selected state
Semantics / Tooltip
```

Labels:

```text
Всегда готов!
Только в день
Занят
```

Manual UI check выполнен.

---

# PART VI — CLEANUP / RULES

## 27. Obsolete TEST statistics layer

Old temporary statistics prototype удалён.

Не восстанавливать:

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

Production replacement:

```text
SubstitutionStatistics*
```

---

## 28. Firestore Rules

File:

```text
firestore.rules
```

Protected areas:

```text
spaces/substitution
participants
pendingCalls
statistics/year_YYYY
call finalization
manager recovery/list
role-aware writes
```

Manager access is based on Spaces role, not UI visibility.

Owner remains highest role.

Old TEST statistics exception закрыта.

### 28.1 Production deploy history

Предыдущее production Substitution Rules состояние было deployed в:

```text
epistola-434b7
```

Functions/Storage этим deploy не затрагивались.

### 28.2 Current local Rules state

После этого deploy была сделана новая security correction:

```text
member self update
→ only own availability
→ status immutable
```

Эта новая correction:

```text
LOCAL
TESTED
NOT DEPLOYED
```

---

# PART VII — VERIFICATION

## 29. Current checkpoint checks

После текущих navigation + security changes выполнено:

```text
dart.bat format
→ clean
```

Flutter analyzer:

```text
flutter.bat analyze
→ No issues found
```

Flutter full suite:

```text
flutter.bat test
→ 751 tests passed
```

Во время suite возможен известный diagnostic noise:

```text
Corrupt JPEG data...
JPEG datastream contains no image
```

Если final result:

```text
All tests passed!
```

это не считается failure текущего этапа.

Full Firestore Rules suite:

```text
tests 133
suites 9
pass 133
fail 0
```

Firestore Emulator shutdown:

```text
SIGINT
```

после successful script является нормальным завершением emulator.

Release build:

```text
flutter.bat build apk --release
→ SUCCESS
→ build\app\outputs\flutter-apk\app-release.apk
→ 56.8 MB
```

`git diff --check`:

```text
clean
```

Возможно warning:

```text
LF will be replaced by CRLF
```

для `.mjs`.

Это line-ending warning, не `diff --check` error.

---

## 30. Manual scenarios

Substitution scenarios ранее проверены:

```text
normal participant call
Undo before 6 sec
statistics unchanged after Undo
app close before finalization
manager recovery
exactly-once statistics update
remove/reinvite preserving UID statistics
immediate statistics refresh
August/September boundary
availability selector
manager vs self availability
statistics rendering
```

Новый navigation scenario также вручную проверен:

```text
app launch
→ Пространства

bottom nav
→ Контакты | Пространства | Профиль

Пространства
→ Чаты
→ existing chat
→ Back
→ chat list
→ Back
→ Spaces

Контакты
→ Back
→ Spaces

Профиль
→ Back
→ Spaces

Spaces
→ Back
→ app exit
```

Result:

```text
работает
```

---

## 31. Generated plugin files

После последней Flutter-command series были восстановлены:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Они не входят в текущие functional changes.

Не восстанавливать generated plugin files после каждой Flutter-команды.

Правило:

```text
закончить серию Flutter commands
→ restore generated noise один раз
```

---

# PART VIII — CURRENT GIT STATE

## 32. Current branch / HEAD

Последняя подтверждённая точка:

```text
branch:
feat/v0.8.0-spaces-substitution-foundation

HEAD:
bf24968
```

Commit:

```text
bf24968 docs: update v0.8.0 substitution foundation
```

Functional изменения после `bf24968` ещё не committed.

До docs replacement `git status --short`:

```text
 M firestore.rules
 M lib/screens/home_screen.dart
 M lib/screens/spaces_page.dart
 M test/rules/firestore/substitution_space_rules.test.mjs
?? lib/screens/chats_space_screen.dart
```

После замены документации также должны появиться:

```text
 M PROJECT_CONTEXT.md
 M ARCHITECTURE.md
 M README.md
```

Не считать HEAD обновлённым, пока commit реально не выполнен.

Не считать branch pushed после новых изменений, пока push реально не выполнен.

Не считать Rules deployed после новой security correction, пока deploy реально не выполнен.

---

# PART IX — NEXT STEPS / ROADMAP

## 33. Immediate next checkpoint

После замены трёх документов:

```powershell
git diff --check
git status --short
```

Flutter test/build повторно не требуется только из-за docs edits.

Перед commit нужно просмотреть итоговый diff.

Commit выполнять только после explicit approval пользователя.

Possible functional commit scope:

```text
Spaces-first navigation
Chats tile wrapper
member availability security correction
associated Rules tests
```

Docs можно зафиксировать либо вместе с этим checkpoint по решению пользователя, либо отдельным docs commit.

Не решать это автоматически.

---

## 34. Near-term product direction

После текущей фиксации следующим крупным направлением может быть:

```text
SpacesBar / announcements foundation
```

Но перед реализацией нужно отдельно решить:

```text
Firestore schema
active message limits
priority semantics
dismiss behavior
carousel behavior
system notification integration
substitution-call integration
```

Не смешивать это с текущим navigation/security checkpoint.

---

# PART X — NEW CHAT HANDOFF

## 35. Новый чат: обязательный старт

Новый чат сначала выполняет:

```powershell
git branch --show-current
git rev-parse --short HEAD
git status --short
```

После этого читает source текущей ветки.

Не начинать с `main`, если feature branch ещё не merged.

Priority:

```text
current source
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Особенно проверить:

```text
lib/screens/home_screen.dart
lib/screens/spaces_page.dart
lib/screens/chats_space_screen.dart
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
test/rules/firestore/substitution_space_rules.test.mjs
```

Не восстанавливать obsolete TEST statistics files.

Не менять shift month attribution без отдельного product decision.

Не переносить finalization/statistics/security logic в UI.

Не возвращать `Чаты` в root bottom navigation без отдельного product decision.

Не выполнять broad Messenger rename.

Не deploy текущую security correction без явного подтверждения.

---

# PART XI — DEVELOPMENT PROTOCOL

## 36. Protocol to preserve

Работа:

```text
маленькими проверяемыми шагами
```

При изменении нескольких строк:

```text
дать точную замену
```

При большом изменении:

```text
дать файл целиком
```

До functional commit:

```text
manual scenario
→ format
→ analyze
→ tests
→ release build
→ restore generated noise
→ git diff --check
→ git status --short
```

Docs-only edits:

```text
не требуют Flutter build/test без отдельной причины
```

State-changing actions:

```text
commit
push
tag
merge
deploy
branch creation
```

только после явного подтверждения пользователя.

Canonical architecture boundary:

```text
Flutter UI
→ controllers / presentation
→ application services
→ domain models / contracts
→ Firebase gateways / adapters
```

Не переносить в widgets:

```text
Firestore transactions
security authorization
statistics accumulation
rollback/cleanup
Firebase infrastructure logic
```

Design target:

```text
40–50 pilot users
```

Экономить:

```text
Firestore reads
Firestore writes
Storage traffic
listeners
```

Owner всегда остаётся highest-priority role.