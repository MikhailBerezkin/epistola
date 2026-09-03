# Epistola — Architecture

Основной технический документ проекта Epistola.

При конфликте информации использовать порядок:

```text
исходный код текущей ветки
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
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution / SpacesBar Foundation` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `769544f` |
| SpacesBar Rules checkpoint | `60966a6` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Main platform | Android |
| Pilot target | 40–50 users |

Главное направление:

```text
Epistola
→ Spaces launcher
→ internal applications
```

Messenger является одним из внутренних приложений, но его existing chat architecture сохраняется.

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

## 2.1 UI

UI отвечает за rendering, gestures, navigation, dialogs, bottom sheets, loading/error presentation, animations и local visual preferences.

UI не должен:

```text
реализовывать Firestore transaction invariants
быть единственной permission boundary
создавать backend schema из visual state
переносить presentation-only parameters в domain/backend
```

## 2.2 Presentation / screen orchestration

Screen может:

```text
создавать services
загружать data
хранить screen state
координировать local hide
запускать application operations
показывать dialogs/snackbars
```

## 2.3 Application services

Application layer отвечает за permission checks, validation и orchestration.

SpacesBar example:

```text
SpacesBarManagementService
```

## 2.4 Domain

Pure domain содержит semantic state:

```text
SpacesAccessRole
SpacesBarMessage
SpacesBarMessageLifetime
SpacesBarBoard
SpacesBarPublicationReceipt
Substitution domain models
```

Domain не зависит от Flutter widgets, `BuildContext`, `Color`, Firestore transactions или `SharedPreferences`.

## 2.5 Gateways / adapters

Firebase-specific code отвечает за Firestore read/write, transactions, server timestamps и schema mapping.

Local persistence adapter (`SharedPreferences`) не является authoritative business storage.

---

# 3. Infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore: eur3
Realtime Database: europe-west1
Cloud Functions: europe-west1
Android package: com.epistola.app
```

Cost principles:

```text
40–50 pilot users
avoid per-widget Firestore queries
minimize writes
cache reusable role/user data
prefer local presentation state where server authority is unnecessary
```

---

# 4. Root navigation

Root:

```text
lib/screens/home_screen.dart
```

Indexes:

```text
0 Contacts
1 Spaces
2 Profile
```

Default = Spaces.

Back policy:

```text
Contacts → Spaces
Profile → Spaces
Spaces → exit
```

When Spaces is selected root AppBar shows:

```text
Epistola
Пространства
```

`⋮` belongs to global Spaces customization, not SpacesBar manager actions.

---

# 5. Spaces Hub

Screen:

```text
lib/screens/spaces_page.dart
```

Current applications:

```text
Чаты
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

`Чаты` routes to existing Messenger through a thin wrapper.

Do not mass-rename Messenger classes/services.

---

# 6. Adaptive Spaces tiles architecture

Layout should be count-driven.

Modes:

```text
regular: <= 6 active tiles
compact: >= 7 active tiles
```

Regular:

```text
2 columns
icon
title
optional subtitle
```

Compact:

```text
shorter tile height
icon
title
no subtitle
```

For 7–8 tiles target is to keep up to 8 visible without increasing SpacesBar height.

Odd final tile:

```text
span two columns
```

A shorter full-width height may be selected later.

For >8:

```text
vertical scroll
```

Optional continuation hint can be added later.

Spaces customization:

```text
⋮ → show/hide available Spaces → possibly reorder
```

---

# 7. Spaces roles architecture

Domain:

```text
SpacesAccessRole
```

Roles:

```text
member
brigadier
owner
```

Owner remains highest-priority.

Capability:

```text
canManageSpacesBar:
member = false
brigadier = true
owner = true
```

Role lookup:

```text
SpacesAccessService
```

Properties:

```text
UID cache
pending-read coalescing
member fallback if no role
```

UI visibility is not security. Rules protect writes independently.

---

# 8. SpacesBar domain

## 8.1 Message

```text
SpacesBarMessage
```

Fields:

```text
id
text
lifetime
createdByUserId
createdAt
expiresAt (derived)
```

Max text = 250 chars.

## 8.2 Lifetime

```text
oneHour
twelveHours
twentyFourHours
untilCancelled
```

`expiresAt` is derived in domain.

## 8.3 Board

```text
SpacesBarBoard
```

Max active messages = 3.

Board revision is monotonic.

---

# 9. SpacesBar Firestore schema

Authoritative document:

```text
spaces/spacesBar
```

Shape:

```text
schemaVersion: 1
revision: int
messages: {
  <messageId>: {
    text: string
    lifetime: oneHour | twelveHours | twentyFourHours | untilCancelled
    createdByUserId: string
    createdAt: Timestamp
  }
}
updatedAt: Timestamp
```

New message identity:

```text
message id = new board revision as string
```

Do not persist:

```text
Flutter Color
glow radius
font size
carousel page
local hidden state
```

---

# 10. SpacesBar read path

```text
SpacesPage
→ SpacesBarPresentationService
→ SpacesBarBoardFirestoreGateway
→ spaces/spacesBar
```

Local side:

```text
SpacesBarHiddenMessagesPreferences
→ SharedPreferences
```

Then:

```text
SpacesBarVisibleMessagesResolver
→ active
→ remove locally hidden
→ presentation ordering
```

No per-message Firestore reads. Board read is one document read.

---

# 11. Presentation state

`SpacesBarPresentationState` carries:

