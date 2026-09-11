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
| Stage | `Spaces / Substitution / SpacesBar / EpiLite / Push Ownership` |
| Feature branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `67800f0` |
| Push installation ownership | `67800f0` |
| Test Mode + Web avatars + final SpacesBar UI | `1ca3bcf` |
| EpiLite Web Lite foundation | `a488c3b` |
| Chats unread summary | `f0a2084` |
| Substitution list editor | `85238a2` |
| Deleted-user cleanup baseline | `e7ac582` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Full platform | Android / `Epistola` |
| Lightweight Web/PWA | `EpiLite` |
| Pilot target | 40–50 users |

`v0.8.0` is not yet declared merged/released.

A docs-only commit may make HEAD newer than `67800f0`.

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
server ownership invariants
backend schema derived from visual state
server persistence of presentation-only parameters
role authorization copied into widgets
```

Application services own validation/orchestration.

Gateways/adapters own Firebase reads/writes, transactions, snapshots, mapping and local persistence adapters.

Domain remains independent of Flutter visual state.

---

# 3. Platform capability boundary

Centralized in:

```text
lib/platform/epistola_platform_capabilities.dart
```

Platform capability means feature availability, not authorization.

Critical separation:

```text
platform capability
≠ business authorization
≠ Firestore security
```

Current broad policy:

```text
supportsPushNotifications
→ Android true
→ Web false

supportsChats
→ Android true
→ Web false
```

But current source has an important presentation gap:

```text
Contacts → user card → Написать
```

can open a private chat on Web because that route is not gated by the same capability.

Conclusion:

```text
Web chats are not fundamentally blocked by backend/rules
→ current limitation is incomplete presentation exposure/verification
```

Do not treat this accidental path as official full Web Chat support yet.

---

# 4. Runtime Test Mode boundary

File:

```text
lib/platform/epistola_runtime_mode.dart
```

Enable:

```powershell
flutter.bat run --dart-define=EPISTOLA_TEST_MODE=true
```

Titles:

```text
Android → Epistola Test
Web → EpiLite Test
```

Current safety scope is intentionally narrow:

```text
SpacesBar production publication avoided
SpacesBar production watch avoided
SpacesBar management avoided
fake SpacesBar messages used for visual testing
```

Important invariant:

```text
Test Mode != full Firebase sandbox
```

Unrelated production Firebase/FCM code may still initialize on Android.

Therefore Test Mode is currently a SpacesBar visual/animation test mechanism, not a global test environment.

---

# 5. Platform products

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
Firebase Storage where supported
Cloud Functions where applicable
```

Do not fork business collections merely to create a Web presentation.

---

# 6. Web startup / notification boundary

Firebase initializes on all supported platforms.

Android push setup is guarded by platform capability.

On Web, do not initialize Android-specific notification flow until dedicated Web push exists:

```text
FirebaseMessaging.onBackgroundMessage
Android local notification setup
Android notification channels
```

Web actions may still cause Android devices to receive backend FCM notifications.

That does not imply Web push support.

---

# 7. EpiLite avatar replacement architecture

Current Web avatar path:

```text
shared avatar UI/controller
→ Web avatar replacement dependency
→ ImagePicker
→ ImageCropper Web
→ bytes
→ FlutterImageCompress
→ Firebase Storage putData
→ avatar metadata
```

Web crop support is integrated through:

```text
web/index.html
→ Cropper.js
```

This was manually verified on iPhone Web/PWA.

Keep:

```text
shared presentation contracts
platform-specific media adapters
```

Do not duplicate profile/avatar screens solely for Web.

---

# 8. Firebase infrastructure

