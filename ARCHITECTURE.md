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
| Current development target | `v0.8.0` |
| Stage | `Spaces / Substitution / SpacesBar` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `544fcaf` |
| Substitution list editor commit | `85238a2` |
| Deleted-user cleanup commit | `e7ac582` |
| Android launcher icon commit | `544fcaf` |
| Previous confirmed-call checkpoint | `9ebf9ab` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Main platform | Android |
| Pilot target | 40–50 users |

`v0.8.0` is not yet declared merged/released.

A docs-only commit may make HEAD newer than `544fcaf`.

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
local editor draft presentation
```

UI must not own:

```text
Firestore transaction invariants
authoritative security
backend schema derived from visual state
server persistence of presentation-only parameters
```

Application services own permission checks, validation and orchestration.

Gateways/adapters own Firestore reads/writes, snapshots, transactions, server timestamps, schema mapping and local persistence adapters.

Domain remains independent of Flutter visual state.

---

# 3. Infrastructure / cost model

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore: eur3
Realtime Database: europe-west1
Cloud Functions: europe-west1
Android package: com.epistola.app
```

Pilot principles:

```text
40–50 users
avoid per-widget Firestore reads
minimize writes
cache reusable user/role data by UID
keep presentation state local when server authority is unnecessary
persist participant reorder only on Apply
reuse canonical business events for multiple projections
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

Default:

```text
Spaces
```

Back:

```text
Contacts → Spaces
Profile → Spaces
Spaces → exit
```

Chats remain internal:

```text
Spaces
→ Чаты
→ existing Messenger
```

Do not mass-rename Messenger internals.

Push-created Spaces routes must remain separate from normal root Back semantics.

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

Working:

```text
Чаты
"Список"
```

Placeholders/unimplemented:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Next planned application foundations include:

```text
Календарь смен
Автобусы
```

Their exact domain/storage contracts are not defined by the current placeholder tiles and must be designed before implementation.

Deferred Spaces Hub layout:

```text
<=6 → regular
7–8 → compact without subtitles
odd last tile → full width
>8 → vertical scroll
```

`⋮` remains reserved for future show/hide/reorder Spaces configuration.

---

# 6. Spaces roles

Roles:

```text
member
brigadier
owner
```

`owner` is highest priority.

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

UI visibility is not security. Rules independently enforce authoritative writes.

---

# 7. General SpacesBar domain/backend

Domain:

```text
SpacesBarMessage
SpacesBarMessageLifetime
SpacesBarBoard
SpacesBarPublicationReceipt
```

Authoritative document:

```text
spaces/spacesBar
```

Schema v1:

```text
revision
messages
updatedAt
```

Capacity:

```text
3 active general messages
```

New ID:

```text
messageId = board revision
```

Lifetimes:

```text
oneHour
twelveHours
twentyFourHours
untilCancelled
```

Lifetime controls expiry and visual accent, not presentation priority.

Do not persist presentation-only values such as:

```text
Color
glow
font size
carousel page
local hide state
```

---

# 8. General SpacesBar read/write

Realtime:

```text
SpacesPage
→ SpacesBarPresentationService.watch(userId)
→ SpacesBarBoardFirestoreGateway.watch()
→ spaces/spacesBar snapshots()
```

General local hide:

```text
SpacesBarHiddenMessagesPreferences
→ SharedPreferences
→ spaces_bar.hidden_message_ids.v1.<uid>
```

Write:

```text
SpacesPage
→ SpacesBarManagementService
→ SpacesBarBoardTransactionGateway
→ Firestore transaction
```

Publish transaction:

```text
read board
clean expired
verify active < 3
revision + 1
new id = revision
append message
rewrite board
server timestamps
```

Delete is transactional and does not delete the whole board document.

---

# 9. Confirmed substitution call

Domain:

```text
SubstitutionConfirmedCall
```

Authoritative path:

```text
spaces/substitution/confirmedCalls/{callId}
```

Finalization transaction:

```text
read pendingCall
→ validate
→ calculate statistics
→ write statistics
→ write confirmedCall
→ delete pendingCall
```

This is the canonical post-Undo business event.

Exactly-once remains based on authoritative pending-call deletion in the same transaction.

---

# 10. Confirmed-call schema / Rules

Storage:

```text
schemaVersion
callId
userId
revision
calledByUserId
calledAt
finalizedAt
shiftYear
shiftMonth
shiftDay
shiftKind
```

Rules bind confirmedCall creation to the valid finalization operation that removes pendingCall and updates matching statistics.

Reads:

```text
called user → own confirmed calls
```

Update/delete:

```text
denied
```

---

# 11. Confirmed-call client gateway

Gateway:

```text
SubstitutionConfirmedCallFirestoreGateway
```

Firebase query:

```text
confirmedCalls.where("userId", isEqualTo: userId)
```

Supports:

```text
loadForUser
watchForUser
```

Malformed documents and document-id/callId mismatches are rejected.

Returned order:

```text
finalizedAt descending
→ revision descending
```

No cross-user query is required for personal SpacesBar/history.

---

# 12. Unified SpacesBar presentation

Model:

```text
SpacesBarPresentationItem
```

Sources:

```text
generalMessage
substitutionCall
```

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Unified list:

```text
visible general messages
+
visible active personal substitution calls
```

Combined order:

```text
publishedAt descending
→ presentationId tie-breaker
```

Personal calls do not consume general `3/3` capacity.

---

# 13. Personal call expiry / hide

Resolver:

```text
SpacesBarSubstitutionCallResolver
```

Active only while:

```text
nowLocal < shiftStartsAtLocal
```

Shift start:

```text
day → 08:00
night → 20:00
```

Local hide:

```text
SpacesBarHiddenSubstitutionCallsPreferences
spaces_bar.hidden_substitution_call_ids.v1.<uid>
```

`SpacesPage` schedules a local Timer for nearest visible expiry.

No server write at shift start.

App resume also recalculates time-dependent visibility.

Confirmed-call history remains after SpacesBar expiry.

---

# 14. SpacesBar state separation

`SpacesBarPresentationState` deliberately keeps separate:

```text
general board
general hidden IDs
active general messages
visible general messages

