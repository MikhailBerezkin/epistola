# Epistola — Architecture

> Основной технический документ проекта Epistola.

## 1. Статус документа

| Параметр | Значение |
| --- | --- |
| Версия документа | `3.0` |
| Версия проекта | `v0.6.5` |
| Этап | **Avatar Foundation** |
| Последний опубликованный стабильный релиз | `v0.6.4` |
| Рабочая ветка | `feat/v0.6.5-avatar-foundation` |
| Статус | Реализация, Android-проверки, автоматические тесты и release APK завершены |
| Последнее обновление | Июль 2026 |

При расхождении информации используется следующий приоритет:

```text
исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

`PROJECT_CONTEXT.md` является главным handoff-документом текущего состояния.
`ARCHITECTURE.md` описывает устойчивые архитектурные решения.
`README.md` предназначен для быстрого знакомства с проектом.

---

## 2. Назначение проекта

Epistola — корпоративный мессенджер на Flutter и Firebase.

Краткосрочная цель:

- стабильное Android-приложение;
- пилотная группа примерно 40–50 пользователей;
- контролируемые расходы Firebase;
- проверяемые небольшие этапы разработки.

Долгосрочная цель:

- мессенджер для компании на 600–700 сотрудников;
- рабочие пространства Spaces;
- задачи;
- объявления;
- документы;
- рабочие смены;
- мини-приложения;
- внутренние корпоративные сервисы;
- возможный собственный backend.

Главный принцип:

> Архитектура должна позволять развивать продукт без полного переписывания существующей системы.

---

## 3. Текущая инфраструктура

### 3.1 Репозиторий

```text
MikhailBerezkin/epistola
```

Исторический репозиторий:

```text
Metaxa251/epistola
```

Исторический репозиторий используется только как архив.

### 3.2 Firebase

```text
Firebase project: epistola-434b7
Firestore region: eur3
Cloud Functions region: europe-west1
Android package: com.epistola.app
Storage bucket: gs://epistola-434b7.firebasestorage.app
```

Используемые сервисы:

- Firebase Authentication;
- Cloud Firestore;
- Firebase Security Rules;
- Firebase Storage;
- Firebase Cloud Messaging;
- Cloud Functions for Firebase.

### 3.3 Основные инфраструктурные файлы

```text
.firebaserc
firebase.json
firestore.rules
firestore.indexes.json
storage.rules
android/app/google-services.json
lib/firebase_options.dart
functions/src/index.ts
```

Инфраструктурные правила должны храниться в корне проекта, а не внутри `lib/`.

---

## 4. Общая архитектура приложения

Высокоуровневая схема:

```text
Flutter UI
    ↓
Presentation controllers
    ↓
Application services
    ↓
Domain models and contracts
    ↓
Infrastructure gateways/adapters
    ↓
Firebase
```

Ответственность слоёв:

| Слой | Ответственность |
| --- | --- |
| UI | Отображение состояния и пользовательские действия |
| Controller | Сериализация UI-операций и преобразование результата в UI-состояние |
| Application service | Оркестрация use case, rollback и cleanup |
| Domain | Модели, правила и контракты без Flutter/Firebase |
| Infrastructure | Firestore, Storage, FCM и другие внешние реализации |

Основные ограничения:

- UI не должен выполнять прямые Storage upload.
- UI не должен выполнять Firestore transaction.
- UI не должен содержать security policy.
- Domain-модели не должны зависеть от Flutter.
- Domain-модели не должны зависеть от Firebase.
- Firebase является текущей инфраструктурой, но не вечной архитектурной зависимостью.
- Внешние реализации должны скрываться за gateways, providers или services.
- Визуальный слой должен оставаться заменяемым.

---

## 5. Структура исходного кода

Актуальное направление структуры:

```text
lib/
├── domain/
│   ├── models/
│   └── value_objects/
├── helpers/
├── models/
├── screens/
├── services/
│   ├── avatar/
│   ├── chat/
│   └── media/
├── theme/
└── widgets/
    ├── avatar/
    ├── chat/
    ├── common/
    └── group/

