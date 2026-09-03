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
| Last functional checkpoint | `769544f` |
| Commit | `feat(spaces): add spaces bar presentation and management` |
| SpacesBar Rules checkpoint | `60966a6` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Platform | Android |

At the current functional checkpoint:

```text
HEAD = origin feature branch = 769544f
working tree was clean after push
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

Empty state:

```text
Нет новых закреплённых сообщений
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

The card uses a clear colored border with a light inward glow.

Pin icon and visible lifetime label were intentionally removed from the message card.

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

Current implementation uses separate `PageView` cards.

Planned later:

```text
one stationary SpacesBar frame
content changes inside the frame
cyclic/infinite swipe without hard end boundary
```

Dots can remain logical current-message indicators.

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

Therefore the same account can hide a message on the phone while still seeing it in the emulator.

Manager editor trash:

```text
delete for all
```

This updates the authoritative Firestore board.

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

Maximum:

```text
3 active messages
```

Reads are one board-document read, not per-message queries.

Writes use Firestore transactions.

---

## SpacesBar Security Rules

Current rules:

```text
signed-in users can get exact board document
list is denied
brigadier/owner can create/update
whole board delete is denied
strict schema/revision/message validation
```

Rules are deployed to production.

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

Latest full checkpoint:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 835 passed

flutter.bat build apk --release
→ SUCCESS
→ 57.4 MB

git.exe diff --check
→ clean
```

Firestore Rules:

```text
SpacesBar targeted: 22/22
full Rules: 155/155
```

Manual testing completed on emulator and physical Android phone.

---

# Next work

Immediate next SpacesBar block:

```text
push integration
exact SpacesBar message targeting from push
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
