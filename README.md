# Epistola

> **Современный корпоративный мессенджер на Flutter и Firebase**

Epistola — долгосрочный проект корпоративной коммуникационной платформы. Сейчас это Android-first мессенджер на Flutter и Firebase. Архитектура постепенно готовится к Web/iOS, рабочим пространствам Spaces, медиа-подсистеме, возможной смене backend-хранилища и будущему собственному backend.

---

## 🚧 Статус проекта

| Параметр | Значение |
| --- | --- |
| Текущая версия | `v0.6.5` |
| Название этапа | **Avatar Foundation** |
| Последний опубликованный стабильный релиз | `v0.6.4` |
| Статус | 🟢 Реализация, Android-проверки, автоматические тесты и release APK готовы |
| Основная платформа | Android |
| Текущий backend | Firebase |
| Репозиторий | `MikhailBerezkin/epistola` |
| Firebase project | `epistola-434b7` |
| Android package | `com.epistola.app` |
| Пилотная группа | примерно 40–50 пользователей |

В ветке `feat/v0.6.5-avatar-foundation` завершён Avatar Foundation:

- пользовательские и групповые аватары;
- галерея и камера;
- квадратный crop;
- JPEG thumbnail и full;
- версионное Storage-хранение;
- атомарная замена metadata;
- rollback при ошибках;
- path-first загрузка;
- кэш;
- fallback на инициалы;
- отображение на основных экранах;
- исправление поиска private chats по данным собеседника.

Финальная release-сборка успешно создана:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Размер последней сборки:

```text
54.4 MB
```

Известное ограничение push-навигации сохраняется: нажатие на уведомление открывает приложение, но пока не переводит непосредственно в нужный чат.

---

## ⚡ Что такое Epistola

Epistola создаётся как единая коммуникационная платформа для сотрудников компании.

Краткосрочная цель — стабильный мессенджер для пилотной группы примерно 40–50 пользователей.

Долгосрочная цель — рабочая платформа для компании на 600–700 сотрудников с чатами, группами, ролями, Spaces, мини-приложениями, файлами, рабочими сменами, задачами, объявлениями, документами и внутренними сервисами.

Основной принцип:

> Сначала надёжная архитектура, затем функциональность поверх неё.

---

## ✨ Реализованные возможности

### 🔐 Пользователи и авторизация

- Firebase Authentication.
- Регистрация пользователя.
- Вход по E-mail и паролю.
- Постоянная сессия.
- Запоминание последнего E-mail.
- Профиль пользователя.
- Редактирование профиля.
- Публичный контактный E-mail, независимый от FirebaseAuth.
- Карточка контакта пользователя.
- Поиск пользователей.
- Экран контактов.
- Пользовательские аватары.

### 💬 Чаты и сообщения

- Личные чаты.
- Групповые чаты.
- Создание private chat только после первого сообщения.
- Отсутствие пустых private chats.
- История сообщений с cursor pagination по 20 документов.
- Realtime-подписка на последнюю страницу.
- Дозагрузка старой истории при прокрутке вверх.
- Сохранение позиции прокрутки.
- Список чатов.
- Последнее видимое сообщение.
- Время последнего сообщения.
- Счётчик непрочитанных сообщений.
- Атомарная запись message document и metadata чата.
- Персональная очистка private chat без физического удаления истории.
- Меню вложений как подготовка к Media Foundation.
- Поиск чатов по имени собеседника и названию группы.

### 👥 Группы

- Создание групп.
- Добавление участников.
- Просмотр информации о группе.
- Список участников.
- Карточки участников.
- Передача прав администратора.
- Защита последнего администратора.
- Безопасный выход.
- Роспуск группы.
- Настройки группы.
- Ограничение отправки сообщений по ролям.
- Групповые аватары.
- Управление групповым аватаром для `owner` и `admin`.

### 🛡️ Роли и модерация

Поддерживаемые роли:

- Владелец.
- Администратор.
- Модератор.
- Участник.
- Гость.

Реализовано:

- Mute.
- Ban.
- Разграничение прав.
- Ограничение отправки сообщений.
- Управление участниками.
- Скрытие недоступных действий в UI.
- Защита от удаления или demote последнего администратора.
- Firestore Rules для ролей и прав.

### 🔔 Push Notification Foundation

В `v0.6.3` реализовано:

- Firebase Cloud Messaging;
- локальные Android-уведомления;
- канал `epistola_messages`;
- foreground, background и terminated-состояния;
- регистрация FCM-токенов устройств;
- автоматическая перерегистрация обновлённого токена;
- удаление токена текущего устройства при выходе;
- Cloud Function `sendMessageNotification`;
- регион функции `europe-west1`;
- исключение отправителя из получателей;
- личные и групповые push;
- удаление невалидных токенов;
- безопасный preview длинного текста.

Push проверены на физическом Android-устройстве:

- приложение открыто;
- приложение свёрнуто;
- приложение закрыто;
- экран заблокирован.

Известное ограничение:

```text
нажатие на уведомление открывает приложение,
но пока не переводит непосредственно в нужный чат
```

### 🗑 Message Deletion Foundation

В `v0.6.4` реализовано:

- удалить сообщение у себя;
- удалить собственное сообщение у всех;
- действие «Удалить у всех» только для отправителя;
- подтверждение удаления у всех;
- логическое удаление без физического удаления Firestore-документа;
- персональное поле `hiddenFor`;
- признаки `deletedForEveryone`, `deletedBy`, `deletedAt`;
- отдельная модель `MessagePresentation`;
- отдельный визуальный слой `MessageItem`;
- сохранение стабильности пагинации;
- поиск предыдущего видимого сообщения для preview карточки чата;
- отсутствие повторного push при логическом удалении.

Поддерживаемые состояния:

```text
visible
hiddenForCurrentUser
deletedForEveryone
```

Разделение слоёв:

```text
Firestore message state
        ↓
MessagePresentation
        ↓
MessageItem
        ↓
MessageBubble
```

Это позволяет менять анимации, форму пузырей, цвета и оформление без изменения Firestore-логики.

---

## 🖼 Avatar Foundation v0.6.5

### Пользовательские аватары

Реализовано:

- выбор изображения из галереи;
- съёмка камерой;
- корректная отмена source sheet, picker и crop;
- Android `image_picker.retrieveLostData()`;
- квадратный crop `1:1`;
- thumbnail `128x128`;
- full `512x512`;
- JPEG-сжатие;
- коррекция ориентации;
- удаление EXIF;
- жёсткие ограничения размера;
- очистка временных файлов;
- загрузка только подготовленных вариантов;
- версионное хранение;
- атомарная замена;
- rollback новой версии при ошибке Firestore;
- best-effort очистка предыдущей версии;
- path-first authenticated loading;
- in-memory LRU-кэш;
- дедупликация параллельных запросов;
- legacy `avatarUrl` fallback;
- стабильные инициалы и цвет.

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

Пользовательские аватары отображаются в:

- профиле;
- списке личных чатов;
- поиске чатов;
- контактах;
- заголовке открытого личного чата;
- черновике чата до первого сообщения;
- списке участников группы.

### Групповые аватары

Реализовано:

- отдельная модель `GroupAvatar`;
- отдельный metadata mapper;
- отдельный Storage upload service;
- отдельный Firestore metadata gateway;
- атомарная замена;
- rollback при ошибке metadata;
- защита версий;
- управление только для `owner` и `admin`;
- Firestore Rules;
- Storage Rules;
- галерея;
- камера;
- квадратный crop;
- первая установка;
- последующая замена.

Storage paths:

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Metadata хранится в:

```text
chats/{chatId}
```

Групповые аватары отображаются в:

- информации о группе;
- основном списке групп;
- поиске чатов;
- заголовке открытого группового чата.

У группы без фотографии остаётся fallback с первой буквой названия.

### Проверенные Android-сценарии

Пользовательские аватары:

- галерея → crop → установка;
- камера → crop → установка;
- замена;
- отображение на основных экранах;
- сохранение старого аватара при ошибке;
- отображение пользователей, с которыми ещё не было чата.

Групповые аватары:

- камера → crop → установка;
- галерея → crop → замена;
- запись thumbnail и full в Firebase Storage;
- обновление metadata;
- отображение в информации о группе;
- отображение в списке;
- отображение в поиске;
- отображение в заголовке;
- fallback у группы без фотографии.

---

## 🔎 Поиск чатов

Private chat в Firestore может иметь техническое поле:

```text
name: private_chat
```

Пользовательский поиск больше не зависит от этого значения.

Реализовано:

- определение второго участника private chat;
- поиск по имени собеседника;
- поиск по E-mail и доступным данным профиля;
- сохранение поиска групп по названию;
- отображение пользовательских и групповых аватаров в результатах.

---

## 🎨 Интерфейс

- Material 3.
- Тёмная тема.
- Edge-to-edge UI.
- Экран настроек.
- Экран профиля.
- BottomSheet для редактирования профиля.
- Контакты.
- Поиск пользователей и чатов.
- Улучшенная обработка Android-кнопки «Назад».
- Haptic feedback.
- Отдельные UI-компоненты для аватаров и сообщений.
- Подготовленный контур для будущих вложений.

Основные avatar UI-компоненты:

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

UI получает готовые модели и не выполняет прямые Storage upload, crop или Firestore transaction.

Это позволяет позднее менять:

- размеры аватаров;
- форму;
- анимации;
- цвета fallback;
- размеры шрифтов;
- темы;
- карточки;
- декоративные эффекты;

без изменения бизнес-логики и Firebase-слоя.

---

## 🧭 Архитектурная идея

```text
Flutter UI
    ↓
Controllers
    ↓
Application services
    ↓
Storage / metadata gateways
    ↓
Firebase adapters
```

Ключевые принципы:

- UI не знает детали инфраструктуры.
- Domain-модели не зависят от Flutter, Firebase или UI.
- Firebase — текущая инфраструктура, но не вечная зависимость.
- Внешние сервисы обёрнуты в gateways/providers.
- Крупные подсистемы сначала проектируются, затем реализуются.
- Визуальный слой остаётся заменяемым.
- Код должен проходить `flutter.bat analyze` без ошибок.

---

## 🏗 Архитектура чатов

Монолитный `ChatService` разделён на специализированные сервисы, сохранив внешний API через фасад:

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

## 🧱 Media Foundation v0.6.2

Media Foundation служит основой для:

- пользовательских аватаров;
- групповых аватаров;
- изображений в сообщениях;
- файлов;
- документов;
- превью;
- голосовых сообщений;
- видео;
- локального кэша;
- сменяемого backend-хранилища.

Слои:

```text
UI
 │
 ▼
Avatar / Attachment application services
 │
 ▼
MediaStorageService
 │
 ▼
MediaStorageProvider
 │
 ├── FirebaseMediaStorageProvider
 ├── S3MediaStorageProvider (future)
 ├── YandexStorageProvider (future)
 └── EpistolaBackendStorageProvider (future)
```

Основные элементы:

| Слой | Ответственность |
| --- | --- |
| `MediaAsset` | Доменное описание медиа |
| `MediaPaths` | Централизованные пути |
| `MediaStorageProvider` | Абстрактный контракт |
| `FirebaseMediaStorageProvider` | Firebase Storage adapter |
| `MediaStorageService` | Фасад для приложения |

---

## 🧩 MediaPaths

Актуальные пути:

```text
user_avatars/{userId}/v{version}/thumb.jpg
user_avatars/{userId}/v{version}/full.jpg

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg

attachments/{chatId}/{messageId}/{fileName}
previews/{chatId}/{messageId}/{fileName}
```

Legacy path:

```text
user_avatars/{userId}/avatar.jpg
```

Он сохраняется только для совместимости и не используется новым avatar pipeline.

---

## 🔥 Firebase

Firebase project:

```text
epistola-434b7
```

Android package:

```text
com.epistola.app
```

Firestore region:

```text
eur3
```

Cloud Functions region:

```text
europe-west1
```

Storage bucket:

```text
gs://epistola-434b7.firebasestorage.app
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
```

### Деплой правил