test/
├── domain/
├── helpers/
├── models/
├── rules/
├── services/
└── widgets/
```

Часть старых моделей пока находится в `lib/models`.

Перенос выполняется постепенно:

- без большого несвязанного рефакторинга;
- только при работе с соответствующим модулем;
- с сохранением проверяемых небольших коммитов.

---

## 6. UI и заменяемый визуальный слой

### 6.1 Основное правило

Внешний вид не должен быть смешан с Firebase-логикой или бизнес-операциями.

UI отвечает за:

- размеры;
- отступы;
- цвета;
- шрифты;
- анимации;
- Material-компоненты;
- взаимодействие пользователя;
- показ результата controller.

UI не отвечает за:

- Storage paths;
- Firebase transaction;
- rollback;
- проверку версии;
- security roles;
- удаление старой версии файла;
- обработку binary payload.

### 6.2 Основные avatar UI-компоненты

```text
AvatarView
UserAvatarView
GroupAvatarView
ChatAvatarView
ChatAppBarTitle
ChatTile
GroupHeader
GroupMembersSection
```

Назначение:

| Компонент | Ответственность |
| --- | --- |
| `AvatarView` | Базовое отображение изображения и fallback |
| `UserAvatarView` | Пользовательский аватар |
| `GroupAvatarView` | Групповой аватар |
| `ChatAvatarView` | Выбор user/group варианта для карточки чата |
| `ChatAppBarTitle` | Заголовок открытого чата |
| `ChatTile` | Карточка чата |
| `GroupHeader` | Шапка информации о группе |
| `GroupMembersSection` | Список участников с пользовательскими аватарами |

Логика `ChatAvatarView`:

```text
private chat
    → UserAvatarView

group chat
    → GroupAvatarView

нет изображения
    → fallback
```

Благодаря этому можно отдельно менять:

- размер аватаров;
- круглую или другую форму;
- анимацию загрузки;
- анимацию замены;
- цвета fallback;
- размеры и семейства шрифтов;
- оформление карточек;
- темы;
- фон чатов;
- декоративные эффекты.

Такие изменения не должны требовать переписывания Firestore и Storage logic.

### 6.3 Message UI

Удаление сообщений также разделено на presentation-слои:

```text
Firestore message state
        ↓
MessagePresentation
        ↓
MessageItem
        ↓
MessageBubble
```

Это позволяет менять:

- анимацию удаления;
- форму пузыря;
- цвет;
- отступы;
- текст-заглушку;
- будущие эффекты;

без изменения Firestore-модели удаления.

---

## 7. Архитектура чатов

### 7.1 ChatService как фасад

Монолитная логика разделена на специализированные сервисы:

```text
UI / Screens
    ↓
ChatService
    ↓
 ┌─────────────────────────────────────────┐
 │ ChatMessagesService                     │
 │ ChatPrivateService                      │
 │ ChatSearchService                       │
 │ ChatMembersService                      │
 │ ChatGroupsService                       │
 │ ChatPermissionsService                  │
 └─────────────────────────────────────────┘
    ↓
Cloud Firestore
```

`ChatService` сохраняет удобный внешний API, а специализированные сервисы разделяют ответственность.

### 7.2 Private chat

Private chat создаётся только после отправки первого сообщения.

Порядок:

```text
пользователь выбирает собеседника
→ открывается draft screen
→ Firestore chat document ещё не создаётся
→ пользователь отправляет первое сообщение
→ создаются chat document и message document
```

Это предотвращает появление пустых private chats.

Техническое поле имени private chat не является пользовательским названием:

```text
name: private_chat
```

Отображаемое имя определяется по профилю второго участника.

### 7.3 Атомарная отправка

Message document и metadata карточки чата обновляются атомарно.

Связанные поля:

```text
lastMessage
lastMessageAt
lastMessageId
```

Это исключает промежуточное состояние, когда сообщение создано, но preview чата не обновлено.

### 7.4 Pagination

История загружается страницами по 20 сообщений.

```text
первый запрос
→ последние 20 сообщений

