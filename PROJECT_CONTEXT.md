# Epistola — Project Context

> Живой документ состояния проекта. Использовать как главный handoff между чатами и аккаунтами.
> При расхождении приоритет: исходный код → `PROJECT_CONTEXT.md` → `ARCHITECTURE.md` → `README.md`.

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Рабочая ветка: `chore/v0.6.6-android-toolchain`
- Базовый стабильный commit: `3d0974c`
- Базовый стабильный tag: `v0.6.5`
- Текущий этап: **Android Toolchain Foundation**
- Планируемый технический релиз: `v0.6.6`
- Последний опубликованный стабильный релиз: `v0.6.5`
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Cloud Functions region: `europe-west1`
- Android package: `com.epistola.app`
- Основная платформа: Android
- Целевая пилотная группа: 40–50 пользователей

Стабильная точка:

```text
3d0974c merge: release v0.6.5 Avatar Foundation
```

`main` был синхронизирован с `origin/main`, а рабочее дерево было чистым до создания технической ветки.

Текущая ветка создана от стабильного `main`:

```text
chore/v0.6.6-android-toolchain
```

Текущий этап не добавляет пользовательские функции и не начинает передачу изображений в сообщениях. Его задача — проверить Android toolchain, локализовать предупреждение Built-in Kotlin и внести только действительно необходимые изменения.

По итогам аудита обновление Gradle, Android Gradle Plugin, Kotlin и целевых медиа-зависимостей не выполнялось: текущая конфигурация совместима, release APK собирается, а доступных версий плагинов с нужной миграцией пока не найдено.

## 2. Android Toolchain Foundation — `v0.6.6`

### 2.1 Цель и границы этапа

Цели:

- зафиксировать текущие версии Flutter, Dart, Java, Gradle, Android Gradle Plugin и Kotlin;
- проверить Android SDK levels;
- проверить `firebase_storage` и `flutter_image_compress`;
- воспроизвести и локализовать предупреждение Built-in Kotlin;
- обновлять только необходимые зависимости и Android-конфигурацию;
- не смешивать toolchain-работу с Image Message Foundation;
- выполнить analyze, все тесты и release build;
- провести ручной Android regression test перед закрытием этапа.

В этом этапе запрещено:

- добавлять тип сообщения `image`;
- добавлять отправку изображений;
- менять Firestore message metadata;
- менять Storage Rules под сообщения;
- редактировать плагины внутри Pub Cache;
- обновлять весь набор зависимостей без причины;
- смешивать технический commit с новой функциональностью.

### 2.2 Зафиксированные версии окружения

```text
Flutter: 3.44.1 stable
Flutter framework revision: 924134a44c
Flutter engine revision: 39b1f7043775b9578bbb26a1676e79c4e31c8b5e
Dart: 3.12.1
DevTools: 2.57.0

Java: OpenJDK 21.0.10
Java source: Android Studio bundled JBR
Java path: C:\Program Files\Android\Android Studio\jbr\bin\java

Android SDK: 36.1.0
Android SDK path: C:\Dev\Android\Sdk
Android platform: android-36.1
Android build-tools: 36.1.0

Gradle Wrapper: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
Google Services Plugin: 4.3.15
```

Важно различать две версии Kotlin:

```text
Kotlin 2.3.20
→ Kotlin Gradle Plugin приложения, указан в android/settings.gradle.kts

Kotlin 2.2.0
→ встроенная версия Kotlin, которую показывает gradlew.bat --version
  и использует сам Gradle
```

Это не конфликт версий.

### 2.3 Java и PowerShell

Обычная команда:

```powershell
java.exe -version
```

не срабатывает, потому что Java не добавлена в глобальный `PATH`.

Flutter при этом корректно использует JDK из Android Studio:

```text
C:\Program Files\Android\Android Studio\jbr
```

Для прямого запуска Gradle в текущем PowerShell-сеансе можно временно задать:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

