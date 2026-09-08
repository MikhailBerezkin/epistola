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
| Stage | `Spaces / Substitution / SpacesBar / EpiLite Web Lite` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `a488c3b` |
| EpiLite Web Lite | `a488c3b` |
| Chats unread summary | `f0a2084` |
| Substitution list editor | `85238a2` |
| Deleted-user cleanup | `e7ac582` |
| Android launcher icon | `544fcaf` |
| Previous confirmed-call checkpoint | `9ebf9ab` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Full platform | Android / `Epistola` |
| Lightweight Web/PWA | `EpiLite` |
| Pilot target | 40–50 users |

`v0.8.0` is not yet declared merged/released.

A docs-only commit may make HEAD newer than `a488c3b`.

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
responsive layout
platform-specific presentation branching
```

UI must not own:

```text
Firestore transaction invariants
authoritative security
backend schema derived from visual state
server persistence of presentation-only parameters
role authorization copied into widgets
```

Application services own permission checks, validation and orchestration.

Gateways/adapters own Firestore reads/writes, snapshots, transactions, server timestamps, schema mapping and local persistence adapters.

Domain remains independent of Flutter visual state.

---

# 3. Platform capability boundary

Platform split is centralized in:

```text
lib/platform/epistola_platform_capabilities.dart
```

Current semantics:

```text
isWebLite
supportsPushNotifications
supportsChats
supportsContacts
supportsSpacesBarManagement
supportsSubstitutionManagement
supportsSubstitutionAvailabilityChanges
```

Use this layer to decide whether a capability exists on a platform.

Do not scatter raw `kIsWeb` checks throughout unrelated feature code when a stable platform capability can express the policy.

Critical separation:

```text
platform capability
≠ business authorization
≠ Firestore security
```

Example:

```text
supportsSpacesBarManagement = true
```

means Web may expose SpacesBar management behavior.

Actual right to publish still depends on:

```text
SpacesAccessRole
→ member / brigadier / owner
```

and authoritative writes remain protected by Firestore Rules.

---

# 4. Platform products

Full application:

```text
Epistola
→ Android
```

Lightweight Web/PWA:

```text
EpiLite
→ Flutter Web
→ Firebase Hosting
```

Hosting:

```text
https://epistola-434b7.web.app
```

Shared backend:

```text
Firebase Auth
Firestore
Firebase Storage where supported/configured
existing domain/application services
```

Do not fork business collections merely to make a Web presentation.

---

# 5. EpiLite Web Lite scope

Verified Web Lite capabilities:

```text
Firebase Auth
root navigation
Spaces
SpacesBar
Substitution "Список"
Profile/logout path
PWA installation
Firebase Hosting
```

Explicit current limitations:

```text
Chats
→ unavailable on Web

Push notifications
→ unavailable on Web

Android/local notification initialization
→ skipped on Web
```

The Web app may perform business actions that cause Android devices to receive existing FCM notifications. This is not Web push support.

Contacts remain visible in current root navigation, but they are not part of the guaranteed Web Lite MVP contract yet.

---

# 6. Web startup / notification boundary

`main.dart` initializes Firebase for all platforms.

Push setup is guarded by:

```text
EpistolaPlatformCapabilities.supportsPushNotifications
```

On Web, do not initialize:

```text
FirebaseMessaging.onBackgroundMessage
NotificationService.initialize
NotificationService.startMessaging
```

until a dedicated Web push foundation is designed.

This prevents Android notification assumptions from leaking into Flutter Web.

---

# 7. Branding / PWA identity

Android:

```text
Epistola
```

Web/PWA:

```text
EpiLite
```

Web MaterialApp title:

```text
EpiLite
```

Android MaterialApp title:

```text
Epistola
```

Home header follows the same platform split.

PWA manifest:

```text
name = EpiLite
short_name = EpiLite
id = /epilite
start_url = /
scope = /
display = standalone
```

Runtime Web branding:

```text
web/index.html
web/manifest.json
web/favicon.png
web/icons/
```

Source artwork:

```text
design/branding/
```

The runtime SpacesBar stencil remains:

```text
assets/images/epistola_seagull_stencil.png
```

and is not a design-source substitute.

---

# 8. Firebase Hosting

`firebase.json` contains Hosting configuration.

Public directory:

```text
build/web
```

SPA rewrite:

```text
** → /index.html
```

Build:

```powershell
flutter.bat build web
```

Deploy:

```powershell
firebase.cmd deploy --only hosting
```

Always build Web before Hosting deploy.

Do not assume deploy automatically runs Flutter build.

---

# 9. Storage/CORS boundary

Web image/avatar fetches from Firebase Storage are subject to browser CORS.

If images work on Android but fail in Web with CORS console errors:

```text
do not add duplicate Firestore reads
do not bypass avatar cache architecture
do not change domain model first
```

Check Storage bucket CORS configuration.

Known bucket:

```text
gs://epistola-434b7.firebasestorage.app
```

A fixed local Web port can be used for reproducible development:

```powershell
flutter.bat run -d chrome --web-port 57097
```

Production origin is Firebase Hosting.

---

# 10. Infrastructure / cost model

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
avoid disabled-feature Web reads
```

---

# 11. Root navigation

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

Android Chats remain internal:

```text
Spaces
→ Чаты
→ existing Messenger
```

Do not mass-rename Messenger internals.

