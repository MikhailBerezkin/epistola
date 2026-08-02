# Epistola — Project Context

> Живой документ состояния проекта.
>
> Использовать как основной handoff между чатами, рабочими сессиями и аккаунтами.
>
> При расхождении источников приоритет:
>
> ```text
> исходный код
> → PROJECT_CONTEXT.md
> → ARCHITECTURE.md
> → README.md
> ```

## 1. Текущая контрольная точка

- Репозиторий: `MikhailBerezkin/epistola`
- Firebase project: `epistola-434b7`
- Firestore region: `eur3`
- Cloud Functions region: `europe-west1`
- Android package: `com.epistola.app`
- Основная платформа: Android
- Целевая пилотная группа: 40–50 пользователей

Последняя стабильная версия:

```text
v0.6.6 — Android Toolchain Foundation
```

Стабильный `main`:

```text
commit: e0a966c
tag: v0.6.6
```

Текущая рабочая ветка:

```text
feat/v0.7.0-image-message-foundation
```

Текущий функциональный HEAD до обновления документации:

```text
7b7189c feat(image-message): integrate image messages into chat UI
```

Рабочая ветка:

```text
ahead of e0a966c by 17 commits
behind by 0 commits
```

Последние функциональные commits:

```text
f5c47ae feat(image-message): add image editing before upload
7b7189c feat(image-message): integrate image messages into chat UI
```

Текущий этап:

```text
v0.7.0 — Image Message Foundation
```

Состояние этапа:

```text
функциональный контур реализован
→ серверные функции и rules опубликованы
→ release APK собран
→ основные сценарии проверены на эмуляторе
→ основные сценарии проверены на физическом Android-телефоне
→ документация обновляется перед выпуском v0.7.0
```

После push commit `7b7189c` рабочее дерево было чистым.

Сейчас локально изменяется только документация этапа.

---

## 2. Image Message Foundation — `v0.7.0`

### 2.1 Цель этапа

Цель — добавить безопасную и экономную отправку JPEG-фотографий в сообщениях с сохранением существующих гарантий Epistola:

- private chat создаётся только после первого успешно отправленного сообщения;
- пустые личные чаты не создаются;
- первое сообщение и документ чата записываются атомарно;
- существующая пагинация не ломается;
- realtime-обновления не удаляют уже загруженную историю;
- удаление «у себя» и «у всех» остаётся логическим;
- push и preview получают понятное представление изображения;
- UI не содержит прямой Firebase business logic;
- незавершённые загрузки очищаются;
- оригинальный файл пользователя не загружается;
- Firebase usage учитывает пилотную группу 40–50 пользователей.

Реально проверенный пользовательский scope текущего этапа:

```text
личные чаты
```

Включая:

```text
существующий личный чат
первая фотография новому контакту
```

Отправку изображений в групповые чаты нельзя считать завершённой без отдельной реализации и ручной проверки.

### 2.2 Пользовательский поток

Существующий личный чат:

```text
галерея или камера
→ редактор изображения
→ thumbnail + full
→ Firebase Storage
→ Firestore message
→ обновление preview чата
→ отображение у обоих пользователей
```

Первое сообщение новому контакту:

```text
выбор пользователя
→ галерея или камера
→ редактор изображения
→ подготовка thumbnail + full
→ получение server-side upload grant
→ загрузка файлов
→ атомарное создание private chat и первого image message
→ появление чата у обоих пользователей
```

При отмене на любом пользовательском шаге:

```text
чат не создаётся
сообщение не создаётся
загрузка не начинается или очищается
```

---

## 3. Domain и metadata изображений

### 3.1 Типы сообщений

Введены доменные модели:

```text
MessageType
MessageContent
MessagePreview
MessagePushRepresentation
ImageMessageMetadata
ImageMessageLimits
ImageMessageSendState
ImageMessageDeletionPolicy
```

Поддерживаемые пользовательские типы:

```text
text
image
```

Неизвестный или некорректный тип не должен незаметно интерпретироваться как валидное изображение.

### 3.2 Image metadata

Image message содержит согласованную пару:

```text
thumbnail
full
```

Оба варианта обязаны:

- принадлежать одному сообщению;
- иметь одинаковый provider;
- иметь одинаковую положительную version;
- использовать MIME type `image/jpeg`;
- иметь разные Storage paths;
- иметь положительные размеры файлов;
- иметь положительные размеры изображения;
- сохранять одинаковое соотношение сторон с небольшим допуском округления.