После этого работают:

```powershell
& "$env:JAVA_HOME\bin\java.exe" -version
.\android\gradlew.bat -p .\android --version
```

Это временная настройка текущего терминала и не изменяет систему после его закрытия.

### 2.4 Android SDK levels и bytecode target

Flutter `3.44.1` подставляет:

```text
compileSdk: 36
targetSdk: 36
minSdk: 24
```

В `android/app/build.gradle.kts` используются значения Flutter:

```kotlin
compileSdk = flutter.compileSdkVersion
minSdk = flutter.minSdkVersion
targetSdk = flutter.targetSdkVersion
```

Java и Kotlin компилируются в JVM 17 bytecode:

```text
Java compatibility: 17
Kotlin jvmTarget: JVM_17
```

Сама Gradle-сборка запускается на JDK 21. Такая связка допустима: JDK 21 запускает toolchain, а приложение получает совместимый JVM 17 bytecode.

Дополнительная Android-зависимость:

```text
com.android.tools:desugar_jdk_libs:2.1.4
```

### 2.5 Текущие Gradle compatibility flags

В `android/gradle.properties` уже присутствуют:

```properties
android.useAndroidX=true
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
```

`android.newDsl=false` и `android.builtInKotlin=false` сохраняют временный режим совместимости с плагинами, которые ещё подключают Kotlin Gradle Plugin старым способом.

Удалять или менять эти флаги до миграции плагинов нельзя.

### 2.6 Проверенные версии медиа-зависимостей

```text
firebase_storage: 13.4.5
firebase_storage_platform_interface: 6.0.5
firebase_storage_web: 3.11.11

flutter_image_compress: 2.5.1
flutter_image_compress_common: 1.1.1
flutter_image_compress_platform_interface: 1.1.0
```

Команда:

```powershell
flutter.bat pub outdated
```

не показала доступных обновлений для:

```text
firebase_storage
flutter_image_compress
```

Следовательно, предупреждение Built-in Kotlin нельзя устранить обычным обновлением этих зависимостей на текущем этапе.

Отдельно доступны небольшие обновления, не связанные с предупреждением:

```text
flutter_local_notifications: 22.1.0 → 22.2.0
image_picker: 1.2.2 → 1.2.3
```

Они намеренно не включены в `v0.6.6`, потому что не требуются для решения текущей задачи.

### 2.7 Локализованное предупреждение Built-in Kotlin

Release build показывает предупреждение для плагинов:

```text
firebase_storage
flutter_image_compress_common
```

Смысл предупреждения:

- плагины пока сами применяют Kotlin Gradle Plugin;
- будущие версии Flutter прекратят поддерживать такой способ;
- плагины должны перейти на Built-in Kotlin;
- текущая сборка ещё поддерживается и завершается успешно.

Предупреждение относится к внутренней Android-конфигурации плагинов, а не к устаревшей версии Kotlin в Epistola.

Не выполнять:

- ручное редактирование файлов в Pub Cache;
- принудительное удаление compatibility flags;
- случайное понижение или повышение Gradle/AGP/Kotlin;
- замену плагинов без отдельного проектирования и тестов.

Принятое решение:

```text
сохранить текущую совместимую конфигурацию
→ отслеживать обновления плагинов
→ мигрировать после появления официально совместимых версий
```

### 2.8 Проверки технической ветки

В ветке `chore/v0.6.6-android-toolchain` выполнено:

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

Предупреждение Built-in Kotlin не останавливает сборку.

Диагностические строки тестов:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

выводятся тестовыми JPEG-данными и не являются падением тестов. Все 251 тест завершаются успешно.

