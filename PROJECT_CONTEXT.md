# Epistola — Project Context

> Живой документ состояния проекта. Использовать как главный handoff между чатами и аккаунтами.
> При расхождении приоритет: исходный код → `PROJECT_CONTEXT.md` → `ARCHITECTURE.md` → `README.md`.

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Рабочая ветка: `feat/v0.6.5-avatar-foundation`
- Текущий HEAD перед обновлением документации: `f00b9a5`
- Текущий этап: **Avatar Foundation**
- Готовящийся стабильный релиз: `v0.6.5`
- Последний опубликованный стабильный релиз: `v0.6.4`
- Последний стабильный `main` до Avatar Foundation: `0e99f5b`
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Cloud Functions region: `europe-west1`
- Android package: `com.epistola.app`
- Основная платформа: Android
- Целевая пилотная группа: 40–50 пользователей

Последние важные коммиты Avatar Foundation:

```text
f00b9a5 feat(group-avatar): show avatar in chat header
7dca1f0 feat(group-avatar): show avatars in chat search
4d13e3a feat(group-avatar): show avatars in group chat list
e1fdb07 feat(group-avatar): show member avatars in group info
79455b6 feat(group-avatar): enable avatar replacement
425a5f9 feat(group-avatar): add avatar source menu
8216fe5 refactor(group-avatar): manage controller lifecycle
d5a759d feat(group-avatar): wire replacement dependencies
a9d81ba feat(group-avatar): add replacement controller
beca054 feat(group-avatar): secure firestore and storage rules
732c53e feat(group-avatar): add atomic replacement service
f1b3749 feat(group-avatar): add firestore metadata gateway
f2c1d95 feat(group-avatar): add storage upload foundation
f5a0713 feat(group-avatar): add domain and metadata foundation
dea7d3d fix(search): match private chats by peer identity
```

## 2. Проверенное состояние проекта

Финальные проверки перед обновлением документации:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 251 tests passed

flutter.bat build apk --release
→ успешно

git.exe diff --check
→ без ошибок

