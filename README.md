# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Проект сейчас имеет два клиентских представления одной платформы:

```text
Epistola
→ полноценное Android-приложение

EpiLite
→ облегчённая Flutter Web / PWA версия
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
| Stage | `Spaces / Substitution / SpacesBar / EpiLite Web Lite` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `a488c3b` |
| EpiLite Web Lite | `a488c3b` |
| Chats unread summary | `f0a2084` |
| Substitution list editor | `85238a2` |
| Deleted-user cleanup | `e7ac582` |
| Android launcher icon | `544fcaf` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Android product | `Epistola` |
| Web/PWA product | `EpiLite` |
| Hosting | `https://epistola-434b7.web.app` |

`v0.8.0` is still a feature-branch target and has not yet been declared merged/released.

A later docs-only commit may make `HEAD` newer than `a488c3b`.

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

Business transaction invariants stay below UI.

UI role visibility is not the security boundary.

Presentation-only state should not be persisted as authoritative backend data.

Platform availability is centralized through:

```text
lib/platform/epistola_platform_capabilities.dart
```

---

# Products

## Epistola

Full Android application.

Current Android scope includes:

```text
Contacts
Spaces
Chats
Profile
push notifications
avatars/media
Substitution
SpacesBar
technical history
```

Android branding remains:

```text
Epistola
```

## EpiLite

Lightweight Web/PWA client built from the same Flutter/Firebase codebase.

Public URL:

```text
https://epistola-434b7.web.app
```

Current verified Web Lite scope:

```text
Firebase Auth
Spaces root
SpacesBar
Список
Profile/logout path
PWA install
```

Current intentional limitations:

```text
Chats
→ Android only

Web push
→ not implemented yet
```

The installed PWA name and branding are:

```text
EpiLite
light-blue gull icon
```

---

# Current root navigation

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Android Chats remain an internal Space:

```text
Пространства
→ Чаты
→ existing Messenger
```

In EpiLite:

```text
Чаты
→ Доступно в Android
```

The Web client does not start the chat unread stream while Chats are disabled.

---

# Current Spaces Hub

Tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Working Android applications:

```text
Чаты
Список
```

Working EpiLite application:

```text
Список
```

Current placeholders:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Planned next application foundations include:

```text
Календарь смен
Автобусы
```

Their product/data contracts must be defined before implementation rather than inferred from placeholder tiles.

---

# Chats unread badge

Checkpoint:

```text
f0a2084
feat(spaces): add chats unread badge
```

Unread state is centralized in:

```text
ChatUnreadSummaryController
```

It owns a shared user-chat stream and avoids one Firestore unread query per tile.

Manual scenario:

```text
0 → 1 → 2 → 1 → 0
```

Web does not create this controller while Chats are disabled.

---

# "Список" / Substitution

Current foundation includes:

```text
participants
canonical rotation queue
availability
vacation/sick hidden slots
removed hidden membership slots
participant management
new-participant one-time top priority
restore at saved hidden anchor
work display name
call flow
Undo
pending-call persistence
recovery
exactly-once finalization
monthly/yearly statistics
confirmedCall event
personal SpacesBar
Epistola technical history
confirmed-call push
atomic list editor
Firestore Rules
```

Owner remains highest priority.

EpiLite uses the same domain/service/Rules authorization as Android.

---

# Participant membership semantics

Participant statuses:

```text
active
vacation
sick
removed
```

Vacation, sick and removed participants remain in the canonical rotation.

Normal:

```text
Удалить из списка
```

means:

```text
status = removed
```

not physical participant-document deletion.

A truly new participant receives one-time priority at the top.

A previously removed participant is restored at the current hidden canonical anchor and does not regain top priority.

This prevents remove/re-add from gaming the queue.

---

# Rotation list editor

Available to:

```text
brigadier
owner
```

Entry:

```text
Список
→ Настройки
→ Режим редактирования списка
```

Editing is local until Apply:

```text
↑ / ↓
→ local draft only
→ 0 Firestore reorder writes
```

Inactive vacation/sick/removed slots stay fixed while active participants move around them.

Apply:

```text
atomic Firestore transaction
normalize canonical participant rotationOrder to 0..N-1
write only changed rotationOrder fields
preserve unrelated concurrent state where allowed
advance monotonic mutation marker
```

Conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

Cancel discards the draft without writes.

---

# Responsive Substitution rows

The participant row was adjusted for narrow Web widths.

Current shared row keeps:

```text
queue badge
participant text
Вызвать
⋮
statistics
```

without relying on a `ListTile.trailing` layout that overflowed in Web.

Manual Android regression was verified after the change.

---

# Substitution gateway split

Participant writes are intentionally separated:

```text
SubstitutionParticipantStateFirestoreGateway
→ ordinary state operations

SubstitutionRotationMembershipFirestoreGateway
→ add / restore / soft remove

SubstitutionRotationEditFirestoreGateway
→ atomic whole-list reorder
```

The separation keeps transaction invariants below UI and independently testable.

---

# Deleted Auth user cleanup

