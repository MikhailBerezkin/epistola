# Epistola — Architecture

Основной технический документ проекта Epistola.

При конфликте информации:

```text
исходный код текущей feature-ветки
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` хранит operational handoff/current checkpoint.

`ARCHITECTURE.md` фиксирует устойчивые технические решения.

`README.md` предназначен для краткого обзора.

---

# 1. Status

| Параметр | Значение |
|---|---|
| Current target | `v0.8.0` |
| Stage | `Spaces / Substitution / EpiLite / Calendar / Vacation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Latest functional checkpoint | `f172ef1` |
| Web chats/performance checkpoint | `764d3de` |
| Push installation ownership | `67800f0` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Full platform | Android / `Epistola` |
| Lightweight Web/PWA | `EpiLite` |
| Pilot target | 40–50 users |

`v0.8.0` ещё не declared merged/released.

Docs-only commit может сделать `HEAD` новее `f172ef1`.

---

# 2. Canonical layers

```text
Flutter UI
    ↓
Presentation / Screen orchestration
    ↓
Controllers / Application Services
    ↓
Domain Models / Contracts
    ↓
Firebase Gateways / Adapters
    ↓
Firebase
```

UI owns:

```text
rendering
gestures
navigation
dialogs
loading/error states
animations
local visual preferences
responsive layout
platform-specific presentation branching
```

UI не должен владеть:

```text
Firestore transaction invariants
authoritative security
server ownership invariants
backend schema derived from visual state
role authorization copied into widgets
```

Application services владеют orchestration/validation.

Gateways/adapters владеют Firebase reads/writes, snapshots, mapping and transactions.

Domain не должен зависеть от Flutter visual state.

---

# 3. Firebase infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore: eur3
Realtime Database: europe-west1
Cloud Functions: europe-west1
Functions runtime: Node.js 22
Android package: com.epistola.app
Hosting: https://epistola-434b7.web.app
```

Pilot principles:

```text
40–50 users
avoid per-widget Firestore reads
parallelize independent reads
cache reusable user/role data by UID
keep presentation state local when server authority is unnecessary
persist reorder only on Apply
reuse canonical business events for multiple projections
```

---

# 4. Platform capability boundary

Centralized in:

`lib/platform/epistola_platform_capabilities.dart`

Critical separation:

```text
platform capability
≠ business authorization
≠ Firestore security
```

Current policy:

```text
supportsPushNotifications
→ Android true
→ Web false

supportsChats
→ Android true
→ Web true
```

Web text chat теперь intentionally enabled и manually verified.

Known Web presentation gap:

```text
chat avatars may fail to render
```

Это не backend/security failure.

---

# 5. Runtime Test Mode boundary

File:

`lib/platform/epistola_runtime_mode.dart`

Enable:

```powershell
flutter.bat run --dart-define=EPISTOLA_TEST_MODE=true
```

Titles:

```text
Android → Epistola Test
Web → EpiLite Test
```

Current safety scope остаётся узким.

Invariant:

```text
Test Mode != full Firebase sandbox
```

Не считать unrelated Firebase/FCM writes изолированными, если они явно не guarded.

---

# 6. Products

```text
Epistola
→ Android full client

EpiLite
→ Flutter Web / PWA
```

Shared backend:

```text
Firebase Auth
Firestore
Firebase Storage where supported
Cloud Functions where applicable
```

Не создавать отдельные business collections только ради Web presentation.

Web push пока unsupported.

---

# 7. Web user loading

Current optimization:

```text
ChatMembersService
SubstitutionUserCache
```

Independent user fetches:

```text
Future.wait
```

вместо последовательных `await` loops.

Цель:

```text
reduce perceived latency
avoid serialized network round trips
keep same data contract
```

Это client performance optimization, не schema change.

---

# 8. Root navigation

Root:

`lib/screens/home_screen.dart`

Indexes:

```text
0 Contacts
1 Spaces
2 Profile
```

Default:

`Spaces`

Back:

```text
Contacts → Spaces
Profile → Spaces
Spaces → exit
```

Messenger остаётся:

```text
Spaces → Чаты
```

---

# 9. Spaces roles

Roles:

```text
member
brigadier
owner
```

`owner` — highest priority.

Substitution managers:

```text
brigadier
owner
```

SpacesBar managers:

```text
brigadier
owner
```

UI visibility не является security boundary.

---

# 10. SpacesBar domain/backend

Authoritative document:

`spaces/spacesBar`

Schema v1:

```text
revision
messages
updatedAt
```

Capacity:

`3 active general messages`

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Не persist presentation-only state:

```text
Color
glow
carousel page
local hide state
```

Local hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

---

# 11. SpacesBar presentation

Current UI contract:

```text
stationary neutral outer frame
colored inner glow near frame
neutral center
true cyclic/infinite PageView
manual drag interpolates glow
auto rotation uses same PageController
```

Timing:

```text
dwell = 10 sec
slide = 1000 ms
```

Personal substitution items merge into the same presentation model but do not consume general `3/3`.

