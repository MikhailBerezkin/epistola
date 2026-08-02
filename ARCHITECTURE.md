Epistola — Architecture

Основной технический документ проекта Epistola.

При расхождении информации используется следующий приоритет:

исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md

PROJECT_CONTEXT.md — handoff текущего состояния.

ARCHITECTURE.md — устойчивые архитектурные решения и границы.

README.md — обзор проекта для быстрого знакомства.

1. Статус документа

Параметр

Значение

Версия документа

4.0

Последняя стабильная версия

v0.6.6

Стабильный commit main

e0a966c

Текущий этап

v0.7.0 Image Message Foundation

Рабочая ветка

feat/v0.7.0-image-message-foundation

Последний функциональный commit

7b7189c

Состояние этапа

функциональность реализована и проверена, документация обновляется перед релизом

Последнее обновление

Август 2026

Текущий Image Message Foundation расширяет сообщения JPEG-изображениями в личных чатах, включая первую фотографию новому контакту.

Проверенная функциональность текущего этапа:

existing private image message
first private image message
gallery
camera
crop editor
thumbnail/full pipeline
secure upload grant
rollback
thumbnail display
full-screen viewer
zoom
autoscroll
keyboard-aware autoscroll

Отправка изображений в групповые чаты не считается завершённой без отдельной реализации и ручной проверки.

2. Назначение проекта

Epistola — корпоративный мессенджер на Flutter и Firebase.

Краткосрочные цели:

стабильное Android-приложение;

пилотная группа 40–50 пользователей;

контролируемые Firebase costs;

небольшие проверяемые этапы;

безопасные личные и групповые чаты;

заменяемый UI;

расширяемый media foundation.

Долгосрочные цели:

корпоративная коммуникационная платформа на 600–700 сотрудников;

задачи;

объявления;

документы;

рабочие смены;

внутренние приложения;

корпоративные сервисы;

возможный собственный backend.

Spaces не должны моделироваться как обычный тип чата.

Будущее направление:

Spaces → внутренние приложения Epistola

Главный принцип:

Архитектура должна позволять развивать продукт без полного переписывания существующей системы.

3. Инфраструктура

3.1 Репозиторий

MikhailBerezkin/epistola

3.2 Firebase

Firebase project: epistola-434b7
Firestore region: eur3
Cloud Functions region: europe-west1
Android package: com.epistola.app
Storage bucket: gs://epistola-434b7.firebasestorage.app

Используются:

Firebase Authentication;

Cloud Firestore;

Firebase Security Rules;

Firebase Storage;

Firebase Cloud Messaging;

Cloud Functions for Firebase.

3.3 Инфраструктурные файлы

.firebaserc
firebase.json
firestore.rules
firestore.indexes.json
storage.rules
android/app/google-services.json
lib/firebase_options.dart
functions/src/index.ts

Infrastructure configuration не должна находиться в UI или domain layer.

4. Архитектурные слои

Основная зависимость:

Flutter UI
    ↓
Presentation / Controllers
    ↓
Application Services
    ↓
Domain Models and Contracts
    ↓
Infrastructure Gateways / Adapters
    ↓
Firebase

Разрешённое направление зависимостей:

верхний слой может зависеть от нижнего контракта
нижний слой не должен зависеть от UI
domain не должен зависеть от Flutter и Firebase

4.1 Flutter UI

Слой включает:

screens
widgets
presentation models
UI state
navigation

UI отвечает за:

отображение;

пользовательские события;

progress;

retry;

локальное состояние;

навигацию;

выбор пользовательского сценария.

UI не должен:

загружать файлы напрямую в Firebase Storage;

выполнять Firestore transactions;

выдавать upload grants;

вычислять security permissions самостоятельно;

формировать canonical Storage paths вручную;

выполнять remote rollback;

содержать compression policy;

удалять активные media assets;

подменять domain validation.

4.2 Presentation