прокрутка вверх
→ следующая страница 20 сообщений
```

Гарантии:

- глубокая история не читается заранее;
- повторные документы объединяются по document ID;
- список остаётся хронологическим;
- позиция прокрутки сохраняется;
- одновременно выполняется только один запрос старой страницы;
- realtime-обновления новых сообщений не удаляют уже загруженную историю.

### 7.5 Персональная очистка private chat

Очистка private chat выполняется только для текущего пользователя.

Используется персональная граница истории:

```text
clearedAtByUser
```

Сообщения физически не удаляются для второго участника.

---

## 8. Поиск чатов

Private chat сопоставляется по second participant identity.

Поиск использует:

- имя собеседника;
- email;
- доступные данные профиля;
- название группы для group chat.

Поиск не должен использовать техническое значение `private_chat` как отображаемое имя.

Поток данных:

```text
chat document
→ resolve peer user
→ calculate display name
→ matchesSearch()
→ ChatTile
```

В результатах отображаются:

- пользовательские аватары private chats;
- групповые аватары group chats;
- fallback при отсутствии изображения.

---

## 9. Media Foundation

### 9.1 Назначение

Media Foundation создан в `v0.6.2`.

Он является основой для:

- пользовательских аватаров;
- групповых аватаров;
- изображений сообщений;
- документов;
- файлов;
- превью;
- голосовых сообщений;
- видео;
- будущего гибридного хранения.

### 9.2 Основные элементы

```text
MediaAsset
MediaPaths
MediaStorageProvider
FirebaseMediaStorageProvider
MediaStorageService
```

| Элемент | Ответственность |
| --- | --- |
| `MediaAsset` | Доменное описание медиа |
| `MediaPaths` | Единое формирование путей |
| `MediaStorageProvider` | Абстрактный контракт хранилища |
| `FirebaseMediaStorageProvider` | Firebase Storage adapter |
| `MediaStorageService` | Фасад для приложения |

### 9.3 Path-first стратегия

Главный источник истины:

```text
provider + storage path + version
```

Download URL не должен быть основой доменной модели.

Причины:

- URL может измениться;
- провайдер может быть заменён;
- требуется аутентифицированный доступ;
- версионный путь удобно использовать как cache key;
- path позволяет мигрировать Storage provider.

### 9.4 Возможные будущие providers

```text
Firebase Storage
S3-compatible storage
Yandex Object Storage
Cloudflare R2
локальный сервер компании
собственный Epistola backend
```

Бизнес-логика и UI не должны переписываться при замене provider.

---

## 10. Avatar Foundation

### 10.1 Общий pipeline изображения

Пользовательский и групповой avatar pipeline используют общую подготовку изображения:

```text
галерея или камера
→ квадратный crop 1:1
→ JPEG processing
→ thumbnail 128x128
→ full 512x512
→ size validation
```

Поддерживается:

- выбор галереи;
- камера;
- отмена picker;
- отмена crop;
- Android lost-data recovery;
- исправление ориентации;
- удаление EXIF;
- cleanup временных файлов;
- загрузка только подготовленных вариантов.

Оригинал из picker:

- не загружается;
- не удаляется приложением;
- не используется как активный avatar asset.

Ограничения:

```text
thumbnail: максимум 128 KB
full: целевой размер до 300 KB
full: абсолютный максимум 512 KB
MIME type: image/jpeg
```

### 10.2 Слои avatar subsystem

```text
Avatar UI
    ↓
ReplacementController
    ↓
ImagePreparationService
    ↓
AtomicReplacementService
    ↓
StorageUploadService + MetadataGateway
    ↓