Backend Auth-delete cleanup removes:

```text
users/{uid}
device token documents
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Historical/business data remains:

```text
confirmedCalls
statistics
chats
messages
```

Ordinary single-user deletion was verified in production.

Bulk Admin SDK `deleteUsers([...])` may require a separately verified cleanup path.

---

# General SpacesBar

Authoritative board:

```text
spaces/spacesBar
```

Manager roles:

```text
brigadier
owner
```

General announcement capacity:

```text
3 active messages
```

Lifetimes / accents:

```text
1h → green
12h → blue
24h → orange
until cancelled → red
```

General local hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

No Firestore write is performed for local hide.

SpacesBar works in both Android Epistola and current EpiLite, with the same role rules.

---

# Personal substitution SpacesBar

Successful call finalization creates:

```text
spaces/substitution/confirmedCalls/{callId}
```

Finalization:

```text
update statistics
create confirmedCall
delete pendingCall
```

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Personal calls do not consume general `3/3` capacity.

A personal call remains active until shift start:

```text
day → 08:00 local
night → 20:00 local
```

Personal local hide:

```text
spaces_bar.hidden_substitution_call_ids.v1.<uid>
```

Confirmed-call history remains after the SpacesBar item expires.

---

# Unified SpacesBar push target

Typed push model supports:

```text
chat
spacesBar
```

Unified field:

```text
spacesBarPresentationId
```

Values:

```text
general:<messageId>
substitution:<callId>
```

Backward compatibility remains for:

```text
chatId
legacy spacesBarMessageId
```

Some old internal `*MessageId` names still carry presentation IDs. They remain compatibility debt and should be cleaned in a dedicated technical block.

---

# Push

Android push infrastructure remains active.

SpacesBar Android channel:

```text
epistola_spaces_bar_v1
```

Substitution confirmed call push is generated from the canonical `confirmedCalls` event.

Current EpiLite policy:

```text
Web push disabled
```

Web does not initialize Android/local notification infrastructure.

A business action performed in EpiLite can still cause an Android device to receive an existing FCM push.

---

# EpiLite PWA / Hosting

Hosting config:

```text
firebase.json
public = build/web
SPA rewrite → /index.html
```

Build:

```powershell
flutter.bat build web
```

Deploy:

```powershell
firebase.cmd deploy --only hosting
```

Always build Web before deploy.

PWA identity:

```text
name = EpiLite
short_name = EpiLite
id = /epilite
start_url = /
scope = /
```

Runtime assets:

```text
web/favicon.png
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
```

Branding source artwork:

```text
design/branding/
```

---

# Development / test commands

Flutter:

```powershell
dart.bat format <files>
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat build web
```

Local Web:

```powershell
flutter.bat run -d chrome --web-port 57097
```

Hosting:

```powershell
firebase.cmd deploy --only hosting
```

Git:

```powershell
git status --short
git diff --check
```

Generated plugin files should be restored once after the final Flutter command in a series.

---

# Latest verification

Checkpoint:

```text
a488c3b
feat(web): add EpiLite web client
```

Flutter:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 978 tests passed

flutter.bat build web
→ SUCCESS

flutter.bat build apk --release
→ SUCCESS
→ 58.4 MB
```

Manual:

```text
EpiLite PWA installed
→ name correct
→ icon correct
→ Web title correct
→ authentication works
→ member and privileged accounts checked
→ SpacesBar works
→ Список works
→ Chats blocked as Android-only

Android regression
→ Epistola branding preserved
→ Spaces works
→ Chats works
→ Список works
→ participant controls render correctly
→ SpacesBar role management preserved
```

---

# Branding assets

Source files are kept out of the project root:

```text
design/branding/Аватар EpiLite.png
design/branding/Аватар Чайки.png
design/branding/Аватар Чайки трафарет.png
```

Runtime application assets remain in their platform/feature paths.

---

# Roadmap

Completed:

```text
Chats unread summary
EpiLite Web Lite / PWA foundation
```

Next priority unless reprioritized:

```text
1. SpacesBar UI
   stationary outer frame
   true cyclic/infinite swipe
   glow tuning

2. Spaces Hub UI/settings
   ⋮
   show/hide Spaces
   regular/compact layout
   7–8
   >8
   odd final tile

3. legacy *MessageId → presentationId cleanup

4. FCM token lifecycle investigation

5. Calendar foundation

6. Buses foundation
```

Possible later EpiLite phases:

```text
Web push
Chats on Web
explicit Contacts support
full responsive parity
```

---

# Documentation workflow

Current source of truth priority:

```text
source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

For the three root docs:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

the preferred replacement workflow is:

```text
assistant prepares all three full files
→ packs them into one ZIP
→ user extracts ZIP
→ root copies replace the three current files
```

This avoids manual section-by-section patching.

---

# New-chat checklist

Before continuing work:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Expected latest functional checkpoint for this block:

```text
a488c3b
feat(web): add EpiLite web client
```

Do not use `main` as the current `v0.8.0` state until merge/release is explicitly verified.