Firestore-представление image metadata содержит:

```text
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
```

Поддерживаемый provider:

```text
firebase
```

Поддерживаемый MIME type:

```text
image/jpeg
```

### 3.3 Лимиты

Thumbnail:

```text
максимальный размер файла: 128 KB
максимальная сторона: 480 px
```

Full:

```text
целевой размер файла: 512 KB
абсолютный максимум: 1 MB
максимальная сторона: 1920 px
```

Допустимое расхождение пропорций thumbnail и full из-за округления:

```text
0.02
```

Оригинальный файл из галереи или камеры в Firebase Storage не загружается.

---

## 4. Storage paths и cache keys

Версионные пути:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Текущая версия изображения сообщения:

```text
version > 0
```

Cache keys:

```text
{thumbnailStoragePath}@{version}
{fullStoragePath}@{version}
```

Thumbnail используется в ленте сообщений.

Full загружается только после явного открытия фотографии пользователем.

Это уменьшает:

- сетевой трафик;
- лишнюю загрузку больших файлов;
- нагрузку на Firebase Storage;
- потребление памяти в длинных чатах.

---

## 5. Подготовка изображения

### 5.1 Источники

Поддерживаются:

```text
галерея
камера
Android lost-data recovery
```

Подготовка не начинается, если пользователь:

- отменил выбор;
- отменил камеру;
- отменил редактор;
- Android не вернул потерянное изображение.

### 5.2 Редактор

После выбора или фотографирования открывается редактор:

```text
Редактирование фотографии
```

Поддерживается:

- свободный crop;
- изменение рамки;
- исходное соотношение сторон;
- квадрат;
- `3:2`;
- `4:3`;
- `16:9`;
- поворот;
- сброс;
- подтверждение;
- отмена без отправки.

Для image messages используется прямоугольный свободный crop.

Квадратный avatar crop остаётся отдельным пользовательским сценарием.

### 5.3 Processor

После редактора создаются два JPEG-файла:

```text
thumbnail
full
```

Processor выполняет:

- чтение исходных размеров;
- уменьшение без увеличения маленького изображения;
- сохранение пропорций;
- отдельные ограничения thumbnail и full;
- повторные попытки качества;
- проверку фактического размера результата;
- проверку фактических dimensions;
- проверку согласованности thumbnail и full;
- безопасную очистку временной рабочей папки.

Если processor не может получить валидную согласованную пару, отправка прекращается.

### 5.4 Временные файлы

Гарантии:

- оригинальный picker-файл не удаляется приложением;
- временный crop-файл удаляется после подготовки;
- рабочая директория processor очищается;
- ошибка cleanup не должна заменять исходную ошибку подготовки;
- успешно подготовленные файлы освобождаются после завершения upload/send pipeline.

---

## 6. Upload foundation

### 6.1 Storage gateway

Добавлен отдельный контракт:

```text
ImageMessageStorageGateway
```

Firebase-реализация:

```text
FirebaseImageMessageStorageAdapter
```

Gateway предоставляет отдельные операции:

```text
uploadThumbnail
uploadFull
delete
```

UI не обращается к Firebase Storage напрямую.

### 6.2 Metadata загрузки

Каждый Storage object получает canonical metadata, связанную с:

- uploader;
- chat;
- message;
- version;
- variant;
- MIME type;
- размером и назначением объекта.

Допускаются только canonical paths:

```text
.../thumb.jpg
.../full.jpg
```

Произвольные дополнительные пути не должны приниматься как image message assets.

### 6.3 Upload orchestration

Сервис:

```text
ImageMessageUploadService
```

отвечает за:

- валидацию входных идентификаторов;
- загрузку thumbnail;
- загрузку full;
- формирование `ImageMessageMetadata`;
- проверку persistable metadata;
- cleanup уже загруженных объектов при частичной ошибке.

Порядок:

```text
upload thumbnail
→ upload full
→ validate metadata
→ вернуть согласованную пару
```

При ошибке после загрузки thumbnail:

```text
thumbnail удаляется
```

При ошибке после загрузки обоих вариантов:

```text
thumbnail и full удаляются
```

---

## 7. Отправка в существующий чат

Application services:

```text
ExistingImageMessageSendService
ExistingImageMessageWriteService
```

Порядок:

```text
подготовка изображения
→ резервирование messageId
→ загрузка Storage assets
→ создание image message
→ обновление lastMessage
```

Запись Firestore должна сохранять согласованность:

```text
message document
chat lastMessage
chat lastMessageAt
```

Preview чата для image message:

```text
Фотография
```

Если Firestore write завершается ошибкой после upload:

```text
загруженные Storage assets очищаются best-effort
```

Успешное сообщение не должно удаляться из-за последующей незначительной ошибки cleanup временных локальных файлов.

---

## 8. Первая фотография нового private chat

Application services:

```text
FirstPrivateImageMessageSendService
FirstPrivateImageMessageWriteService
FirstPrivateImageUploadGrantService
```

Главное требование:

```text
выбор пользователя и выход назад
→ не создаёт private chat
```

То же правило действует при фотографии:

```text
отмена галереи
отмена камеры
отмена редактора
ошибка подготовки
ошибка grant
ошибка загрузки
ошибка Firestore write
→ не оставляют пустой private chat
```

### 8.1 Server-side upload grant

Для безопасной загрузки первой фотографии до существования chat document используется Cloud Function:

```text
createFirstPrivateImageUploadGrant
```

Регион:

```text
europe-west1
```

Grant связывает:

- uploader;
- peer;
- canonical private chat ID;
- messageId;
- version.

Клиент не должен самостоятельно выдавать себе grant.

Grant не может использоваться:

- другим uploader;
- для другого peer;
- для другого chatId;
- для другого messageId;
- для другой version;
- для произвольного Storage path.

### 8.2 Атомарное создание

После успешной загрузки выполняется атомарная Firestore-операция:

```text
создание private chat
создание первого image message
обновление lastMessage
обновление lastMessageAt
```

При конфликте существующего чата используется безопасный путь обновления существующего private chat.

---

## 9. Rollback и remote cleanup

Модели и сервисы:

```text
ImageMessageRemoteCleanupPlan
ImageMessageRemoteCleanupService
```

Cleanup plan знает, какие remote assets были созданы текущей попыткой.

Основные случаи:

```text
ошибка thumbnail upload
→ удалять нечего

thumbnail загружен, full не загружен
→ удалить thumbnail

thumbnail и full загружены, Firestore write не выполнен
→ удалить thumbnail и full

Firestore write выполнен успешно
→ не удалять активные assets
```

Remote cleanup выполняется best-effort.

Ошибка удаления orphan-файла:

- не должна скрывать основную ошибку;
- не должна превращать успешную отправку в неуспешную;
- должна оставаться доступной для будущей диагностики и retention cleanup.

---

## 10. Firestore Rules

Firestore Rules расширены для image messages.

Проверяется:

- пользователь аутентифицирован;
- senderId соответствует `request.auth.uid`;
- пользователь является участником чата;
- message type поддерживается;
- text message имеет допустимую text-структуру;
- image message содержит полную image metadata;
- provider равен `firebase`;
- MIME type равен `image/jpeg`;
- version положительна;
- thumbnail и full paths canonical;
- paths соответствуют chatId, messageId и version;
- размеры файлов находятся в лимитах;
- dimensions находятся в лимитах;
- thumbnail и full согласованы;
- first private message создаётся только по разрешённому атомарному сценарию;
- upload grant нельзя подменить другой версией или другими идентификаторами.

Добавлены отдельные emulator tests:

```text
image_message_upload_grant_rules.test.mjs
message_create_rules.test.mjs
private_chat_first_message_rules.test.mjs
```

Firestore Rules опубликованы в:

```text
epistola-434b7
```

---

## 11. Storage Rules

Storage Rules расширены для:

```text
chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg
```

Проверяется:

- пользователь аутентифицирован;
- MIME type `image/jpeg`;
- canonical path;
- variant соответствует имени файла;
- metadata соответствует пути;
- uploader соответствует текущему пользователю;
- размеры находятся в лимитах;
- существующий чат разрешает upload только участнику;
- первая фотография нового private chat требует валидный server-side grant;
- grant должен совпадать по uploader, peer, chatId, messageId и version;
- нельзя использовать grant другой версии;
- нельзя загружать произвольный третий файл;
- удаление разрешается только для canonical image assets в рамках установленной политики.

Добавлен крупный набор Storage Rules emulator tests:

```text
test/rules/storage/image_message_storage_rules.test.mjs
```

Storage Rules опубликованы в:

```text
epistola-434b7
```

---

## 12. Push и preview

Доменные resolvers:

```text
MessagePreviewResolver
MessagePushResolver
```

Для text message:

```text
preview → текст сообщения
push → текст сообщения
```

Для image message:

```text
preview → Фотография
push → Фотография
```

Cloud Function push не должна выводить внутренний Storage path или техническую metadata.

Существующая Cloud Function:

```text
sendMessageNotification
```

сохраняет поддержку:

- личных чатов;
- групповых чатов;
- cleanup невалидных device tokens;
- региона `europe-west1`.

Известное ограничение push:

```text
нажатие на уведомление открывает приложение,
но пока не переводит непосредственно в нужный чат
```

---

## 13. Совместимость с удалением сообщений

Image message использует существующую логическую модель удаления.

Удаление «у себя»:

```text
сообщение скрывается только для текущего пользователя
Storage assets сохраняются для других участников
```

Удаление «у всех»:

```text
сообщение логически помечается deletedForEveryone
Storage assets не удаляются немедленно
```

Текущая политика:

```text
shouldDeleteStorageImmediately == false
```

Причина:

- другие участники могут ещё иметь доступ при delete-for-self;
- немедленное физическое удаление может конфликтовать с realtime и cache;
- нужен отдельный retention cleanup;
- логическое удаление уже является источником пользовательской видимости.

Будущий cleanup удалённых image assets должен проектироваться отдельно и не должен ломать историю, rollback и права доступа.

---

## 14. Интеграция в UI

### 14.1 Меню вложений

По нажатию на кнопку `+` открывается bottom sheet.

Текущие пункты:

```text
Галерея
Камера
Файл
Голосовое
```

Работают:

```text
Галерея
Камера
```

Пункты:

```text
Файл
Голосовое
```

пока показывают информационное уведомление о будущей версии.

Временно удалены из интерфейса:

```text
Геопозиция
Контакт
```

Они будут возвращаться только после отдельного проектирования.

### 14.2 Экран «Новое сообщение»

На экране оставлены:

```text
Найти пользователя
Создать группу
```

Удалён пункт:

```text
Создать пространство
```

Spaces не должны проектироваться как обычный тип чата.

Будущее направление:

```text
Spaces → внутренние приложения Epistola
```

### 14.3 Состояние отправки

Во время подготовки и загрузки:

- отображается индикатор;
- повторное нажатие блокируется;
- текстовая отправка не должна запускать конфликтующую image-операцию;
- ошибка возвращает интерфейс в доступное состояние;
- отмена не считается ошибкой.

### 14.4 Message presentation

`MessagePresentation` расширен без переноса Firebase logic в UI.

Image message содержит:

```text
isImageMessage
imageMetadata
```

Основная цепочка отображения:

```text
Firestore snapshot
→ message mappers
→ MessagePresentation
→ MessageItem
→ MessageBubble
→ ImageMessageThumbnail
```

---

## 15. Thumbnail в ленте

Компонент:

```text
ImageMessageThumbnail
```

Поведение:

- использует thumbnail Storage path;
- получает download URL через `MediaStorageService`;
- использует versioned cache key;
- сохраняет пропорции изображения;
- отображает progress;
- отображает retry при ошибке;
- открывает full viewer по нажатию.

Thumbnail отображается внутри обычного message bubble.

Время сообщения остаётся видимым.

Изображение корректно загружается снова после перезапуска приложения.

---

## 16. Полноэкранный просмотр

Экран:

```text
ImageMessageViewerScreen
```

Используется:

```text
fullStoragePath
fullCacheKey
```

Поддерживается:

- чёрный фон;
- AppBar;
- загрузка full-варианта;
- progress;
- retry;
- pinch-to-zoom;
- перемещение увеличенного изображения;
- максимальное увеличение до `5x`;
- двойное нажатие для увеличения;
- повторное двойное нажатие для сброса;
- стрелка AppBar;
- системная Android-кнопка «Назад»;
- возврат в тот же чат;
- сохранение текущего положения списка после возврата.

Full-файл не загружается для обычного показа ленты.

---

## 17. Автопрокрутка

### 17.1 Проблема крупного изображения

После появления крупного image bubble высота списка могла окончательно измениться уже после первой прокрутки.

Результат:

```text
следующее текстовое сообщение
могло появиться ниже видимой области
```

Исправление:

- первая прокрутка после изменения списка;
- повторная корректирующая прокрутка после layout;
- таймер корректировки отменяется в `dispose`;
- принудительный scroll выполняется только если пользователь был возле низа.

### 17.2 Виртуальная клавиатура

На физическом телефоне клавиатура уменьшает доступную высоту чата.

Добавлен учёт:

```text
MediaQuery.viewInsets.bottom
```

`MessagesList` получает изменение keyboard inset и корректирует нижнюю позицию после перестройки layout.

Проверено:

- отправка фотографии;
- открытие клавиатуры;
- отправка текста;
- новое сообщение полностью видно над клавиатурой;
- второе последовательное сообщение также прокручивается;
- чтение старой истории выше не прерывается принудительным переходом вниз.

---

## 18. Проверенные Android-сценарии

### 18.1 Существующий private chat

Проверено:

- открытие меню вложений;
- выбор фотографии из галереи;
- съёмка камерой;
- стандартное подтверждение снимка камеры;
- открытие редактора;
- crop;
- изменение пропорций;
- подтверждение редактора;
- отмена редактора;
- индикатор подготовки;
- индикатор загрузки;
- блокировка повторной отправки;
- появление фотографии в ленте;
- правильные пропорции;
- правильное время;
- получение фотографии собеседником;
- повторная загрузка после перезапуска;
- preview `Фотография` в списке чатов.

### 18.2 Первая фотография новому контакту

Проверено:

```text
Новое сообщение
→ Найти пользователя
→ открыть пользователя
→ не отправлять текст
→ выбрать фотографию
```

Результат:

- создаётся private chat;
- первая фотография видна отправителю;
- первая фотография видна собеседнику;
- чат появляется в общем списке;
- preview показывает `Фотография`;
- пустой чат до отправки не создаётся.

### 18.3 Viewer

Проверено:

- открытие фотографии по нажатию;
- загрузка full;
- zoom;
- перемещение;
- двойное нажатие;
- возврат стрелкой AppBar;
- возврат системной Android-кнопкой;
- возврат в чат без потери позиции.

### 18.4 Редактор

Проверено:

- редактор после галереи;
- редактор после камеры;
- crop применяется;
- отмена не отправляет сообщение;
- отправляется отредактированная версия;
- редактор работает на физическом Android-телефоне.

Отображение crop UI на эмуляторе может выглядеть необычно из-за размера и конфигурации виртуального экрана. Финальная функциональная проверка выполнена на телефоне.

### 18.5 Автоскролл

Проверено:

- сообщение после фотографии прокручивается вниз;
- последовательные сообщения остаются видимыми;
- исправление работает с открытой виртуальной клавиатурой на телефоне;
- ручное чтение старых сообщений не должно принудительно прерываться.

---

## 19. Проверки текущей ветки

Последние итоговые проверки:

```text
flutter.bat analyze
→ No issues found
```

Полный Flutter test suite:

```text
flutter.bat test
→ 386 tests passed
```

Cloud Functions TypeScript build:

```text
npm.cmd --prefix functions run build
→ tsc успешно
```

Cloud Functions lint:

```text
npm.cmd --prefix functions run lint
→ успешно
```

Известное предупреждение lint:

```text
SUPPORTED TYPESCRIPT VERSIONS: >=3.3.1 <5.2.0
YOUR TYPESCRIPT VERSION: 6.0.3
```

Оно не остановило build или lint.

`git.exe diff --check` после восстановления generated-файлов:

```text
пустой вывод
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

APK установлен и проверен на физическом Android-телефоне.

Диагностические тестовые строки:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
JPEG datastream contains no image
```

появляются из-за намеренно некорректных JPEG-данных в тестах и не являются падением тестов.

---

## 20. Cloud deployments

Успешно опубликована Cloud Function:

```text
createFirstPrivateImageUploadGrant
```

Регион:

```text
europe-west1
```

Также продолжает работать:

```text
sendMessageNotification
```

Firestore Rules опубликованы:

```text
firebase.cmd deploy --only firestore
```

Storage Rules опубликованы:

```text
firebase.cmd deploy --only storage
```

Firebase project:

```text
epistola-434b7
```

Firebase CLI может показывать уведомление о новой версии. Это не является ошибкой deploy.

---

## 21. Завершённые стабильные этапы

### `v0.6.2` — Media Foundation

Реализовано:

- `MediaAsset`;
- `MediaStorageProvider`;
- `FirebaseMediaStorageProvider`;
- `MediaStorageService`;
- `MediaPaths`;
- Firebase Storage foundation;
- базовые Storage Rules.

### `v0.6.2.1` — Security Foundation

Реализовано:

- private chat создаётся только после первого сообщения;
- отсутствие пустых private chats;
- pagination по 20 сообщений;
- realtime merge без потери загруженной истории;
- атомарное message + chat metadata;
- персональная очистка private chat;
- усиленные Firestore Rules;
- роли и membership guarantees.

