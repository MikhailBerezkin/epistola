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

Текущий локальный functional checkpoint:

```text
544fcaf
chore(android): update launcher icon
```

Функциональные commits последнего завершённого блока:

```text
85238a2
feat(spaces): add substitution list editing

e7ac582
feat(auth): clean deleted users from spaces

544fcaf
chore(android): update launcher icon
```

Предыдущий крупный Spaces/Substitution checkpoint:

```text
9ebf9ab
feat(spaces): add confirmed substitution call delivery
```

Предыдущий SpacesBar realtime checkpoint:

```text
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

На момент подготовки этого документа новые functional commits ещё не были финально запушены после документационного обновления. В новом чате обязательно проверять фактические `HEAD` и `origin`, а не выводить их из текста документа.

---

# 2. Финальные проверки текущего functional checkpoint

Flutter:

```text
flutter.bat test
→ 978 tests passed

flutter.bat analyze
→ No issues found

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

Targeted rotation/editor suite:

```text
38/38 passed
```

Firestore Rules — последний targeted substitution suite:

```text
56/56 passed
0 failed
```

Cloud Functions — deleted-user cleanup:

```text
node --test functions/test/deleted_user_cleanup.test.cjs
→ 4/4 passed

npm.cmd --prefix functions run lint
→ no errors
→ остаётся известное предупреждение TypeScript 6.0.3 /
   @typescript-eslint supported range

npm.cmd --prefix functions run build
→ SUCCESS
```

Git:

```text
git diff --check
→ clean

git diff --cached --check
→ clean перед functional commits

generated Flutter plugin files
→ восстановлены после последней Flutter-команды
→ в functional commits не попали
```

Production/manual verification:

```text
latest substitution Firestore Rules
→ deployed

deleted-user cleanup Function
→ deployed и проверен ранее в этом блоке

fresh release APK 58.4 MB
→ проверен на физическом Android-телефоне

Android launcher gull icon
→ отображается

Substitution list editor:
→ открыть режим редактирования
→ переместить участника
→ Применить
→ закрыть/повторно открыть "Список"
→ новый порядок сохраняется

Отмена:
→ локальный draft отбрасывается
→ сохранённый порядок не меняется

vacation participant:
→ hidden canonical slot behavior проверен

rapid arrow taps:
→ Flutter assertion/crash больше не воспроизводится
→ сверхбыстрые overlapping taps могут безопасно отбрасываться frame-lock'ом
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
Primary platform: Android
Pilot target: 40–50 users
```

Cost principles:

```text
minimum unnecessary Firestore reads/writes
no per-widget Firestore queries
reuse UID-keyed caches
keep presentation state local when server authority is unnecessary
list reorder writes only once on Apply
avoid duplicate authoritative business records
```

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

Generated plugin files restore once after the final Flutter command in a series.

---

# 5. Spaces root and Hub

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

Messenger remains internal:

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
"Список"
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Currently implemented/working Spaces applications:

```text
Чаты
"Список"
```

Currently unimplemented/placeholders:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Planned next product work after the current checkpoint includes dedicated foundations for:

```text
Календарь смен
Автобусы
```

Do not invent their backend/domain contract from the placeholder UI. In the next chat first audit current source and then define each foundation deliberately before implementation.

Deferred tile UX:

```text
<=6 → regular
7–8 → compact, no subtitles
odd final tile → full width
>8 → vertical scroll
⋮ → future show/hide/reorder
```

---

# 6. Spaces roles

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
canManageSpacesBar