Presentation layer преобразует backend/domain state в удобные UI-модели.

Ключевые модели:

MessagePresentation
MessageVisibilityState

Presentation отвечает за:

видимость сообщения;

данные отправителя;

время;

текст;

признак image message;

image metadata;

выбор UI-компонента.

Presentation не определяет Firestore Rules и не выполняет upload.

4.3 Application Services

Application services оркестрируют пользовательский use case.

Они отвечают за:

последовательность операций;

проверку входных идентификаторов;

подготовку файлов;

upload;

atomic write;

rollback;

cleanup;

преобразование domain-моделей;

обработку ошибки и отмены.

Примеры:

ImageMessageImagePreparationService
ImageMessageUploadService
ExistingImageMessageSendService
ExistingImageMessageWriteService
FirstPrivateImageMessageSendService
FirstPrivateImageMessageWriteService
FirstPrivateImageUploadGrantService
ImageMessageRemoteCleanupService

4.4 Domain

Domain содержит независимые правила.

Примеры:

MessageType
MessageContent
MessagePreview
MessagePushRepresentation
ImageMessageMetadata
ImageMessageLimits
ImageMessageSendState
ImageMessageDeletionPolicy
MediaAsset
UserAvatar
GroupAvatar

Domain отвечает за:

допустимые типы;

invariants;

лимиты;

состояние операции;

решения deletion policy;

persistable metadata;

независимую от Firebase валидацию.

4.5 Infrastructure

Infrastructure реализует контракты через Firebase.

Примеры:

FirebaseImageMessageStorageAdapter
FirebaseMediaStorageProvider
Firestore gateways
Cloud Functions callable gateway

Infrastructure отвечает только за:

конкретный SDK;

upload/delete/download;

callable invocation;

Firestore read/write;

перевод исключений инфраструктуры.

5. Основная структура проекта

lib/
├── domain/
│   └── models/
├── models/
├── screens/
├── services/
│   ├── avatar/
│   ├── chat/
│   └── media/
├── theme/
├── widgets/
│   ├── avatar/
│   ├── chat/
│   ├── common/
│   └── group/
├── firebase_options.dart
└── main.dart

functions/
└── src/
    └── index.ts

test/
├── domain/
├── helpers/
├── models/
├── rules/
├── services/
└── widgets/

Основные документы:

PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md

6. Идентификация пользователей

Firebase Authentication UID является главным идентификатором пользователя.

Инвариант:

FirebaseAuth.currentUser.uid
==
users/{uid}

Нельзя вводить отдельный application user ID, не связанный с Firebase UID.

Публичный контактный E-mail может отличаться от технического FirebaseAuth E-mail, но не заменяет UID.

7. Архитектура чатов

7.1 Chat facade

Исторически ChatService используется как facade.

Внутренние обязанности разделены на специализированные сервисы:

ChatBaseService
ChatMessagesService
ChatPrivateService
ChatGroupsService
ChatMembersService
ChatPermissionsService
ChatSearchService
ChatPeerResolver
ChatPeerUserCache

Facade не должен превращаться в монолит.

Новые функциональные use cases должны размещаться в отдельном application service.

7.2 Private chat ID

Private chat должен иметь deterministic canonical ID для пары пользователей.

Преимущества:

отсутствие дублирующих личных чатов;

безопасное создание первого сообщения;

предсказуемые Rules;

возможность server-side upload grant;

повторное открытие существующего private chat.

Клиент не должен считать произвольный chatId валидным private chat ID.

7.3 Создание private chat

Главная гарантия:

выбор пользователя
→ выход назад
→ private chat не создаётся

Private chat создаётся только при успешном первом сообщении.

Для text message:

подготовить данные
→ transaction
   ├── создать chat при отсутствии
   ├── создать message
   ├── записать lastMessage
   └── записать lastMessageAt

Для image message загрузка Storage assets предшествует atomic Firestore write и защищается upload grant.