---

# 12. Substitution participant model

Path:

`spaces/substitution/participants/{userId}`

Statuses:

```text
active
vacation
sick
removed
```

Canonical rotation содержит active и inactive participants.

Inactive statuses сохраняют hidden `rotationOrder` anchors.

Это предотвращает priority gaming через remove/re-add или временную inactive state.

`removed` — soft membership removal.

---

# 13. Substitution gateway separation

Сохранять отдельные write contracts:

```text
SubstitutionParticipantStateFirestoreGateway
SubstitutionRotationMembershipFirestoreGateway
SubstitutionRotationEditFirestoreGateway
SubstitutionCallFirestoreGateway
```

Не объединять разные transaction invariants в generic gateway.

---

# 14. Rotation editor

Editing local until Apply.

Apply:

```text
read canonical state
validate revision/conflict
normalize rotationOrder
persist atomically
```

Conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# 15. Call transaction with shiftClaims

Current call architecture:

`spaces/substitution/shiftClaims/{claimId}`

Purpose:

```text
one concrete work shift
→ cannot be called twice
```

Atomic call transaction:

```text
pendingCalls/{callId}
shiftClaims/{claimId}
participants/{userId}.rotationOrder
spaces/substitution revision/lastCall/nextRotationOrder
```

Rules требуют linked pendingCall + shiftClaim.

Standalone pendingCall/shiftClaim invalid.

Existing claim rejects duplicate call.

---

# 16. Undo semantics

Current undo window:

`3 seconds`

Domain source:

`SubstitutionPendingCall.undoWindow`

Undo valid только before deadline.

Atomic undo:

```text
delete pendingCall
delete shiftClaim
restore participant rotation
restore allowed module state
```

Confirmed-call mapper:

```text
< 3 sec finalize → invalid
exact 3 sec boundary → valid
```

---

# 17. Finalization / exactly-once

Transaction:

```text
read pendingCall
validate expiry
calculate statistics
write/update statistics
write immutable confirmedCall
delete pendingCall
```

Exactly-once protected by pendingCall deletion in same transaction.

Confirmed event:

`spaces/substitution/confirmedCalls/{callId}`

Confirmed calls immutable.

---

# 18. Statistics

Finalization updates statistics exactly once.

Production verification:

```text
called participant
→ +1 shift statistic
→ participant moved to queue bottom
```

Counters must remain tied to authoritative finalize transaction.

---

# 19. Self-return from sick

Current repository rule:

```text
ordinary participant:
own sick → active
```

Нельзя менять:

```text
rotationOrder
another participant
unrelated fields
```

Vacation remains separate:

```text
vacation → active
→ manager-controlled
```

Это repository change, не production transition hotfix.

---

# 20. Push deep links

Types:

```text
chat
spacesBar
```

Unified field:

`spacesBarPresentationId`

Values:

```text
general:<messageId>
substitution:<callId>
```

Legacy internal `*MessageId` names остаются compatibility debt.

---

# 21. Push installation ownership

Stable identity:

`SharedPreferences → push_installation_id`

Format:

```text
16 secure random bytes
→ 32 lowercase hex
```

Invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installationIds
```

FCM token — delivery address, не installation identity.

---

# 22. Canonical push registry

Path:

`pushInstallations/{installationId}`

Schema v2:

```text
schemaVersion
userId
token
platform
updatedAt
```

Legacy `ownerUserId` читается только для migration.

---

# 23. Push callable ownership API

Functions:

```text
claimPushInstallation
releasePushInstallation
```

Region:

`europe-west1`

Auth source:

`callableRequest.auth.uid`

New client:

```text
auth state → claim
token refresh → claim
logout/unregister → release
```

---

# 24. Production device-rule migration state

Repository target:

```text
users/{uid}/devices/{deviceId}

read own → allowed
client create/update/delete → denied
```

Cloud Functions use Admin SDK.

Production currently runs temporary compatibility:

```text
legacy old APK
→ create/update/delete own device doc allowed
→ exact token/platform/updatedAt schema
```

Reason:

`some active users still use old APKs`

После следующего broad rollout compatibility нужно удалить.

---

# 25. Production Rules vs repository Rules

Current split:

```text
production
→ transition rules
→ shiftClaims enabled
→ legacy device writes temporarily enabled
→ Vacation rules absent

repository firestore.rules
→ shiftClaims enabled
→ strict device ownership
→ self-return sick→active
→ Vacation Foundation rules
```

Поэтому:

```text
DO NOT blindly deploy repository firestore.rules
```

Каждый будущий deploy должен явно фиксировать intended ruleset.

---

# 26. Calendar base schedule

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

Base schedule immutable/deterministic.

Exceptions = overlays.

---

# 27. Calendar presentation modes

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
```

Default:

`medium`

Crew + mode load before main render.

Selected date digit → red.

Selected date drives header and future `Дела`.

---

# 28. Calendar navigation

Supports:

```text
target date centering
swipe navigation
correct month title across month boundary
Today navigation
```

