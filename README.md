# Epistola

> **Корпоративный мессенджер на Flutter и Firebase**

Epistola — Android-first корпоративный мессенджер и долгосрочная коммуникационная платформа. Проект развивается небольшими проверяемыми этапами с разделением UI, application logic, domain-моделей и Firebase infrastructure.

---

## 🚧 Статус проекта

| Параметр | Значение |
| --- | --- |
| Последний стабильный релиз | `v0.6.5` |
| Последний стабильный commit | `3d0974c` |
| Текущий этап | **Android Toolchain Foundation** |
| Планируемая техническая версия | `v0.6.6` |
| Рабочая ветка | `chore/v0.6.6-android-toolchain` |
| Следующий функциональный этап | `v0.7.0 Image Message Foundation` |
| Основная платформа | Android |
| Backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Пилотная группа | примерно 40–50 пользователей |

`v0.6.5 Avatar Foundation` выпущен и является текущей стабильной базой.

В `v0.6.6 Android Toolchain Foundation` выполнен аудит Flutter, Java, Gradle, Android Gradle Plugin, Kotlin и медиа-зависимостей. Код приложения и Android-конфигурация пока не менялись: текущая связка совместима, а release APK успешно собирается.

```text
Flutter: 3.44.1 stable
Dart: 3.12.1
Java: OpenJDK 21.0.10
Gradle Wrapper: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20

compileSdk: 36
targetSdk: 36
minSdk: 24
JVM target: 17
```

Последние проверки:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 251 tests passed

flutter.bat build apk --release
→ успешно
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Размер:

```text
54.4 MB
```

---

## ⚡ Что такое Epistola

Краткосрочная цель — стабильный мессенджер для пилотной группы 40–50 пользователей.

Долгосрочная цель — коммуникационная платформа для компании на 600–700 сотрудников:

- личные и групповые чаты;
- роли и модерация;
- Spaces;
- задачи;
- объявления;
- документы;
- рабочие смены;
- файлы и медиа;
- мини-приложения;
- внутренние корпоративные сервисы;
- возможный собственный backend.

Основной принцип:

> Сначала надёжная архитектура, затем функциональность поверх неё.

---

## ✨ Реализованные возможности

### 🔐 Пользователи и авторизация

- Firebase Authentication.
- Регистрация.
- Вход по E-mail и паролю.
- Постоянная сессия.
- Запоминание последнего E-mail.
- Профиль пользователя.
- Редактирование профиля.
- Публичный контактный E-mail, независимый от FirebaseAuth.
- Карточка контакта.
- Поиск пользователей.
- Экран контактов.
- Пользовательские аватары.

### 💬 Чаты и сообщения

- Личные чаты.
- Групповые чаты.
- Создание private chat только после первого сообщения.
- Отсутствие пустых private chats.
- Атомарное создание первого сообщения и metadata чата.
- Cursor pagination по 20 сообщений.
- Дозагрузка старой истории при прокрутке вверх.
- Сохранение позиции прокрутки.
- Realtime-обновления без потери загруженной истории.
- Последнее видимое сообщение в карточке чата.
- Счётчик непрочитанных сообщений.
- Персональная очистка private chat.
- Поиск чатов по данным собеседника и названию группы.
- Логическое удаление сообщений.

### 👥 Группы

- Создание групп.
- Добавление участников.
- Информация о группе.
- Список участников.
- Карточки участников.
- Передача прав.
- Защита последнего администратора.
- Безопасный выход.
- Роспуск группы.
- Настройки группы.
- Ограничение отправки по ролям.
- Групповые аватары.
- Управление групповым аватаром для `owner` и `admin`.

### 🛡️ Роли и модерация

Поддерживаемые роли:

```text
owner
admin
moderator
member
guest
```

Реализовано:

- mute;
- ban;
- разграничение прав;
- ограничения отправки;
- управление участниками;
- скрытие недоступных действий в UI;
- Firestore Rules для ролей и permissions;
- защита последнего администратора;
- передача прав и безопасный выход.

---

## 🔔 Push Notification Foundation — `v0.6.3`