После `analyze`, `test` и `build` Flutter может изменять:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake
```

Если изменения вызваны только генерацией плагинов и не относятся к задаче, файлы восстанавливаются через `git.exe restore` и не коммитятся.

После последнего восстановления:

```text
git.exe status --short
→ пустой вывод
```

### 2.9 Ручная проверка перед закрытием `v0.6.6`

До финального commit и выпуска `v0.6.6` требуется проверить на Android:

- запуск приложения;
- вход в существующий аккаунт;
- открытие списка личных и групповых чатов;
- пользовательские аватары;
- групповые аватары;
- выбор изображения из галереи;
- камера;
- квадратный crop;
- замена пользовательского аватара;
- замена группового аватара;
- запись metadata в Firestore;
- загрузка thumbnail и full в Firebase Storage.

Так как рабочие зависимости и Android-конфигурация не изменялись, ожидается отсутствие функциональных отличий от `v0.6.5`, но ручная regression-проверка всё равно обязательна перед релизом.

### 2.10 Нормальные сообщения, не являющиеся ошибками

Tree-shaking MaterialIcons:

```text
Tree-shaking reduced MaterialIcons font size
```

является нормальной оптимизацией release build.

Git-сообщения:

```text
LF will be replaced by CRLF
```

не являются ошибками Flutter или Android-сборки.

Отсутствие Visual Studio в `flutter.bat doctor -v` относится только к сборке Windows desktop. Для основной Android-платформы Epistola это не блокирующая проблема.

## 3. Завершённые стабильные этапы

- `v0.6.2` — Media Foundation.
- `v0.6.2.1` — Security Foundation.
- `v0.6.3` — Push Notification Foundation.
- `v0.6.4` — Message Deletion Foundation.
- `v0.6.5` — Avatar Foundation.

Текущий технический этап:

- `v0.6.6` — Android Toolchain Foundation, в работе.

Следующий функциональный этап после успешного завершения `v0.6.6`:

- `v0.7.0` — Image Message Foundation.

## 4. User Avatar Foundation — `v0.6.5`

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
- draft-чате до отправки первого сообщения;
- списке участников группы.

Пользователи без фотографии получают fallback с двумя буквами. Цвет fallback стабилен и определяется по UID.

## 5. Group Avatar Foundation — `v0.6.5`

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

В информации о группе owner/admin может:

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

## 6. Проверенные Android-сценарии `v0.6.5`

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

Основное правило:

```text
Flutter UI
→ controllers
→ application services
→ domain models/contracts
→ Firebase gateways/adapters
```

UI должен оставаться отдельно от:

- Firebase Storage;
- Firestore transactions;
- application services;
- rollback;
- cleanup;
- security rules.

### 8.1 UI-слой

Основные avatar-компоненты:

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

### 8.4 Требование к будущим изображениям в сообщениях

Image Message Foundation должен повторять существующее разделение:

```text
Message UI
→ image message controller
→ preparation/upload/send services
→ image message domain model and contracts
→ Firebase Storage and Firestore adapters
```

Нельзя размещать в message bubble:

- прямой Firebase Storage upload;
- Firestore transaction logic;
- rollback;
- cleanup;
- security policy;
- подготовку thumbnail/full.

Визуальные компоненты должны быть заменяемыми, чтобы позднее можно было менять:

- темы;
- размеры и семейства шрифтов;
- форму и размер пузырей;
- анимации;
- цвета;
- фон чатов;
- размеры и форму аватаров;
- оформление image preview;

без переписывания business logic и Firebase-слоя.

## 9. Завершённые предыдущие foundations

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
- сохранение загруженной истории при realtime updates;
- персональную очистку private chat;
- логическое удаление сообщений;
- удаление сообщения «у себя»;
- удаление собственного сообщения «у всех»;
- push-уведомления;
- поиск пользователей, контактов и чатов;
- private chat search по данным второго участника;
- роли, mute, ban и permissions;
- добавление участников;
- защиту последнего администратора;
- передачу прав и безопасный выход;
- Media Foundation abstractions;
- версионную замену пользовательских аватаров;
- версионную замену групповых аватаров;
- rollback при ошибке metadata;
- path-first loading;
- fallback на инициалы;
- fallback группы по первой букве;
- отдельный заменяемый UI-слой;
- будущую роль `owner` максимального приоритета.

## 11. Известный технический долг

### Высокий и средний приоритет

- Push-нажатие пока не открывает непосредственно нужный чат.
- Avatar path-first cache пока только in-memory.
- `firebase_storage` и `flutter_image_compress_common` ещё используют старый способ подключения Kotlin Gradle Plugin.
- Compatibility flags `android.newDsl=false` и `android.builtInKotlin=false` пока необходимы.
- После появления совместимых версий плагинов нужен отдельный повторный аудит Built-in Kotlin.
- Firestore Rules emulator tests нужно расширять.
- Требуется дальнейшая оптимизация Firestore reads.
- Нужны дополнительные тесты конкурентных операций с двух устройств.
- `ARCHITECTURE.md` позднее желательно разделить на отдельные документы.
- Необходимо контролировать Storage usage для пилотной группы 40–50 пользователей.
- Перед Image Message Foundation нужно отдельно спроектировать лимиты хранения, cache и cleanup.
- Release APK пока подписывается debug signing configuration; перед внешним production-релизом потребуется отдельная signing-настройка.

### Отложенные небольшие обновления

Не включены в `v0.6.6`, потому что не относятся к предупреждению Built-in Kotlin:

```text
flutter_local_notifications: 22.1.0 → 22.2.0
image_picker: 1.2.2 → 1.2.3
```

Обновлять их следует отдельным контролируемым изменением с analyze, test, release build и ручной проверкой соответствующих сценариев.

### Будущий UI

Через отдельный UI-слой планируются:

- анимации установки и удаления;
- темы;
- фон чатов;
- формы и размеры пузырей;
- размеры и семейства шрифтов;
- дополнительные стили карточек;
- визуальные эффекты без изменения бизнес-логики.

## 12. Следующий функциональный этап — Image Message Foundation `v0.7.0`

Image Message Foundation начинается только после успешного завершения `v0.6.6`.

Будущий поток:

```text
галерея или камера
→ подготовка изображения
→ thumbnail + full
→ Firebase Storage
→ metadata сообщения
→ отображение изображения в сообщении
→ полноэкранный просмотр
```

Планируется:

- тип сообщения `image`;
- выбор из галереи;
- камера;
- квадратный или безопасно ограниченный crop, если он потребуется по UX;
- исправление ориентации;
- удаление EXIF;
- сжатие;
- thumbnail;
- full;
- progress;
- отмена;
- retry;
- rollback;
- cleanup;
- Firestore metadata;
- Storage Rules;
- preview в списке чатов;
- push-текст `Фотография`;
- совместимость с удалением «у себя / у всех»;
- сохранение pagination;
- экономный cache;
- полноэкранный просмотр.

Не начинать весь этап одним большим изменением.

Первый подэтап:

```text
Image Message Domain + Metadata Foundation
```

Сначала отдельно спроектировать:

- domain-модель image message;
- message type;
- metadata schema;
- инварианты thumbnail/full;
- Storage paths;
- ограничения размеров;
- состояния upload;
- rollback/cleanup contracts;
- правила совместимости с удалением;
- preview contract;
- push representation;
- тесты mapper/domain logic.

Только после этого подключать picker, camera, compression, upload и UI.

### 12.1 Предварительные Storage paths

Пути пока не утверждены и должны быть спроектированы до реализации.

Ожидаемое направление:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Финальный формат нельзя закреплять до проверки:

- Firestore message creation flow;
- возможности заранее получить `messageId`;
- retry semantics;
- cleanup orphan uploads;
- delete-for-everyone policy;
- Storage Rules;
- стоимости Storage operations.

### 12.2 Экономия Firebase

Для пилотной группы 40–50 пользователей:

- не хранить исходный файл;
- загружать только подготовленные thumbnail и full;
- не выполнять лишние Firestore reads для каждого bubble;
- объединять параллельные запросы одинакового изображения;
- использовать версионные cache keys;
- ограничивать максимальный размер скачиваемых байтов;
- не загружать full до явного открытия, если thumbnail достаточно;
- предусмотреть cleanup незавершённых upload;
- не удалять физические данные без продуманной совместимости с delete-for-self/delete-for-everyone;
- контролировать количество Storage list/read/delete operations.

## 13. Следующий порядок действий

Текущий порядок для `v0.6.6`:

1. Заменить `PROJECT_CONTEXT.md` актуальной полной версией.
2. Проверить diff документа.
3. При необходимости обновить `ARCHITECTURE.md`.
4. При необходимости обновить `README.md`.
5. Выполнить:

```powershell
git.exe diff --check
git.exe status --short
```

6. Установить или запустить текущий release APK на Android.
7. Выполнить ручной regression test:
   - вход;
   - пользовательские аватары;
   - групповые аватары;
   - камера;
   - галерея;
   - crop;
   - Firebase Storage;
   - Firestore metadata.
8. После ручного подтверждения повторить финальные проверки:

```powershell
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