7.4 Existing private chat

Если private chat уже существует:

проверить membership
→ зарезервировать messageId
→ подготовить content
→ записать message
→ обновить chat metadata

Image message добавляет upload и rollback до Firestore write.

7.5 Group chat

Group chat включает:

title;

members;

roles;

permissions;

group metadata;

optional group avatar.

В текущем этапе text group messages сохраняются без изменений.

Image messages в групповых чатах требуют отдельного use case и не должны автоматически считаться поддержанными только из-за общей domain-модели.

8. Модель сообщения

8.1 Message types

Поддерживаемые пользовательские типы:

text
image

Unknown type не должен интерпретироваться как валидный image message.

8.2 MessageContent

MessageContent отделяет пользовательское содержимое от Firestore document shape.

Text content содержит текст.

Image content содержит ImageMessageMetadata.

8.3 Firestore message

Message document концептуально содержит:

senderId
createdAt
type
content-specific fields
visibility fields

Для text message persistable data содержит text.

Для image message persistable data содержит полную image metadata.

8.4 Message mappers

Ключевые mapper/resolver-компоненты:

MessageContentMapper
MessageDocumentMapper
ImageMessageMetadataMapper
MessagePreviewResolver
MessagePushResolver

Задача mapper:

прочитать backend data;

проверить структуру;

создать domain object;

не пропустить partially valid image metadata;

сформировать canonical write map.

8.5 Preview

Text:

preview → текст

Image:

preview → Фотография

Preview не должен содержать Storage path или техническую metadata.

8.6 Push representation

Text:

push body → текст

Image:

push body → Фотография

Push Cloud Function должна использовать representation, а не пытаться отображать image metadata.

9. Logical deletion

Состояния presentation:

visible
hiddenForCurrentUser
deletedForEveryone

9.1 Delete for self

hiddenFor[currentUid] = timestamp

Message document сохраняется.

Другие участники продолжают видеть сообщение.

9.2 Delete for everyone

deletedForEveryone = true

Только sender может удалить сообщение у всех.

Message document не удаляется физически.

9.3 Image asset policy

ImageMessageDeletionPolicy не разрешает немедленное физическое удаление Storage assets.

Delete for self:

message скрыт только текущему пользователю
assets сохраняются

Delete for everyone:

message скрыт логически для всех
assets сохраняются до отдельного retention cleanup

Текущий инвариант:

shouldDeleteStorageImmediately == false

Будущий cleanup должен учитывать:

retention period;

активные ссылки;

cache;

возможный rollback;

конкурентные клиенты;

права удаления.

10. Pagination и realtime

10.1 Page size

20 messages

10.2 Initial load

Загружаются последние 20 сообщений.

10.3 Older pages

При достижении верхней границы:

load next page
→ merge by document ID
→ chronological order
→ preserve viewport

10.4 Realtime snapshot

Realtime snapshot новых сообщений не должен заменять весь локальный список.

Инвариант:

уже загруженные старые страницы сохраняются

10.5 Hidden messages

Hidden/deleted state влияет на presentation, но не должен разрушать pagination cursors.

10.6 Preview после удаления

После удаления последнего сообщения выбирается последнее видимое сообщение.

11. Автопрокрутка

11.1 Когда разрешён автоматический scroll

Автопрокрутка разрешена, если:

пользователь находился возле нижней границы;

отправлено собственное сообщение;

добавлено новое сообщение при просмотре низа;

изменился keyboard inset и пользователь оставался у низа.

Автопрокрутка не должна срабатывать, если пользователь читает старую историю выше.

11.2 Image layout correction

Image bubble может окончательно изменить размер после загрузки thumbnail.

Поэтому используется:

первичный scroll after frame
→ повторная correction after layout

Correction timer:

отменяется перед новым запуском;

отменяется в dispose;

не работает после уничтожения widget;

не должен вызывать scroll без attached controller.