member = false
brigadier = true
owner = true
```

UI visibility is not the security boundary. Firestore Rules independently protect authoritative writes.

---

# 7. General SpacesBar

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

---

# 8. Personal substitution SpacesBar

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

# 9. Personal call expiry and local hide

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

# 10. Current SpacesBar UI

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

---

# 11. Unified SpacesBar push target

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

These old names can now carry a unified presentation ID. Do not rename them during unrelated work.

Explicit valid push target stays stronger than newer realtime state until user navigation releases the target.

Local hide remains stronger than push-target forcing.

---

# 12. General SpacesBar push

Function:

```text
sendSpacesBarNotification
```

Trigger:

```text
onDocumentWritten("spaces/spacesBar")
```

Push only for exactly one valid new general announcement.

Recipients:

```text
collectionGroup("devices")
→ dedupe
→ exclude publisher tokens
→ multicast <=500
→ cleanup invalid token docs
```

Channel:

```text
epistola_spaces_bar_v1
```

Sound:

```text
seagull_notification
```

---

# 13. Canonical confirmed substitution call

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

# 14. Substitution confirmed-call push

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

---

# 15. Epistola technical chat

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

Listener exists only while technical screen is open. `ChatsPage` does not keep a confirmedCalls preview listener; subtitle stays static.

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

---

# 16. Participant statuses and membership semantics

Canonical participant path:

```text
spaces/substitution/participants/{userId}
```

Current statuses:

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
→ hidden from List/Vacation/Sick tabs
→ retains canonical rotation slot
→ can later be restored
```

Normal substitution action:

```text
Удалить из списка
```

is a soft removal:

```text
status = removed
```

It is NOT a client physical document delete.

Client Rules deny physical participant delete.

Auth-user deletion is a separate privileged backend cleanup path.

---

# 17. Hidden canonical slot invariant

Vacation, sick and removed participants remain in the canonical rotation.

Example:

```text
A
B (vacation)
C
D
```

Move active participant `C` one visible place up:

```text
C
B (vacation)
A
D
```

`B` keeps the hidden canonical slot.

Calls and list reorders operate active participants around hidden participants.

When vacation/sick participant becomes active again, or removed participant is restored, that participant returns at the canonical position reached while hidden.

This invariant is required to prevent invisible participants from losing queue history.

---

# 18. New participant and restore semantics

Truly new, never-before-added participant:

```text
→ one-time priority at top
```

After normal calls the participant follows ordinary rotation.

Previously removed participant:

```text
remove
→ status = removed
→ document and anchor remain

restore
→ status = active
→ restore at current hidden canonical anchor
→ NOT at top
```

Repeat remove/add cannot grant repeated new-user priority.

The system distinguishes:

```text
never participated before
vs
participated before but currently removed
```

---

# 19. Gateway responsibility split

State-only participant gateway:

```text
SubstitutionParticipantStateFirestoreGateway
```

Transactional membership gateway:

```text
SubstitutionRotationMembershipFirestoreGateway
```

Rotation editor gateway:

```text
SubstitutionRotationEditFirestoreGateway
```

Reason for separation:

```text
ordinary participant state mutation
≠ membership mutation
≠ whole-list reorder
```

These operations have different Firestore transaction invariants and must remain independently testable.

Former file/class naming was cleaned up accordingly.

---

# 20. Substitution rotation draft

Domain:

```text
SubstitutionRotationDraft
```

Stores:

```text
original canonical participants
current local participants
```

Entry into editor:

```text
load authoritative edit baseline
→ snapshot current canonical participants
→ local draft
```

Before Apply:

```text
0 Firestore writes
```

Arrow semantics:

```text
↑ → one visible active place up
↓ → one visible active place down
```

Inactive vacation/sick/removed slots are skipped as visible move targets but retain their canonical positions.

Before persistence:

```text
normalizedParticipants()
→ full canonical rotationOrder = 0..N-1
```

---

# 21. Rotation edit service and baseline

Application service:

```text
SubstitutionRotationEditService
```

Baseline:

```text
SubstitutionRotationEditBaseline
```

Fields:

```text
nextRotationOrder
revision
```

Apply result:

```text
noChanges
applied
conflict
```

No changes:

```text
→ exit editor
→ no reorder write
```

Applied:

```text
→ atomic transaction committed
→ exit editor
→ realtime canonical list becomes authoritative
```

Conflict:

```text
→ discard stale edit session
→ show:
Список изменился. Откройте режим редактирования заново.
```

---

# 22. Atomic rotation Apply

`SubstitutionRotationEditFirestoreGateway` validates within the transaction:

```text
module nextRotationOrder marker
module revision
pending call absence
participant composition
participant existence
original rotationOrder of each participant
```

It writes only changed:

```text
rotationOrder
```

Concurrent fields that are not the editor's responsibility must not be overwritten, including:

```text
availability
status
```

Successful Apply normalizes participant `rotationOrder`:

```text
0..N-1
```

but does NOT normalize module `nextRotationOrder` to N.

Editor Apply advances:

```text
nextRotationOrder = previous nextRotationOrder + 1
```

`nextRotationOrder` therefore also acts as a monotonic mutation/edit marker.

Do not reinterpret it as always equal to participant count.

---

# 23. Membership transaction behavior

`SubstitutionRotationMembershipFirestoreGateway` baseline includes:

```text
moduleExists
nextRotationOrder
revision
ordered participants
pending-call state
```

Add/restore:

```text
pending call → reject
verify baseline
new participant → create with new-participant priority
removed participant → restore existing hidden anchor
existing non-removed participant → no duplicate
```

Soft remove:

```text
pending call → reject
missing target → error
already removed → idempotent
verify module/order/status baseline
status = removed
preserve rotationOrder
preserve availability
advance mutation marker
```

First-create case can create/initialize the substitution module as required by the existing gateway contract.

---

# 24. Firestore Rules for membership/editor

Rules now recognize:

```text
active
vacation
sick
removed
```

Ordinary participant state updates must not bypass membership semantics involving `removed`.

Manager-only membership/reorder authorization:

```text
brigadier
owner
```

Rules validate required transaction shape, including applicable:

```text
module mutation marker
pending-call absence
new participant creation
restore
soft remove
rotationOrder updates
```

Client physical participant delete:

```text
denied
```

Current targeted suite:

```text
56/56 passed
```

Latest Rules were deployed before physical-device Apply verification.

---

# 25. Rotation editor UI

Entry:

```text
"Список"
→ Настройки
→ Режим редактирования списка
```

Available only to:

```text
brigadier
owner
```

Entering editor:

```text
beginEditing()
→ server baseline
→ local draft
→ switch to active List tab
```

While editing:

```text
title = Редактирование списка
normal "Вызвать" hidden
participant ⋮ / card hidden
statistics hidden
settings disabled
active rows show ↑ / ↓
bottom actions = Отмена / Применить
```

`Применить` active only when draft has real changes.

During Apply:

```text
Отмена disabled
arrows ignored
Применить shows Применение...
```

Back/system Back cancels local edit session when Apply is not in progress.

---

# 26. Editor scroll / rapid-tap stabilization

The active list keeps the moved participant approximately under the same physical finger position.

Implementation concept:

```text
measure row global Y before move
→ mutate local draft
→ post-frame measure same row after rebuild
→ compensate ScrollController offset
```

Edit-only scroll reserve allows movement to continue near the first/last active position.

A one-frame move lock prevents overlapping row-key/rebuild operations.

Expected behavior:

```text
normal/fast repeated taps
→ participant can move repeatedly
→ no Flutter assertion

ultra-fast overlapping taps
→ some taps may be intentionally dropped
```

This is presentation logic only and must not alter domain/business semantics.

---

# 27. Deleted Auth user cleanup

Dedicated Cloud Function handles ordinary single-user Auth deletion.

Cleanup targets:

```text
users/{uid}
→ including device-token documents

spaces/substitution/participants/{uid}

spaces_access/{uid}
```

Preserved:

```text
confirmedCalls
statistics
chats
messages
historical business data
```

Ordinary single Auth deletion was manually verified in production.

Important caveat:

```text
Admin SDK bulk deleteUsers([...])
may not fire per-user Auth onDelete handlers
```

Do not assume bulk-delete parity without a dedicated verified path.

