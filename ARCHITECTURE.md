# Epistola — Architecture

> Основной технический документ проекта Epistola.
>
> При расхождении информации используется следующий приоритет:
>
> ```text
> исходный код
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```
>
> `PROJECT_CONTEXT.md` — главный handoff-документ текущего состояния.
> `ARCHITECTURE.md` — устойчивые архитектурные решения.
> `README.md` — краткое знакомство с проектом.

---

## 1. Статус документа

| Параметр | Значение |
| --- | --- |
| Версия документа | `3.1` |
| Базовая стабильная версия | `v0.6.5` |
| Последний стабильный commit | `3d0974c` |
| Текущий этап | **Android Toolchain Foundation** |
| Планируемая версия | `v0.6.6` |
| Рабочая ветка | `chore/v0.6.6-android-toolchain` |
| Следующий функциональный этап | `v0.7.0 Image Message Foundation` |
| Последнее обновление | Июль 2026 |

Текущий технический этап не добавляет пользовательские функции и не начинает передачу изображений в сообщениях.

---

## 2. Назначение проекта

Epistola — корпоративный мессенджер на Flutter и Firebase.

Краткосрочные цели:

- стабильное Android-приложение;
- пилотная группа 40–50 пользователей;
- контролируемые расходы Firebase;
- небольшие проверяемые этапы;
- заменяемый UI;
- безопасная подготовка к media messages.

Долгосрочные цели:

- корпоративный мессенджер на 600–700 сотрудников;
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

## 3. Инфраструктура

### 3.1 Репозиторий

```text
MikhailBerezkin/epistola
```

Исторический архив:

```text
Metaxa251/epistola
```

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

### 3.3 Инфраструктурные файлы

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

Infrastructure configuration должна оставаться вне UI и business logic.

---

## 4. Android Toolchain Foundation — `v0.6.6`

### 4.1 Цель этапа

- зафиксировать версии Flutter, Dart, Java, Gradle, AGP и Kotlin;
- проверить Android SDK levels;
- проверить `firebase_storage` и `flutter_image_compress`;
- локализовать предупреждение Built-in Kotlin;
- внести только необходимые изменения;
- не смешивать toolchain update с Image Message Foundation.

### 4.2 Зафиксированная конфигурация

```text
Flutter: 3.44.1 stable
Dart: 3.12.1
DevTools: 2.57.0

Java: OpenJDK 21.0.10
Java provider: Android Studio bundled JBR
Java path: C:\Program Files\Android\Android Studio\jbr\bin\java

Android SDK: 36.1.0
Android platform: android-36.1
Android build-tools: 36.1.0

Gradle Wrapper: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
Google Services Plugin: 4.3.15

compileSdk: 36
targetSdk: 36
minSdk: 24
Java/Kotlin bytecode target: JVM 17
```

### 4.3 Kotlin versions

```text
Kotlin Gradle Plugin 2.3.20
→ plugin приложения из android/settings.gradle.kts

Kotlin 2.2.0 в gradlew --version
→ Kotlin, встроенный в сам Gradle
```

Это не конфликт.

### 4.4 Java

Flutter использует JDK Android Studio:

```text
C:\Program Files\Android\Android Studio\jbr
```

Если `java.exe -version` не работает через обычный PowerShell, это означает только отсутствие Java в глобальном `PATH`.

Для текущего терминала:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

& "$env:JAVA_HOME\bin\java.exe" -version
.\android\gradlew.bat -p .\android --version
```

### 4.5 Android SDK levels

В `android/app/build.gradle.kts` используются Flutter defaults:

```kotlin
compileSdk = flutter.compileSdkVersion
minSdk = flutter.minSdkVersion
targetSdk = flutter.targetSdkVersion
```

Зафиксированные значения:

```text
compileSdk: 36
targetSdk: 36
minSdk: 24
```

### 4.6 JVM target

```text
JDK 21
→ запускает Gradle и Android toolchain