full confirmed-call history
hidden substitution IDs
active substitution calls
visible substitution calls

unified presentationItems
nextSubstitutionExpiryAtLocal
```

Important:

```text
manager editor → general activeMessages only
technical history → full confirmedCalls
SpacesBar → visible presentationItems
```

Do not collapse these into one authoritative backend structure.

---

# 15. SpacesBar UI

Widget:

```text
SpacesBarPanel
```

Current:

```text
height = 141 px
font = 18 px
1 item → no dots/chevrons
>1 → chevrons + dots + PageView
auto rotation = 15 sec
manual navigation resets interval
```

Empty state:

```text
assets/images/epistola_seagull_stencil.png
```

General accents:

```text
1h green
12h blue
24h orange
untilCancelled red
```

Substitution accent:

```text
purple
```

Current PageView remains finite at swipe boundaries.

Deferred:

```text
stationary outer frame
true cyclic/infinite swipe
glow tuning
```

---

# 16. Unified push deep-link

Domain:

```text
PushDeepLinkRequest
PushDeepLinkTargetType
```

Types:

```text
chat
spacesBar
```

Unified field:

```text
spacesBarPresentationId
```

Valid:

```text
general:<messageId>
substitution:<callId>
```

Backward compatibility:

```text
legacy chatId
legacy spacesBarMessageId
```

Legacy general normalization:

```text
spacesBarMessageId=42
→ general:42
```

Deduplication:

```text
chat:<id>
spacesBar:<presentationId>
```

---

# 17. Legacy routing naming

Some APIs still use old names:

```text
resolveSpacesBarMessageId
spacesBarTargetMessageId
targetMessageId
```

Current value may be a presentation ID.

This is compatibility debt. Do not rename during unrelated work.

---

# 18. Exact target contract

Panel matching:

```text
item.presentationId == target
```

or legacy general:

```text
item.generalMessageId == target
```

Explicit valid push target remains stronger than newly-added realtime state while the user remains on the target.

Manual navigation releases this priority.

Local hide remains stronger than push forcing.

---

# 19. SpacesBar Android notification channel

```text
epistola_spaces_bar_v1
```

Properties:

```text
importance high
sound seagull_notification
vibration enabled
pattern [0, 250, 100, 250]
```

Foreground local notifications and background FCM use the same semantic channel.

OS/device settings remain authoritative for actual background vibration.

---

# 20. Push Functions

General SpacesBar:

```text
sendSpacesBarNotification
onDocumentWritten("spaces/spacesBar")
```

Recipient discovery:

```text
collectionGroup("devices")
→ dedupe
→ exclude publisher tokens
→ multicast <=500
→ cleanup invalid tokens
```

Substitution confirmed call:

```text
sendSubstitutionCallNotification
onDocumentCreated(
  "spaces/substitution/confirmedCalls/{callId}"
)
```

Recipient query:

```text
users/{recipientUserId}/devices
```

Payload:

```text
deepLinkType = spacesBar
spacesBarPresentationId = substitution:<callId>
notificationMode = sound
```

No separate technical-chat push is created.

---

# 21. Epistola technical chat

Purpose:

```text
read-only technical history
```

Tile:

```text
Epistola
Технические сообщения
```

Not a normal chat document.

No fake `chats` record and no generic `systemMessages` collection.

Source chain:

```text
confirmedCalls
→ SubstitutionConfirmedCallFirestoreGateway
→ SubstitutionCallSystemMessageSource
→ SubstitutionCallSystemMessageMapper
→ EpistolaSystemChatService
→ EpistolaSystemChatScreen
```

History order:

```text
old → new
```

Listener exists only while screen is open.

Unsupported by design:

```text
composer
send
delete/clear
reply
reactions
attachments
typing
read receipts
unread count
normal chat preview persistence
```

---

# 22. Substitution participant canonical model

Canonical path:

```text
spaces/substitution/participants/{userId}
```

Statuses:

```text
active
vacation
sick
removed
```

The canonical queue contains both active and inactive participants.

The visible queue is a projection of the canonical ordering.

`removed` is a soft membership state, not a normal client document deletion.

---

# 23. Hidden canonical slot invariant

Inactive statuses:

```text
vacation
sick
removed
```

retain:

```text
rotationOrder
canonical queue membership/anchor
```

Active participants can rotate or be manually reordered around hidden anchors.

Example:

```text
A
B (vacation)
C
D
```

Move `C` one visible active place up:

```text
C
B (vacation)
A
D
```

The inactive slot remains fixed.

On return/restore, the inactive participant reappears at the current canonical anchor.

---

# 24. New participant vs restore

Never-before-added participant:

```text
one-time priority at top
```

Previously removed participant:

```text
restore existing anchor
no top priority
```

This prevents repeated remove/re-add from gaming queue priority.

Membership history inside substitution is therefore represented by keeping the participant document with status `removed`.

Auth deletion is a separate lifecycle event and can physically clean the participant document.

---

# 25. Gateway separation

State-only participant gateway:

```text
SubstitutionParticipantStateFirestoreGateway
```

Membership gateway:

```text
SubstitutionRotationMembershipFirestoreGateway
```

Rotation editor gateway:

```text
SubstitutionRotationEditFirestoreGateway
```

These represent distinct write contracts:

```text
state mutation
membership mutation
whole-list reorder
```

Do not collapse them into one generic participant gateway.

---

# 26. Rotation draft domain

Domain:

```text
SubstitutionRotationDraft
```

Stores:

```text
original participants
current participants
```

Active move API:

```text
canMoveActiveUp
canMoveActiveDown
moveActiveUp
moveActiveDown
```

Inactive slots are preserved while active participants swap visible active positions.

Normalization before persistence:

```text
rotationOrder = 0..N-1
```

across the complete canonical participant list.

---

# 27. Rotation edit service

Service:

```text
SubstitutionRotationEditService
```

Baseline:

```text
SubstitutionRotationEditBaseline
→ nextRotationOrder
→ revision
```

Apply result:

```text
noChanges
applied
conflict
```

Editor UI is not authoritative; the service/gateway transaction remains the write boundary.

---

# 28. Rotation edit transaction

Gateway:

```text
SubstitutionRotationEditFirestoreGateway
```

Transaction checks:

```text
module nextRotationOrder
module revision
pending-call absence
participant composition
participant existence
original rotationOrder
```

Only changed participant:

```text
rotationOrder
```

is written.

Concurrent unrelated participant state must not be overwritten:

```text
availability
status
```

Successful Apply:

```text
normalize participant rotationOrder
advance module nextRotationOrder by 1
```

The module marker is monotonic and is not normalized to participant count.

Conflict produces no partial reorder.

---

# 29. Membership transaction gateway

Gateway:

```text
SubstitutionRotationMembershipFirestoreGateway
```

Baseline includes:

```text
moduleExists
nextRotationOrder
revision
ordered participants
pending-call state
```

Add/restore:

```text
pending-call protection
new participant insertion
removed participant restoration
baseline verification
mutation-marker advance
```

Soft remove:

```text
status = removed
rotationOrder retained
availability retained
baseline verification
mutation-marker advance
```

Physical participant delete through client Rules is denied.

---

# 30. Firestore Rules — substitution editor/membership

Rules recognize:

```text
active
vacation
sick
removed
```

They separate:

```text
ordinary participant state updates
membership changes involving removed
rotation editor reorder
call/finalization transactions
```

Membership/reorder manager roles:

```text
brigadier
owner
```

Required transaction invariants include applicable:

```text
module marker update
pending-call absence
participant set/order checks
new participant creation shape
restore shape
soft-remove shape
allowed reorder fields
```

Current targeted suite:

```text
56/56 passed
```

Latest Rules were deployed before phone Apply testing.

---

# 31. Rotation editor presentation

Screen orchestration:

```text
lib/screens/substitution_space_screen.dart
```

Editor entry:

```text
Настройки
→ Режим редактирования списка
```

Manager only:

```text
brigadier
owner
```

Before Apply:

```text
server baseline loaded once
local draft
0 Firestore reorder writes
```

Editing UI:

```text
Вызвать hidden
participant card / ⋮ hidden
statistics hidden
↑ / ↓ on active rows
settings disabled
Отмена / Применить at bottom
```

Apply:

```text
SubstitutionRotationEditService.apply
→ atomic gateway transaction
```

Conflict message:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# 32. Editor scroll stabilization

Presentation-only behavior:

```text
measure row Y before local move
→ update draft
→ post-frame measure same row
→ compensate ScrollController
```

Edit-only scroll reserve allows moves near the list edges.

A frame-level move lock prevents overlapping GlobalKey/rebuild operations.

Result:

```text
participant stays near same finger position
normal fast repeated taps are safe
ultra-fast overlapping taps can be dropped
```

Do not move this presentation behavior into domain/services.

---

# 33. Deleted Auth user cleanup

Cloud Function handles ordinary single Auth-user deletion.

Cleanup:

```text
users/{uid}
users/{uid}/devices/*
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Preserve:

```text
confirmedCalls
statistics
chats
messages
```

This is privileged backend cleanup and is intentionally separate from substitution soft removal.

Bulk Admin SDK `deleteUsers([...])` may not trigger identical per-user handlers and must not be assumed supported without verification.

---

# 34. Android launcher assets

Runtime assets:

```text
assets/images/epistola_app_icon.png
assets/images/epistola_seagull_stencil.png
```

Master artwork:

```text
Аватар Чайки.png
Аватар Чайки трафарет.png
```

Android launcher icon now uses approved gull artwork in:

```text
mdpi
hdpi
xhdpi
xxhdpi
xxxhdpi
```

Physical-device verification passed.

---

# 35. Existing Messenger architecture

Private chats:

```text
text
images
pagination
logical delete
push deep links
read receipts
typing
active-chat push suppression
avatar/user card
notification controls
```

Group chats:

```text
roles
owner/admin protections
ownership transfer
avatars
push deep links
reactions
identity/member cards
notification controls
```

Message history:

```text
page size 20
older-page loading
scroll preservation
realtime merge
date separators
floating date indicator
image-aware scroll behavior
```

---

# 36. Verification

Current functional commits:

```text
85238a2 feat(spaces): add substitution list editing
e7ac582 feat(auth): clean deleted users from spaces
544fcaf chore(android): update launcher icon
```

Flutter:

```text
978 tests passed
analyze clean
release APK 58.4 MB
```

Rotation/editor targeted:

```text
38/38
```

Substitution Rules targeted:

```text
56/56
```

Deleted-user cleanup:

```text
4/4
lint no errors
build success
```

Production/manual:

```text
latest substitution Rules deployed
deleted-user cleanup deployed
phone reorder Apply persistence passed
Cancel passed
vacation hidden-slot behavior passed
rapid-tap crash regression passed
Android launcher icon passed
```

---

# 37. Known queued issue

Observed separately:

```text
owner may receive copy of substitution push intended for another user
```

Current unverified suspicion:

```text
stale FCM token after account switching
```

Investigate notification token lifecycle/logout separately.

Do not alter rotation or call business logic until root cause is proven.

---

# 38. Next application foundations

Planned after current checkpoint/handoff:

```text
Календарь смен
Автобусы
```

Current repository only establishes them as Spaces tiles/placeholders.

Therefore next implementation must begin with:

```text
audit placeholder route/UI
define product scope
define domain model
define storage/read/write contract
define role/security boundary
define Firebase cost strategy
define tests
then implement UI on top
```

Do not silently invent coupling to `Substitution` or reuse its Firestore schema unless a genuine shared domain contract is intentionally designed.

---

# 39. Deferred architecture work

Presentation-only:

```text
stationary SpacesBar frame
true cyclic/infinite swipe
glow tuning
```

Spaces Hub:

```text
tile show/hide/reorder
regular/compact modes
>8 continuation
```

Dedicated naming cleanup:

```text
legacy SpacesBar "*MessageId" APIs
→ presentation-ID terminology
```

Notification lifecycle:

```text
verify unregisterCurrentDevice/signOut token cleanup
```

Do not mix these into unrelated feature work.

---

# 40. Source-of-truth rule for next work

At the beginning of a new development chat:

```text
verify branch/status/HEAD/origin
read current source
read PROJECT_CONTEXT.md
read ARCHITECTURE.md
read README.md
```

Last functional checkpoint documented here:

```text
544fcaf
```

A docs-only commit may make HEAD newer.

Historical one-off handoff files are not canonical after these documents are updated.