```text
board
hiddenMessageIds
activeMessages
visibleMessages
```

Important distinction:

```text
activeMessages = authoritative active server messages
visibleMessages = active - local hidden
```

Manager editor therefore can show an active message that local presentation hid.

---

# 12. Local hide architecture

```text
long press
→ Убрать сообщение
→ SharedPreferences
```

Key:

```text
spaces_bar.hidden_message_ids.v1.<uid>
```

Properties:

```text
per user
per device
persistent across restart
no Firestore write
```

The same user on two devices can have different local visibility. This is intended.

If product requirements later require account-wide dismiss, create a new explicit backend design; do not silently change current semantics.

---

# 13. Presentation ordering

Resolver order:

```text
oneHour
→ twelveHours
→ twentyFourHours
→ untilCancelled
```

Equal lifetime:

```text
newer createdAt first
```

Then deterministic message id/revision tie-breaker.

This is presentation ordering, not stored priority.

---

# 14. SpacesBar write path

Manager write entry:

```text
SpacesPage
→ SpacesBarManagementService
→ SpacesBarBoardTransactionGateway
→ Firestore transaction
```

`SpacesBarManagementService` performs application-layer permission gating.

Allowed roles:

```text
brigadier
owner
```

Member fails before gateway invocation.

Firestore Rules independently enforce manager writes.

---

# 15. Publish invariants

Publish transaction:

```text
read document
parse board
resolve UTC now
remove expired from active set
reject if active >= 3
revision + 1
message id = revision
create valid domain message
rewrite board
server timestamps
return publication receipt
```

Concurrent correctness belongs to transaction gateway, not UI.

---

# 16. Global delete invariants

Manager editor:

```text
trash
→ confirmation
→ deleteMessage(messageId)
→ transaction
→ reload board
```

Transaction removes requested message, cleans expired state, increments revision and rewrites board.

Do not use whole-document delete.

---

# 17. Security Rules

Exact board read:

```text
allow get: signedIn()
```

Collection listing:

```text
allow list: false
```

Manager writes:

```text
brigadier / owner
```

Whole document delete:

```text
false
```

Rules validate strict keys, schemaVersion, revision monotonicity, max 3, text 1..250, allowed lifetime, createdByUserId, server timestamps, new id = revision and existing-message constraints.

Tests:

```text
targeted 22/22
full Firestore Rules 155/155
```

Rules are deployed to production.

---

# 18. SpacesBar UI architecture

Main widget:

```text
SpacesBarPanel
```

Height:

```text
141 px
```

Content font:

```text
18 px
```

States:

```text
loading
error + retry
empty
1 message
2–3 messages
```

One message:

```text
no dots
no chevrons
```

2–3 messages:

```text
left/right chevrons
dots bottom-center
horizontal PageView swipe
auto rotation
```

Current interval:

```text
15 seconds
```

Any manual navigation restarts a full interval.

Manager overlay:

```text
pencil bottom-right
```

Member does not get pencil.

---

# 19. Visual semantics

Lifetime → accent:

```text
1h → green
12h → blue
24h → orange
untilCancelled → red
```

Accent is presentation-only.

Current design:

```text
clear outer border
soft inward glow
neutral card background
```

Future tuning target:

```text
glow approximately 7–12 px inward
```

Message card intentionally does not show pin icon or lifetime text.

---

# 20. Current carousel limitation

Current:

```text
PageView pages are separate cards
```

Accepted for current checkpoint.

Future presentation-only refactor:

```text
one stationary outer SpacesBar
→ content changes inside
```

Possible implementation:

```text
GestureDetector / horizontal gesture
AnimatedSwitcher
slide/fade content transition
logical currentIndex
```

No changes required to Firestore/domain/management/local hide/15-second policy.

Also deferred:

```text
finite PageView → infinite/cyclic swipe
```

Dots can remain based on logical modulo index.

---

# 21. SpacesBar editor

Widget:

```text
SpacesBarEditorSheet
```

Outputs publish/delete actions.

Form:

```text
multiline text
250 char limit
lifetime dropdown
publish button
```

At 3/3 publish form is replaced by capacity notice. Transaction and Rules remain authoritative enforcement.

---

# 22. Substitution architecture

Main screen:

```text
lib/screens/substitution_space_screen.dart
```

v0.8.0 includes participant/queue/call/recovery/statistics foundations.

Important principles:

```text
owner highest
transaction correctness below UI
recovery/retry-safe operations
no obsolete TEST statistics in production path
```

SpacesBar should not manually duplicate Substitution business events in long-term architecture.

---

# 23. Future multi-channel event architecture

Desired later design:

```text
business event
→ push
→ SpacesBar
→ optional system notification surface
```

A Substitution call should eventually be one business event projected into multiple presentation channels, not unrelated records.

---

# 24. Verification

Current functional checkpoint:

```text
flutter analyze: clean
Flutter tests: 835 passed
release APK: 57.4 MB
diff check: clean
```

Manual emulator:

```text
publish
delete
3/3
carousel
colors
15-sec timer
```

Manual phone:

```text
member permission UI
local hide persistence
per-device semantics
```

---

# 25. Near-term roadmap

Next SpacesBar engineering block:

```text
push integration
exact message targeting/selection from push
```

Deferred UI polish:

```text
stationary frame with internal content transition
infinite/cyclic swipe
glow tuning
```

Deferred Spaces Hub:

```text
⋮ active tile configuration
regular/compact tile modes
>8 continuation behavior
```