```text
Repository: MikhailBerezkin/epistola
Firebase project: epistola-434b7
Firestore: eur3
Realtime Database: europe-west1
Cloud Functions: europe-west1
Functions runtime: Node.js 22
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

# 9. Root navigation

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

Android Messenger remains internal:

```text
Spaces
→ Чаты
→ existing Messenger
```

Do not mass-rename Messenger internals.

---

# 10. Spaces Hub

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

Current UI backlog:

```text
⋮ settings
show/hide Spaces
regular/compact layout
7–8 compact behavior
>8 behavior
odd last tile behavior
```

These are presentation concerns and should not change domain/security contracts.

---

# 11. Chat unread architecture

Controller:

```text
ChatUnreadSummaryController
```

owns one user-chat stream and derives centralized unread state.

Avoid:

```text
one Firestore unread query per tile/widget
```

This remains a cost/read optimization and a single-source presentation model.

---

# 12. Spaces roles

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

UI visibility is not security.

Firestore Rules independently protect authoritative client writes.

---

# 13. General SpacesBar domain/backend

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

Lifetime controls expiry/accent, not presentation priority.

Do not persist presentation-only values such as:

```text
Color
glow
font size
carousel page
local hide state
```

---

# 14. General SpacesBar read/write

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

Delete is transactional and does not delete the board document.

---

# 15. Final SpacesBar presentation architecture

Widget:

```text
SpacesBarPanel
```

Current visual contract:

```text
stationary neutral outer frame
colored inner glow near frame
neutral center
true cyclic/infinite PageView navigation
manual drag interpolates glow continuously
auto rotation uses same controller animation
no fade-to-dark intermediate state
```

Timing:

```text
dwell = 10 seconds
auto slide = 1000 ms
```

Glow tuning checkpoint:

```text
strong edge alpha ≈ 45
inner alpha ≈ 10
```

The cyclic carousel is presentation-only.

It must not alter:

```text
message lifetime
message ordering
server IDs
hide state
backend board schema
```

---

# 16. Unified SpacesBar presentation

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

Combined order:

```text
publishedAt descending
→ presentationId tie-breaker
```

Personal calls do not consume general `3/3` capacity.

---

# 17. Personal call expiry / hide

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

No server write occurs when the visual item expires.

Confirmed-call history remains.

---

# 18. Confirmed substitution call

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

Exactly-once remains based on pending-call deletion in the same transaction.

Schema:

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

Confirmed calls are immutable business events.

---

# 19. Unified push deep-link

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

Valid values:

```text
general:<messageId>
substitution:<callId>
```

Backward compatibility remains for legacy `spacesBarMessageId` and chat IDs.

Some older internal names still say `*MessageId` even when carrying a unified presentation ID.

This is intentional compatibility debt for a dedicated cleanup phase.

---

# 20. Android push delivery model

Existing recipient documents remain:

```text
users/{uid}/devices/{installationId}
```

Delivery Functions query these documents to obtain FCM tokens.

This storage remains the delivery projection even after canonical ownership registry was introduced.

Do not confuse:

```text
pushInstallations/{installationId}
→ authoritative current installation ownership

users/{uid}/devices/{installationId}
→ delivery projection consumed by existing push senders
```

Both are kept transactionally consistent by the ownership service for new clients.

---

# 21. Push installation identity

Stable local key:

```text
SharedPreferences
push_installation_id
```

Format:

```text
16 secure random bytes
→ 32 lowercase hex chars
```

Invariant:

```text
one installationId
→ one current authenticated user
```

Allowed:

```text
one user
→ multiple installationIds
```

FCM token itself is not the installation identity.

---

# 22. Canonical push ownership registry

Authoritative path:

```text
pushInstallations/{installationId}
```

Current schema:

```text
schemaVersion = 2
userId
token
platform
updatedAt
```

Legacy schema v1:

```text
ownerUserId
```

is read only for migration.

New writes replace it with:

```text
userId
```

`userId` means authenticated account assigned to that installation and has no relationship to the application's `owner` role.

---

# 23. Push ownership callable API

Cloud Functions:

```text
claimPushInstallation
releasePushInstallation
```

Region:

```text
europe-west1
```

Authentication source:

```text
callableRequest.auth.uid
```

Client cannot nominate another user ID.

Claim request exact shape:

```text
installationId
token
platform
```

Release request exact shape:

```text
installationId
```

Validation:

```text
installationId = 32 lowercase hex
platform = android
token trimmed, non-empty, <=4096
unknown fields rejected
```

Web is currently excluded because Web push is not supported.

---

# 24. Claim transaction

Pseudo-flow:

```text
read pushInstallations/{installationId}

if old user != authenticated user:
  delete users/{oldUid}/devices/{installationId}

set users/{currentUid}/devices/{installationId}
set pushInstallations/{installationId}
```

All writes happen in one Firestore Admin transaction.

Properties:

```text
idempotent same-user claim
token refresh update
cross-account migration
multi-device preservation
```

---

# 25. Release transaction

If registry belongs to caller:

```text
delete pushInstallations/{installationId}
delete users/{callerUid}/devices/{installationId}
```

If registry belongs to another user:

```text
delete only caller's stale device document
leave current registry/current user's device intact
```

If registry does not exist:

```text
cleanup caller stale device document
```

This protects against delayed/stale logout races.

---

# 26. PushTokenService client integration

Client:

```text
lib/services/push_token_service.dart
```

Behavior:

```text
FirebaseAuth.authStateChanges
→ current authenticated user
→ get FCM token
→ claimPushInstallation

