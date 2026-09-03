# Epistola — SpacesBar Handoff / Q&A
Дата: 2026-09-03

## 0. Как использовать этот файл

Этот файл — подробный переход между чатами по текущей работе над SpacesBar.

При конфликте источников использовать приоритет:

```text
исходный код текущей ветки
→ этот handoff
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Важно: `PROJECT_CONTEXT.md`, `ARCHITECTURE.md` и `README.md` на текущем HEAD всё ещё описывают SpacesBar как future/design direction и частично содержат старую контрольную точку. Текущий исходный код после следующего commit/push будет авторитетнее этих устаревших разделов.

---

# 1. Текущая Git-контрольная точка перед commit/push

Repository:

```text
MikhailBerezkin/epistola
```

Branch:

```text
feat/v0.8.0-spaces-substitution-foundation
```

HEAD до текущих локальных SpacesBar-изменений:

```text
d4bcda1
```

Текущая работа над SpacesBar пока локальная и должна быть закоммичена и запушена перед переходом в новый чат.

---

# 2. Что уже было сделано до SpacesBar

Главный экран Epistola уже переведён на Spaces-first navigation.

Текущий root:

```text
Контакты | Пространства | Профиль
```

Default:

```text
Пространства
```

Messenger доступен через:

```text
Пространства
→ Чаты
```

Текущий production module:

```text
"Список"
```

Остальные плитки Spaces пока placeholders.

---

# 3. SpacesBar — продуктовые решения в формате вопрос / ответ

## Вопрос: Что такое SpacesBar?

Ответ:

SpacesBar — постоянная информационная область на экране `Пространства`, расположенная над сеткой плиток.

Она предназначена для общих закреплённых сообщений и, позже, для персонального вызова из `"Списка"`.

---

## Вопрос: Что реализуем сейчас?

Ответ:

Сейчас реализуется только первая версия:

```text
общие закреплённые сообщения
```

Их создают:

```text
brigadier
owner
```

Их читают обычные пользователи, включая пользователей со статусом guest в текущей Contacts/Users-модели, после того как Security Rules будут привязаны к реальной существующей модели доступа.

Персональный substitution call в SpacesBar сейчас НЕ реализуется.

Он будет добавлен позже, когда будет расширяться call flow `"Списка"`.

---

## Вопрос: Кто может публиковать и удалять общие закреплённые сообщения?

Ответ:

Только:

```text
brigadier
owner
```

Для этого в domain уже добавлена capability:

```dart
canManageSpacesBar
```

Результат:

```text
member     → false
brigadier  → true
owner      → true
```

`owner` остаётся highest-priority role.

---

## Вопрос: Кто видит сообщения?

Ответ:

Все допустимые участники Epistola/Contacts, включая guest-статус.

Но Firestore Rules ещё НЕ реализованы.

Перед Rules новый чат должен сначала проверить существующую реализацию users/contacts/guest в `firestore.rules` и соответствующих сервисах.

Нельзя автоматически заменить это условием:

```text
request.auth != null
```

пока не изучена реальная модель доступа.

---

## Вопрос: Сколько общих закреплённых сообщений может быть одновременно?

Ответ:

Максимум:

```text
3 active common messages
```

Это не UI-only ограничение.

Оно должно быть защищено transaction/server-side логикой от race condition.

Сценарий:

```text
brigadier A видит 2/3
brigadier B видит 2/3
оба одновременно публикуют
```

не должен привести к:

```text
4/3
```

Текущий transaction gateway уже защищает это через Firestore transaction.

---

## Вопрос: Что происходит, если уже есть 3 активных сообщения?

Ответ:

Никакой тихой замены.

Пользователь должен:

```text
удалить одно сообщение
или
дождаться его истечения
```

Нельзя автоматически удалять самое старое.

---

## Вопрос: Максимальная длина текста?

Ответ:

```text
250 символов
```

Это окончательно согласованное значение для первой версии.

Domain и gateway уже валидируют это ограничение.

---

## Вопрос: Какие сроки действия доступны?

Ответ:

```text
1 час
12 часов
24 часа
До отмены
```

Domain enum:

```text
oneHour
twelveHours
twentyFourHours
untilCancelled
```

Default duration отсутствует.

Если publisher пытается опубликовать сообщение без выбранного срока, UI должен показать:

```text
Выберите срок действия
```

Нельзя автоматически выбирать 12 часов или другой вариант.

---

## Вопрос: Какие цвета соответствуют срокам?

Ответ:

Только presentation layer:

```text
1 час       → зелёный
12 часов    → синий
24 часа     → оранжевый
До отмены   → красный
```

Цвет НЕ хранится в Firestore/domain.

---

## Вопрос: Как определяется истечение?

Ответ:

Для конечных сроков:

```text
expiresAt = createdAt + lifetime
```

Но `expiresAt` отдельно в Firestore НЕ хранится.

Он вычисляется в domain.

Для:

```text
untilCancelled
```

expiration отсутствует.

---

## Вопрос: Почему `createdAt` пишется через serverTimestamp?

Ответ:

Чтобы canonical время публикации задавал Firestore server, а не телефон publisher.

Новый message получает:

```text
FieldValue.serverTimestamp()
```

Существующие сообщения при rewrite сохраняют исходный `Timestamp`.

---

## Вопрос: Что происходит с истёкшими сообщениями?

Ответ:

Client сразу считает их неактивными.

Не нужен Cloud Function ровно в момент expiration.

При следующей write-operation доски:

```text
publish
delete
```

истёкшие записи удаляются из board document.

То есть:

```text
expired → сразу скрывается client-side
expired → физически очищается при следующей записи
```

---

## Вопрос: Можно ли редактировать опубликованный текст?

Ответ:

Нет.

Первая версия:

```text
delete
+
republish
```

Это специально упрощает schema, Rules и историю изменений.

---

## Вопрос: Как работает глобальное удаление?

Ответ:

В editor brigadier/owner может удалить любое common pinned message.

Перед удалением:

```text
Удалить закреплённое сообщение для всех?
```

Кнопки:

```text
Отмена
Удалить
```

Глобальное delete выполняется через тот же transaction foundation.

---

## Вопрос: Что такое локальное `Убрать сообщение`?

Ответ:

Это совсем другой механизм.

Long press на SpacesBar message:

```text
Убрать сообщение
Отмена
```

`Убрать сообщение`:

```text
только локально для текущего пользователя
```

Firestore write НЕ выполняется.

Сообщение остаётся:

```text
для других пользователей
для publisher
в authoritative board
```

Brigadier/owner также может локально убрать сообщение для себя.

Глобальный delete остаётся только в editor.

---

## Вопрос: Где хранить локально скрытые сообщения?

Ответ:

В local preferences / local storage.

Не хранить:

```text
hiddenBy
seenBy
dismissedBy
```

в Firestore.

Это важно для Firebase free-tier и 40–50-user pilot.

Перед реализацией нужно посмотреть существующий SharedPreferences/local-preferences pattern проекта и использовать тот же подход.

---

## Вопрос: Что делать, если скрыто последнее видимое сообщение?

Ответ:

Показывать neutral/logo SpacesBar.

Не показывать:

```text
"вы скрыли все сообщения"
```

и не создавать специальный backend state.

---

## Вопрос: Может ли новый push снова показать локально скрытое старое сообщение?

Ответ:

Нет.

Если messageId находится в local hidden IDs, повторный push того же messageId не должен возвращать его в carousel.

---

## Вопрос: Какая должна быть высота SpacesBar?

Ответ:

Он располагается:

```text
на всю ширину содержимого Spaces
с теми же боковыми отступами, что grid
над плитками
```

Высота примерно соответствует текущему свободному месту под grid на ранее обсуждавшемся screenshot, но должна быть responsive для маленьких телефонов.

Даже когда сообщений нет, область должна оставаться визуально стабильной.

---

## Вопрос: Что показывать в пустом состоянии?

Ответ:

Neutral Epistola/logo state.

Допустимый текст для общего empty state:

```text
Нет новых закреплённых сообщений
```

Если все сообщения пользователь локально скрыл, предпочтительно оставить просто neutral/logo state без акцента на том, что они были скрыты.

---

## Вопрос: Сколько строк текста показывать?

Ответ:

До:

```text
4 строк
```

Если текст реально не помещается по layout:

```text
Подробнее
```

`Подробнее` показывается только при фактическом overflow, а не по длине строки/количеству символов.

Полный текст открывается в bottom sheet.

---

## Вопрос: Как работает carousel?

Ответ:

Auto rotation:

```text
20 секунд на карточку
```

Manual swipe:

```text
reset timer
```

То есть после ручного перехода новая выбранная карточка получает полный новый 20-second interval.

---

## Вопрос: Какой indicator использовать?

Ответ:

Предпочтение:

```text
dots
```

а не `1/3`, если это нормально выглядит в итоговом UI.

Hidden messages не входят в количество dots.

---

## Вопрос: Как сортировать common messages?

Ответ:

Сначала по lifetime — от самого короткого к самому длинному:

```text
1h
12h
24h
untilCancelled
```

Внутри одинакового lifetime:

```text
newer first
```

Будущий personal substitution call будет иметь отдельный higher-priority placement и не считается частью текущей common-message сортировки.

---

## Вопрос: Как выглядит editor?

Ответ:

Для brigadier/owner:

```text
Активные сообщения N/3
```

Сверху список active messages:

```text
короткий preview
status / remaining time
```

Ниже:

```text
multiline text field
duration selector
Опубликовать
```

Если duration не выбран:

```text
Выберите срок действия
```

Опубликованный message открывается в detail card:

```text
полный текст
created time
duration
remaining time
Удалить
Закрыть
```

Текст опубликованного message не редактируется.

---

## Вопрос: Какая кнопка публикации?

Ответ:

Только:

```text
Опубликовать
```

Не добавлять отдельную кнопку:

```text
Отправить push
```

Push должен быть следствием успешного business event / Firestore write.

---

## Вопрос: Как будет работать push?

Ответ:

Каждая успешная публикация common pinned message должна породить alert.

Notification:

```text
title: Epistola
body: начало/текст закреплённого сообщения
```

Не добавлять в body:

```text
duration
publisher metadata
technical fields
```

Использовать существующие:

```text
Epistola seagull sound
vibration
```

Push должен приходить даже если приложение foreground.

---

## Вопрос: Что делает tap по push?

Ответ:

Если пользователь находится не на Spaces:

```text
tap push
→ открыть Spaces
→ выбрать exact messageId
```

Если пользователь уже находится на Spaces:

```text
не делать forced navigation
→ one-shot refresh board
→ выбрать incoming message
→ reset carousel timer
```

Payload должен содержать как минимум:

```text
event type
messageId
```

Перед реализацией нужно изучить текущие:

```text
functions/
FCM
NotificationService
push deep-link model
deep-link coordinator/resolver
foreground notification behavior
```

Не создавать параллельную push architecture.

---

## Вопрос: Нужен ли постоянный Firestore listener?

Ответ:

Нет.

Обычное открытие Spaces:

```text
one-shot board read
```

Push/resume при необходимости:

```text
one-shot reread
```

Не создавать persistent listener без отдельной причины.

---

## Вопрос: Почему это важно?

Ответ:

Pilot:

```text
40–50 users
```

Нужно минимизировать Firestore reads/writes.

SpacesBar board специально проектируется как один document read.

---

# 4. Утверждённая Firestore data shape

Документ:

```text
spaces/spacesBar
```

Schema:

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

Не хранить:

```text
expiresAt
color
priority
position
seenBy
hiddenBy
cancelledAt
```

в текущей common-message версии.

---

# 5. Почему messages — map, а не array?

Ответ:

`messageId` является key:

```text
messages.<messageId>
```

Это упрощает:

```text
ID uniqueness
Rules changed-key validation
targeted semantic comparison
```

При этом board остаётся одним документом и одним read.

---

# 6. Revision / messageId

Board содержит monotonic:

```text
revision
```

При публикации:

```text
nextRevision = revision + 1
messageId = nextRevision.toString()
```

Expired/deleted IDs не переиспользуются.

Это делает messageId стабильным для:

```text
local hidden IDs
push payload
deep-link selection
```

---

# 7. Уже реализованные source files

## Domain

### `lib/domain/models/spaces_access_role.dart`

Добавлено:

```dart
bool get canManageSpacesBar
```

`brigadier` и `owner` → true.

---

### `lib/domain/models/spaces_bar_message.dart`

Содержит:

```text
SpacesBarMessageLifetime
SpacesBarMessage
maxTextLength = 250
validation
expiration calculation
isActiveAt()
```

Важно:

Domain НЕ делает message inactive только потому, что local clock чуть раньше server-createdAt.

Это намеренно, чтобы новый server-timestamp message не исчезал из-за небольшого clock skew телефона.

---

### `lib/domain/models/spaces_bar_board.dart`

Содержит:

```text
revision
messages
maxMessages = 3
duplicate-ID protection
activeMessagesAt()
hasCapacityAt()
```

---

### `lib/domain/models/spaces_bar_publication_receipt.dart`

Содержит:

```text
messageId
revision
```

---

# 8. Уже реализованные services/gateways

Directory:

```text
lib/services/spaces/spaces_bar/
```

---

## `spaces_bar_board_mapper.dart`

Strict schema mapper.

Проверяет exact board/message fields.

Поддерживает:

```text
schemaVersion = 1
revision >= 0
canonical IDs
250-char text
valid lifetime
createdByUserId
Timestamp createdAt
Timestamp updatedAt
```

`toWriteMap()`:

```text
updatedAt → serverTimestamp
new message createdAt → serverTimestamp
existing createdAt → original Timestamp
```

---

## `spaces_bar_board_firestore_gateway.dart`

One-shot read gateway.

Behavior:

```text
missing document
→ SpacesBarBoard.empty()