Реализовано:

- Firebase Cloud Messaging;
- локальные Android-уведомления;
- foreground, background и terminated-состояния;
- уведомления при заблокированном экране;
- регистрация FCM tokens;
- обновление token;
- удаление token текущего устройства при logout;
- Cloud Function `sendMessageNotification`;
- регион `europe-west1`;
- исключение отправителя;
- личные и групповые push;
- очистка невалидных tokens.

Известное ограничение:

```text
нажатие на уведомление открывает приложение,
но пока не переводит непосредственно в нужный чат
```

---

## 🗑 Message Deletion Foundation — `v0.6.4`

Поддерживаемые состояния:

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

Реализовано:

- удалить сообщение у себя;
- удалить собственное сообщение у всех;
- «Удалить у всех» только для отправителя;
- logical deletion без физического удаления Firestore document;
- отдельная `MessagePresentation`;
- отдельный `MessageItem`;
- стабильность pagination;
- поиск предыдущего видимого сообщения для chat preview;
- отсутствие повторного push при logical deletion.

Presentation flow:

```text
Firestore message state
        ↓
MessagePresentation
        ↓
MessageItem
        ↓
MessageBubble
```

Это позволяет менять bubble UI без изменения Firestore deletion logic.

---

## 🖼 Avatar Foundation — `v0.6.5`

### Пользовательские аватары

Поддерживается:

- галерея;
- камера;
- квадратный crop `1:1`;
- отмена picker и crop;
- Android `retrieveLostData()`;
- thumbnail `128×128`;
- full `512×512`;
- JPEG-сжатие;
- коррекция ориентации;
- удаление EXIF;
- ограничения размера;
- очистка временных файлов;
- versioned Storage paths;
- atomic replacement;
- rollback при ошибке metadata;
- best-effort cleanup старой версии;
- path-first loading;
- in-memory LRU cache;
- дедупликация parallel loads;
- fallback на две буквы и стабильный цвет.

Storage paths:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Firestore metadata:

```text
avatarProvider
avatarThumbStoragePath
avatarFullStoragePath
avatarThumbSizeBytes
avatarFullSizeBytes
avatarVersion
avatarUpdatedAt
```

Отображение:

- профиль;
- контакты;
- список private chats;
- поиск чатов;
- заголовок private chat;
- draft chat;
- участники группы.

### Групповые аватары

Реализовано отдельно от пользовательских:

- `GroupAvatar`;
- metadata mapper;
- Storage upload service;
- Firestore metadata gateway;
- atomic replacement service;
- replacement controller;
- Firestore Rules;
- Storage Rules;
- gallery/camera/crop;
- установка и замена;
- управление только `owner` и `admin`.

Storage paths:

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Metadata хранится в:

```text
chats/{chatId}
```

Отображение:

- информация о группе;
- список групп;
- поиск чатов;
- заголовок group chat.

Fallback — первая буква названия группы.

---

## 🔎 Поиск чатов

Private chat в Firestore может иметь техническое поле:

```text
name: private_chat
```

Пользовательский поиск не зависит от этого значения.

Private chat ищется по:

- имени второго участника;
- E-mail;
- доступным данным профиля.

Group chat ищется по названию группы.

В результатах отображаются пользовательские и групповые аватары.

---

## 🧰 Android Toolchain Foundation — `v0.6.6`

### Зафиксированные версии

```text
Flutter: 3.44.1 stable
Dart: 3.12.1
Java: OpenJDK 21.0.10
Android SDK: 36.1.0
Gradle Wrapper: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
Google Services Plugin: 4.3.15

compileSdk: 36
targetSdk: 36
minSdk: 24
JVM target: 17
```

### Проверенные зависимости

```text
firebase_storage: 13.4.5
flutter_image_compress: 2.5.1
flutter_image_compress_common: 1.1.1
```

`flutter.bat pub outdated` не показал обновлений для `firebase_storage` и `flutter_image_compress`.

### Built-in Kotlin warning

Warning появляется для:

```text
firebase_storage
flutter_image_compress_common
```

