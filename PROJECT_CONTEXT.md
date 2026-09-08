# Epistola — Project Context

> Живой operational handoff-документ проекта.
>
> При конфликте источников:
>
> ```text
> исходный код текущей feature-ветки
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```
>
> Не использовать `main` как источник текущего состояния `v0.8.0`, пока feature-ветка не merged/released.

---

# 1. Актуальная контрольная точка

Repository:

```text
MikhailBerezkin/epistola
```

Feature branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

Текущий functional checkpoint:

```text
a488c3b
feat(web): add EpiLite web client
```

Предыдущий functional checkpoint:

```text
f0a2084
feat(spaces): add chats unread badge
```

Выбранные предыдущие checkpoints:

```text
85238a2
feat(spaces): add substitution list editing

e7ac582
feat(auth): clean deleted users from spaces

544fcaf
chore(android): update launcher icon

9ebf9ab
feat(spaces): add confirmed substitution call delivery

123cda1
feat(spaces): add realtime spaces bar notifications
```

Последний стабильный release до `v0.8.0`:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

`v0.8.0` всё ещё находится в feature-ветке.

Без отдельного Git-подтверждения не считать выполненными:

```text
merge в main
release declaration
release tag
```

Документационный commit может сделать `HEAD` новее `a488c3b`.

В новом чате обязательно сначала проверять фактические:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Не выводить состояние `origin` из этого документа.

---

# 2. Финальные проверки текущего functional checkpoint

Flutter:

```text
dart.bat format
→ 6 files
→ 0 changed

flutter.bat analyze
→ No issues found

flutter.bat test
→ 978 tests passed

flutter.bat build web
→ SUCCESS
→ build/web

flutter.bat build apk --release
→ SUCCESS
→ build/app/outputs/flutter-apk/app-release.apk
→ 58.4 MB
```

Во время полного Flutter suite может появляться диагностический JPEG output:

```text
Corrupt JPEG data...
JPEG datastream contains no image
```

Если итог:

```text
All tests passed!
```

это не падение suite.

Release APK может показывать предупреждение о будущей миграции Flutter plugins с Kotlin Gradle Plugin на Built-in Kotlin. На checkpoint `a488c3b` это предупреждение не ломает release build.

Git:

```text
git diff --check
→ clean

git diff --cached --check
→ clean перед functional commit

generated Flutter plugin files
→ восстановлены после последней Flutter-команды
→ в functional commit не попали

.firebase/
→ удалена перед functional commit
```

Manual verification — EpiLite:

```text
Firebase Hosting deployed
→ https://epistola-434b7.web.app

PWA install on Android
→ works

installed app name
→ EpiLite

installed launcher icon
→ new light-blue gull icon

browser tab title
→ EpiLite

Web app header
→ EpiLite

existing Firebase account authentication
→ works

member account
→ manually checked

privileged account
→ manually checked

SpacesBar
→ loads
→ role-based management preserved

"Список"
→ opens
→ role-based actions preserved

narrow Web participant rows
→ no trailing overflow / RenderFlex spam

Chats
→ intentionally unavailable on Web
→ tile shows "Доступно в Android"

Web push
→ intentionally disabled in current Web Lite scope
```

Manual verification — Android regression:

```text
Android app remains Epistola

Пространства
→ opens

Чаты
→ opens

Список
→ opens

participant row
→ renders correctly

Вызвать / ⋮ / statistics controls
→ render correctly where applicable

SpacesBar manager controls
→ remain available by existing role rules
```

---

# 3. Infrastructure

```text
Firebase project: epistola-434b7
Android package: com.epistola.app

Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Cloud Functions runtime: Node.js 22

Full application:
Android / Epistola

Lightweight Web/PWA:
EpiLite

Firebase Hosting:
https://epistola-434b7.web.app

Pilot target:
40–50 users
```

Cost principles:

```text
minimum unnecessary Firestore reads/writes
no per-widget Firestore queries
reuse UID-keyed caches
keep presentation state local when server authority is unnecessary
list reorder writes only once on Apply
avoid duplicate authoritative business records
reuse existing Firebase backend for EpiLite where safe
```

Hosting configuration:

```text
firebase.json

hosting.public
→ build/web

SPA rewrite
→ ** → /index.html
```

Deploy:

```powershell
flutter.bat build web
firebase.cmd deploy --only hosting
```

Do not deploy without explicit approval.

---

# 4. Development workflow

Environment:

```text
Windows
PowerShell
VS Code
Flutter
Android Studio JBR
Java 21.0.10
```

Commands:

```text
flutter.bat
dart.bat
firebase.cmd
npm.cmd
npx.cmd
git
```

Workflow:

```text
small verifiable steps
risky actions separately
manual test before commit
commit / push / deploy only after explicit approval
large edit → full file
small edit → precise replacement
```