11.3 Виртуальная клавиатура

На физическом Android-телефоне клавиатура изменяет доступную высоту окна.

ChatScreen получает:

MediaQuery.viewInsets.bottom

Значение передаётся в MessagesList.

При изменении inset и сохранении состояния near-bottom выполняется корректировка после layout.

12. Image Message Foundation

12.1 Цель

Добавить JPEG image messages без нарушения:

first-message-only chat creation;

pagination;

realtime;

logical deletion;

push;

Firebase Rules;

cost controls;

UI replaceability.

12.2 Проверенный scope

existing private chat
first private message to a new contact

Источники:

gallery
camera
Android lost-data recovery

12.3 Полный pipeline

picker
→ editor
→ image preparation
→ thumbnail/full processor
→ storage upload
→ message write
→ preview/push
→ local cleanup

Для first private image message:

picker
→ editor
→ preparation
→ server-side upload grant
→ storage upload
→ atomic chat + message write
→ cleanup

13. Image preparation

13.1 Picker gateway

Image selection скрывается за gateway, уже используемым avatar foundation.

UI вызывает user intent:

gallery
camera
recover lost image

Gateway возвращает picked file или null.

null означает пользовательскую отмену, а не ошибку.

13.2 Editor

После picker вызывается crop editor.

Для image messages:

свободный прямоугольный crop;

поворот;

reset;

отмена;

набор стандартных aspect ratios.

Editor возвращает новый временный файл.

При отмене:

send result → cancelled
upload не начинается

13.3 Processor

Класс:

ImageMessageImageProcessor

Создаёт:

PreparedImageMessageImages

Содержимое:

thumbnailPath
fullPath
thumbnailWidth
thumbnailHeight
fullWidth
fullHeight
thumbnailSizeBytes
fullSizeBytes
workingDirectory
cleanup callback

Processor:

читает source dimensions;

масштабирует вниз;

не увеличивает маленькое изображение без необходимости;

генерирует JPEG;

применяет quality attempts;

проверяет фактический размер;

проверяет dimensions;

проверяет relationship thumbnail/full;

очищает неуспешные результаты.

13.4 Лимиты

Thumbnail:

max size: 128 KB
max dimension: 480 px

Full:

target size: 512 KB
hard max size: 1 MB
max dimension: 1920 px

Допуск aspect ratio:

0.02

13.5 Cleanup ownership

Picker source не принадлежит processor и не удаляется processor.

Crop output считается временным и удаляется после подготовки.

Working directory принадлежит prepared result и освобождается после завершения send use case.

Ошибка cleanup не должна заменять исходную processing error.

14. Image metadata

14.1 Domain representation

ImageMessageMetadata
├── thumbnail: MediaAsset
└── full: MediaAsset

Derived values:

version
provider
messageId
paths
sizes
dimensions
cache keys

14.2 Complete metadata

Metadata считается complete, если:

version положительна;

provider не пуст;

messageId не пуст;

thumbnail и full имеют одинаковую version;

thumbnail и full имеют одинаковый provider;

ownerType равен message;

ownerId совпадает;

asset types корректны;

MIME type image/jpeg;

оба path не пусты;

paths различаются.

14.3 Persistable metadata

Дополнительно:

provider равен firebase;

sizes существуют и положительны;

sizes не превышают лимиты;

dimensions существуют и положительны;

thumbnail dimensions не превышают thumbnail limit;

full dimensions не меньше thumbnail dimensions;

full dimensions не превышают full limit;

aspect ratio совпадает с допуском.

14.4 Firestore map

Canonical map:

provider
thumbStoragePath
fullStoragePath
thumbSizeBytes
fullSizeBytes
thumbWidth
thumbHeight
fullWidth
fullHeight
mimeType
version

Partially valid map должен отвергаться.

15. Media paths

Централизованный builder:

MediaPaths

Image message paths:

chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg

Нельзя:

формировать path в UI;

менять порядок сегментов;

использовать original.jpg;

использовать произвольное имя файла;

смешивать version;

загружать thumbnail в full path;

загружать full в thumb path.

Version должна быть положительной.

16. Storage gateway

Contract:

ImageMessageStorageGateway

Методы:

uploadThumbnail
uploadFull
delete

Firebase adapter:

FirebaseImageMessageStorageAdapter

Adapter отвечает за:

выбор canonical path;

создание Storage metadata;

Firebase Storage SDK call;

возврат MediaAsset;

delete по path.

Adapter не решает, когда создавать chat и когда выполнять rollback всей операции.

17. Upload orchestration

Service:

ImageMessageUploadService

Вход:

prepared local files
uploaderId
chatId
messageId
version
optional first-private-grant mode

Порядок:

validate identifiers
→ upload thumbnail
→ upload full
→ construct ImageMessageMetadata
→ validate persistable metadata
→ return result

Rollback:

thumbnail upload failed
→ no remote cleanup

full upload failed
→ delete thumbnail

metadata validation failed
→ delete thumbnail
→ delete full

Remote cleanup выполняется best-effort.

Исходная ошибка сохраняется как главная.

18. Existing private image message

Send service:

ExistingImageMessageSendService

Writer:

ExistingImageMessageWriteService

Порядок:

prepare image
→ reserve messageId
→ upload thumbnail/full
→ validate metadata
→ atomic message write
→ update chat preview
→ release local files

Writer проверяет:

chatId;

currentUserId;

messageId;

sender membership;

persistable image metadata;

canonical message map;

canonical preview.

При write failure:

remote cleanup uploaded assets
→ rethrow original write failure

19. First private image message

19.1 Причина отдельного use case

До создания chat document Storage Rules не могут проверить обычное membership.

Нельзя:

заранее создавать пустой chat;

ослаблять Storage Rules;

разрешать произвольную загрузку аутентифицированному пользователю.

Поэтому используется server-side grant.

19.2 Grant service

Client service:

FirstPrivateImageUploadGrantService

Cloud Function:

createFirstPrivateImageUploadGrant

Регион:

europe-west1

Grant связывает:

uploaderId
peerId
chatId
messageId
version

Cloud Function проверяет:

caller authenticated;

peer существует и допустим;

caller не равен peer;

chatId canonical для пары;

identifiers валидны;

version допустима;

grant создаётся server-side.

19.3 Storage Rules

При отсутствии chat document upload разрешается только при валидном grant.

Grant должен точно совпадать с:

request.auth.uid;

peer;

chatId;

messageId;

version;

canonical path.

Grant другой version отвергается.

19.4 Send service

FirstPrivateImageMessageSendService

Порядок:

prepare image
→ compute canonical chatId
→ reserve messageId
→ request grant
→ upload thumbnail/full with grant metadata
→ atomic first message write
→ local cleanup

19.5 Writer

FirstPrivateImageMessageWriteService

Атомарная запись:

chat
message
lastMessage
lastMessageAt

Если chat появился конкурентно:

проверить, что это тот же canonical private chat;

проверить membership;

использовать безопасный existing-chat update;

не создавать duplicate private chat.

19.6 Failure guarantee

Любая ошибка до успешного Firestore commit:

не должна оставлять пустой chat

Если remote assets уже существуют:

best-effort cleanup

20. Remote cleanup

20.1 Cleanup plan

ImageMessageRemoteCleanupPlan

Хранит созданные текущей попыткой paths.

20.2 Cleanup service

ImageMessageRemoteCleanupService

Поведение:

delete known remote paths
ignore not-found where безопасно
collect cleanup failures
preserve original send error

20.3 Failure table

Стадия ошибки

Cleanup

До upload

отсутствует

Thumbnail upload

отсутствует или частичный SDK cleanup

После thumbnail

удалить thumbnail