Firebase Storage + Firestore
```

Разделение обязанностей:

| Слой | Ответственность |
| --- | --- |
| UI | Выбор source и показ результата |
| Controller | Защита от повторного запуска и единый результат операции |
| Preparation | Picker, crop, compression и temporary files |
| Replacement | Upload, transaction, rollback и cleanup |
| Storage service | Версионная загрузка пары файлов |
| Metadata gateway | Транзакционная смена активной metadata |
| Firebase adapter | Конкретные SDK-вызовы |

### 10.3 Результат controller

Controller должен возвращать явное состояние:

```text
success
cancelled
failure
alreadyRunning
```

UI не должен определять успешность операции по косвенным признакам.

---

## 11. Пользовательские аватары

### 11.1 Доменная модель

Пользовательский аватар основан на `MediaAsset` и содержит:

- thumbnail asset;
- full asset;
- provider;
- owner UID;
- version;
- updated timestamp;
- размеры;
- Storage paths.

### 11.2 Storage paths

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Legacy path:

```text
user_avatars/{uid}/avatar.jpg
```

Legacy path сохраняется только для совместимости и не используется новым pipeline.

### 11.3 Firestore metadata

Документ:

```text
users/{uid}
```

Поля:

```text
avatarProvider
avatarThumbStoragePath
avatarFullStoragePath
avatarThumbSizeBytes
avatarFullSizeBytes
avatarVersion
avatarUpdatedAt
```

Legacy поле:

```text
avatarUrl
```

Оно читается только как fallback совместимости.

### 11.4 Атомарная замена

```text
1. Подготовить thumbnail и full.
2. Загрузить новую версию.
3. Записать metadata транзакцией.
4. Удалить старую версию best-effort.
```

Гарантии:

- старый avatar активен до успешной transaction;
- неуспешная подготовка ничего не меняет;
- неполная upload-пара очищается;
- при ошибке metadata новая версия удаляется;
- ошибка cleanup старой версии не отменяет новый avatar;
- version должна строго возрастать;
- устаревшая конкурентная операция не перезаписывает новую.

### 11.5 Отображение

Пользовательский avatar отображается в:

- профиле;
- контактах;
- списке private chats;
- chat search;
- заголовке открытого private chat;
- draft private chat до первого сообщения;
- списке участников группы.

Fallback:

- инициалы пользователя;
- максимум две буквы;
- стабильный цвет по UID.

---

## 12. Групповые аватары

### 12.1 Отдельная модель

Групповой avatar не является пользовательским avatar с другим owner ID.

Отдельные элементы:

```text
GroupAvatar
GroupAvatarMetadataMapper
GroupAvatarStorageUploadService
FirebaseGroupAvatarMetadataGateway
AtomicGroupAvatarReplacementService
GroupAvatarReplacementController
GroupAvatarView
```

Причины отдельной модели:

- другая ownership policy;
- другая Firestore metadata;
- другие Security Rules;
- другой fallback;
- другой экран управления;
- отдельные права `owner/admin`.

### 12.2 Storage paths

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

### 12.3 Firestore metadata

Metadata хранится в:

```text
chats/{chatId}
```

Thumbnail и full должны:

- принадлежать одному `chatId`;
- иметь одинакового provider;
- иметь одинаковую version;
- быть записаны полным согласованным набором.

### 12.4 Права управления

Изменять групповой avatar могут только:

```text
owner
admin
```

Членство само по себе недостаточно.

Роль `moderator` не получает управление avatar автоматически.

### 12.5 Атомарная замена

```text
prepare
→ upload новой версии
→ transaction group metadata
→ best-effort cleanup предыдущей версии
```

Гарантии совпадают с пользовательской заменой:

- предыдущий avatar сохраняется при ошибке;
- новая Storage-версия откатывается при ошибке metadata;
- конфликт версии отклоняется;
- UI не выполняет transaction напрямую.

### 12.6 Отображение

Групповой avatar отображается в:

- информации о группе;
- основном списке групп;
- поиске чатов;
- заголовке открытого group chat.

Fallback:

```text
первая буква названия группы
```

---

## 13. Avatar image loading и cache

Path-first загрузка выполняется через Firebase Storage SDK.

Cache key:

```text
storagePath@version
```

Это гарантирует:

- новая version не использует старые bytes;
- замена avatar автоматически меняет cache key;
- параллельные запросы одного asset могут объединяться;
- повторные Storage reads сокращаются.

Текущий cache:

- находится в памяти процесса;
- ограничен по размеру;
- не сохраняется после перезапуска приложения.

При ошибке path-first loading:

```text
legacy URL
→ fallback initials
```

Persistent disk cache остаётся будущей задачей.

---

## 14. Firestore Security Rules для аватаров

### 14.1 Пользовательский avatar

Разрешается:

- чтение аутентифицированными пользователями;
- изменение metadata только владельцем `users/{uid}`;
- запись только полного согласованного набора;
- строго возрастающий `avatarVersion`;
- корректные versioned Storage paths.

Запрещается:

- изменение avatar metadata другого пользователя;
- отрицательная или нулевая version;
- откат version;
- несогласованные thumb/full paths;
- новая запись legacy URL как источника истины;
- изменение посторонних полей через avatar update.

### 14.2 Групповой avatar

Разрешается только когда:

- пользователь аутентифицирован;
- chat существует;
- `type == group`;
- пользователь находится в `memberIds`;
- роль пользователя `owner` или `admin`;
- изменяются только разрешённые avatar keys;
- version строго возрастает;
- metadata полная и согласованная.

Остальные group update flows должны продолжать работать через свои отдельные rule predicates.

---

## 15. Storage Security Rules для аватаров

### 15.1 Пользовательские пути

```text
/user_avatars/{uid}/{version}/thumb.jpg
/user_avatars/{uid}/{version}/full.jpg
```

Проверяется:

- аутентификация;
- `request.auth.uid == uid` для write/delete;
- корректный version segment;
- MIME type `image/jpeg`;
- thumbnail до `128 KB`;
- full до `512 KB`.

### 15.2 Групповые пути

```text
/group_avatars/{chatId}/{version}/thumb.jpg
/group_avatars/{chatId}/{version}/full.jpg
```

Для write/delete Storage Rules читают chat document и проверяют:

- group chat;
- membership;
- роль `owner` или `admin`;
- корректную version;
- MIME type;
- размер.

### 15.3 Update существующего объекта

Версионная стратегия использует создание нового path.

```text
allow update: false
```

Новая версия создаётся отдельным объектом, а предыдущая удаляется после успешной metadata transaction.

---

## 16. Push Notification Foundation

### 16.1 Архитектура

```text
новое message document
        ↓