JVM 17
→ bytecode target приложения
```

Эти значения выполняют разные задачи.

### 4.7 Compatibility flags

В `android/gradle.properties`:

```properties
android.useAndroidX=true
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
```

`android.newDsl=false` и `android.builtInKotlin=false` нужны для временной совместимости с плагинами, которые ещё применяют Kotlin Gradle Plugin прежним способом.

Удалять эти flags без подтверждённой миграции нельзя.

### 4.8 Медиа-зависимости

```text
firebase_storage: 13.4.5
flutter_image_compress: 2.5.1
flutter_image_compress_common: 1.1.1
```

`flutter.bat pub outdated` не показал доступных обновлений для:

```text
firebase_storage
flutter_image_compress
```

### 4.9 Built-in Kotlin warning

Warning вызывают:

```text
firebase_storage
flutter_image_compress_common
```

Причина:

- внутренние Android-модули плагинов применяют Kotlin Gradle Plugin;
- будущие версии Flutter потребуют Built-in Kotlin;
- текущая сборка ещё поддерживается;
- release APK успешно собирается.

Предупреждение относится к plugin internals, а не к устаревшему Kotlin в Epistola.

Принятое решение:

```text
не редактировать Pub Cache
не обновлять Gradle/AGP/Kotlin вслепую
не удалять compatibility flags
сохранить текущую рабочую конфигурацию
ждать официальной миграции плагинов
```

### 4.10 Результат проверок

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 251 tests passed

flutter.bat build apk --release
→ успешно, 54.4 MB
```

APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

### 4.11 Generated plugin files

Flutter может автоматически менять:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake
```

Если изменения не относятся к задаче:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

---

## 5. Общая архитектура

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

| Слой | Ответственность |
| --- | --- |
| UI | Отображение и пользовательские действия |
| Controller | Сериализация UI-операций и UI-state |
| Application service | Use case, rollback, cleanup |
| Domain | Модели, инварианты, контракты |
| Infrastructure | Firestore, Storage, FCM, внешние SDK |

Ограничения:

- UI не выполняет прямой Storage upload;
- UI не выполняет Firestore transaction;
- UI не содержит rollback и cleanup;
- UI не определяет security policy;
- Domain не зависит от Flutter;
- Domain не зависит от Firebase;
- Firebase implementation скрывается за contracts;
- визуальный слой остаётся заменяемым;
- feature и toolchain changes не смешиваются.

---

## 6. Структура кода

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

Часть legacy models пока находится в `lib/models`.

Перенос выполняется постепенно, только при работе с соответствующим модулем.

---

## 7. Заменяемый UI

UI отвечает за:

- размеры;
- отступы;
- цвета;
- шрифты;
- анимации;
- Material widgets;
- пользовательские действия;
- отображение controller result.

UI не отвечает за:

- Storage paths;
- Firebase transaction;
- rollback;
- cleanup;
- version validation;
- security roles;
- binary processing;
- orphan cleanup.

### 7.1 Avatar UI

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

```text
private chat → UserAvatarView
group chat   → GroupAvatarView
нет фото     → fallback
```

Можно менять форму, размер, цвет, анимации и темы без изменения Firebase logic.

### 7.2 Message UI

```text
Firestore message state
        ↓
MessagePresentation
        ↓
MessageItem
        ↓
MessageBubble
```

Presentation layer позволяет менять bubble UI без изменения message deletion model.

### 7.3 Будущий Image Message UI

```text
ImageMessagePresentation
        ↓
ImageMessageBubble
        ↓
