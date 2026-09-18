# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Два клиентских представления:

```text
Epistola
→ полноценное Android-приложение

EpiLite
→ Flutter Web / PWA
```

Pilot target:

```text
40–50 users
```

---

# Current development status

| Параметр | Значение |
|---|---|
| Target | `v0.8.0` |
| Stage | `Spaces / Substitution / EpiLite / Calendar / Vacation` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Latest functional checkpoint | `f172ef1` |
| Web chats/performance | `764d3de` |
| Push installation ownership | `67800f0` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Hosting | `https://epistola-434b7.web.app` |

`v0.8.0` всё ещё находится в feature-ветке и не объявлен merged/released.

Docs-only commit может сделать `HEAD` новее `f172ef1`.

---

# Architecture

Core layering:

```text
Flutter UI
→ presentation / screen orchestration
→ controllers / application services
→ domain
→ Firebase gateways / adapters
```

Business transaction invariants остаются ниже UI.

UI role visibility не является security boundary.

Platform capability:

`lib/platform/epistola_platform_capabilities.dart`

---

# Products

## Epistola

Full Android application.

Current scope:

```text
Contacts
Spaces
Chats
Profile
push notifications
avatars/media
Substitution
SpacesBar
Calendar
```

## EpiLite

Lightweight Web/PWA client на той же Flutter/Firebase codebase.

Verified Web scope:

```text
Firebase Auth
Spaces
SpacesBar
Список
Profile/logout
Web avatar replacement
Chats text flow
PWA install
```

Web push:

`not supported`

Known Web gap:

`chat avatars may still fail to render`

---

# Web chats / performance

Checkpoint:

`764d3de — feat(web): enable chats and speed up user loading`

Changes:

```text
supportsChats → Web true
ChatMembersService user loading → parallel
SubstitutionUserCache user loading → parallel
```

Manual Web check:

```text
Chats open
names load quickly
text message sends successfully
```

---

# Spaces

Root navigation:

```text
Контакты | Пространства | Профиль
```

Spaces tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Owner remains highest-priority role.

---

# Substitution / Список

Current foundation includes:

```text
participants
canonical rotation
availability
vacation/sick/removed hidden anchors
participant management
call flow
3-second Undo
pending calls
shiftClaims duplicate-shift protection
exactly-once finalization
statistics
confirmedCall history
personal SpacesBar
push
rotation editor
Firestore Rules
```

Current self-service addition:

```text
ordinary participant may return self:
sick → active
```

Vacation return remains manager-controlled.

---

# Production Substitution hotfix — 2026-09-18

Production call flow failed because:

```text
new APK call transaction required shiftClaims
production Rules were older
```

A transition Firestore ruleset was tested and deployed.

It contains:

```text
shiftClaims support
legacy-compatible old-APK device writes
```

It intentionally does NOT contain:

```text
Vacation Foundation Rules
current repository strict device write lock
```

Production manual verification passed:

```text
Owner called bot
Undo window ≈ 3 sec
bot moved down list
statistics +1
SpacesBar notification received
push received
```

Old APK without Spaces also received push.

---

# Push installation ownership

Canonical invariant:

```text
one installationId
→ one current authenticated user

one user
→ multiple installations allowed
```

Registry:

`pushInstallations/{installationId}`

Callables:

```text
claimPushInstallation
releasePushInstallation
```

Important current split:

```text
repository firestore.rules
→ strict device writes denied

production
→ temporary legacy device write compatibility
```

After the next broad APK rollout, remove legacy compatibility and deploy strict Rules.

---

# Calendar

Current Calendar foundation:

```text
full-screen calendar
selected date centering
month boundary update
selected date red digit
shift labels
Today navigation
full / medium / compact modes
persisted view mode
```

View mode key:

`shift_calendar_view_mode`

Default:

`medium`

Base schedule:

```text
4 crews
8-day cycle
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

Header menu:

```text
Отпуска
Будильники
Темы календаря
```

Handlers пока placeholders.

---

# Vacation Foundation

Checkpoint:

`f172ef1 — feat(calendar): add vacation foundation and calendar settings`

Persistence:

`spaces/calendar/vacationPeriods/{userId}__{slot}`

Schema:

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

Tests explicitly confirm:

```text
slot 6 valid
slot 7 rejected
```

Ownership:

```text
signed-in users may read
user may write/delete only own vacations
no manager special edit
```

Important:

`Vacation Rules are committed locally but are NOT deployed to production yet`

---

# Vacation UX decisions

Calendar is the source of truth.

Vacation is an overlay on immutable base shift schedule.

Future Vacation UI:

```text
actual current/future vacations
+ Добавить отпуск
```

Do not show six empty technical slots.

Planned input formats:

```text
18.09.2026
18.09
18 сентября
18 сентября 2026
```

Omitted year uses current Calendar year.

Cross-year:

```text
20.12 → 10.01
Calendar year 2026
→ 20.12.2026 .. 10.01.2027
```

Visible History screen is not required now.

Storage must eventually preserve historical vacation coloring when technical slots are reused.

History/slot-reuse design is still unresolved.

---

# Calendar overlay direction

Do not rewrite the base 8-day schedule.

Compose:

```text
base shift
+ vacation
+ sick
+ substitution
+ additional shift / халтура
```

This preserves deterministic historical reconstruction.

---

# Verification

Latest functional checkpoint:

`f172ef1`

Flutter:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 1012/1012 passed
```

Targeted:

```text
Vacation Dart → 20/20
SubstitutionConfirmedCallMapper → 12/12
```

Rules:

```text
current local targeted group → 91/91
Vacation Rules → 12/12
```

Production transition predeploy:

```text
call / shiftClaims → 23/23
undo → 5/5
finalize → 11/11
legacy push compatibility → 6/6
```

Generated Flutter plugin files restored after final Flutter command and are not included in functional commits.

---

# Development commands

Flutter:

```powershell
dart.bat format <files>
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat build web
```

Firebase emulator after fresh VS Code/PowerShell session:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Git:

```powershell
git.exe status --short
git.exe diff --check
```

Generated plugin files:

`restore once after final Flutter command`

---

# Current roadmap

Immediate:

```text
Vacation editor
friendly vacation date parser
Calendar vacation coloring/overlay
history-safe slot reuse decision
additional shift / халтура
small Calendar polish
```

Push/security after APK adoption:

```text
remove production legacy device writes
deploy strict repository Rules
audit pushInstallations cleanup for deleted Auth users
```

Other backlog:

```text
Web chat avatar rendering
Spaces Hub settings/layout
legacy *MessageId → presentationId cleanup
Buses after current schedule is obtained
Web push later
```

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

Expected functional checkpoint:

`f172ef1`

Do not use `main` as current `v0.8.0` source until merge/release is explicitly verified.