Firestore onDocumentCreated trigger
        ↓
sendMessageNotification
        ↓
чтение memberIds
        ↓
исключение отправителя
        ↓
чтение device tokens
        ↓
FCM multicast
```

Cloud Function:

```text
sendMessageNotification
```

Trigger:

```text
chats/{chatId}/messages/{messageId}
```

Region:

```text
europe-west1
```

### 16.2 Device registration

```text
users/{uid}/devices/{installationId}
```

Поддерживается:

- регистрация FCM token;
- обновление token;
- удаление token текущего устройства при logout;
- удаление невалидных tokens серверной функцией.

### 16.3 Состояния приложения

Проверено:

- foreground;
- background;
- terminated;
- заблокированный экран.

### 16.4 Известное ограничение

Нажатие на push открывает приложение, но пока не выполняет deep-link непосредственно в нужный chat.

Это отдельный будущий этап.

---

## 17. Message Deletion Foundation

### 17.1 Состояния

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

### 17.2 Удаление у себя

- сообщение скрывается только для текущего пользователя;
- документ физически не удаляется;
- второй участник продолжает видеть сообщение.

### 17.3 Удаление у всех

- доступно только отправителю;
- текст очищается;
- сохраняются признаки logical deletion;
- сообщение отображается как удалённое состояние;
- document ID и cursor остаются стабильными.

### 17.4 Preview карточки чата

При удалении последнего сообщения выполняется поиск предыдущего видимого сообщения.

Учитываются:

- `deletedForEveryone`;
- персональный `hiddenFor`;
- `clearedAtByUser`;
- время сообщения.

---

## 18. Роли и модерация групп

Поддерживаемые роли:

```text
owner
admin
moderator
member
guest
```

Будущая роль `owner` считается максимальной по приоритету.

Поддерживается:

- mute;
- ban;
- ограничение отправки;
- управление участниками;
- передача прав;
- защита последнего администратора;
- безопасный выход;
- роспуск группы;
- permissions на добавление участников.

Правила UI не заменяют Firestore Security Rules.

Даже скрытое действие должно быть запрещено на backend-уровне.

---

## 19. Контроль Firestore reads

Основные меры:

- pagination по 20 сообщений;
- старая история только по запросу прокрутки;
- in-memory avatar cache;
- дедупликация parallel avatar loads;
- thumbnail в списках;
- full только там, где он действительно нужен;
- отсутствие создания пустых private chats;
- Firestore хранит metadata, а не binary files.

Цель — рациональная работа для пилотной группы 40–50 пользователей.

Оптимизация должна опираться на реальные метрики, а не только на предположения.

---

## 20. Контроль Storage usage

Принципы:

- оригинальные фотографии не загружаются;
- используются thumbnail и full;
- thumbnail ограничен `128 KB`;
- full ограничен `512 KB`;
- при замене используется новая version;
- старая version удаляется best-effort;
- orphaned upload откатывается при ошибке metadata;
- UI списков использует thumbnail;
- повторные загрузки сокращаются cache.

В будущем необходимы:

- persistent disk cache;
- аудит orphaned assets;
- автоматическая cleanup strategy;
- мониторинг egress;
- лимиты для message attachments.

---

## 21. Тестирование

### 21.1 Автоматические проверки

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
git.exe diff --check
git.exe status --short
```