git.exe status --short
→ рабочее дерево было чистым до изменения документации
```

Release APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Размер последней release-сборки:

```text
54.4 MB
```

Во время Android-сборки показывается предупреждение о будущем требовании Built-in Kotlin для плагинов `firebase_storage` и `flutter_image_compress_common`. Сборка завершается успешно. Обновление Kotlin/Gradle выполняется отдельным техническим этапом после `v0.6.5`, чтобы не смешивать его с Avatar Foundation.

## 3. Завершённые стабильные этапы

- `v0.6.2` — Media Foundation.
- `v0.6.2.1` — Security Foundation.
- `v0.6.3` — Push Notification Foundation.
- `v0.6.4` — Message Deletion Foundation.
- `v0.6.5` — Avatar Foundation, готовится к слиянию и выпуску.

## 4. User Avatar Foundation

### 4.1 Подготовка изображения

Реализовано:

- выбор фотографии из галереи;
- съёмка фотографии камерой;
- квадратный crop `1:1`;
- корректная отмена source sheet, picker и crop;
- Android `image_picker.retrieveLostData()` после пересоздания Activity;
- thumbnail `128x128`;
- full `512x512`;
- JPEG-сжатие;
- исправление ориентации;
- удаление EXIF;
- повторные попытки сжатия full-варианта;
- жёсткие ограничения размера;
- безопасная очистка временных файлов;
- оригинал из picker не загружается и не удаляется приложением.

Ограничения:

```text
thumbnail: максимум 128 KB
full: целевой размер до 300 KB
full: абсолютный максимум 512 KB
```

### 4.2 Версионное хранение

Storage paths:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Metadata пользователя хранится в:

```text
users/{uid}
```

Поля metadata:

```text
avatarProvider
avatarThumbStoragePath
avatarFullStoragePath
avatarThumbSizeBytes
avatarFullSizeBytes
avatarVersion
avatarUpdatedAt
```

Новый pipeline не использует download URL как источник истины. Старое поле `avatarUrl` временно поддерживается только как legacy fallback.

### 4.3 Атомарная замена

Порядок операции:

```text
1. Подготовка thumbnail и full.
2. Загрузка новой версионной пары в Storage.
3. Транзакционная запись metadata в Firestore.
4. Best-effort удаление предыдущей версии.
```

Гарантии:

- при ошибке подготовки активный аватар не меняется;
- при ошибке загрузки неполная новая версия очищается;
- при ошибке Firestore новая загруженная версия удаляется как rollback;
- старый аватар остаётся активным до успешной записи metadata;
- ошибка удаления старых файлов после успешной записи не отменяет новый аватар;
- версия должна быть положительной и строго возрастать;
- конкурирующая устаревшая операция не может перезаписать более новую версию.

### 4.4 Загрузка и кэш

Реализовано:

- path-first загрузка через аутентифицированный Firebase Storage SDK;
- ключ кэша `path@version`;
- in-memory LRU-кэш;
- объединение параллельных запросов одного изображения;
- повторная проверка максимального размера полученных байтов;
- legacy URL fallback;
- fallback на стабильные инициалы и цвет.

Path-first кэш пока не сохраняется между запусками приложения.

### 4.5 Отображение пользовательских аватаров

`UserAvatarView` используется в:

- профиле пользователя;
- списке личных чатов;
- поиске чатов;
- контактах;
- заголовке открытого личного чата;
- черновике личного чата до отправки первого сообщения;
- списке участников группы.

Пользователи без фотографии получают fallback с инициалами. Цвет fallback стабилен и определяется по UID.

## 5. Group Avatar Foundation

### 5.1 Общая модель

Групповые аватары реализованы отдельно от пользовательских:

- доменная модель `GroupAvatar`;
- `GroupAvatarMetadataMapper`;
- `GroupAvatarStorageUploadService`;
- `FirebaseGroupAvatarMetadataGateway`;
- `AtomicGroupAvatarReplacementService`;
- `GroupAvatarReplacementController`;
- `GroupAvatarView`.

Общий pipeline выбора, crop и подготовки изображения используется повторно, но group metadata, права и Storage paths остаются отдельными.

### 5.2 Версионное хранение

Storage paths:

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Metadata хранится в документе:

```text
chats/{chatId}
```

Thumbnail и full обязаны относиться к одной группе, одному provider и одной version.

### 5.3 Права управления

Изменять групповой аватар могут только участники группы с ролью:

```text
owner
admin
```

Firestore Rules и Storage Rules проверяют:

- аутентификацию;
- существование группы;
- `type == group`;
- членство текущего пользователя;
- роль `owner` или `admin`;
- корректность `chatId` в путях;
- полную согласованную metadata;
- положительную строго возрастающую версию;
- MIME type `image/jpeg`;
- лимиты `128 KB` и `512 KB`.

Rules опубликованы в Firebase project `epistola-434b7`.

### 5.4 Установка и замена

В информации о группе администратор может:

- выбрать фото из галереи;
- сделать фото камерой;
- выполнить квадратный crop;
- установить первый групповой аватар;
- заменить существующий аватар.

Замена использует безопасный порядок:

```text
upload новой версии
→ transaction metadata
→ best-effort cleanup старой версии
```

При любой неуспешной операции предыдущий групповой аватар остаётся активным.

### 5.5 Отображение групповых аватаров

`GroupAvatarView` и общий `ChatAvatarView` используются в:

- информации о группе;
- основном списке групп;
- поиске чатов;
- заголовке открытого группового чата.

У группы без фотографии отображается fallback с первой буквой названия.

## 6. Проверенные Android-сценарии

### 6.1 Пользовательские аватары

Проверено на Android:

- выбор фотографии из галереи;
- фотографирование камерой;
- crop;
- отмена;
- первая установка;
- повторная замена;
- изменение metadata в Firestore;
- загрузка файлов в Storage;
- отображение в профиле;
- отображение в списке личных чатов;
- отображение в заголовке личного чата;
- отображение в поиске и контактах;
- отображение пользователей, с которыми ещё не создавался чат;
- сохранение предыдущего аватара при неуспешной операции.

### 6.2 Групповые аватары

Проверено на физическом Android-телефоне:

```text
камера → crop → установка
галерея → crop → замена
```

Также проверено:

- создание папки версии в Firebase Storage;
- запись thumbnail и full;
- изменение metadata группы;
- отображение новой версии без переустановки приложения;
- fallback у группы без фотографии;
- отображение в информации о группе;
- отображение в основном списке групп;
- отображение в поиске;
- отображение в заголовке открытого группового чата;
- отображение пользовательских аватаров участников группы.

## 7. Исправление поиска чатов

До исправления карточка private chat показывала имя собеседника, но `matchesSearch()` могла искать по техническому полю:

```text
name: private_chat
```

Исправлено:

- private chat сопоставляется по профилю второго участника;
- поиск использует имя, email и доступные данные собеседника;
- техническое имя документа больше не является пользовательским названием private chat;
- поиск групп работает по названию группы;
- аватары пользователей и групп отображаются в результатах поиска.

Проверено вручную на Android.

## 8. Архитектурные границы

Avatar Foundation сохраняет разделение слоёв:

```text
UI widgets
    ↓
Controllers
    ↓
Preparation / replacement services
    ↓
Storage and metadata gateways
    ↓