9. Восстановить посторонние generated plugin files, если Flutter снова их изменит.
10. Выполнить:

```powershell
git.exe diff --check
git.exe status --short
```

11. Закоммитить документацию и только необходимые изменения в `chore/v0.6.6-android-toolchain`.
12. Отправить ветку в GitHub.
13. Слить ветку в `main`.
14. Повторить analyze, test и release build на `main`.
15. Создать tag `v0.6.6`.
16. Отправить `main` и tag.
17. Создать отдельную ветку для `v0.7.0 Image Message Foundation`.
18. Начать только с domain-модели и metadata.

Не коммитить до ручной проверки изменённого сценария, если пользователь явно не подтвердил обратное.

## 14. Команды Windows

Использовать PowerShell и явные executable-имена.

### 14.1 Flutter

```powershell
flutter.bat --version
flutter.bat doctor -v
flutter.bat pub deps --style=compact
flutter.bat pub outdated
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
```

### 14.2 Форматирование Dart

```powershell
$flutterBin = Split-Path (Get-Command flutter.bat).Source
$dartExe = Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe"

& $dartExe format lib test
```

### 14.3 Gradle и Java

Для текущего PowerShell-сеанса:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

& "$env:JAVA_HOME\bin\java.exe" -version
.\android\gradlew.bat -p .\android --version
```

### 14.4 Firebase и Node

```powershell
firebase.cmd --version
firebase.cmd deploy --only firestore:rules,storage
npm.cmd --version
```

### 14.5 Git

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

Восстановление generated plugin files:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

## 15. Рабочий стиль

- Работать маленькими проверяемыми шагами.
- После каждого шага ждать скриншот или полный результат пользователя.
- Не давать сразу много изменений.
- Перед изменением кратко объяснять, какой файл меняется и зачем.
- Не коммитить до ручной проверки изменённого сценария, если пользователь явно не подтвердил обратное.
- После завершённого этапа выполнять format, analyze, test и release build.
- Не смешивать feature-изменения с обновлением toolchain.
- Не начинать Image Message Foundation до закрытия Android Toolchain Foundation.
- Команды для Windows давать с явными executable-именами:
  - `flutter.bat`
  - `firebase.cmd`
  - `npm.cmd`
  - `git.exe`
- При сборке отслеживать generated plugin files и не коммитить их без причины.
- Учитывать Firebase usage и целевую пилотную группу 40–50 пользователей.
- Сохранять архитектурные границы между UI, controllers, services, domain и Firebase adapters.
- Если `PROJECT_CONTEXT.md` становится слишком большим или недостаточным, заранее предложить разделение на дополнительные документы, но основной источник handoff остаётся `PROJECT_CONTEXT.md`.