Special docs workflow:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

For these three files, prefer:

```text
assistant prepares full replacement files
→ packs exactly these three files into ZIP
→ user downloads ZIP
→ PowerShell extracts to temp
→ root files are replaced with Copy-Item -Force
```

Do not make the user manually patch these three docs section-by-section unless explicitly requested.

Generated Flutter plugin files restore once after the final Flutter command in a series.

---

# 5. Platform split: Epistola / EpiLite

The same Flutter/Firebase codebase now has an explicit lightweight Web boundary.

Capability file:

```text
lib/platform/epistola_platform_capabilities.dart
```

Current policy:

```text
isWebLite
→ true on Web

supportsPushNotifications
→ Android = true
→ Web = false

supportsChats
→ Android = true
→ Web = false

supportsContacts
→ reserved capability flag
→ current root navigation still exposes Contacts
→ Contacts are not part of the guaranteed EpiLite MVP scope

supportsSpacesBarManagement
→ true
→ actual permission still determined by Spaces role

supportsSubstitutionManagement
→ true
→ actual permission still determined by existing role/domain/security rules

supportsSubstitutionAvailabilityChanges
→ true
```

Important:

```text
capability flag
≠ authorization
```

Platform capability answers whether a feature is enabled for the platform.

Business/security permission still comes from:

```text
role/domain logic
+
Firestore Rules
```

---

# 6. EpiLite Web Lite foundation

Brand:

```text
Web/PWA
→ EpiLite

Android/full app
→ Epistola
```

Current PWA identity:

```text
name = EpiLite
short_name = EpiLite
id = /epilite
start_url = /
scope = /
display = standalone
```

PWA files:

```text
web/index.html
web/manifest.json
web/favicon.png
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
```

Icon URLs use cache-busting query suffixes in the manifest.

Source branding artwork:

```text
design/branding/Аватар EpiLite.png
design/branding/Аватар Чайки.png
design/branding/Аватар Чайки трафарет.png
```

Runtime SpacesBar stencil remains separate and must not be moved just because branding sources were moved:

```text
assets/images/epistola_seagull_stencil.png
```

Web title:

```text
MaterialApp title
→ EpiLite on Web
→ Epistola on Android

Home screen header
→ EpiLite on Web
→ Epistola on Android
```

---

# 7. EpiLite current supported scope

Current Web Lite MVP verified manually:

```text
Firebase Auth
Spaces root
SpacesBar
"Список"
Profile/logout path
PWA installation
Firebase Hosting
```

Current explicit limitations:

```text
Chats
→ disabled on Web
→ Android-only dialog

Web push
→ disabled

FCM/local Android notification initialization
→ skipped on Web
```

Do not interpret an Android push arriving while a Web action is performed as Web push support. Android may receive the push through its existing device token.

Contacts currently remain visible through root navigation, but they are not part of the intentionally guaranteed MVP contract yet.

Future Web work may expand EpiLite toward full Epistola, but this must happen feature-by-feature through platform capabilities rather than by scattering `kIsWeb` checks throughout unrelated UI.

---

# 8. Web Firebase/Storage notes

Firebase Auth and Firestore are shared with Android.

Web avatar/image loading required Storage CORS work during bring-up.

If hosted Web images fail again, verify the active Storage bucket CORS instead of changing avatar widgets to add new Firestore/Storage reads.

Known bucket:

```text
gs://epistola-434b7.firebasestorage.app
```

Web bring-up used fixed localhost port for reproducible CORS testing:

```powershell
flutter.bat run -d chrome --web-port 57097
```

Do not hard-code this localhost origin into application logic.

---

# 9. Spaces root and Hub

Root:

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Back:

```text
Контакты → Пространства
Профиль → Пространства
Пространства → exit
```

Android Messenger remains internal:

```text
Пространства
→ Чаты
→ ChatsSpaceScreen
→ ChatsPage
```

Do not mass-rename Messenger internals.

Current tiles:

```text
Чаты
Список
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Android working Spaces:

```text
Чаты
Список
```

EpiLite working Spaces:

```text
Список
```

EpiLite Chats tile:

```text
title = Чаты
subtitle = Доступно в Android
tap → Android-only dialog
```

Placeholders/unimplemented:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Deferred Hub UX:

```text
⋮ settings
show/hide Spaces
regular/compact layout
7–8 compact
>8 behavior
odd final tile behavior
```

---

# 10. Chats unread summary

Functional checkpoint:

```text
f0a2084
feat(spaces): add chats unread badge
```

Architecture:

```text
ChatUnreadSummaryController
```

owns one:

```text
getUserChats()
```

stream and derives centralized unread counts.

Important:

```text
ChatTile
→ no per-tile Firestore unread query
```

Hub badge:

```text
Чаты tile
→ upper-right unread badge
```

Manual verified:

```text
0 → 1 → 2 → 1 → 0
```

EpiLite does not create the chat unread controller because Chats are disabled on Web.

This avoids unnecessary Web chat reads for a disabled feature.

---

# 11. Spaces roles

```text
member
brigadier
owner
```

`owner` remains highest-priority.

Substitution manager capability:

```text
member
→ cannot manage participant membership/order

