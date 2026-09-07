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

# Current development status

| Параметр | Значение |
|---|---|
| Target | `v0.8.0` |
| Stage | `Spaces / Substitution / SpacesBar` |
| Branch | `feat/v0.8.0-spaces-substitution-foundation` |
| Last functional checkpoint | `544fcaf` |
| Substitution list editor | `85238a2` |
| Deleted-user cleanup | `e7ac582` |
| Android launcher icon | `544fcaf` |
| Previous confirmed-call checkpoint | `9ebf9ab` |
| Stable baseline before v0.8.0 | `v0.7.4` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Platform | Android |

`v0.8.0` is still a feature-branch target and has not yet been declared merged/released.

A later docs-only commit may make HEAD newer than `544fcaf`.

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

Presentation-only state should not be persisted as authoritative backend data.

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

Working applications:

```text
Чаты
"Список"
```

Current placeholders:

```text
Судозаходы
Календарь смен
Автобусы
ОТ и ТБ
```

Planned next application foundations include:

```text
Календарь смен
Автобусы
```

Their product/data contracts must be defined before implementation rather than inferred from the placeholder tiles.

---

# "Список" / Substitution

Current foundation includes:

```text
participants
canonical rotation queue
availability
vacation/sick hidden slots
removed hidden membership slots
participant management
new-participant one-time top priority
restore at saved hidden anchor
work display name
call flow
Undo
pending-call persistence
recovery
exactly-once finalization
monthly/yearly statistics
confirmedCall event
personal SpacesBar
Epistola technical history
confirmed-call push
atomic list editor
Firestore Rules
```

Owner remains highest priority.

---

# Participant membership semantics

Participant statuses:

```text
active
vacation
sick
removed
```

Vacation, sick and removed participants remain in the canonical rotation.

Normal:

```text
Удалить из списка
```

means:

```text
status = removed
```

not physical participant-document deletion.

A truly new participant receives one-time priority at the top.

A previously removed participant is restored at the current hidden canonical anchor and does not regain top priority.

This prevents remove/re-add from gaming the queue.

---

# Rotation list editor

Available to:

```text
brigadier
owner
```

Entry:

```text
"Список"
→ Настройки
→ Режим редактирования списка
```

Editing is local until Apply:

```text
↑ / ↓
→ local draft only
→ 0 Firestore reorder writes
```

Inactive vacation/sick/removed slots stay fixed while active participants move around them.

Apply:

```text
atomic Firestore transaction
normalize canonical participant rotationOrder to 0..N-1
write only changed rotationOrder fields
preserve unrelated concurrent availability/status
advance monotonic mutation marker
```

Conflict protection checks the source order/composition and module baseline.

Conflict UI:

```text
Список изменился. Откройте режим редактирования заново.
```

Cancel discards the draft without writes.

The list preserves the moved row near the same finger position. A frame lock prevents rapid overlapping taps from crashing Flutter; ultra-fast overlapping taps may be dropped.

---

# Substitution gateway split

Participant writes are now intentionally separated:

```text
SubstitutionParticipantStateFirestoreGateway
→ ordinary state operations

SubstitutionRotationMembershipFirestoreGateway
→ add / restore / soft remove

SubstitutionRotationEditFirestoreGateway
→ atomic whole-list reorder
```

The separation keeps transaction invariants below UI and independently testable.

---

# Deleted Auth user cleanup

A backend Auth-delete cleanup removes:

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

# General SpacesBar

Authoritative board:

```text
spaces/spacesBar
```

Manager roles:

```text
brigadier
owner
```

General announcement capacity:

```text
3 active messages
```

Lifetimes / accents:

```text
1h → green
12h → blue
24h → orange
until cancelled → red
```

General local hide:

```text
SharedPreferences
spaces_bar.hidden_message_ids.v1.<uid>
```

No Firestore write is performed for local hide.

---

# Personal substitution SpacesBar

Successful call finalization creates:

```text
spaces/substitution/confirmedCalls/{callId}
```

Finalization:

```text
update statistics
create confirmedCall
delete pendingCall
```

Presentation IDs:

```text
general:<messageId>
substitution:<callId>
```

Personal calls do not consume general `3/3` capacity.

A personal call remains active until shift start:

```text
day → 08:00 local
night → 20:00 local
```

Personal local hide:

```text
spaces_bar.hidden_substitution_call_ids.v1.<uid>
```

Confirmed-call history remains after the SpacesBar item expires.

---

# Unified SpacesBar push target

Typed push model supports:

```text
chat
spacesBar
```

Unified field:

```text
spacesBarPresentationId
```

Values:

```text
general:<messageId>
substitution:<callId>
```

Backward compatibility remains for:

```text
legacy chatId
legacy spacesBarMessageId
```

Some internal routing APIs still use `*MessageId` names while carrying presentation IDs. This remains deferred naming debt.

---

# Push functions

General SpacesBar:

```text
sendSpacesBarNotification
```

Substitution call:

```text
sendSubstitutionCallNotification
```

Substitution recipient lookup:

```text
users/{calledUserId}/devices
```

Payload:

```text
deepLinkType = spacesBar
spacesBarPresentationId = substitution:<callId>
notificationMode = sound
```

Channel:

```text
epistola_spaces_bar_v1
```

Sound:

```text
seagull_notification
```

No separate push is generated by technical history.

---

# Epistola technical chat

Private chats include read-only technical row:

```text
Epistola
Технические сообщения
```

This is not a normal chat.

There is no fake `chats` record and no generic `systemMessages` collection.

Source:

```text
confirmedCalls
→ system message mapper/source/service
→ EpistolaSystemChatScreen
```

Current boundary:

```text
no composer
no send
no delete/clear
no reactions
no typing
no read receipts
no unread badge
```

---

# Gull artwork / Android launcher icon

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

The Android launcher icon is now replaced with approved gull artwork in all five mipmap density folders.

Physical-device verification passed.

---

# Verification

Current functional commits:

```text
85238a2
feat(spaces): add substitution list editing

e7ac582
feat(auth): clean deleted users from spaces

544fcaf
chore(android): update launcher icon
```

Checks:

```text
flutter.bat test
→ 978 passed

flutter.bat analyze
→ No issues found

release APK
→ SUCCESS
→ 58.4 MB

rotation/editor targeted tests
→ 38/38

substitution Firestore Rules
→ 56/56

deleted-user cleanup tests
→ 4/4

Functions lint
→ no errors

Functions build
→ SUCCESS
```

Production/manual:

```text
latest substitution Rules deployed
deleted-user cleanup deployed
phone Apply persistence test passed
Cancel test passed
vacation hidden-slot behavior passed
rapid-tap crash regression passed
Android launcher icon passed
```

---

# Known queued issue

Observed separately:

```text
owner may receive a copy of a substitution notification
intended for the called user
```

Current suspicion is stale FCM token state after account switching, but this is not verified.

Investigate device-token unregister/logout lifecycle separately; do not modify rotation/call business logic until root cause is proven.

---

# Planned next work

After the current checkpoint and new-chat handoff:

```text
1. verify branch / status / HEAD / origin
2. read current source and canonical docs
3. continue remaining agreed roadmap work without reconstructing old decisions
4. develop dedicated foundation for Календарь смен
5. develop dedicated foundation for Автобусы
```

For `Календарь смен` and `Автобусы`, the current repository only establishes placeholder Spaces tiles. The next chat should first define the intended product/domain/storage/security contract from the current source and user requirements, then implement each foundation in small verifiable steps.

Other deferred work:

```text
stationary SpacesBar frame
true cyclic/infinite swipe
glow tuning
Spaces tile configuration
regular/compact layout
>8 continuation
legacy SpacesBar "*MessageId" naming cleanup
```

---

# Source of truth for new chats

Before new work:

```powershell
git branch --show-current
git status --short
git rev-parse --short HEAD
git rev-parse --short origin/feat/v0.8.0-spaces-substitution-foundation
```

Then read from the current feature branch:

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

A docs-only commit may make HEAD newer.

Do not use `main` as the source of current `v0.8.0` state until release/merge is explicitly completed.
