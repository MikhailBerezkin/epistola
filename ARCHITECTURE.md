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
| Last functional checkpoint | `123cda1` |
| Functional commit | `feat(spaces): add realtime spaces bar notifications` |
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

Messenger является одним из внутренних приложений, но existing chat architecture сохраняется.

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
подписываться на streams
хранить screen state
координировать local hide
запускать application operations
показывать dialogs/snackbars
```

## 2.3 Application services

Application layer отвечает за permission checks, validation и orchestration.

SpacesBar examples:

```text
SpacesBarPresentationService
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
PushDeepLinkRequest / PushDeepLinkTargetType
Substitution domain models
```

Domain не зависит от Flutter widgets, `BuildContext`, `Color`, Firestore transactions или `SharedPreferences`.

## 2.5 Gateways / adapters

Firebase-specific code отвечает за Firestore read/write, snapshots, transactions, server timestamps и schema mapping.

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

Root Back policy:

```text
Contacts → Spaces
Profile → Spaces
Spaces → exit
```

Push-created SpacesBar route uses:

```text
HomeScreen(
  spacesBarTargetMessageId: ...,
  allowRoutePop: true,
)
```

This is intentionally different from normal root `HomeScreen(allowRoutePop: false)`.

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

Lifetime is used for:

```text
expiry
visual accent
```

Lifetime is NOT current presentation priority.

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
push delivery state
```

---

# 10. SpacesBar realtime read path

Current path:

```text
SpacesPage
→ SpacesBarPresentationService.watch(userId)
→ SpacesBarBoardFirestoreGateway.watch()
→ snapshots() on spaces/spacesBar
```

Local side:

```text
SpacesBarHiddenMessagesPreferences
→ SharedPreferences
```

Each board event resolves:

```text
authoritative board
→ active messages
→ load current local hidden ids
→ remove locally hidden
→ newest-first sort
→ SpacesBarPresentationState
```

No per-message Firestore reads.

A listener is one document realtime stream.

One-shot `load()` remains available for focused read scenarios/tests, but main Spaces screen uses realtime watch.

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

Manager editor can therefore show an active message that local presentation hid.

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

Push exact-target does not override local hide.

---

# 13. Presentation ordering

Current resolver order:

```text
newer createdAt first
```

Tie-breaker:

```text
message id/revision descending
```

Lifetime does not affect ordering.

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

Allowed roles:

```text
brigadier
owner
```

Member fails before gateway invocation.

Firestore Rules independently enforce manager writes.

Realtime listener observes publish/delete result, so main SpacesBar does not require an explicit post-write reload.

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
```

Transaction removes requested message, cleans expired state, increments revision and rewrites board.

Do not use whole-document delete.

Delete-only write must not generate a SpacesBar push.

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

# 19. Exact target UI contract

Panel input:

```text
targetMessageId
```

Priority contract:

```text
explicit push target
> newly-added realtime message
```

while the user is still on that explicit target.

This prevents:

```text
tap old push
→ initial target visible
→ newer realtime snapshot arrives
→ accidental jump to newest
```

Once the user manually moves away from target, normal carousel/realtime behavior resumes.

Regression test exists in:

```text
test/widgets/spaces/spaces_bar/spaces_bar_panel_test.dart
```

---

# 20. Visual semantics

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

Message card intentionally does not show pin icon or lifetime text.

---

# 21. Current carousel limitation

Current:

```text
finite PageView
pages are separate cards
```

Accepted for current checkpoint.

Future presentation-only refactor:

```text
one stationary outer SpacesBar
→ content changes inside

finite
→ infinite/cyclic swipe
```

No changes required to Firestore/domain/management/local hide/realtime/push/15-second policy.

---

# 22. SpacesBar editor

Widget:

```text
SpacesBarEditorSheet
```

Form:

```text
multiline text
250 char limit
lifetime dropdown
publish button
```

At 3/3 publish form is replaced by capacity notice. Transaction and Rules remain authoritative enforcement.

---

# 23. Push deep-link architecture

Domain model:

```text
PushDeepLinkRequest
PushDeepLinkTargetType
```

Supported target types:

```text
chat
spacesBar
```

Remote data:

```text
chat:
deepLinkType = chat
chatId = ...