Он связан с внутренней Android-конфигурацией плагинов, которые пока применяют Kotlin Gradle Plugin прежним способом.

Текущие compatibility flags:

```properties
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
```

Принятое решение:

- не редактировать Pub Cache;
- не обновлять Gradle, AGP и Kotlin вслепую;
- не удалять compatibility flags;
- ждать официальной миграции плагинов;
- не смешивать toolchain work с новыми функциями.

APK продолжает успешно собираться.

Нормальные сообщения:

- tree-shaking MaterialIcons — нормальная release-оптимизация;
- `LF will be replaced by CRLF` — нормальное Git-предупреждение на Windows;
- отсутствие Visual Studio в `flutter doctor` не блокирует Android-разработку.

---

## 🎨 Интерфейс

- Material 3.
- Тёмная тема.
- Edge-to-edge UI.
- Экран настроек.
- Экран профиля.
- BottomSheet редактирования профиля.
- Контакты.
- Поиск пользователей и чатов.
- Haptic feedback.
- Отдельные UI-компоненты для аватаров и сообщений.
- Подготовленный контур вложений.

Avatar UI:

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

UI получает готовые модели и не выполняет напрямую:

- Storage upload;
- crop orchestration;
- Firestore transaction;
- rollback;
- cleanup;
- security policy.

Это позволяет менять темы, размеры, форму пузырей, фон чатов, аватары и анимации без переписывания Firebase-слоя.

---

## 🧭 Архитектура

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

Принципы:

- UI не знает детали Firebase infrastructure.
- Domain не зависит от Flutter и Firebase.
- Firebase adapters скрыты за contracts.
- Rollback и cleanup находятся в application services.
- Storage paths формируются централизованно.
- UI-компоненты заменяемы.
- Feature changes не смешиваются с toolchain changes.
- Крупные foundations сначала проектируются, затем реализуются.

---

## 🏗 Архитектура чатов

```text
UI / Screens
    ↓
ChatService (Facade)
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

---

## 🧱 Media Foundation — `v0.6.2`

Основные элементы:

| Элемент | Ответственность |
| --- | --- |
| `MediaAsset` | Доменное описание media |
| `MediaPaths` | Централизованные Storage paths |
| `MediaStorageProvider` | Абстрактный Storage contract |
| `FirebaseMediaStorageProvider` | Firebase Storage adapter |
| `MediaStorageService` | Application facade |

Path-first identity:

```text
provider + storage path + version
```

Download URL не является доменной основой.

Будущие providers могут включать:

- S3-compatible storage;
- Yandex Object Storage;
- Cloudflare R2;
- локальный сервер компании;
- собственный Epistola backend.

---

## 🔥 Firebase

```text
Firebase project: epistola-434b7
Firestore region: eur3
Cloud Functions region: europe-west1
Android package: com.epistola.app
Storage bucket: gs://epistola-434b7.firebasestorage.app
```

Основные файлы:

```text
firebase.json
.firebaserc
firestore.rules
firestore.indexes.json
storage.rules
android/app/google-services.json
lib/firebase_options.dart
functions/src/index.ts
```

Деплой Rules:

```powershell
firebase.cmd deploy --only firestore:rules,storage
```

Indexes:

```powershell
firebase.cmd deploy --only firestore:indexes
```

---

## 🛠 Используемые технологии

- Flutter.
- Dart.
- Firebase Authentication.
- Cloud Firestore.
- Firebase Security Rules.
- Firebase Storage.
- Firebase Cloud Messaging.
- Cloud Functions.
- Shared Preferences.
- Material 3.
- Image Picker.
- Image Cropper.
- Flutter Image Compress.
- Cached Network Image.
- Git / GitHub.
- Firebase CLI.

---

## 📁 Структура проекта

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

Legacy models постепенно переносятся из `lib/models` в domain-слой без большого несвязанного рефакторинга.

---

## 📌 Текущий прогресс

| Возможность | Статус |
| --- | :---: |
| Авторизация и сессия | ✅ |
| Профиль и контакты | ✅ |
| Личные чаты | ✅ |
| Групповые чаты | ✅ |
| Pagination сообщений | ✅ |
| Роли, mute и ban | ✅ |
| Передача прав и безопасный выход | ✅ |
| Push-уведомления | ✅ |
| Push deep-link в конкретный чат | ⏳ |
| Удаление у себя | ✅ |
| Удаление у всех | ✅ |
| Media Foundation | ✅ |
| Пользовательские аватары | ✅ |
| Групповые аватары | ✅ |
| Галерея, камера и crop | ✅ |
| Versioned avatar storage | ✅ |
| Atomic replacement и rollback | ✅ |
| Android Toolchain audit | ✅ |
| Built-in Kotlin migration плагинов | ⏳ |
| Image Message Domain + Metadata | ⏳ |
| Отправка изображений | ⏳ |
| Отправка файлов | ⏳ |
| Голосовые сообщения | ⏳ |
| Spaces | ⏳ |
| Web | ⏳ |
| iOS | ⏳ |

---

## 🖼 Следующий этап — `v0.7.0 Image Message Foundation`

Image Message Foundation начинается только после закрытия `v0.6.6`.

Первый подэтап:

```text
Image Message Domain + Metadata Foundation
```

Сначала проектируются:

- message type `image`;
- domain model;
- Firestore metadata schema;
- thumbnail/full assets;
- provider;
- Storage paths;
- sizes и dimensions;
- upload states;
- retry;
- rollback;
- cleanup;
- chat preview;
- push representation;
- delete-for-self/delete-for-everyone compatibility;
- tests domain/mappers.

Будущий поток:

```text
галерея или камера
→ preparation
→ thumbnail + full
→ Firebase Storage
→ message metadata
→ image bubble
→ fullscreen view
```

Планируется:

- gallery;
- camera;
- compression;
- EXIF removal;
- thumbnail;
- full;
- upload progress;
- cancel;
- retry;
- rollback;
- cleanup;
- Storage Rules;
- chat preview `Фотография`;
- push `Фотография`;
- pagination compatibility;
- экономный cache.

Не начинать весь этап одним большим изменением.

---

## 🧪 Проверки

Основные команды:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
git.exe diff --check
git.exe status --short
```