Today:

```text
PageController
_goToToday()
```

Phone swipe feel may still receive tuning.

---

# 29. Calendar overflow actions

Header `⋮`:

```text
Отпуска
Будильники
Темы календаря
```

Handlers currently placeholders.

Menu should route to feature orchestration, not own persistence.

---

# 30. Calendar overlay architecture

Effective day:

```text
baseShift
+ vacationOverlay
+ sickOverlay
+ substitutionOverlay
+ additionalShiftOverlay
```

Нельзя переписывать base 8-day cycle для exceptions.

Нужно позже явно определить overlay priority при конфликтах.

---

# 31. VacationPeriod domain

Persistence:

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

Date storage:

`YYYYMMDD integer`

Document ID:

`<userId>__<slot>`

Mapper rejects malformed schema/date/id/slot.

---

# 32. Vacation slot capacity

Current technical capacity:

`1..6`

Boundary:

```text
slot 6 valid
slot 7 rejected
```

Slots — persistence capacity only.

UI не должен показывать шесть постоянных empty slots.

---

# 33. Vacation ownership Rules

Signed-in:

```text
get/list vacationPeriods → allowed
```

Write:

```text
user create/update/delete only own vacation period
```

No manager override.

Validation:

```text
exact field set
schemaVersion = 1
valid userId
slot 1..6
valid YYYYMMDD
endDay >= startDay
updatedAt timestamp
updatedAt == request.time
document ID matches userId + slot
```

---

# 34. Vacation semantics

Calendar = source of truth.

Vacation = date-range overlay, не participant status history.

Desired editor:

```text
show actual current/future vacations
show "+ Добавить отпуск"
hide empty technical slots
```

После последнего vacation day:

```text
со следующего дня item исчезает из current/future editor
```

Но historical Calendar coloring должен сохраниться.

Delete = correction/cancellation and removes coloring.

Natural completion не должна стирать history.

---

# 35. History / slot reuse unresolved invariant

Six slots нельзя автоматически recycle простым overwrite, если прошлые месяцы должны реконструировать vacation history.

Перед recycling определить один из вариантов:

```text
archive collection
append-only history
slot generation/version
separate current index + historical records
```

Visible History screen сейчас не нужен.

Storage history и UI history — разные вопросы.

---

# 36. Friendly vacation date input — planned

Desired:

```text
18.09.2026
18.09
18 сентября
18 сентября 2026
```

No year:

`use currently opened Calendar year`

Cross-year:

```text
20.12 → 10.01
Calendar year 2026
→ 20.12.2026 .. 10.01.2027
```

Parser/editor not implemented yet.

---

# 37. Performance/read discipline

Examples:

```text
pagination page size = 20
central unread summary
UID caches
Future.wait for independent user loads
local-only presentation preferences
```

Avoid:

```text
one Firestore stream per decorative widget
serial independent reads
server writes for local UI state
```

---

# 38. Deleted Auth user cleanup

Existing cleanup:

```text
users/{uid}
users/{uid}/devices/*
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Follow-up:

`pushInstallations/{installationId}`

whose `userId` points to deleted user.

---

# 39. Buses boundary

Known naming:

```text
Управление
Медпункт
Раздевалка
Автово
```

Two buses run cyclically.

Weekday/weekend service differs.

Old schedule is not authoritative enough; wait for newer confirmed schedule.

---

# 40. Verification discipline

Flutter:

```text
dart.bat format
flutter.bat analyze
targeted tests
full flutter.bat test at checkpoint
```

Rules:

```text
targeted emulator tests
relevant full group before deploy
```

Production Rules deploy:

```text
identify exact ruleset
verify no unintended local feature enters deploy
deploy only after explicit approval
```

Generated plugin files:

`restore once after final Flutter command`

---

# 41. Windows encoding discipline

`Set-Content -Encoding utf8` may prepend BOM:

`EF-BB-BF`

Firestore Rules compiler can reject it at L1:1.

Preferred no-BOM:

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

---

# 42. Current verification evidence

Latest functional checkpoint:

`f172ef1`

Flutter:

```text
analyze → clean
full test → 1012/1012
Vacation targeted → 20/20
confirmed-call mapper → 12/12
```

Rules:

```text
current local group → 91/91
Vacation Rules → 12/12
```

Production transition predeploy:

```text
call/shiftClaims → 23/23
undo → 5/5
finalize → 11/11
legacy push → 6/6
```

Manual production:

```text
Owner call works
3 sec undo observed
participant moves down
statistics +1
SpacesBar received
push received
old APK without Spaces also received push
```

---

# 43. Next architecture focus

Immediate:

```text
Vacation editor orchestration
friendly date parsing
Calendar vacation overlay
safe history/slot reuse design
```

Then:

```text
additional shift / халтура overlay
Calendar polish
```

Security migration:

```text
after next APK rollout
→ remove legacy production device writes
→ deploy strict repository Rules
```

Technical debt:

```text
Web chat avatars
pushInstallations cleanup
legacy *MessageId names
```
