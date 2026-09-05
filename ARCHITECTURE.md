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
| Last functional checkpoint | `9ebf9ab` |
| Functional commit | `feat(spaces): add confirmed substitution call delivery` |
| Previous SpacesBar checkpoint | `123cda1` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Main platform | Android |
| Pilot target | 40–50 users |

After functional push:

```text
HEAD = origin feature branch = 9ebf9ab
working tree = clean
```

`v0.8.0` is not yet declared merged/released.

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

UI owns rendering, gestures, navigation, dialogs, loading/error states, animations and local visual preferences.

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

Deferred layout:

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

SpacesBar capability:

```text
canManageSpacesBar
member = false
brigadier = true
owner = true
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

General message:

```text
text
lifetime
createdByUserId
createdAt
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

Do not persist presentation-only values such as Color, glow, font size, carousel page or local hide state.

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

Manager:

```text
brigadier
owner
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

General order:

```text
createdAt descending
→ deterministic id/revision tie-breaker
```

---

# 9. Confirmed substitution call

Domain:

```text
SubstitutionConfirmedCall
```

Fields:

```text
callId
userId
revision
calledByUserId
calledAt
finalizedAt
shift
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

General:

```text
publishedAt = message.createdAt
```

Substitution:

```text
publishedAt = call.finalizedAt
accent = purple
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

At timer fire:

```text
refreshForCurrentTime(currentState)
```

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

This is incremental compatibility debt. Do not rename during unrelated work.

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

Explicit valid push target:

```text
target > newly-added realtime item
```

while user remains on target.

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

# 20. General SpacesBar function

Export:

```text
sendSpacesBarNotification
```

Trigger:

```text
onDocumentWritten("spaces/spacesBar")
```

Only one valid new general message produces a push.

Recipient discovery:

```text
collectionGroup("devices")
```

Then:

```text
dedupe
exclude publisher tokens
multicast <=500
cleanup invalid tokens
```

---

# 21. Substitution call function

Export:

```text
sendSubstitutionCallNotification
```

Trigger:

```text
onDocumentCreated(
  "spaces/substitution/confirmedCalls/{callId}"
)
```

Helper:

```text
buildSubstitutionCallNotification
```

Validates callId, recipient userId, date and shift kind.

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

# 22. Epistola technical chat

Purpose:

```text
read-only technical history
```

Tile:

```text
Epistola
Технические сообщения
```

Avatar:

```text
assets/images/epistola_app_icon.png
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

System message:

```text
id = substitutionCall:<callId>
createdAt = call.calledAt
```

History order:

```text
old → new
```

Listener exists only while screen is open.

`ChatsPage` does not keep a confirmedCalls preview listener.

---

# 23. Technical-chat UX boundary

Supported:

```text
loading
error/retry
empty
realtime list
initial bottom scroll
conditional auto-scroll when near bottom
```

Not supported by design:

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

Any expansion is a separate product decision.

---

# 24. Visual assets

Runtime:

```text
assets/images/epistola_app_icon.png
assets/images/epistola_seagull_stencil.png
```

Master:

```text
Аватар Чайки.png
Аватар Чайки трафарет.png
```

Current use:

```text
app icon asset → technical chat avatar
stencil → empty SpacesBar
```

Android launcher icon has not been replaced in functional checkpoint `9ebf9ab`.

---

# 25. Substitution projection flow

```text
manager calls participant
→ pendingCall
→ Undo window
```

Undo:

```text
no confirmedCall
→ no downstream confirmed-call projection
```

No Undo:

```text
finalization transaction
→ confirmedCall
```

Downstream projections:

```text
confirmedCall
→ personal SpacesBar
→ technical history
→ substitution push
```

These channels project one canonical event, not unrelated authoritative copies.

---

# 26. Existing substitution foundation

```text
participants
rotationOrder
availability
vacation/sick
participant management
work display name
call/Undo
pending calls
recovery
exactly-once finalization
monthly/yearly statistics
confirmed calls
personal SpacesBar
technical history
push
Rules
```

Owner priority/protections must not be weakened.

---

# 27. Verification

Functional commit:

```text
9ebf9ab
feat(spaces): add confirmed substitution call delivery
```

Flutter:

```text
922 tests passed
analyze clean
release APK 58.2 MB
```

Functions:

```text
substitution helper 6/6
lint no errors
build success
```

Rules:

```text
latest full suite for this block: 165/165
```

Production:

```text
confirmedCalls Rules deployed
sendSpacesBarNotification deployed
sendSubstitutionCallNotification deployed
```

Manual:

```text
future confirmed substitution call
→ personal SpacesBar
→ technical history
→ push
```

---

# 28. Deferred architecture work

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

Visual follow-up:

```text
actual Android launcher icon replacement
```

Do not mix these into unrelated feature work.

---

# 29. Source-of-truth rule for next work

At the beginning of a new development chat:

```text
verify branch/status/HEAD/origin
read current source
read PROJECT_CONTEXT.md
read ARCHITECTURE.md
read README.md
```

Historical one-off handoff files are not canonical after these documents are updated.