```powershell
firebase.cmd deploy --only firestore:rules,storage
```

Firestore indexes:

```powershell
firebase.cmd deploy --only firestore:indexes
```

---

## 🛡 Firestore и Storage Rules

Firestore Rules защищают:

- профили пользователей;
- avatar metadata;
- чаты;
- сообщения;
- членство;
- роли;
- права отправки;
- логическое удаление;
- последнего администратора;
- групповую avatar metadata;
- строго возрастающие версии.

Storage Rules проверяют:

- аутентификацию;
- владельца пользовательского аватара;
- роль `owner` или `admin` для группового аватара;
- соответствие пути конкретному UID или `chatId`;
- MIME type `image/jpeg`;
- thumbnail максимум `128 KB`;
- full максимум `512 KB`;
- положительную версию;
- запрет неизвестных путей.

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
│   └── models/
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

Старые модели постепенно переносятся из `lib/models` в `lib/domain/models` без большого несвязанного рефакторинга.

---

## 📌 Текущий прогресс

| Возможность | Статус |
| --- | :---: |
| Авторизация и сессия | ✅ |
| Профиль и редактирование | ✅ |
| Контакты и поиск пользователей | ✅ |
| Личные чаты | ✅ |
| Групповые чаты | ✅ |
| Pagination сообщений | ✅ |
| Роли, mute и ban | ✅ |
| Передача прав и безопасный выход | ✅ |
| Push-уведомления | ✅ |
| Push-переход непосредственно в чат | ⏳ |
| Удаление сообщения у себя | ✅ |
| Удаление сообщения у всех | ✅ |
| Предыдущее preview после удаления | ✅ |
| Media Foundation | ✅ |
| Пользовательские аватары | ✅ |
| Групповые аватары | ✅ |
| Галерея, камера и crop | ✅ |
| Версионное хранение аватаров | ✅ |
| Атомарная замена и rollback | ✅ |
| Аватары в профиле и контактах | ✅ |
| Аватары в списках и поиске | ✅ |
| Аватары в заголовках чатов | ✅ |
| Аватары участников группы | ✅ |
| Отправка изображений | ⏳ |
| Отправка файлов | ⏳ |
| Голосовые сообщения | ⏳ |
| Spaces | ⏳ |
| Web | ⏳ |
| iOS | ⏳ |

---

## 🚀 Дорожная карта

### Завершено

- `v0.6.2` — Media Foundation.
- `v0.6.2.1` — Security Foundation.
- `v0.6.3` — Push Notification Foundation.
- `v0.6.4` — Message Deletion Foundation.
- `v0.6.5` — Avatar Foundation, готовится к публикации.

### Ближайшие технические задачи

- обновление Kotlin/Gradle toolchain;
- расширение emulator tests для Security Rules;
- дальнейшая оптимизация Firestore reads;
- тесты конкурентных avatar-операций с двух устройств;
- persistent path-first avatar cache;
- push deep-link непосредственно в чат.

### Будущие Media-этапы

- изображения в сообщениях;
- документы;
- карточки файлов;
- полноэкранный просмотр изображений;
- прогресс загрузки;
- голосовые сообщения;
- видео;
- локальный disk cache;
- автоматическая очистка кэша;
- гибридное хранилище.

### Будущие продуктовые этапы

- статусы доставки и прочтения;
- пересылка сообщений;
- закреплённые сообщения;
- приглашения в группы;
- Spaces;
- мини-приложения;
- Web;
- iOS;
- возможный собственный backend.

---

## 🧩 Spaces

Spaces — стратегическое направление развития Epistola.

Планируется, что Space сможет объединять:

- чаты;
- группы;
- задачи;
- объявления;
- документы;
- смены;
- внутренние сервисы;
- мини-приложения.

Spaces должны использовать те же архитектурные принципы:

- доменные модели;
- отдельные application services;
- абстракции инфраструктуры;
- заменяемый UI;
- контролируемые расходы Firebase.

---

## 📚 Документация

Приоритет источников:

```text
исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md
```

Основные файлы:

```text
PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md
```

В будущем документация будет разделена на модульную структуру `docs/`, а `ARCHITECTURE.md` станет индексом и точкой входа.