Firebase adapters
```

### 8.1 UI-слой

Основные компоненты:

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

UI:

- получает готовые модели;
- не выполняет прямой crop;
- не выполняет прямой Storage upload;
- не записывает metadata напрямую;
- не содержит Firebase transaction logic;
- не определяет security policy.

`ChatAvatarView` централизует визуальный выбор:

```text
private chat → UserAvatarView
group chat → GroupAvatarView
нет данных → fallback
```

Это позволяет позднее менять:

- форму и размер аватаров;
- анимацию загрузки и замены;
- цвета fallback;
- размеры шрифтов;
- оформление карточек;
- темы и декоративные элементы;

без изменения Firestore, Storage и application logic.

### 8.2 Application/service-слой

Контроллеры:

- сериализуют пользовательские операции;
- возвращают `success`, `cancelled`, `failure`, `alreadyRunning`;
- не рисуют интерфейс;
- не зависят от конкретной карточки или экрана.

Services отвечают за:

- подготовку;
- загрузку;
- атомарную замену;
- rollback;
- cleanup;
- защиту версий.

### 8.3 Infrastructure-слой

Firebase adapters отвечают только за:

- Storage upload/delete/getData;
- Firestore transaction;
- чтение и запись metadata.

Domain-модели не зависят от Flutter UI.

## 9. Завершённые предыдущие этапы

### Media Foundation — `v0.6.2`

- `MediaAsset`;
- `MediaStorageProvider`;
- `FirebaseMediaStorageProvider`;
- `MediaStorageService`;
- `MediaPaths`;
- Firebase Storage;
- Storage Rules.

### Security Foundation — `v0.6.2.1`

- private chat создаётся только после первого сообщения;
- pagination по 20 сообщений;
- атомарная отправка message + chat metadata;
- персональная очистка private chat;
- усиленные Firestore Rules.

### Push Notification Foundation — `v0.6.3`

- FCM;
- foreground/background/terminated notifications;
- device tokens;
- Cloud Function `sendMessageNotification`;
- регион `europe-west1`;
- удаление невалидных токенов;
- push для личных и групповых чатов.

Известное ограничение:

```text
нажатие на уведомление открывает приложение,
но пока не переводит непосредственно в нужный чат
```

### Message Deletion Foundation — `v0.6.4`

- удалить сообщение у себя;
- удалить собственное сообщение у всех;
- логическое удаление без физического удаления документа;
- состояния `visible`, `hiddenForCurrentUser`, `deletedForEveryone`;
- отдельный presentation/UI-слой;
- поиск предыдущего видимого сообщения для preview карточки чата.

## 10. Неприкосновенные функции

Нельзя ломать:

- соответствие Firebase Auth UID документу `users/{uid}`;
- личные и групповые сообщения;
- создание private chat только после первого сообщения;
- отсутствие пустых private chats;
- атомарное первое сообщение;
- атомарное обновление `lastMessage`;
- pagination по 20 сообщений;
- персональную очистку private chat;
- логическое удаление сообщений;
- push-уведомления;
- поиск пользователей, контактов и чатов;
- роли, mute, ban и permissions;
- добавление участников;
- защиту последнего администратора;
- передачу прав и безопасный выход;
- Media Foundation abstractions;
- версионную замену аватаров;
- rollback при ошибке metadata;
- fallback на инициалы;
- отдельный заменяемый UI-слой;
- будущую роль `owner` максимального приоритета.

## 11. Известный технический долг

### Высокий и средний приоритет

- Push-нажатие пока не открывает непосредственно нужный чат.
- Avatar path-first cache пока только in-memory.
- Kotlin Gradle Plugin и Android Gradle-конфигурацию нужно обновить отдельным этапом.
- Firestore Rules emulator tests нужно расширять.
- Требуется дальнейшая оптимизация Firestore reads.
- Нужны дополнительные тесты конкурентных операций с двух устройств.
- `ARCHITECTURE.md` позднее желательно разделить на отдельные документы.
- Необходимо контролировать Storage usage для пилотной группы 40–50 пользователей.

### Будущий UI

Через отдельный UI-слой планируются:

- анимации установки и удаления;
- темы;
- фон чатов;
- формы и размеры пузырей;
- размеры и семейства шрифтов;
- дополнительные стили карточек;
- визуальные эффекты без изменения бизнес-логики.

## 12. Следующий порядок действий

1. Обновить `PROJECT_CONTEXT.md`.
2. Обновить `README.md`.
3. Обновить `ARCHITECTURE.md`.
4. Выполнить финальные проверки:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
git.exe diff --check
git.exe status --short
```

5. Закоммитить документацию в `feat/v0.6.5-avatar-foundation`.
6. Отправить ветку в GitHub.
7. Перейти в `main`.
8. Обновить `main`.
9. Слить `feat/v0.6.5-avatar-foundation` в `main`.
10. Повторить analyze, test и release build на `main`.
11. Создать тег `v0.6.5`.
12. Отправить `main` и тег в GitHub.
13. Подготовить новую рабочую ветку для следующего этапа.

## 13. Команды Windows

Использовать PowerShell и явные executable-имена:

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

Для форматирования Dart-файлов:

```powershell
$flutterBin = Split-Path (Get-Command flutter.bat).Source
$dartExe = Join-Path $flutterBin "cache\\dart-sdk\\bin\\dart.exe"

& $dartExe format lib test
```

## 14. Рабочий стиль

- Работать маленькими проверяемыми шагами.
- Перед коммитом выполнять ручную проверку изменённого сценария.
- После этапа выполнять format, analyze, test и release build.
- Не смешивать feature-изменения с обновлением toolchain.
- Команды для Windows давать с явными executable-именами:
  - `flutter.bat`
  - `firebase.cmd`
  - `npm.cmd`
  - `git.exe`
- Учитывать Firebase usage и целевую пилотную группу 40–50 пользователей.