thumbnail / progress / retry / error UI
```

Image bubble не должен выполнять upload, transaction, rollback или cleanup.

---

## 8. Архитектура чатов

### 8.1 ChatService facade

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

### 8.2 Private chat

```text
выбор собеседника
→ draft screen
→ chat document ещё не существует
→ первое сообщение
→ atomic creation chat + message
```

Пустые private chats не создаются.

Техническое имя:

```text
name: private_chat
```

не является пользовательским display name.

### 8.3 Атомарная отправка

```text
message document
+ lastMessage
+ lastMessageAt
+ lastMessageId
```

обновляются согласованно.

### 8.4 Pagination

```text
первый запрос → последние 20 сообщений
scroll up     → следующая страница 20 сообщений
```

Гарантии:

- старая история не читается заранее;
- documents дедуплицируются по ID;
- порядок остаётся хронологическим;
- scroll position сохраняется;
- одновременно загружается одна старая page;
- realtime updates не удаляют загруженную историю.

### 8.5 Персональная очистка

```text
clearedAtByUser
```

скрывает историю только для текущего пользователя.

---

## 9. Поиск чатов

Private chat ищется по профилю второго участника:

- имя;
- email;
- доступные profile fields.

Group chat ищется по названию группы.

```text
chat document
→ resolve peer
→ display identity
→ matchesSearch()
→ ChatTile
```

Техническое значение `private_chat` не участвует в пользовательском поиске.

---

## 10. Media Foundation — `v0.6.2`

Основные элементы:

```text
MediaAsset
MediaPaths
MediaStorageProvider
FirebaseMediaStorageProvider
MediaStorageService
```

| Элемент | Ответственность |
| --- | --- |
| `MediaAsset` | Доменное описание media |
| `MediaPaths` | Централизованные paths |
| `MediaStorageProvider` | Storage contract |
| `FirebaseMediaStorageProvider` | Firebase adapter |
| `MediaStorageService` | Application facade |

Главный источник истины:

```text
provider + storage path + version
```

Download URL не является доменной основой.

Возможные будущие providers:

```text
Firebase Storage
S3-compatible storage
Yandex Object Storage
Cloudflare R2
локальный сервер компании
собственный Epistola backend
```

---

## 11. Avatar Foundation — `v0.6.5`

### 11.1 Pipeline

```text
галерея или камера
→ crop 1:1
→ JPEG processing
→ thumb 128x128
→ full 512x512
→ size validation
```

Поддерживается:

- gallery;
- camera;
- picker/crop cancel;
- Android lost-data recovery;
- orientation fix;
- EXIF removal;
- temporary cleanup;
- upload только подготовленных variants.

Лимиты:

```text
thumb: максимум 128 KB
full: целевой размер до 300 KB
full: абсолютный максимум 512 KB
MIME: image/jpeg
```

### 11.2 Слои

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

Controller result:

```text
success
cancelled
failure
alreadyRunning
```

---

## 12. Пользовательские аватары

### 12.1 Storage paths

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Legacy:

```text
user_avatars/{uid}/avatar.jpg
```

### 12.2 Firestore metadata

```text
users/{uid}
```

```text
avatarProvider
avatarThumbStoragePath
avatarFullStoragePath
avatarThumbSizeBytes
avatarFullSizeBytes
avatarVersion
avatarUpdatedAt
```

`avatarUrl` читается только как legacy fallback.

### 12.3 Atomic replacement

```text
prepare
→ upload new version
→ Firestore transaction
→ best-effort cleanup old version
```

Гарантии:

- старый avatar остаётся активным до успешной transaction;
- incomplete upload очищается;
- metadata failure вызывает rollback новой version;
- cleanup failure не отменяет новый avatar;
- version строго возрастает;
- stale operation не перезаписывает новую.

### 12.4 Отображение

- profile;
- contacts;
- private chat list;
- chat search;
- private chat header;
- draft chat;
- group members.

Fallback:

- максимум две буквы;
- стабильный цвет по UID.

---

## 13. Групповые аватары

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

### 13.1 Storage paths

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

### 13.2 Metadata

```text
chats/{chatId}
```

Thumb и full должны принадлежать одному `chatId`, provider и version.

### 13.3 Permissions

Управление доступно только:

```text
owner
admin
```

### 13.4 Replacement

```text
prepare
→ upload
→ transaction group metadata
→ best-effort cleanup
```

### 13.5 Отображение

- group info;
- group list;
- chat search;
- group chat header.

Fallback — первая буква названия группы.

---

## 14. Avatar loading и cache

```text
cache key = storagePath@version
```

Реализовано:

- path-first loading;
- in-memory LRU cache;
- deduplication parallel requests;
- byte limit validation;
- legacy URL fallback;
- initials fallback.

Текущий cache не сохраняется после перезапуска приложения.

---

## 15. Security Rules для аватаров

### 15.1 Firestore

User avatar:

- update только владельцем `users/{uid}`;
- полный согласованный metadata set;
- version строго возрастает;
- paths соответствуют UID и version.

Group avatar:

- authenticated user;
- group exists;
- `type == group`;
- membership;
- role `owner` или `admin`;
- разрешённые avatar fields;
- согласованная metadata;
- возрастающая version.

### 15.2 Storage

User paths:

```text
/user_avatars/{uid}/{version}/thumb.jpg
/user_avatars/{uid}/{version}/full.jpg
```

Group paths:

```text
/group_avatars/{chatId}/{version}/thumb.jpg
/group_avatars/{chatId}/{version}/full.jpg
```

Проверяются:

- authentication;
- ownership/role;
- MIME `image/jpeg`;
- valid version;
- size limits.

Existing object update запрещён:

```text
allow update: false
```

---

## 16. Push Notification Foundation — `v0.6.3`

```text
new message
→ Firestore trigger
→ sendMessageNotification
→ memberIds
→ exclude sender
→ device tokens
→ FCM multicast
```

Trigger:

```text
chats/{chatId}/messages/{messageId}
```

Region:

```text
europe-west1
```

Device registration:

```text
users/{uid}/devices/{installationId}
```

Известное ограничение: push tap открывает приложение, но не выполняет deep-link в конкретный chat.

---

## 17. Message Deletion Foundation — `v0.6.4`

Состояния:

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

Delete-for-self:

- скрывает сообщение только текущему пользователю;
- не удаляет document;
- не влияет на второго участника.

Delete-for-everyone:

- доступно только sender;
- переводит message в logical deleted state;
- сохраняет document ID и cursor.

Preview последнего сообщения ищет предыдущий visible message с учётом:

- `deletedForEveryone`;
- `hiddenFor`;
- `clearedAtByUser`;
- timestamp.

---

## 18. Роли и модерация

```text
owner
admin
moderator
member
guest
```

Поддерживается:

- mute;
- ban;
- sending restrictions;
- управление участниками;
- передача прав;
- защита последнего администратора;
- безопасный выход;
- роспуск группы;
- permissions на добавление участников.

UI restrictions не заменяют Firestore Rules.

---

## 19. Контроль Firestore и Storage usage

Firestore:

- pagination по 20;
- старая история по запросу;
- отсутствие пустых private chats;
- metadata вместо binary data;
- avatar cache;
- thumbnail в списках.

Storage:

- оригиналы не загружаются;
- thumb + full;
- versioned paths;
- rollback orphan upload;
- best-effort cleanup old version;
- full только там, где он нужен.

Цель — рациональная работа для 40–50 пользователей.

---

## 20. Image Message Foundation — `v0.7.0`

Начинается только после закрытия `v0.6.6`.

### 20.1 Первый подэтап

```text
Image Message Domain + Metadata Foundation
```

Сначала проектируются:

- message type `image`;
- domain model;
- metadata schema;
- thumbnail/full assets;
- provider;
- paths;
- sizes;
- dimensions;
- MIME;
- version;
- upload states;
- retry;
- rollback;
- cleanup;
- preview;
- push representation;
- deletion compatibility.

### 20.2 Будущий поток

```text
галерея или камера
→ preparation
→ thumbnail + full
→ Firebase Storage
→ message metadata
→ image bubble
→ fullscreen viewer
```

### 20.3 Архитектура

```text
Image Message UI
        ↓