Последний результат Avatar Foundation:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 251 tests passed

flutter.bat build apk --release
→ успешно, 54.4 MB
```

### 21.2 Android-проверки пользовательских аватаров

Проверено:

- галерея;
- камера;
- crop;
- отмена;
- установка;
- замена;
- Firestore metadata;
- Firebase Storage;
- profile;
- private chat list;
- chat header;
- chat search;
- contacts;
- draft chat;
- users without existing chat.

### 21.3 Android-проверки групповых аватаров

Проверено:

```text
камера → crop → установка
галерея → crop → замена
```

Также проверено:

- Storage version folder;
- thumbnail и full;
- metadata update;
- group info;
- group list;
- chat search;
- group chat header;
- fallback группы без фотографии;
- пользовательские аватары участников.

### 21.4 Security Rules

Firestore и Storage Rules были:

- проверены компиляцией;
- проверены локальными emulators;
- развёрнуты в Firebase project.

Rules emulator test suite требуется расширять дальше.

---

## 22. Release process

Перед стабильным тегом:

```text
1. Завершить feature branch.
2. Выполнить ручные проверки.
3. Выполнить analyze.
4. Выполнить tests.
5. Собрать release APK.
6. Обновить PROJECT_CONTEXT.md.
7. Обновить README.md.
8. Обновить ARCHITECTURE.md.
9. Закоммитить документацию.
10. Слить branch в main.
11. Повторить проверки на main.
12. Создать annotated tag.
13. Отправить main и tag.
```

Для `v0.6.5`:

```powershell
git.exe tag -a v0.6.5 -m "Avatar Foundation"
git.exe push origin v0.6.5
```

Feature-изменения нельзя смешивать с несвязанным обновлением Android/Kotlin toolchain.

---

## 23. Команды Windows

Проект использует PowerShell и явные executable-имена:

```powershell
flutter.bat pub get
flutter.bat run
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release

firebase.cmd deploy --only firestore:rules,storage
firebase.cmd deploy --only firestore:indexes

git.exe status --short
git.exe diff --check
git.exe add .
git.exe commit
git.exe push
```

Форматирование Dart:

```powershell
$flutterBin = Split-Path (Get-Command flutter.bat).Source
$dartExe = Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe"