После full

удалить thumbnail и full

Firestore write

удалить thumbnail и full

После успешного write

не удалять active assets

21. Firestore Rules

Rules являются последней серверной границей.

Client validation не заменяет Rules.

Image message create проверяет:

caller authenticated;

senderId равен caller UID;

caller имеет право отправлять;

supported message type;

canonical content shape;

complete image metadata;

provider firebase;

MIME image/jpeg;

положительную version;

допустимые sizes;

допустимые dimensions;

согласованный aspect ratio;

canonical Storage paths;

соответствие path текущим chatId и messageId.

First private image message дополнительно проверяет:

canonical private chat;

корректную пару участников;

atomic create;

согласованный chat preview;

отсутствие произвольных дополнительных изменений.

Rules tests:

test/rules/firestore/image_message_upload_grant_rules.test.mjs
test/rules/firestore/message_create_rules.test.mjs
test/rules/firestore/private_chat_first_message_rules.test.mjs

22. Storage Rules

Canonical pattern:

chat_media/{chatId}/messages/{messageId}/v{version}/{variant}.jpg

Допустимые конечные имена:

thumb.jpg
full.jpg

Проверяются:

authentication;

content type;

size;

path segments;

version;

variant;

custom metadata;

uploader;

chat membership;

first-private grant;

соответствие grant;

delete permission.

Не допускаются:

original.jpg;

третья variant;

path traversal;

grant другого пользователя;

grant другого chat;

grant другого message;

grant другой version;

подмена metadata;

oversized upload;

unsupported content type.

Storage emulator tests:

test/rules/storage/image_message_storage_rules.test.mjs

23. UI image messages

23.1 Input

Основные компоненты:

MessageInput
MessageInputArea

MessageInput отвечает за базовое поле и кнопку отправки.

MessageInputArea объединяет:

text input;

attachment menu;

gallery callback;

camera callback;

busy state.

23.2 Attachment sheet

Пункты:

Галерея
Камера
Файл
Голосовое

Gallery и Camera вызывают реальные use cases.

File и Voice показывают placeholder notification.

Геопозиция и Контакт временно удалены.

23.3 Busy state

Во время подготовки или отправки:

показывается progress;

повторный image action блокируется;

конфликтующая отправка не запускается;

после ошибки UI возвращается в доступное состояние;

cancel не показывается как техническая ошибка.

23.4 Draft private chat

PrivateChatDraftScreen поддерживает:

первое text message;

первую фотографию;

gallery;

camera;

busy state;

переход в созданный chat.

До успешной отправки private chat не существует.

24. Image display

24.1 Presentation flow

Firestore snapshot
→ MessageContentMapper
→ ImageMessageMetadataMapper
→ MessagePresentation
→ MessageItem
→ MessageBubble
→ ImageMessageThumbnail

24.2 Thumbnail

ImageMessageThumbnail:

использует thumbnail path;

запрашивает download URL через media service;

использует cache key path@version;

сохраняет aspect ratio;

показывает progress;

показывает retry;

открывает viewer.

Thumbnail не должен загружать full file.

24.3 Viewer

ImageMessageViewerScreen:

использует full path;

использует full cache key;

чёрный фон;

progress;

retry;

InteractiveViewer;

min scale 1;

max scale 5;

boundary margin;

double-tap zoom/reset;

AppBar back;

Android system back.

24.4 Cache

Versioned cache key предотвращает показ старой версии при изменении path/version.

thumbnailCacheKey = thumbPath@version
fullCacheKey = fullPath@version

25. Push architecture

Cloud Function:

sendMessageNotification

Trigger:

chats/{chatId}/messages/{messageId}

Функция:

получает созданное сообщение;

исключает sender;

определяет recipients;

получает tokens;

формирует title/body;

отправляет FCM;

удаляет невалидные tokens.

Message representation:

text → текст
image → Фотография

Известное ограничение:

notification tap открывает приложение,
но не конкретный chat

26. Avatar architecture

26.1 Общая media foundation

Avatar и image message используют общие идеи:

picker gateway;

crop;

JPEG compression;

versioned paths;

thumbnail/full;

cleanup;

Firebase adapters.

Но use cases разделены.

Нельзя использовать square avatar policy для message photo без явного адаптера.

26.2 User avatar paths

user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

26.3 Group avatar paths

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg

26.4 Replacement

prepare new version
→ upload
→ atomic metadata update
→ best-effort old version cleanup

Старая активная версия сохраняется при ошибке до metadata commit.

26.5 Loading

Path-first loading:

storage path
→ download URL
→ cached network image

Cache key:

path@version

27. Roles и permissions

Role order:

owner
admin
moderator
member
guest

owner сохраняет максимальный приоритет.

Rules и UI должны согласованно проверять:

отправку;

mute;

ban;

управление участниками;

изменение group avatar;

передачу прав;

выход;

роспуск.

UI hiding не является security boundary.

Реальная защита находится в Firestore и Storage Rules.

28. Android Toolchain Foundation

Зафиксированная конфигурация:

Flutter: 3.44.1
Dart: 3.12.1
Java: 21.0.10
Gradle: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
Google Services Plugin: 4.3.15
compileSdk: 36
targetSdk: 36
minSdk: 24
JVM target: 17

Compatibility flags:

android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false

Built-in Kotlin warning относится к plugin internals:

firebase_storage
flutter_image_compress_common

Запрещено:

редактировать Pub Cache;

удалять flags без проверки;

обновлять AGP/Gradle/Kotlin во время feature work;

считать отсутствие Visual Studio проблемой Android build.

29. Testing strategy

29.1 Domain tests

Проверяют:

limits;

metadata invariants;

send states;

deletion policy;

message types;

content;

preview;

push representation.

29.2 Service tests

Проверяют:

preparation;

compression attempts;

cleanup;

upload ordering;

rollback;

grant calls;

atomic write maps;

existing chat send;

first private image send;

failure preservation.

29.3 Rules emulator tests

Проверяют серверные invariants независимо от клиента.

Scope:

Firestore message create
first private message
upload grants
Storage canonical paths
metadata
version
membership
permissions

29.4 Widget tests

Проверяют:

message presentation;

avatars;

chat title;

list behavior;

fallback UI.

29.5 Manual Android tests

Обязательны для:

gallery;

camera;

crop UI;

keyboard;

scroll;

system back;

full viewer;

real Firebase upload;

second device visibility.

30. Проверки перед commit

Обычный Flutter feature:

flutter.bat analyze
flutter.bat test <target>
git.exe diff --check
git.exe status --short

Финал этапа:

flutter.bat analyze
flutter.bat test
npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
flutter.bat build apk --release
git.exe diff --check
git.exe status --short

После Flutter-команд могут измениться:

linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake

Их восстанавливают один раз в конце серии проверок:

git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake

31. Deploy strategy

Cloud Functions:

npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
firebase.cmd deploy --only functions

Одна функция:

firebase.cmd deploy --only functions:createFirstPrivateImageUploadGrant

Firestore Rules:

firebase.cmd deploy --only firestore

Storage Rules:

firebase.cmd deploy --only storage

Deploy выполняется только в:

epistola-434b7

32. Cost controls

Пилотная группа:

40–50 users

Основные решения:

pagination по 20;

thumbnail в ленте;

full только по клику;

ограничение JPEG size;

отсутствие загрузки оригинала;

versioned immutable paths;

cleanup partial uploads;

дедупликация media loads;

осторожное использование realtime listeners;

ограничение Cloud Functions maxInstances;

удаление невалидных push tokens.

Перед добавлением нового media type оцениваются:

средний размер;

количество Storage operations;

количество Firestore writes;

количество download URL requests;