ImageMessageController
        ↓
ImagePreparationService
        ↓
ImageMessageUploadService
        ↓
ImageMessageSendService
        ↓
Domain contracts
        ↓
Storage + Firestore adapters
```

### 20.4 Предварительные paths

Финальный формат пока не утверждён.

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

До утверждения нужно проверить:

- получение `messageId` до upload;
- retry semantics;
- orphan cleanup;
- delete-for-everyone policy;
- Storage Rules;
- количество Firebase operations;
- необходимость version segment.

### 20.5 Pagination compatibility

Image message должен оставаться обычным элементом message stream.

Нельзя:

- создавать отдельный parallel message list;
- ломать cursor;
- сбрасывать загруженную history;
- загружать full при каждом snapshot.

### 20.6 Deletion compatibility

Delete-for-self:

- не удаляет Storage asset;
- не влияет на второго участника.

Delete-for-everyone:

- сохраняет message document;
- переводит в `deletedForEveryone`;
- очищает preview;
- physical cleanup требует отдельной policy.

### 20.7 Preview и push

```text
chat preview: Фотография
push text: Фотография
```

Push Function не должна читать binary image.

### 20.8 Экономия Firebase

- не хранить original;
- thumbnail для bubble/list;
- full только при открытии;
- cache key по path/version;
- deduplicate downloads;
- ограничивать downloaded bytes;
- cleanup failed uploads;
- избегать Storage list;
- контролировать egress и operation count.

---

## 21. Тестирование

Основные команды:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
git.exe diff --check
git.exe status --short
```

Последний результат `v0.6.6`:

```text
analyze → No issues found
test → 251 tests passed
release APK → успешно, 54.4 MB
```

JPEG diagnostics в тестах:

```text
Corrupt JPEG data
JPEG datastream contains no image
```

не являются падением, если итог — `All tests passed`.

### 21.1 Android regression `v0.6.6`

Перед release:

- запуск;
- login;
- private chats;
- group chats;
- user avatars;
- group avatars;
- gallery;
- camera;
- crop;
- replacement;
- Firestore metadata;
- Firebase Storage.

---

## 22. Release process

```text
1. Завершить рабочую ветку.
2. Выполнить ручные проверки.
3. Выполнить format.
4. Выполнить analyze.
5. Выполнить tests.
6. Собрать release APK.
7. Обновить PROJECT_CONTEXT.md.
8. Обновить ARCHITECTURE.md.
9. Обновить README.md.
10. Выполнить diff check.
11. Commit.
12. Push branch.
13. Merge в main.
14. Повторить проверки.
15. Создать annotated tag.
16. Push main и tag.
```

Для `v0.6.6`:

```powershell
git.exe tag -a v0.6.6 -m "Android Toolchain Foundation"
git.exe push origin v0.6.6
```