Auth deletion and substitution soft removal are intentionally different semantics.

Current hidden-anchor behavior does not provide stable business identity across delete/recreate with a new UID.

---

# 28. Android launcher icon / gull assets

Runtime:

```text
assets/images/epistola_app_icon.png
assets/images/epistola_seagull_stencil.png
```

Master artwork:

```text
Аватар Чайки.png
Аватар Чайки трафарет.png
```

Android launcher icon is now replaced in:

```text
mipmap-mdpi
mipmap-hdpi
mipmap-xhdpi
mipmap-xxhdpi
mipmap-xxxhdpi
```

Commit:

```text
544fcaf
chore(android): update launcher icon
```

Fresh release APK was verified on physical phone.

---

# 29. Existing Messenger foundations

Private chats:

```text
text
images
pagination
logical delete
push deep links
read receipts ✓ / ✓✓
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
👍 / 👎 reactions
identity/member cards
notification controls
```

Message history:

```text
pagination 20
older-page loading
scroll preservation
realtime merge
date separators
floating date indicator
image-aware scroll behavior
```

---

# 30. Known queued notification issue

Observed separately from the rotation editor:

```text
owner may receive a copy of a substitution notification
that was intended for the called user
```

Current suspicion:

```text
stale FCM device token after account switching
```

This is NOT yet verified.

Later investigation should inspect logout/device token lifecycle, including occurrences of:

```text
unregisterCurrentDevice
signOut
```

Do not modify substitution rotation/call semantics to fix this before proving the root cause.

---

# 31. Do not regress

Do not:

```text
weaken owner priority/protections
move transaction invariants into UI
use UI role visibility as only security
physically delete participant for normal "Удалить из списка"
give restored participant repeated new-user top priority
destroy hidden vacation/sick/removed anchors
write Firestore on every editor arrow tap
overwrite concurrent availability/status during reorder
normalize nextRotationOrder to participant count
allow stale edit session to silently overwrite concurrent list change
store Flutter Color/presentation state in Firestore
turn SpacesBar local hide into server writes
count personal calls against general 3/3
create generic systemMessages backend
turn Epistola history into fake normal chat
generate a second push from technical history
break legacy chat deep links
break legacy general spacesBarMessageId payload
add per-widget Firestore queries
```

---

# 32. Deferred / next development

Completed in the current functional block:

```text
removed hidden membership state
new participant one-time top priority
restore removed participant at hidden anchor
transactional membership gateway
participant state gateway naming split
rotation draft
rotation edit service
atomic reorder gateway
manager-only editor UI
active-arrow scroll stabilization
rapid-tap frame lock
membership/editor Rules
deleted Auth user cleanup
Android launcher icon replacement
phone production verification
```

Previously completed foundation remains active:

```text
confirmedCall canonical event
personal substitution SpacesBar
local personal hide
shift-start expiry
Epistola read-only technical history
unified SpacesBar presentation IDs
substitution confirmed-call push
exact target support
```

Queued follow-up:

```text
investigate possible stale FCM token / duplicate recipient behavior
```

Planned new Spaces application work:

```text
Календарь смен
Автобусы
```

For both new applications:

```text
first audit current placeholder/source
define product/domain/data/security boundary
then implement as separate foundations
keep UI replaceable
minimize Firebase usage
do not couple them to Substitution internals unless a real shared contract is identified
```

Other deferred work:

```text
stationary SpacesBar frame
true infinite/cyclic swipe
glow tuning
Spaces tile configuration
regular/compact tile modes
>8 continuation
legacy "*MessageId" naming cleanup
```

---

# 33. New-chat startup checklist

At the beginning of the next chat run:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read from CURRENT FEATURE BRANCH:

```text
current source
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Priority:

```text
source
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Last functional checkpoint documented here:

```text
544fcaf
```

A later docs-only commit may make HEAD newer.

Do not start from `main`.

Do not treat historical temporary handoff files as canonical after these docs are installed.

No commit / push / deploy without explicit user approval.