brigadier
→ can manage substitution

owner
→ can manage substitution
→ remains highest-priority role
```

SpacesBar capability:

```text
member = false
brigadier = true
owner = true
```

EpiLite preserves the same role semantics.

UI visibility is not the security boundary. Firestore Rules independently protect authoritative writes.

---

# 12. General SpacesBar

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

Each general message:

```text
text
lifetime
createdByUserId
createdAt
```

Max active general announcements:

```text
3
```

Message ID:

```text
messageId = new board revision
```

Lifetimes / accents:

```text
1 hour → green
12 hours → blue
24 hours → orange
until cancelled → red
```

General order:

```text
createdAt descending
→ deterministic id/revision tie-breaker
```

Lifetime controls expiry/accent, not priority.

Realtime source:

```text
spaces/spacesBar snapshots()
```

Local general hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

No Firestore write for local hide.

Manager editor counts only active general announcements for `3/3`.

EpiLite uses the same backend and same role rules for SpacesBar.

---

# 13. Current SpacesBar UI

Main widget:

```text
SpacesBarPanel
```

Current:

```text
height = 141 px
message font = 18 px
1 item → no dots/chevrons
>1 → chevrons + dots + PageView
auto rotation = 15 sec
manual navigation resets timer
```

Empty state:

```text
assets/images/epistola_seagull_stencil.png
Нет новых закреплённых сообщений
```

Current implementation still uses finite PageView boundaries.

Deferred presentation-only:

```text
stationary outer frame
true cyclic/infinite swipe
glow tuning
```

These remain next UI work after the Web Lite diversion unless reprioritized.

---

# 14. Personal substitution SpacesBar

Unified presentation model:

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

Combined list:

```text
visible general messages
+
visible active substitution calls
```

Combined order:

```text
publishedAt descending
→ presentationId tie-breaker
```

Personal calls do NOT consume general `3/3` capacity.

---

# 15. Personal call expiry and local hide

A personal call is active only while:

```text
nowLocal < shiftStartsAtLocal
```

Shift starts:

```text
day → 08:00 local
night → 20:00 local
```

At shift start:

```text
personal SpacesBar item disappears
confirmedCall remains
Epistola technical history remains
```

`SpacesPage` schedules a local Timer for nearest visible expiry and recalculates on app resume.

Separate local hide:

```text
spaces_bar.hidden_substitution_call_ids.v1.<uid>
```

SharedPreferences semantics:

```text
per user
per device
persistent
no Firestore write
```

---

# 16. Canonical confirmed substitution call

Successful finalization transaction:

```text
read pendingCall
→ validate
→ update statistics
→ create confirmedCall
→ delete pendingCall
```

Canonical immutable event:

```text
spaces/substitution/confirmedCalls/{callId}
```

Fields:

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

Meaning:

```text
userId → called user
calledByUserId → brigadier / owner who initiated call
calledAt → original call time
finalizedAt → final confirmation after Undo window
```

Exactly-once protection comes from deleting the authoritative pending call in the same transaction.

Confirmed-call gateway:

```text
SubstitutionConfirmedCallFirestoreGateway
```

Production query:

```text
confirmedCalls.where("userId", isEqualTo: currentUserId)
```

Returned calls:

```text
finalizedAt descending
→ revision descending
```

Rules:

```text
called user → get/list own confirmed calls
manager finalization transaction → valid create
update/delete → denied
```

---

# 17. Substitution confirmed-call push

Function:

```text
sendSubstitutionCallNotification
```

Trigger:

```text
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

Body:

```text
Вы вызваны на дневную смену DD.MM.YYYY в 08:00
Вы вызваны на ночную смену DD.MM.YYYY в 20:00
```

Uses the same SpacesBar Android channel.

No second FCM push is generated by the technical chat.

EpiLite does not initialize the Web push pipeline yet.

---

# 18. Unified SpacesBar push target

`PushDeepLinkRequest` supports:

```text
chat
spacesBar
```

Current unified field:

```text
spacesBarPresentationId
```

Valid IDs:

```text
general:<messageId>
substitution:<callId>
```

Backward compatibility:

```text
legacy chatId
legacy general spacesBarMessageId
```

Legacy:

```text
spacesBarMessageId = 42
→ internally general:42
```