& $dartExe format lib test
```

---

## 24. Неприкосновенные функции

Нельзя ломать:

- соответствие Firebase Auth UID документу `users/{uid}`;
- регистрацию и авторизацию;
- постоянную сессию;
- личные сообщения;
- групповые сообщения;
- создание private chat только после первого сообщения;
- отсутствие пустых private chats;
- атомарное первое сообщение;
- атомарное обновление last-message metadata;
- pagination по 20;
- персональную очистку private chat;
- logical message deletion;
- push-уведомления;
- поиск пользователей;
- контакты;
- поиск чатов по peer identity;
- роли;
- mute;
- ban;
- передачу прав;
- защиту последнего администратора;
- безопасный выход;
- Media Foundation abstractions;
- versioned avatar storage;
- atomic avatar replacement;
- rollback при ошибке metadata;
- fallback на инициалы;
- отдельный заменяемый UI-слой.

---

## 25. Известный технический долг

### 25.1 Высокий и средний приоритет

- Push deep-link непосредственно в chat.
- Persistent avatar disk cache.
- Расширение Firestore Rules emulator tests.
- Конкурентные avatar-операции с двух устройств.
- Дальнейшая оптимизация Firestore reads.
- Мониторинг Storage egress.
- Аудит orphaned media.
- Разделение большого технического документа на `docs/`.

### 25.2 Android toolchain

Release build показывает предупреждение о будущем требовании Built-in Kotlin для некоторых plugins.

Текущая сборка успешна.

Обновление:

- Kotlin Gradle Plugin;
- Android Gradle Plugin;
- Gradle wrapper;
- plugin compatibility;

должно выполняться отдельным техническим этапом после `v0.6.5`.

### 25.3 Будущий UI

Через отдельный UI-слой планируются:

- темы;
- фон чатов;
- формы пузырей;
- размер пузырей;
- размеры шрифтов;
- семейства шрифтов;
- анимации удаления;
- анимации avatar replacement;
- оформление карточек;
- дополнительные visual effects.

---

## 26. Будущие Media-этапы

- изображения в сообщениях;
- preview;
- документы;
- карточки файлов;
- полноэкранный просмотр изображений;
- upload progress;
- retry;
- voice messages;
- video;
- persistent cache;
- automatic cache cleanup;
- hybrid storage;
- file retention policy.

Новые media-функции должны использовать существующие:

```text
MediaAsset
MediaPaths
MediaStorageProvider
MediaStorageService
```

Они не должны напрямую встраивать Firebase Storage calls в UI.

---

## 27. Spaces

Spaces — долгосрочное направление проекта.

Предполагаемая структура:

```text
Space
├── chats
├── groups
├── tasks
├── announcements
├── documents
├── shifts
└── mini-apps
```

Каждый модуль должен использовать:

- domain model;
- application services;
- infrastructure adapters;
- Security Rules;
- отдельный заменяемый UI;
- контролируемые Firestore reads.

---

## 28. Правила разработки

- Работать маленькими проверяемыми шагами.
- Не коммитить до ручного теста изменённого сценария.
- После этапа выполнять format, analyze, test и release build.
- Не смешивать feature и toolchain update.
- UI держать отдельно от application logic.
- Firebase calls держать в infrastructure adapters.
- Storage paths хранить централизованно.
- Не загружать несжатые оригиналы.
- Security Rules считать обязательной частью feature.
- После стабильного этапа обновлять документацию.
- После стабильной версии создавать Git tag.
- Учитывать пилотную группу 40–50 пользователей и расходы Firebase.

---

## 29. План завершения v0.6.5

```text
1. Обновить PROJECT_CONTEXT.md.
2. Обновить README.md.
3. Обновить ARCHITECTURE.md.
4. Выполнить diff check.
5. Выполнить analyze.
6. Выполнить tests.
7. Собрать release APK.
8. Закоммитить документацию.
9. Push feature branch.
10. Merge в main.
11. Повторить проверки.
12. Создать tag v0.6.5.
13. Push main и tag.
```

После выпуска `v0.6.5` Avatar Foundation считается стабильной базой для дальнейших media- и UI-этапов.