valid document
→ mapped board

invalid document
→ StateError
```

Обычный load:

```text
one Firestore document read
```

---

## `spaces_bar_board_transaction_gateway.dart`

Transaction infrastructure:

```text
SpacesBarBoardTransactionRunner
SpacesBarBoardTransactionContext
Firebase implementation
```

### publish()

Flow:

```text
validate text + publisher
→ transaction read board
→ parse
→ active filtering
→ capacity check 3
→ revision + 1
→ create new message
→ prune expired
→ write one board document
→ return publication receipt
```

New `createdAt`:

```text
FieldValue.serverTimestamp()
```

Race condition capacity защищается Firestore transaction.

### deleteMessage()

Flow:

```text
validate messageId
→ transaction read
→ missing board → false
→ invalid board → StateError
→ missing target → false/no write
→ remove selected target
→ prune expired
→ revision + 1
→ write board
→ true
```

Это global delete foundation.

Local hide не использует этот gateway.

---

# 9. Уже добавленные tests

## Role

```text
test/domain/models/spaces_access_role_test.dart
```

Добавлена проверка `canManageSpacesBar`.

Targeted run ранее:

```text
7 tests passed
```

---

## Message domain

```text
test/domain/models/spaces_bar_message_test.dart
```

Покрывает:

```text
lifetime parse
1h / 12h / 24h expiration
untilCancelled
trim
250 accepted
251 rejected
empty values
expiration boundary
```

---

## Board domain

```text
test/domain/models/spaces_bar_board_test.dart
```

Покрывает:

```text
empty
max 3
reject 4
negative revision
duplicate IDs
source-list immutability
active filtering
expired frees capacity
full active board
```

---

## Mapper

```text
test/services/spaces/spaces_bar/spaces_bar_board_mapper_test.dart
```

Покрывает strict parsing/writing и serverTimestamp behavior.

Последний combined domain + mapper targeted result:

```text
33 tests passed
```

---

## Read gateway

```text
test/services/spaces/spaces_bar/spaces_bar_board_firestore_gateway_test.dart
```

Результат:

```text
3 tests passed
```

Покрывает:

```text
missing → empty
valid → one read
malformed → StateError
```

---

## Transaction gateway

```text
test/services/spaces/spaces_bar/spaces_bar_board_transaction_gateway_test.dart
```

Последний результат:

```text
16 tests passed
```

Покрывает publish + global delete.

---

# 10. Последняя проверка перед handoff

Последний targeted transaction test:

```text
00:00 +16: All tests passed!
```

Последний analyzer:

```text
flutter.bat analyze
→ No issues found!
```

Full Flutter suite после добавления текущего SpacesBar foundation в этой сессии ещё не запускался.

Release APK после этих SpacesBar изменений тоже ещё не собирался.

Это не release checkpoint, а промежуточный implementation handoff.

---

# 11. Важная техническая оговорка про время

Новый `createdAt` authoritative:

```text
Firestore serverTimestamp
```

Но внутри client Firestore transaction текущий `now` используется для определения, какие ранее сохранённые сообщения уже expired и могут быть pruned.

Это означает:

```text
cleanup/capacity pruning
```

слегка зависит от clock телефона.

Для pilot это пока принято как допустимое решение.

Не переключать архитектуру молча на callable Cloud Function.

Если server-authoritative expiration внутри publish станет обязательным, сначала отдельно обсудить смену architecture.

---

# 12. Что НЕ реализовано

На момент handoff НЕ реализованы:

```text
Firestore Security Rules для spaces/spacesBar
Rules emulator tests
local hidden-message persistence
SpacesBar UI
empty state UI
carousel
20-second timer
dots
Подробнее bottom sheet
editor UI
duration selector UI
global delete confirmation UI
push trigger
push payload routing
Spaces deep-link selection
personal substitution call
```

---

# 13. Следующий обязательный шаг в новом чате

НЕ начинать сразу с UI.

Сначала:

```text
Firestore Security Rules
```

Но до написания Rules нужно изучить существующую модель доступа пользователей.

Новый чат должен прочитать:

```text
firestore.rules
```

особенно:

```text
users
contacts
guest
spaces_access
isSpacesManager()
```

Также найти tests, которые описывают Contacts/users access.

Цель:

```text
read spaces/spacesBar
→ всем реально допустимым участникам Epistola/Contacts, включая guest

