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

Последний functional checkpoint:

```text
9ebf9ab
feat(spaces): add confirmed substitution call delivery
```

После push:

```text
HEAD = 9ebf9ab
origin/feat/v0.8.0-spaces-substitution-foundation = 9ebf9ab
working tree = CLEAN
```

Предыдущий крупный SpacesBar checkpoint:

```text
123cda1
feat(spaces): add realtime spaces bar notifications
```

`v0.8.0` всё ещё в feature-ветке. Без отдельного Git-подтверждения не считать выполненными merge в `main`, release tag или release declaration.

Последний стабильный release до `v0.8.0`:

```text
v0.7.4 — Avatar Interaction/Card + Notification Controls Foundation
```

---

# 2. Проверки checkpoint 9ebf9ab

Flutter:

```text
flutter.bat test
→ 922 tests passed

flutter.bat analyze
→ No issues found

flutter.bat build apk --release
→ SUCCESS
→ 58.2 MB
```

Во время полного Flutter suite может появляться диагностический JPEG output:

```text
Corrupt JPEG data...
JPEG datastream contains no image
```

Если итог `All tests passed`, это не падение suite.

Git:

```text
git diff --check
→ clean

generated Flutter plugin files
→ восстановлены после последней Flutter-команды
→ в commit не попали
```

Cloud Functions:

```text
node --test functions/test/substitution_call_notification.test.cjs
→ 6/6 passed

npm.cmd --prefix functions run lint
→ no errors
→ остаётся известное предупреждение TypeScript 6.0.3 / @typescript-eslint

npm.cmd --prefix functions run build
→ SUCCESS
```

Firestore Rules:

```text
latest full suite for this block
→ 165/165 passed
```

Production:

```text
confirmedCalls Rules
→ deployed

sendSpacesBarNotification
→ deployed

sendSubstitutionCallNotification
→ deployed
```

Cloud Functions:

```text
region: europe-west1
runtime: Node.js 22
generation: 2nd Gen
```

Manual verification:

```text
future confirmed substitution call
→ personal purple SpacesBar item
→ Epistola technical history entry
→ one substitution push
→ fresh release APK handles unified SpacesBar target
```

---

# 3. Infrastructure

```text
Firebase project: epistola-434b7
Android package: com.epistola.app
Firestore region: eur3
Realtime Database region: europe-west1
Cloud Functions region: europe-west1
Primary platform: Android
Pilot target: 40–50 users
```

Cost principles:

```text
minimum unnecessary Firestore reads/writes
no per-widget Firestore queries
reuse UID-keyed caches
keep presentation state local when server authority is unnecessary
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
2–3 safe related steps at a time
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

Working modules:

```text
Чаты
"Список"
```

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

SpacesBar capability:

```text
canManageSpacesBar
member = false
brigadier = true
owner = true
```

UI visibility is not the security boundary. Rules independently protect writes.

---

# 7. General SpacesBar

Authoritative document:

```text
spaces/spacesBar
```

Schema v1 stores:

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

Lifetimes:

```text
1 hour
12 hours
24 hours
until cancelled
```

Accents:

```text
1h → green
12h → blue
24h → orange
untilCancelled → red
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

# 8. Canonical confirmed substitution call

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

Exactly-once protection still comes from deleting the authoritative pending call in the same transaction.

Confirmed-call gateway:

```text
SubstitutionConfirmedCallFirestoreGateway
```

Production query:

```text
confirmedCalls.where("userId", isEqualTo: currentUserId)
```

Supports load + watch, validates document shape and requires document.id == callId.

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

# 9. Personal substitution SpacesBar

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

# 10. Personal call expiry and local hide

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

`SpacesPage` schedules a local Timer for the nearest visible expiry and recalculates on app resume. No Firestore write is needed at 08:00/20:00.

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

A call for a shift that has already started can remain in technical history while no longer being active in SpacesBar.

---

# 11. Current SpacesBar UI

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

Current implementation still uses separate finite PageView cards.

Deferred presentation-only:

```text
stationary outer frame
true cyclic/infinite swipe
glow tuning
```

---

# 12. Unified SpacesBar push target

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

Target matching supports:

```text
item.presentationId == target
```

plus legacy general:

```text
item.generalMessageId == target
```

Explicit valid push target stays stronger than a newer realtime item until the user manually moves away.

Local hide remains stronger than push-target forcing.

---

# 13. General SpacesBar push

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

Helper validates callId, recipient userId, calendar date and day/night shift kind.

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

# 16. Gull assets

Runtime:

```text
assets/images/epistola_app_icon.png
assets/images/epistola_seagull_stencil.png
```

Master artwork in repository root:

```text
Аватар Чайки.png
Аватар Чайки трафарет.png
```

Current usage:

```text
epistola_app_icon.png → technical chat avatar
epistola_seagull_stencil.png → empty SpacesBar
```

Important:

```text
Android launcher icon was NOT replaced in checkpoint 9ebf9ab.
```

---

# 17. "Список" flow after current checkpoint

Existing foundation:

```text
participants
rotation queue
availability
vacation / sick
participant management
work display name
call participant
Undo
pending call persistence
recovery
exactly-once finalization
monthly/yearly statistics
confirmedCall
personal SpacesBar
technical history
confirmed-call push
Rules
```

Expected call flow:

```text
manager calls participant
→ pendingCall
→ 6-second Undo window
```

Undo:

```text
pending cancelled
→ no confirmedCall
→ no personal SpacesBar
→ no technical history entry
→ no confirmed-call push
```

No Undo:

```text
finalization transaction
→ statistics
→ confirmedCall
→ pending deleted
→ personal SpacesBar
→ technical history
→ substitution push
```

All downstream surfaces project the same canonical event rather than creating duplicate authoritative records.

Owner protections remain highest priority.

---

# 18. Existing Messenger foundations

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

# 19. Do not regress

Do not:

```text
weaken owner priority/protections
move transaction invariants into UI
use UI role visibility as only security
store Flutter Color/presentation state in Firestore
turn local hide into server writes
count personal calls against general 3/3
create generic systemMessages backend
turn Epistola history into fake normal chat
generate second push from technical chat
break legacy chat deep links
break legacy general spacesBarMessageId payload
let newer realtime state override explicit valid push target
add per-widget Firestore queries
```

---

# 20. Deferred / next chat

Completed in `9ebf9ab`:

```text
confirmedCall canonical event
personal substitution SpacesBar
local personal hide
local shift-start expiry
Epistola read-only technical history
gull runtime assets
unified SpacesBar presentation IDs
substitution confirmed-call push
exact target support
production Rules / Function deploys
manual physical-device verification
```

Deferred:

```text
stationary SpacesBar frame
true infinite/cyclic swipe
glow tuning
Spaces tile configuration
regular/compact tile modes
>8 continuation
legacy "*MessageId" naming cleanup
actual Android launcher icon replacement
```

Do not silently mix these into unrelated work.

---

# 21. New-chat startup checklist

Run:

```powershell
git.exe branch --show-current
git.exe status --short
git.exe rev-parse --short HEAD
git.exe rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Expected functional point before a later docs commit:

```text
branch = feat/v0.8.0-spaces-substitution-foundation
HEAD = 9ebf9ab
origin = 9ebf9ab
working tree = CLEAN
```

After a docs-only commit HEAD may be newer, but `9ebf9ab` remains the last functional checkpoint.

Then read from CURRENT FEATURE BRANCH:

```text
current source
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

Do not start from `main`.

Do not treat old temporary handoff files as canonical after these docs are installed.

No commit / push / deploy without explicit user approval.