### `v0.6.3` — Push Notification Foundation

Реализовано:

- FCM;
- foreground notifications;
- background notifications;
- terminated-state notifications;
- device tokens;
- Cloud Function `sendMessageNotification`;
- регион `europe-west1`;
- удаление невалидных токенов;
- push для личных и групповых сообщений.

### `v0.6.4` — Message Deletion Foundation

Реализовано:

- удалить сообщение «у себя»;
- удалить собственное сообщение «у всех»;
- логическое удаление;
- `hiddenFor`;
- `deletedForEveryone`;
- presentation layer;
- предыдущий видимый message preview;
- защита удаления «у всех» только для sender.

### `v0.6.5` — Avatar Foundation

Реализовано:

- пользовательские аватары;
- групповые аватары;
- галерея;
- камера;
- квадратный crop;
- thumbnail и full;
- versioned Storage paths;
- атомарная замена;
- rollback;
- cleanup старой версии;
- path-first loading;
- cache key `path@version`;
- fallback на инициалы;
- fallback группы;
- отображение на основных экранах.

### `v0.6.6` — Android Toolchain Foundation

Стабильная конфигурация:

```text
Flutter: 3.44.1
Dart: 3.12.1
Java: 21.0.10
Gradle: 9.1.0
Android Gradle Plugin: 9.0.1
Kotlin Gradle Plugin: 2.3.20
```

Технический релиз не добавлял пользовательских функций.

Известное предупреждение Built-in Kotlin связано с внутренней конфигурацией плагинов:

```text
firebase_storage
flutter_image_compress_common
```

Предупреждение не блокирует release build.

---

## 22. Avatar Foundation — действующие гарантии

### 22.1 User avatars