create/update board
→ только brigadier/owner

delete whole board document
→ вероятно запретить; operations идут через update/set board
```

Rules должны дополнительно проверять schema:

```text
schemaVersion == 1
revision
messages map
messages.size() <= 3
message fields
text 1..250
lifetime enum
publisher
createdAt
updatedAt
```

Нужно отдельно продумать Rules для:

```text
publish new message
delete existing message
prune expired messages during write
revision increment
serverTimestamp/request.time
createdByUserId == request.auth.uid для нового сообщения
```

Не писать Rules по памяти — сначала изучить текущий `firestore.rules`.

---

# 14. После Rules

План:

```text
1. Firestore Rules + emulator tests
2. local hide storage
3. SpacesBar presentation widget
4. carousel / dots / 20 sec
5. Подробнее bottom sheet
6. brigadier/owner editor
7. publish + delete UI
8. push integration
9. exact message selection on push
10. manual emulator + phone verification
11. full flutter test
12. release APK
13. docs checkpoint
14. final commit/push or next release checkpoint
```

---

# 15. Push integration rule

Перед кодом push обязательно прочитать существующие:

```text
functions/
lib/services/notification_service.dart
push deep-link models/services/coordinator
foreground notification path
existing seagull sound/vibration handling
```

SpacesBar не должен создавать вторую независимую notification architecture.

Желаемый принцип:

```text
successful common-pin business event
→ server push
```

UI только вызывает:

```text
Опубликовать
```

---

# 16. Generated Flutter files

Перед текущим commit/push были видны:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
```