---

## 🧪 Проверка и сборка

Получение зависимостей:

```powershell
flutter.bat pub get
```

Запуск:

```powershell
flutter.bat run
```

Анализ:

```powershell
flutter.bat analyze
```

Тесты:

```powershell
flutter.bat test
```

Release APK:

```powershell
flutter.bat build apk --release
```

APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Проверка diff и дерева:

```powershell
git.exe diff --check
git.exe status --short
```

Последняя проверка Avatar Foundation:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 251 tests passed

flutter.bat build apk --release
→ успешно, 54.4 MB
```

Во время сборки показывается предупреждение Kotlin Gradle Plugin. Оно не останавливает текущую сборку и будет устранено отдельным техническим этапом.

---

## 🔧 Команды Windows

В проекте используются явные executable-имена:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release

firebase.cmd deploy --only firestore:rules,storage

git.exe status --short
git.exe diff --check
git.exe add .
git.exe commit
git.exe push
```

---

## 🏷 Git Tags

Последний опубликованный стабильный тег:

```text
v0.6.4
```

Готовящийся тег:

```text
v0.6.5
```

Назначение:

```text
Avatar Foundation
```

Команды после слияния в `main`:

```powershell
git.exe tag -a v0.6.5 -m "Avatar Foundation"
git.exe push origin v0.6.5
```

---

## 🧾 История последних этапов

### v0.6.2 — Media Foundation

- Firebase Storage;
- `MediaAsset`;
- `MediaStorageProvider`;
- `FirebaseMediaStorageProvider`;
- `MediaStorageService`;
- `MediaPaths`;
- сменяемое backend-хранилище.

### v0.6.2.1 — Security Foundation

- нормализация текста;
- лимит 4096 символов;
- атомарная отправка сообщения;
- private chat после первого сообщения;
- персональная очистка;
- pagination по 20;
- усиленные Firestore Rules.

### v0.6.3 — Push Notification Foundation

- FCM;
- локальные уведомления;
- device tokens;
- Cloud Function;
- личные и групповые push;
- foreground, background, terminated и locked-screen проверки.

### v0.6.4 — Message Deletion Foundation

- удалить у себя;
- удалить у всех;
- logical deletion;
- presentation layer;
- стабильная pagination;
- предыдущее видимое preview.

### v0.6.5 — Avatar Foundation

- пользовательские аватары;
- групповые аватары;
- галерея;
- камера;
- crop;
- thumbnail и full;
- версионные пути;
- атомарная замена;
- rollback;
- path-first loading;
- кэш;
- Security Rules;
- отображение на основных экранах;
- исправленный поиск private chats;
- физические Android-проверки;
- успешная release-сборка.

---

## 🎯 Принципы разработки

- Архитектура важнее скорости.
- Сначала проектирование, затем реализация.
- Работать маленькими проверяемыми шагами.
- Не смешивать UI, application logic и Firebase infrastructure.
- UI должен оставаться заменяемым.
- Domain-модели не должны зависеть от Flutter или Firebase.
- Firestore хранит данные и metadata, но не бинарные файлы.
- Медиа проходят сжатие и ограничения.
- Storage paths централизованы.
- Feature-изменения не смешиваются с обновлением toolchain.
- После этапа выполняются analyze, test и release build.
- После стабильной версии создаётся Git tag.

---

## 🧭 Контроль расходов

Epistola проектируется с учётом ограниченного бюджета инфраструктуры.

Контролируются:

- Firestore reads и writes;
- Storage operations;
- Storage egress;
- размеры thumbnail и full;
- повторные загрузки;
- кэш;
- временные файлы;
- число версий;
- реальные показатели пилотной группы.

Для пилота важно собирать реальные метрики и не выполнять преждевременную оптимизацию без данных.

---

## ❤️ О проекте

Epistola — долгосрочный проект современной корпоративной платформы для общения и совместной работы.

Текущая цель — безопасно и последовательно развивать стабильную основу, сохраняя возможность будущего роста, смены инфраструктуры и полной замены визуального слоя без переписывания бизнес-логики.