Storage paths:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
```

Metadata:

```text
avatarProvider
avatarThumbStoragePath
avatarFullStoragePath
avatarThumbSizeBytes
avatarFullSizeBytes
avatarVersion
avatarUpdatedAt
```

Порядок замены:

```text
подготовка
→ upload новой версии
→ transaction metadata
→ best-effort cleanup старой версии
```

При ошибке старый активный аватар сохраняется.

### 22.2 Group avatars

Storage paths:

```text
group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg
```

Изменять групповой аватар могут:

```text
owner
admin
```

Metadata хранится в:

```text
chats/{chatId}
```

### 22.3 Отображение

Пользовательские аватары отображаются:

- в профиле;
- в списке личных чатов;
- в поиске;
- в контактах;
- в заголовке private chat;
- до отправки первого сообщения;
- у участников группы.

Групповые аватары отображаются:

- в информации о группе;
- в основном списке групп;
- в поиске;
- в заголовке group chat.

---

## 23. Архитектурные границы

Основная цепочка:

```text
Flutter UI
→ controllers / presentation
→ application services
→ domain models and contracts
→ Firebase gateways / adapters
```

Для image messages:

```text
MessageInput / MessageInputArea
→ image preparation
→ image upload service
→ existing or first-private send service
→ writer
→ Firebase adapters
```

Обратный путь отображения:

```text
Firestore
→ mappers
→ MessagePresentation
→ MessageBubble
→ ImageMessageThumbnail
→ ImageMessageViewerScreen
```

### 23.1 UI не должен

UI не должен содержать:

- прямой Firebase Storage upload;
- Firestore transaction logic;
- upload grant security;
- rollback;
- remote cleanup;
- подготовку thumbnail/full;
- правила доступа;
- canonical path validation.

### 23.2 Services отвечают за

Services отвечают за:

- подготовку;
- crop integration;
- compression;
- upload;
- orchestration;
- atomic write;
- rollback;
- cleanup;
- mapping;
- preview;
- push representation.

### 23.3 Domain отвечает за

Domain отвечает за:

- типы сообщений;
- image metadata;
- лимиты;
- invariants;
- send states;
- deletion policy;
- независимые от UI решения.

### 23.4 Firebase adapters отвечают за

Firebase adapters отвечают только за:

- Storage upload/delete/download;
- callable Cloud Functions;
- Firestore transaction;
- чтение и запись metadata.

---

## 24. Неприкосновенные функции

Нельзя ломать:

- соответствие Firebase Auth UID документу `users/{uid}`;
- личные текстовые сообщения;
- групповые текстовые сообщения;
- создание private chat только после первого сообщения;
- отсутствие пустых private chats;
- атомарное первое сообщение;
- атомарное обновление `lastMessage`;
- pagination по 20 сообщений;
- сохранение старых страниц при realtime updates;
- корректную прокрутку;
- персональную очистку private chat;
- удаление сообщения «у себя»;
- удаление собственного сообщения «у всех»;
- logical deletion;
- поиск пользователей;
- контакты;
- поиск чатов;
- private chat search по peer identity;
- роли;
- mute;
- ban;
- permissions;
- добавление участников;
- защиту последнего администратора;
- передачу прав;
- безопасный выход из группы;
- push-уведомления;
- Media Foundation abstractions;
- пользовательские аватары;
- групповые аватары;
- versioned Storage paths;
- rollback аватаров;
- image message metadata invariants;
- image message rollback;
- server-side first-image grant;
- thumbnail/full separation;
- preview `Фотография`;
- загрузку full только после открытия;
- совместимость image messages с logical deletion;
- fallback UI;
- будущую роль `owner` максимального приоритета.

---

## 25. Известный технический долг

### Высокий и средний приоритет

- Push-нажатие пока не открывает конкретный чат.
- Отправка image messages в групповые чаты не заявлена завершённой.
- Нужны дополнительные реальные тесты конкурентной отправки изображения с двух устройств.
- Нужен будущий retention cleanup для Storage assets логически удалённых image messages.
- Нельзя немедленно физически удалять image assets при delete-for-everyone без отдельной политики.
- Path-first avatar cache пока преимущественно in-memory.
- Необходимо продолжать контролировать Firebase Storage usage.
- Firestore reads требуют дальнейшей оптимизации по мере роста приложения.
- App Check пока не является завершённым production-hardening этапом.
- Release APK пока использует текущую signing-конфигурацию; перед внешним production-релизом нужна отдельная release signing setup.
- Firestore и Storage Rules emulator tests нужно расширять при каждом новом media type.
- `ARCHITECTURE.md` со временем желательно разделить на несколько тематических документов.
- `PROJECT_CONTEXT.md` следует сохранять как handoff, а не превращать в полный reference manual.

### Android toolchain

Compatibility flags пока необходимы:

```properties
android.newDsl=false
android.builtInKotlin=false
```

Не редактировать плагины внутри Pub Cache.

Не менять Gradle, AGP или Kotlin без отдельного контролируемого аудита.

### Отложенные вложения

Пока не реализованы:

```text
файлы
голосовые сообщения
геопозиция
контакты
```

### Spaces

Spaces не должны возвращаться как обычная карточка создания чата.

Планируемое направление:

```text
внутренние приложения Epistola
```

---

## 26. Будущие UI-возможности

Архитектура должна позволять менять без переписывания Firebase business logic:

- темы;
- светлый и тёмный режим;
- фон чатов;
- форму пузырей;
- размер пузырей;
- цвета;
- размеры шрифтов;
- семейства шрифтов;
- оформление image preview;
- анимации отправки;
- анимации удаления;
- progress UI;
- retry UI;
- галерею нескольких изображений;
- свайп между изображениями;
- подписи к фотографиям;
- реакцию на изображения;
- анимацию открытия viewer.

---

## 27. Следующий порядок действий

Текущая функциональность уже закоммичена и отправлена до commit:

```text
7b7189c
```

Далее:

1. Полностью заменить `PROJECT_CONTEXT.md` этой актуальной версией.
2. Сохранить файл.
3. Выполнить:

```powershell
git.exe diff -- PROJECT_CONTEXT.md
git.exe diff --check
git.exe status --short
```

4. Обновить `ARCHITECTURE.md`.
5. Обновить `README.md`.
6. Проверить документацию:

```powershell
git.exe diff --check
git.exe status --short
```

7. Создать отдельный documentation commit.
8. Отправить ветку в GitHub.
9. Убедиться, что рабочее дерево чистое.
10. Слить:

```text
feat/v0.7.0-image-message-foundation
→ main
```

11. На `main` повторить:

```powershell
flutter.bat analyze
flutter.bat test
npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
flutter.bat build apk --release
```

12. После Flutter-проверок восстановить generated plugin files, если они снова изменились.
13. Проверить:

```powershell
git.exe diff --check
git.exe status --short
```

14. Создать tag:

```text
v0.7.0
```

15. Отправить `main` и tag.
16. Зафиксировать новую стабильную точку в следующем handoff.

Не коммитить документацию до её просмотра.

---

## 28. Команды Windows

Использовать PowerShell и явные executable-имена.

### Flutter

```powershell
flutter.bat --version
flutter.bat doctor -v
flutter.bat pub get
flutter.bat pub outdated
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release
flutter.bat run
```

### Node и Cloud Functions

```powershell
node.exe --version
npm.cmd --version
npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint
```

### Firebase

```powershell
firebase.cmd --version
firebase.cmd deploy --only functions
firebase.cmd deploy --only firestore
firebase.cmd deploy --only storage
```

При необходимости deploy одной функции:

```powershell
firebase.cmd deploy --only functions:createFirstPrivateImageUploadGrant
```

### Git

```powershell
git.exe branch --show-current
git.exe status --short
git.exe diff
git.exe diff --check
git.exe diff --cached --stat
git.exe log -1 --oneline --decorate
git.exe add
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