Форматирование Dart:

```powershell
$flutterBin = Split-Path (Get-Command flutter.bat).Source
$dartExe = Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe"

& $dartExe format lib test
```

Generated plugin files, которые Flutter может изменить автоматически:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake
```

Если они не относятся к задаче:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

---

## 🪟 Windows / PowerShell

Использовать явные executable-имена:

```powershell
flutter.bat
firebase.cmd
npm.cmd
git.exe
```

Java для прямого Gradle-вызова в текущем terminal session:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

& "$env:JAVA_HOME\bin\java.exe" -version
.\android\gradlew.bat -p .\android --version
```

---

## 📚 Документация

Приоритет источников:

```text
исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

- `PROJECT_CONTEXT.md` — главный handoff текущего состояния.
- `ARCHITECTURE.md` — устойчивые технические решения.
- `README.md` — краткий обзор проекта.

---

## 🔒 Неприкосновенные функции

Нельзя ломать:

- Auth UID ↔ `users/{uid}`;
- регистрацию, login и постоянную сессию;
- private/group messages;
- создание private chat только после первого message;
- отсутствие пустых private chats;
- atomic first message;
- pagination по 20;
- сохранение history при realtime update;
- personal clear;
- delete-for-self;
- delete-for-everyone только sender;
- push notifications;
- user/contact/chat search;
- private chat search по peer identity;
- роли и permissions;
- защиту последнего администратора;
- передачу прав и безопасный выход;
- Media Foundation contracts;
- versioned avatars;
- rollback;
- path-first loading;
- fallback;
- заменяемый UI.

---

## 🗺 Дальнейшее направление

После `v0.7.0 Image Message Foundation` планируются:

- файлы и документы;
- карточки файлов;
- voice messages;
- video;
- persistent media cache;
- automatic cache cleanup;
- hybrid storage;
- message media retention policy;
- Spaces;
- корпоративные сервисы;
- возможный собственный backend.