spacesBar:
deepLinkType = spacesBar
spacesBarMessageId = ...
```

Legacy raw `chatId` remote/local payload remains supported.

Type-aware deduplication:

```text
chat:<id>
spacesBar:<id>
```

SpacesBar resolver does not load chat data.

---

# 24. Push navigation architecture

```text
RemoteMessage / local notification response
→ PushDeepLinkRequest
→ PushDeepLinkCoordinator
→ target-specific resolver
→ target-specific navigation
```

SpacesBar:

```text
resolveSpacesBarMessageId
→ authenticated user check
→ HomeScreen(
     spacesBarTargetMessageId: id,
     allowRoutePop: true,
   )
→ SpacesPage
→ SpacesBarPanel(targetMessageId: id)
```

No Firestore chat lookup for SpacesBar target.

---

# 25. SpacesBar Android notification channel

Channel:

```text
epistola_spaces_bar_v1
```

Presentation:

```text
importance high
sound seagull_notification
vibration enabled
pattern [0, 250, 100, 250]
```

Foreground uses Flutter local notifications.

Background/locked screen uses FCM Android notification payload with same channel id and sound/vibration configuration.

Device/OS channel settings remain authoritative for actual vibration behavior in background.

---

# 26. Cloud Function notification architecture

Export:

```text
sendSpacesBarNotification
```

Trigger:

```text
onDocumentWritten("spaces/spacesBar")
```

Detector:

```text
detectSpacesBarPublication(beforeData, afterData)
```

Only one newly-added valid message produces a notification event.

Ignored:

```text
delete-only
existing-message update
multi-add
malformed add
```

Expired removals may occur in the same board write as one valid addition.

Recipient discovery:

```text
collectionGroup("devices").get()
```

Then:

```text
validate token
dedupe token
collect publisher tokens
remove publisher tokens from recipient map
send multicast chunks <= 500
delete invalid-token device documents
```

Publisher exclusion is based on `createdByUserId`, not role.

Cost model for pilot:

```text
one devices collection-group read per SpacesBar publication
no per-recipient user reads
```

---

# 27. Cloud Function deployment

Production:

```text
function: sendSpacesBarNotification
region: europe-west1
runtime: nodejs22
generation: 2nd Gen
```

Tests:

```text
functions notification helper: 7/7
functions lint: no errors
```

Known non-blocking tooling warning:

```text
current TypeScript version is newer than the parser's declared supported range
```

Do not upgrade Firebase Functions/TypeScript dependencies as part of unrelated feature work unless separately planned.

---

# 28. Backward compatibility note

Device tokens from older Epistola installations are still recipient candidates.

Therefore an older app version that does not implement SpacesBar may receive a SpacesBar FCM notification.

Current pilot accepts this.

If rollout requires stricter compatibility, add explicit client capability/app-version metadata and filter recipients server-side rather than overloading current deep-link semantics.

---

# 29. Substitution architecture

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

# 30. Future multi-channel event architecture

Desired later design:

```text
business event
→ push
→ SpacesBar
→ optional system notification surface
```

A Substitution call should eventually be one business event projected into multiple presentation channels, not unrelated records.

---

# 31. Verification

Current functional checkpoint:

```text
123cda1 feat(spaces): add realtime spaces bar notifications
```

Latest final checks:

```text
Flutter tests: 849 passed
flutter analyze: clean
git diff check: clean
release APK: successful; latest recorded size 57.5 MB
SpacesBar notification helper: 7/7
Functions lint: no errors
SpacesBar Rules: 22/22 targeted
Firestore Rules: 155/155 full
```

Manual emulator + physical devices:

```text
publish/delete
3/3
realtime cross-device update
newest-first
carousel
15-sec timer
member permission UI
local hide persistence
push receive
seagull sound
vibration with locked screen on verified device
exact-target from multiple pending notifications
```

---

# 32. Near-term roadmap

Completed:

```text
SpacesBar realtime
SpacesBar push
exact message targeting
production notification function
```

Deferred presentation-only:

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

Next functional block should be chosen from the current v0.8.0 roadmap after reading current branch source and `PROJECT_CONTEXT.md`; do not assume the old "push integration" roadmap item is still pending.