cache behavior;

retention policy.

33. Security principles

Client UI не является security boundary.

Auth UID проверяется серверными Rules.

Membership проверяется Rules.

Role проверяется Rules.

Canonical paths проверяются Rules.

Storage metadata проверяется Rules.

First-private pre-chat upload требует server-side grant.

Grant имеет узкий scope.

Atomic writes проверяются Firestore Rules.

Unknown/partial image metadata отвергается.

Cleanup permission не должна позволять удалять чужие активные assets.

App Check остаётся отдельным production-hardening этапом.

34. Неприкосновенные invariants

Нельзя ломать:

Auth UID == users/{uid};

отсутствие пустых private chats;

first message atomicity;

deterministic private chat ID;

atomic message + preview;

pagination по 20;

сохранение старых страниц;

near-bottom-only autoscroll;

logical deletion;

sender-only delete for everyone;

private clear only for current user;

role permissions;

last admin protection;

owner maximum priority;

safe group exit;

push sender exclusion;

versioned avatar paths;

avatar rollback;

image metadata completeness;

thumbnail/full relationship;

canonical image paths;

first-image server grant;

partial upload rollback;

original image not uploaded;

full loaded only on demand;

UI/Firebase separation.

35. Известный технический долг

Высокий и средний приоритет:

notification tap не открывает конкретный chat;

group image messages не завершены;

production retention cleanup для deleted image assets отсутствует;

App Check не завершён;

release signing требует отдельной настройки;

нужны дополнительные concurrent tests с двумя физическими устройствами;

Firestore reads требуют наблюдения по мере роста;

Storage usage требует наблюдения;

path-first avatar cache преимущественно in-memory;

Rules tests нужно расширять при каждом новом media type;

документацию со временем стоит разделить на тематические ADR/reference файлы.

Отложено:

files
voice messages
geolocation
contacts
group image messages
media captions
multi-image galleries

36. UI evolution

Архитектура должна позволять менять без переписывания Firebase logic:

theme;

dark/light mode;

chat wallpapers;

bubble shape;

bubble size;

colors;

fonts;

message animations;

deletion animations;

image opening animation;

attachment sheet;

progress;

retry;

multi-image layout;

swipe viewer.

UI получает готовую presentation/domain модель и передаёт user intent в service.

37. Следующие архитектурные этапы

После стабилизации v0.7.0 возможны отдельные foundations:

Push Deep Link Foundation.

Group Image Message Foundation.

File Message Foundation.

Voice Message Foundation.

Media Retention Cleanup Foundation.

App Check / Production Hardening.

Release Signing.

Internal Applications Foundation.

Каждый этап должен:

иметь отдельную ветку;

не смешивать toolchain и feature changes;

начинаться с domain/security design;

иметь automated tests;

проходить Android manual test;

завершаться документацией и stable tag.

38. Рабочие правила

Основной язык координации — русский.

Windows-команды даются с явными executable-именами.

Изменения выполняются маленькими шагами.

Большие файлы предпочтительно заменять целиком.

Перед commit показывается status.

Изменённый пользовательский сценарий проверяется вручную.

После этапа выполняются analyze, full tests и release build.

Functions проходят build и lint.

Rules deploy выполняется осознанно.

Generated files не включаются случайно.

Firebase free-tier учитывается в архитектуре.

При недостатке контекста обновляется PROJECT_CONTEXT.md.

39. Release flow v0.7.0

После обновления документации:

PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md

Выполнить:

git.exe diff --check
git.exe status --short

Создать documentation commit.

Отправить feature branch.

Слить:

feat/v0.7.0-image-message-foundation
→ main

На main повторить:

flutter.bat analyze
flutter.bat test
npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
flutter.bat build apk --release

Восстановить generated plugin files, если они изменились.

Проверить чистое дерево.

Создать и отправить:

tag v0.7.0

После этого main и tag становятся новой стабильной точкой.