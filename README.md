# Epistola

Корпоративная Flutter/Firebase платформа для коммуникации и внутренних приложений компании.

Epistola развивается из messenger-first приложения в единый Android workspace:

```text
communication
+
internal Spaces
+
work services
```

Pilot target:

```text
40–50 users
```

---

## Current development status

| Параметр | Значение |
|---|---|
| Target | `v0.8.0` |
| Stage | `Spaces / Substitution / SpacesBar Foundation` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `123cda1` |
| Commit | `feat(spaces): add realtime spaces bar notifications` |
| SpacesBar Rules checkpoint | `60966a6` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Platform | Android |

After the functional push:

```text
HEAD = origin feature branch = 123cda1
working tree = clean
```

`v0.8.0` is still a feature-branch target and has not yet been declared merged/released.

---

# Architecture

Core layering:

```text
Flutter UI
→ presentation / screen orchestration
→ application services
→ domain
→ Firebase gateways / adapters
```

Business transaction invariants stay below UI.

UI role visibility is not the security boundary.

Presentation-specific colors/layout are not persisted as domain data.

---

# Root navigation

Current root:

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Chats are an internal Space:

```text
Пространства
→ Чаты
→ existing Messenger
```

Messenger internals remain chat/Messenger architecture.

SpacesBar push opens a temporary Spaces route with an exact message target; normal root Back behavior remains separate.

---

# Current Spaces Hub

Tiles:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Header when Spaces is selected:

```text
Epistola
Пространства
```

`⋮` is reserved for future Spaces tile configuration.

Current six-tile layout remains unchanged.

---

# SpacesBar

SpacesBar is implemented above the tile grid.

Current height:

```text
141 px
```

Current message font:

```text
18 px
```

Maximum active messages:

```text
3
```

Lifetimes:

```text
1 hour
12 hours
24 hours
until cancelled
```

Visual accents:

```text
1h → green
12h → blue
24h → orange
until cancelled → red
```

Lifetime controls expiry/accent, not current presentation priority.

Current message order:

```text
newest createdAt first
→ id/revision descending tie-breaker
```

---

## SpacesBar realtime

The main Spaces screen listens to the single authoritative board document:

```text
spaces/spacesBar
```

Flow:

```text
Firestore snapshot
→ active messages
→ current local hidden ids
→ newest-first resolver
→ SpacesBarPanel
```

Manual two-device verification:

```text
publish/delete on manager device
→ already-open member phone updates automatically
```

No per-message Firestore queries are used.

---

## SpacesBar carousel

For one visible message:

```text
no chevrons
no dots
```

For two or three:

```text
left/right chevrons
dots
horizontal swipe
automatic rotation
```

Current auto-rotation:

```text
15 seconds
```

Manual swipe/chevron navigation resets the interval.

Current implementation uses separate finite `PageView` cards.

Planned later:

```text
one stationary SpacesBar frame
content changes inside the frame
cyclic/infinite swipe without hard end boundary
```

---

## SpacesBar roles

Roles:

```text
member
brigadier
owner
```

Manager pencil:

```text
brigadier → yes
owner → yes
member → no
```

Owner remains highest priority.

---

## SpacesBar editor

Manager editor supports:

```text
active count N/3
active message list
delete for all
multiline text
250 chars
lifetime selection
publish
```

At `3/3` the publish form is hidden until one message is deleted.

---

## Local hide vs global delete

Long press:

```text
Убрать сообщение
```

This is local-only and stored in `SharedPreferences`.

Properties:

```text
per user
per device
survives app restart
no Firestore write
```

Manager editor trash performs authoritative delete-for-all.

---

## SpacesBar backend

Firestore document:

```text
spaces/spacesBar
```

Schema version:

```text
1
```

Board stores:

```text
revision
messages
updatedAt
```

Message stores:

```text
text
lifetime
createdByUserId
createdAt
```

Writes use Firestore transactions.

Rules are deployed to production.

---

# SpacesBar push notifications

Functional checkpoint `123cda1` adds full SpacesBar push integration.

Remote deep link:

```text
deepLinkType = spacesBar
spacesBarMessageId = <id>
```

Existing chat deep links remain backward-compatible.

Android notification channel:

```text
epistola_spaces_bar_v1
```

Behavior:

```text
high priority
seagull_notification sound
vibration
announcement preview
```

Cloud Function:

```text
sendSpacesBarNotification
europe-west1
Node.js 22
2nd Gen
```

Trigger:

```text
onDocumentWritten("spaces/spacesBar")
```

Only one newly published valid message generates a push.

No push for:

```text
delete-only
existing-message update
malformed/multi-add write
```

Publisher tokens are excluded by `createdByUserId`.

Invalid FCM token records are cleaned after multicast failures.

---

## Exact push target

If several SpacesBar notifications are pending:

```text
push №9
push №10
tap push №9
→ message №9 must open
```

A newer realtime snapshot must not override the explicit push target while the user remains on that target.

This scenario has a regression widget test and passed manual physical-device verification.

---

## Manual push verification

Verified on physical Android device for a `member`:

```text
push received
seagull sound
vibration
works with screen off
tap opens Spaces
correct target announcement shown
```

The earlier missing vibration on Poco F6 was traced to device settings, not Epistola.

Backward-compatibility note:

```text
older Epistola installs can still receive the new FCM push
because their registered device token remains in backend
```

If rollout later requires it, recipient filtering can be extended with client version/capability metadata.

---

# Future Spaces tile behavior

Agreed product direction:

```text
<= 6 active tiles
→ regular layout with subtitles

7–8 active tiles
→ compact shorter layout
→ subtitles hidden

odd count
→ last tile spans full width

> 8 active tiles
→ vertical scroll
→ optional subtle continuation indicator
```

SpacesBar height stays fixed.

`⋮` will later control visible Spaces and may also support ordering.

---

# "Список" / Substitution

`"Список"` is the main production work module being developed in v0.8.0.

Foundation already includes:

```text
participants
rotation queue
availability
vacation/sick status
participant management
work display name
call participant flow
Undo
pending call persistence
exactly-once finalization
recovery
monthly/yearly statistics
Firestore Rules
```

Owner remains highest-priority.

---

# Existing Messenger foundations

Private chats:

```text
text
images
pagination
logical delete
push deep links
read receipts
typing
active-chat notification suppression
avatar/user card
notification controls
```

Group chats:

```text
roles
owner protection
avatars
push deep links
reactions
identity/member cards
notification controls
```

Notifications:

```text
FCM
custom sound
vibration
image preview
channels
active-chat suppression
```

---

# Current verification

Latest functional checkpoint:

```text
123cda1 feat(spaces): add realtime spaces bar notifications
```

Checks:

```text
flutter.bat test
→ 849 passed

flutter.bat analyze
→ No issues found

git diff check
→ clean

release APK
→ SUCCESS
→ latest recorded size 57.5 MB

SpacesBar notification helper
→ 7/7

Functions lint
→ no errors

SpacesBar Rules
→ 22/22 targeted

full Firestore Rules
→ 155/155
```

Manual testing completed on emulator and physical Android devices.

---

# Next work

The previous immediate SpacesBar block is complete:

```text
realtime sync
newest-first order
push integration
exact message targeting
production function deploy
```

Deferred presentation-only work:

```text
stationary SpacesBar frame with internal transition
infinite cyclic swipe
glow tuning
```

Deferred Spaces Hub work:

```text
⋮ tile configuration
regular/compact layout switching
>8 tile scroll hint
```

For full operational handoff read:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
```

Before new work, confirm current branch/HEAD/status and inspect current source first.