Generated plugin files восстанавливать в конце серии Flutter-проверок, а не после каждой отдельной команды.

### Release APK

Путь:

```text
E:\Dev\Projects\epistola\build\app\outputs\flutter-apk\app-release.apk
```

---

## 29. Окружение разработки

Основная ОС:

```text
Windows
```

IDE:

```text
Visual Studio Code
```

Android-проверки:

```text
Android Emulator
физический Android-телефон Poco
```

Flutter:

```text
3.44.1 stable
```

Dart:

```text
3.12.1
```

Java:

```text
OpenJDK 21.0.10
Android Studio bundled JBR
```

Gradle:

```text
9.1.0
```

Android Gradle Plugin:

```text
9.0.1
```

Kotlin Gradle Plugin:

```text
2.3.20
```

Firebase CLI:

```text
15.19.1
```

Node:

```text
22.17.1
```

npm:

```text
10.9.2
```

NVM root:

```text
C:\nvm
```

Node symlink:

```text
C:\nodejs
```

---

## 30. Рабочий стиль

- Общение и координация — на русском языке.
- Работать маленькими проверяемыми шагами.
- После каждого шага ждать результат или скриншот.
- Не давать много независимых изменений одновременно.
- Перед заменой файла указывать точный путь.
- Для больших изменений предпочтительно давать файл целиком.
- Код давать в блоке с кнопкой копирования.
- Пользователь сохраняет через `Ctrl+S`.
- VS Code автоматически форматирует Dart при сохранении.
- Не требовать `Shift+Alt+F`, если автоформатирование уже работает.
- Не использовать несуществующую команду `flutter.bat format`.
- Команды Windows давать с явными executable-именами:
  - `flutter.bat`
  - `firebase.cmd`
  - `npm.cmd`
  - `git.exe`
- Не коммитить изменённый пользовательский сценарий до ручной проверки, если пользователь явно не подтвердил обратное.
- После этапа выполнять analyze, test и release build.
- Для Cloud Functions выполнять build и lint.
- Generated plugin files не восстанавливать после каждой проверки.
- Восстанавливать generated plugin files один раз в конце серии проверок.
- Учитывать Firebase free-tier и пилотную группу 40–50 пользователей.
- Не загружать оригиналы изображений без необходимости.
- Не смешивать toolchain-обновления с feature-разработкой.
- Сохранять границы между UI, domain, services и Firebase adapters.
- При недостатке контекста заранее просить обновлённый `PROJECT_CONTEXT.md`.

---

## 31. Краткий handoff для следующей сессии

```text
Проект: Epistola
Репозиторий: MikhailBerezkin/epistola

Стабильный main:
e0a966c
tag v0.6.6

Рабочая ветка:
feat/v0.7.0-image-message-foundation

Последний функциональный HEAD:
7b7189c

Текущий этап:
v0.7.0 Image Message Foundation

Состояние:
функциональность реализована;
Cloud Function опубликована;
Firestore Rules опубликованы;
Storage Rules опубликованы;
386 Flutter tests passed;
analyze clean;
functions build clean;
functions lint completed;
release APK проверен на физическом телефоне.

Работает:
галерея;
камера;
crop;
thumbnail/full;
first private image message;
existing private image message;
preview Фотография;
полноэкранный viewer;
zoom;
системный back;
автоскролл;
автоскролл с виртуальной клавиатурой.

Сейчас:
обновить PROJECT_CONTEXT.md;
обновить ARCHITECTURE.md;
обновить README.md;
закоммитить документацию;
слить ветку в main;
повторить проверки;
создать tag v0.7.0.
```