FirebaseMessaging.onTokenRefresh
→ claimPushInstallation

unregisterCurrentDevice
→ releasePushInstallation
```

The client no longer relies on direct Firestore device ownership writes in the new APK.

---

# 27. Device security Rules

Desired post-migration rule:

```text
users/{uid}/devices/{deviceId}

read own devices
→ allowed

create/update/delete by client
→ denied
```

Trusted Cloud Functions use Admin SDK and are unaffected by client Rules.

The restrictive Rules are committed and tested but intentionally not deployed yet.

Reason:

```text
legacy APKs still depend on direct device writes
```

Rollout must be staged.

---

# 28. Push migration rollout

Safe order:

```text
1. deploy callables
2. distribute new APK
3. wait for adoption
4. verify active users migrated
5. deploy restrictive device Rules
```

Current state:

```text
step 1 complete
step 2 planned/current release work
step 5 deferred ~5–7 days
```

If many users remain on old APK, postpone step 5.

Do not trade stale-device security for an avoidable outage of push registration on old clients.

---

# 29. Push incident design lesson

A single physical device may authenticate as different users over its lifetime.

Therefore this pattern is unsafe:

```text
on login:
  write token under current user
```

without also removing prior ownership for the same installation.

Canonical installation registry solves that by making account migration explicit and atomic.

The app role `owner` must never be inferred from installation ownership terminology.

---

# 30. Deleted-user cleanup boundary

Current Auth-delete cleanup removes:

```text
users/{uid}
users/{uid}/devices/*
spaces/substitution/participants/{uid}
spaces_access/{uid}
```

Historical records are preserved.

New architecture adds:

```text
pushInstallations/{installationId}
```

Current cleanup predates this registry.

Required follow-up:

```text
audit deleted-user cleanup
→ remove/resolve canonical registry documents whose userId matches deleted UID
```

Do not assume this is already done.

---

# 31. Epistola technical chat

Purpose:

```text
read-only technical history
```

It is a projection of canonical confirmedCalls, not a fake normal chat.

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

# 32. Substitution participant canonical model

Path:

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

The canonical queue contains active and inactive participants.

The visible queue is a projection.

`removed` is a soft membership state.

---

# 33. Hidden canonical slot invariant

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

Active participants can move around hidden anchors.

Previously removed participants restore at their canonical anchor.

This prevents remove/re-add priority gaming.

---

# 34. Substitution gateway separation

State-only gateway:

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

These are distinct write contracts and should not be collapsed into one generic gateway.

---

# 35. Rotation draft/editor

Domain:

```text
SubstitutionRotationDraft
```

Editing remains local until Apply.

Apply:

```text
single authoritative transaction
normalize complete canonical rotationOrder 0..N-1
persist only allowed changes
```

Exact conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

---

# 36. Buses foundation boundary

Current business information is provisional.

Known route naming:

```text
Управление
Медпункт
Раздевалка
Автово
```

Two buses run cyclically between terminal points with intermediate stops.

Weekday/weekend service differs.

The old schedule document is not authoritative enough for implementation.

Architecture should wait for a newer confirmed schedule before introducing a persistent schedule model.

---

# 37. Verification discipline

Ordinary Flutter changes:

```text
dart.bat format
flutter.bat analyze
targeted tests
```

Checkpoint:

```text
flutter.bat test
release build when needed
manual device test
```

Functions:

```text
npm.cmd run lint
npm.cmd run build
node --test targeted suites
```

Rules:

```text
targeted emulator tests
full Firestore Rules suite before deploy
```

Current checkpoint evidence:

```text
Flutter analyze → clean
Flutter tests → 981 passed
Functions ownership tests → 19 passed
Push device Rules → 6 passed
Full Firestore Rules → 185 passed
```

Restore generated Flutter plugin files once after the final Flutter command in a series.

---

# 38. Current backlog boundary

Completed in current sequence:

```text
Chats unread summary
EpiLite Web Lite/PWA foundation
Web avatar replacement
SpacesBar final cyclic/glow UI
SpacesBar Test Mode foundation
Push installation ownership foundation
```

Immediate rollout:

```text
new Android APK distribution
wait for ownership migration
restrictive device Rules deploy after adoption
```

Security follow-up:

```text
deleted-user cleanup for pushInstallations
```

Next product/UI unless reprioritized:

```text
Spaces Hub ⋮
show/hide Spaces
regular/compact layout
>8 behavior
odd final tile
```

Technical cleanup:

```text
legacy *MessageId → presentationId naming
```

Later explicit foundations:

```text
official Web Chats
Web push
Calendar
Buses
```