Push-created Spaces routes must remain separate from normal root Back semantics.

Web header may say `EpiLite`; this does not rename Android or Messenger domain entities.

---

# 12. Spaces Hub

Screen:

```text
lib/screens/spaces_page.dart
```

Current applications:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Android working:

```text
Чаты
Список
```

Web Lite working:

```text
Список
```

Web Chats behavior:

```text
no ChatUnreadSummaryController
no Messenger navigation
tile subtitle = Доступно в Android
tap → Android-only dialog
```

Placeholders/unimplemented:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Deferred Spaces Hub layout:

```text
<=6 → regular
7–8 → compact without subtitles
odd last tile → full width
>8 → vertical scroll
```

`⋮` remains reserved for future show/hide/reorder Spaces configuration.

---

# 13. Chat unread architecture

Checkpoint:

```text
f0a2084
feat(spaces): add chats unread badge
```

Controller:

```text
ChatUnreadSummaryController
```

owns one user-chat stream and derives total unread state centrally.

Avoid:

```text
one Firestore unread query per ChatTile
```

The Hub reads the controller state and renders one badge.

Web does not start this controller because Chats are disabled.

This is both a platform-boundary and cost/read optimization.

---

# 14. Spaces roles

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

Web preserves the same roles; it does not invent a separate Web authorization model.

---

# 15. General SpacesBar domain/backend

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

# 16. General SpacesBar read/write

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

Web uses the same service/gateway chain.

---

# 17. SpacesBar UI

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

These are presentation-only changes and must not rewrite backend/domain logic.

---

# 18. Confirmed substitution call

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

# 19. Confirmed-call schema / Rules

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

# 20. Confirmed-call client gateway

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

# 21. Unified SpacesBar presentation

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

# 22. Personal call expiry / hide

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

# 23. SpacesBar state separation

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

# 24. Unified push deep-link

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

# 25. Legacy routing naming

Some APIs still use old names:

```text
resolveSpacesBarMessageId
spacesBarTargetMessageId
targetMessageId
```

Current value may be a presentation ID.

This is compatibility debt.

Do not rename during unrelated work.

---

# 26. Exact target contract

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

# 27. SpacesBar Android notification channel

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

This is Android-specific until Web push is separately implemented.

---

# 28. Push Functions

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
→ cleanup invalid token docs
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

# 29. Epistola technical chat

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

# 30. Substitution participant canonical model

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

# 31. Hidden canonical slot invariant

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

# 32. New participant vs restore

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

Membership history inside substitution is represented by keeping the participant document with status `removed`.

Auth deletion is a separate lifecycle event and can physically clean the participant document.

---

# 33. Gateway separation

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

# 34. Rotation draft domain

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

# 35. Rotation edit service

Service:

```text
SubstitutionRotationEditService
```

Editing remains local until Apply.

Apply:

```text
single authoritative transaction
```

Only changed `rotationOrder` fields are persisted.

Unrelated concurrent participant state should be preserved where allowed by the transaction contract.

Conflict protection checks the editor baseline.

Exact UI conflict text:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# 36. Narrow responsive participant row

`SubstitutionParticipantRow` uses explicit Row/Expanded layout instead of depending on `ListTile.trailing`.

Reason:

```text
narrow Web width
+
button / menu / statistics controls
```

Old layout could produce:

```text
Trailing widget consumes the entire tile width
RenderFlex overflow
Text layout not available
```

The new layout keeps:

```text
queue badge
name/subtitle
compact controls
```

Android regression must remain part of future edits to this shared widget.

---

# 37. Deleted-user cleanup

Auth-delete backend cleanup removes active identity/application records:

```text
users/{uid}
device token documents
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Historical/business records remain:

```text
confirmedCalls
statistics
chats
messages
```

Do not treat normal substitution soft removal as Auth deletion.

Bulk Admin SDK deletion requires separate verification if used.

---

# 38. Branding asset separation

Design sources:

```text
design/branding/
```

Runtime application assets remain in their feature/runtime paths.

Do not point widgets directly at large design-source PNGs merely because they exist in the repository.

PWA icons are generated/runtime Web assets under:

```text
web/icons/
```

Android launcher assets remain Android resources.

This keeps product branding sources separate from platform runtime output.

---

# 39. Verification discipline

For ordinary Dart/Flutter changes:

```text
dart.bat format
flutter.bat analyze
targeted tests
```

At checkpoints:

```text
flutter.bat test
flutter.bat build apk --release
```

For Web-affecting checkpoints:

```text
flutter.bat build web
manual browser/PWA verification
```

For rules-only changes:

```text
targeted Firebase Emulator rules tests
```

For Hosting:

```text
fresh flutter build web
then firebase hosting deploy
```

Restore generated Flutter plugin files once after the final Flutter command in a series.

---

# 40. Current backlog boundary

Completed:

```text
Chats unread summary
EpiLite Web Lite/PWA foundation
```

Next UI backlog unless reprioritized:

```text
SpacesBar stationary outer frame
true cyclic/infinite swipe
glow tuning

Spaces Hub ⋮
show/hide Spaces
regular/compact layout
>8 behavior

legacy *MessageId → presentationId cleanup
```

Later:

```text
FCM token lifecycle investigation
Calendar foundation
Buses foundation
```

EpiLite future phases must remain separate explicit foundations:

```text
Web push
Chats on Web
full responsive parity
```