---

## 23. Команды Windows

Flutter:

```powershell
flutter.bat --version
flutter.bat doctor -v
flutter.bat pub get
flutter.bat pub deps --style=compact
flutter.bat pub outdated
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

Format:

```powershell
$flutterBin = Split-Path (Get-Command flutter.bat).Source
$dartExe = Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe"

& $dartExe format lib test
```

Java/Gradle:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

& "$env:JAVA_HOME\bin\java.exe" -version
.\android\gradlew.bat -p .\android --version
```

Firebase/Node:

```powershell
firebase.cmd --version
firebase.cmd deploy --only firestore:rules,storage
firebase.cmd deploy --only firestore:indexes
npm.cmd --version
```

Git:

```powershell
git.exe status --short
git.exe diff
git.exe diff --check
git.exe log -1 --oneline --decorate
git.exe branch --show-current
git.exe add .
git.exe commit
git.exe push
```

---

## 24. Неприкосновенные функции

Нельзя ломать:

- Auth UID ↔ `users/{uid}`;
- регистрацию и login;
- постоянную сессию;
- private/group messages;
- private chat только после первого message;
- отсутствие пустых private chats;
- atomic first message;
- atomic last-message metadata;
- pagination по 20;
- сохранение history при realtime updates;
- personal chat clear;
- delete-for-self;
- delete-for-everyone только sender;
- push notifications;
- user/contact/chat search;
- private chat search по peer identity;
- roles, mute, ban;
- передача прав;
- защита последнего администратора;
- безопасный выход;
- Media Foundation contracts;
- versioned user/group avatars;
- atomic replacement;
- rollback;
- path-first loading;
- initials/group fallback;
- заменяемый UI;
- будущую роль `owner` максимального приоритета.

---

## 25. Технический долг

Высокий и средний приоритет:

- push deep-link в chat;
- persistent avatar disk cache;
- расширение Rules emulator tests;
- конкурентные avatar operations;
- оптимизация Firestore reads;
- monitoring Storage egress;
- orphan media audit;
- signing configuration production APK;
- message media retention policy;
- image upload cleanup strategy.

Android toolchain:

```text
firebase_storage
flutter_image_compress_common
→ требуют будущую миграцию на Built-in Kotlin
```

Сейчас release build успешен, совместимых обновлений нет, compatibility flags сохраняются.

Отложенные небольшие обновления:

```text
flutter_local_notifications: 22.1.0 → 22.2.0
image_picker: 1.2.2 → 1.2.3
```

Они не входят в `v0.6.6`.

---

## 26. Spaces

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

Каждый модуль должен иметь:

- domain model;
- application services;
- infrastructure adapters;
- Security Rules;
- заменяемый UI;
- контролируемые reads.

---

## 27. Правила разработки

- Работать маленькими проверяемыми шагами.
- После каждого шага ждать результат пользователя.
- Не коммитить до ручного теста изменённого сценария.
- После этапа выполнять format, analyze, test и release build.
- Не смешивать feature и toolchain update.
- UI держать отдельно от application logic.
- Firebase calls держать в infrastructure adapters.
- Storage paths хранить централизованно.
- Не загружать несжатые оригиналы.
- Security Rules считать частью feature.
- После стабильного этапа обновлять документацию.
- После стабильной версии создавать Git tag.
- Учитывать пилотную группу 40–50 пользователей.
- Image Message Foundation начинать с domain + metadata.
- Не редактировать Pub Cache.
- Не удалять compatibility flags без доказанной совместимости.
- Не коммитить generated plugin files без причины.

---

## 28. План завершения `v0.6.6`

```text
1. Обновить PROJECT_CONTEXT.md.
2. Обновить ARCHITECTURE.md.
3. Обновить README.md.
4. Выполнить diff check.
5. Проверить release APK на Android.
6. Проверить login.
7. Проверить user avatars.
8. Проверить group avatars.
9. Проверить gallery.
10. Проверить camera.
11. Проверить crop.
12. Проверить Firestore metadata.
13. Проверить Firebase Storage.
14. Выполнить format.
15. Выполнить analyze.
16. Выполнить tests.
17. Собрать release APK.
18. Восстановить generated plugin files.
19. Commit.
20. Push branch.
21. Merge в main.
22. Повторить проверки.
23. Создать tag v0.6.6.
24. Push main и tag.
25. Создать ветку v0.7.0.
26. Начать Image Message Domain + Metadata Foundation.
```

После выпуска `v0.6.6` Android Toolchain Foundation считается технической базой для `v0.7.0 Image Message Foundation`.