Это известный generated Flutter noise.

Их НЕ включать в SpacesBar commit.

Перед staging восстановить:

```powershell
git restore linux/flutter/generated_plugins.cmake macos/Flutter/GeneratedPluginRegistrant.swift windows/flutter/generated_plugin_registrant.cc windows/flutter/generated_plugins.cmake
```

---

# 17. Локальный Git status перед handoff commit

Перед восстановлением generated files был:

```text
 M lib/domain/models/spaces_access_role.dart
 M linux/flutter/generated_plugins.cmake
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M test/domain/models/spaces_access_role_test.dart
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugins.cmake
?? lib/domain/models/spaces_bar_board.dart
?? lib/domain/models/spaces_bar_message.dart
?? lib/domain/models/spaces_bar_publication_receipt.dart
?? lib/services/spaces/spaces_bar/
?? test/domain/models/spaces_bar_board_test.dart
?? test/domain/models/spaces_bar_message_test.dart
?? test/services/spaces/spaces_bar/
```

После restore generated files должны остаться только реальные SpacesBar/domain/test изменения плюс этот handoff file.

---

# 18. Рекомендованный commit

Commit message:

```text
feat(spaces): add spaces bar data foundation
```

Этот commit является implementation checkpoint, не release.

Не считать после него:

```text
SpacesBar complete
Rules deployed
UI complete
push complete
v0.8.0 released
```

---

# 19. Что новому чату сделать в самом начале

1. Прочитать этот handoff.
2. Проверить:

```powershell
git branch --show-current
git rev-parse --short HEAD
git status --short
```

3. Прочитать actual source текущей branch.
4. Прочитать `PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `README.md`, но помнить, что их SpacesBar sections могут быть устаревшими.
5. Не перепроектировать уже утверждённые решения без причины.
6. Начать с audit существующей users/contacts/guest security model.
7. Затем спроектировать Rules + targeted emulator tests.
8. Работать маленькими проверяемыми шагами.

---

# 20. Краткая контрольная фраза для нового чата

```text
Продолжаем Epistola v0.8.0 SpacesBar с запушенной data/transaction foundation.
Не начинай с UI.
Сначала прочитай текущую ветку и этот handoff, затем проверь существующую users/contacts/guest модель в firestore.rules и сделай Firestore Rules + targeted emulator tests для spaces/spacesBar.
```