Deduplication:

```text
chat:<id>
spacesBar:<presentationId>
```

Important naming debt:

```text
resolveSpacesBarMessageId
spacesBarTargetMessageId
targetMessageId
```

These old names can carry a unified presentation ID.

Do not rename them during unrelated work.

Explicit valid push target stays stronger than newer realtime state until user navigation releases the target.

Local hide remains stronger than push-target forcing.

---

# 19. Epistola technical chat

Private chats include a read-only technical row:

```text
Epistola
Технические сообщения
```

Avatar:

```text
assets/images/epistola_app_icon.png
```

It is NOT a normal chat.

Do not create:

```text
fake Chat
normal chats/{id} record
normal messages subcollection
generic systemMessages collection
```

Current source:

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
source = substitutionCall
sourceId = callId
createdAt = call.calledAt
```

History is ordered old → new.

Listener exists only while technical screen is open.

Read-only boundary:

```text
no composer
no send
no delete/clear
no reply
no reactions
no attachments
no typing
no read receipts
no unread badge
```

This technical chat is Android Messenger functionality, not part of current EpiLite Chats scope.

---

# 20. Participant statuses and membership semantics

Canonical participant path:

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

Meaning:

```text
active
→ visible in active queue
→ can be called

vacation
→ hidden from active queue
→ retains canonical rotation slot

sick
→ hidden from active queue
→ retains canonical rotation slot

removed
→ hidden from active queue
→ retains canonical membership anchor
```

Normal:

```text
Удалить из списка
```

means soft removal:

```text
status = removed
```

not physical participant-document deletion.

A never-before-added participant receives one-time priority at top.

A previously removed participant restores at its current hidden canonical anchor and does not regain top priority.

This prevents remove/re-add from gaming queue priority.

---

# 21. Hidden canonical slot invariant

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

# 22. Gateway separation

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

# 23. Rotation draft and editor

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

Editing is local until Apply.

Entry:

```text
Список
→ Настройки
→ Режим редактирования списка
```

Available to:

```text
brigadier
owner
```

Apply performs an atomic transaction.

Conflict text is exact:

```text
Список изменился. Откройте режим редактирования заново.
```

Do not casually reword this string.

Cancel discards local draft without writes.

---

# 24. Substitution narrow-layout adaptation

`SubstitutionParticipantRow` was refactored away from a `ListTile` trailing layout that produced narrow Web overflows.

Current row uses explicit:

```text
Row
Expanded text column
compact control row
```

This fixed Web console/runtime issues such as:

```text
Trailing widget consumes the entire tile width
RenderFlex overflowed on the right
Text layout not available
```

Android regression was manually checked after the refactor.

When changing this row later, test both:

```text
narrow Web/mobile width
Android
```

---

# 25. Deleted Auth user cleanup

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

Bulk Admin SDK `deleteUsers([...])` may not trigger identical per-user cleanup and needs a separately verified path if used.

---

# 26. Cost/read discipline

Pilot target:

```text
40–50 users
```

Rules:

```text
avoid per-widget Firestore queries
avoid hidden Web reads for disabled features
centralize chat unread streams
reuse UID-keyed user/avatar caches
do not duplicate canonical business events
local visual hide stays local
rotation draft stays local until Apply
write reorder only once on Apply
```

EpiLite should reuse existing services/gateways where behavior is truly shared.

Do not create parallel Web-specific Firestore collections merely because presentation differs.

---

# 27. Current deferred / next work

Original priority before EpiLite diversion:

```text
1. Chats unread counter
   → DONE
   → f0a2084

2. SpacesBar UI
   → stationary outer frame
   → true cyclic/infinite swipe
   → glow tuning

3. Spaces Hub UI/settings
   → ⋮
   → show/hide Spaces
   → regular/compact
   → 7–8
   → >8
   → odd final tile

4. technical cleanup
   → old *MessageId names toward presentationId

5. FCM token lifecycle investigation
   → unregisterCurrentDevice / signOut

6. Calendar foundation

7. Buses foundation
```

EpiLite Web Lite foundation:

```text
DONE
→ a488c3b
```

Possible future EpiLite phases:

```text
Web push foundation
full Chats on Web
explicit Contacts support policy
responsive desktop/tablet layout
full Web feature parity
```

Do not expand these by accident during unrelated Android work.

---

# 28. New-chat startup checklist

At the beginning of a new Epistola development chat, first verify:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read from the current feature branch:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Priority:

```text
current source code
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Expected functional checkpoint after this block:

```text
a488c3b
feat(web): add EpiLite web client
```

A later docs-only commit may make `HEAD` newer.

Before proposing code, audit the source files relevant to the requested block.

Do not use `main` as the current `v0.8.0` source until release/merge is explicitly verified.
