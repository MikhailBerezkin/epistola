Epistola

Корпоративный мессенджер на Flutter и Firebase

Epistola — Android-first корпоративный мессенджер и основа для будущей внутренней коммуникационной платформы компании. Проект развивается небольшими проверяемыми этапами с разделением UI, application services, domain-моделей и Firebase infrastructure.

Статус проекта

Параметр

Значение

Последний стабильный релиз

v0.6.6

Последний стабильный commit main

e0a966c

Текущий функциональный этап

v0.7.0 Image Message Foundation

Рабочая ветка

feat/v0.7.0-image-message-foundation

Последний функциональный commit ветки

7b7189c

Состояние этапа

функциональность реализована и проверена, документация обновляется перед релизом

Основная платформа

Android

Backend

Firebase

Репозиторий

MikhailBerezkin/epistola

Firebase project

epistola-434b7

Firestore region

eur3

Cloud Functions region

europe-west1

Android package

com.epistola.app

Пилотная группа

около 40–50 пользователей

Текущая ветка создана от стабильного v0.6.6 Android Toolchain Foundation.

Последние итоговые проверки функциональной ветки:

flutter.bat analyze
→ No issues found

flutter.bat test
→ 386 tests passed

npm.cmd --prefix functions run build
→ tsc успешно

npm.cmd --prefix functions run lint
→ успешно

flutter.bat build apk --release
→ успешно

Release APK:

build\app\outputs\flutter-apk\app-release.apk

APK установлен и проверен на физическом Android-телефоне.

Что такое Epistola

Краткосрочная цель — стабильный корпоративный мессенджер для пилотной группы 40–50 пользователей.

Долгосрочная цель — коммуникационная платформа для компании на 600–700 сотрудников:

личные и групповые чаты;

роли и модерация;

изображения, файлы и голосовые сообщения;

задачи;

объявления;

документы;

рабочие смены;

внутренние приложения;

корпоративные сервисы;

возможный собственный backend.

Spaces больше не рассматриваются как обычный тип чата. Планируемое направление:

Spaces → внутренние приложения Epistola

Главный принцип проекта:

Сначала надёжные архитектурные гарантии, затем пользовательские функции поверх них.

Реализованные возможности

Пользователи и авторизация

Firebase Authentication.

Регистрация.

Вход по E-mail и паролю.

Постоянная сессия.

Запоминание последнего E-mail.

Профиль пользователя.

Редактирование профиля.

Публичный контактный E-mail, независимый от FirebaseAuth.

Карточка контакта.

Поиск пользователей.

Экран контактов.

Пользовательские аватары.

Личные чаты

Личные текстовые чаты.

Создание private chat только после первого сообщения.

Отсутствие пустых private chats.

Атомарное создание первого сообщения и metadata чата.

Отправка изображения в существующий private chat.

Создание private chat первой фотографией.

Персональная очистка private chat.

Поиск private chat по данным собеседника, а не по техническому имени документа.

Пользовательские аватары в списке, поиске, draft и заголовке чата.

Групповые чаты

Создание групп.

Добавление участников.

Информация о группе.

Список участников.

Карточки участников.

Передача прав.

Защита последнего администратора.

Безопасный выход.

Роспуск группы.

Настройки группы.

Ограничение отправки по ролям.

Групповые аватары.

Управление групповым аватаром для owner и admin.

Текущий Image Message Foundation проверен для личных чатов. Отправка изображений в групповые чаты не заявлена завершённой.

История сообщений

Cursor pagination по 20 сообщений.

Дозагрузка старой истории при прокрутке вверх.

Сохранение позиции прокрутки.

Realtime-обновления без потери уже загруженных страниц.

Стабильное объединение сообщений по document ID.

Автопрокрутка при отправке новых сообщений.

Корректировка прокрутки после появления крупного изображения.

Учёт изменения высоты окна при открытии виртуальной клавиатуры.

Удаление сообщений

Поддерживаемые состояния:

visible
hiddenForCurrentUser
deletedForEveryone

Реализовано:

удалить сообщение у себя;

удалить собственное сообщение у всех;

«Удалить у всех» только для отправителя;

logical deletion без физического удаления Firestore document;

поиск предыдущего видимого сообщения для preview чата;

отсутствие повторного push при логическом удалении.

Роли и модерация

Поддерживаемые роли:

owner
admin
moderator
member
guest

Реализовано:

mute;

ban;

разграничение прав;

ограничения отправки;

управление участниками;

скрытие недоступных действий в UI;

Firestore Rules для ролей и permissions;

защита последнего администратора;

передача прав;

безопасный выход.

Будущая роль owner должна оставаться ролью максимального приоритета.

Image Message Foundation — v0.7.0

Поддерживаемые сценарии

Изображение можно отправить:

в существующий личный чат;

как первое сообщение новому контакту;

из галереи;

с камеры.

Проверенный поток первой фотографии:

Новое сообщение
→ Найти пользователя
→ открыть пользователя
→ выбрать фотографию
→ отредактировать
→ отправить
→ private chat создаётся вместе с первым image message

До успешной отправки чат не создаётся.

Меню вложений

Текущее меню:

Галерея
Камера
Файл
Голосовое

Работают:

Галерея
Камера

Пункты Файл и Голосовое пока показывают информационное уведомление о будущей версии.

Временно удалены:

Геопозиция
Контакт

Редактирование фотографии

После выбора или фотографирования открывается редактор.

Поддерживается:

свободный crop;

изменение области обрезки;

исходное соотношение сторон;

квадрат;

3:2;

4:3;

16:9;

поворот;

сброс;

подтверждение;

отмена без отправки.

Подготовка изображения

Приложение не загружает исходный оригинал.

После редактирования создаются два JPEG-варианта:

thumbnail
full

Лимиты thumbnail:

максимальный размер: 128 KB
максимальная сторона: 480 px

Лимиты full:

целевой размер: 512 KB
абсолютный максимум: 1 MB
максимальная сторона: 1920 px

Thumbnail и full обязаны:

принадлежать одному сообщению;

иметь одинаковую version;

иметь одинаковый provider;

использовать image/jpeg;

сохранять одинаковые пропорции;

находиться в canonical Storage paths.

Storage paths

chat_media/{chatId}/messages/{messageId}/v{version}/thumb.jpg
chat_media/{chatId}/messages/{messageId}/v{version}/full.jpg

Оригинальный файл не загружается.

Безопасная первая фотография

До создания private chat обычная проверка membership ещё невозможна. Поэтому используется серверный upload grant:

createFirstPrivateImageUploadGrant

Grant связывает:

uploader;

peer;

canonical private chat ID;

messageId;

version.

После загрузки выполняется атомарная операция:

создание private chat
+ создание первого image message
+ lastMessage
+ lastMessageAt

Grant нельзя использовать:

другому пользователю;

с другим peer;

с другим chatId;

с другим messageId;

с другой version;

для произвольного Storage path.

Rollback и cleanup

Если загрузка или запись сообщения прерывается:

уже загруженный thumbnail удаляется;

уже загруженный full удаляется;

пустой private chat не остаётся;

локальные временные файлы очищаются;

ошибка cleanup не заменяет исходную ошибку;

успешное сообщение не удаляется из-за вторичной ошибки cleanup.

Отображение в чате

В ленте используется thumbnail с правильными пропорциями.

Время сообщения остаётся видимым.

В списке чатов preview:

Фотография

После перезапуска приложения изображение загружается снова.

У собеседника отображается то же изображение.

Полноэкранный просмотр

По нажатию на thumbnail открывается ImageMessageViewerScreen.

Поддерживается:

чёрный фон;

загрузка full-варианта;

progress;

retry;

pinch-to-zoom;

перемещение увеличенного изображения;

увеличение до 5x;

двойное нажатие для увеличения;

повторное двойное нажатие для сброса;

возврат стрелкой AppBar;

возврат системной Android-кнопкой;

возврат в тот же чат.

Full-файл не загружается для обычного отображения ленты.

Автопрокрутка

Исправлены два Android-сценария:

После появления крупного image bubble следующее сообщение остаётся видимым.

При открытой виртуальной клавиатуре новое сообщение прокручивается в область над клавиатурой.

При чтении старой истории приложение не должно принудительно возвращать пользователя вниз.

Push Notification Foundation — v0.6.3

Реализовано:

Firebase Cloud Messaging;

локальные Android-уведомления;

foreground, background и terminated-состояния;

уведомления при заблокированном экране;

регистрация и обновление FCM tokens;

удаление token текущего устройства при logout;

Cloud Function sendMessageNotification;

регион europe-west1;

исключение отправителя;

личные и групповые push;

очистка невалидных tokens;

представление image message как Фотография.

Известное ограничение:

нажатие на уведомление открывает приложение,
но пока не переводит непосредственно в нужный чат

Message Deletion Foundation — v0.6.4

Presentation flow:

Firestore message state
        ↓
MessagePresentation
        ↓
MessageItem
        ↓
MessageBubble

Это позволяет менять bubble UI без изменения Firestore deletion logic.

Image messages используют ту же logical deletion модель.

Текущая политика Storage assets:

delete for self
→ assets сохраняются для других участников

delete for everyone
→ сообщение скрывается логически
→ assets не удаляются немедленно

Будущий retention cleanup должен проектироваться отдельно.

Avatar Foundation — v0.6.5

Пользовательские аватары

Поддерживается:

галерея;

камера;

квадратный crop 1:1;

Android retrieveLostData();

thumbnail 128×128;

full 512×512;

JPEG-сжатие;

коррекция ориентации;

ограничения размера;

очистка временных файлов;

versioned Storage paths;

atomic replacement;

rollback при ошибке metadata;

best-effort cleanup старой версии;

path-first loading;

cache key path@version;

fallback на две буквы и стабильный цвет.

Storage paths:

user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg

Отображение:

профиль;

контакты;

список private chats;

поиск чатов;

заголовок private chat;

draft chat;

участники группы.

Групповые аватары

Storage paths:

group_avatars/{chatId}/v{version}/thumb.jpg
group_avatars/{chatId}/v{version}/full.jpg

Реализовано:

отдельная domain-модель;

metadata mapper;

Storage upload service;

Firestore metadata gateway;

atomic replacement service;

rollback;

Firestore Rules;

Storage Rules;

gallery/camera/crop;

установка и замена;

управление только owner и admin.

Отображение:

информация о группе;

список групп;

поиск чатов;

заголовок group chat.

Android Toolchain Foundation — v0.6.6

Зафиксированная конфигурация:

Flutter: 3.44.1 stable
Dart: 3.12.1
Java: OpenJDK 21.0.10
Gradle Wrapper: 9.1.0
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

Built-in Kotlin warning связан с внутренней Android-конфигурацией плагинов:

firebase_storage
flutter_image_compress_common

Принятое решение:

не редактировать Pub Cache;

не обновлять Gradle, AGP и Kotlin вслепую;

не удалять compatibility flags без подтверждённой миграции;

не смешивать toolchain work с функциональными этапами.

Архитектура

Основная цепочка:

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

Принципы:

UI не знает детали Firebase infrastructure.

Domain не зависит от Flutter и Firebase.

Firebase adapters скрыты за contracts.

Rollback и cleanup находятся в application services.

Storage paths формируются централизованно.

Security invariants дублируются в domain validation и Firebase Rules.

UI-компоненты заменяемы.

Feature changes не смешиваются с toolchain changes.

Большие foundations сначала проектируются, затем интегрируются в UI.

Image message flow:

MessageInput
→ ImageMessageImagePreparationService
→ ImageMessageImageProcessor
→ ImageMessageUploadService
→ ExistingImageMessageSendService
   или FirstPrivateImageMessageSendService
→ writer
→ Firebase adapters

Display flow:

Firestore snapshot
→ mappers
→ MessagePresentation
→ MessageItem
→ MessageBubble
→ ImageMessageThumbnail
→ ImageMessageViewerScreen

Подробности находятся в ARCHITECTURE.md.

Основные зависимости

firebase_core
firebase_auth
cloud_firestore
firebase_storage
firebase_messaging
cloud_functions
flutter_local_notifications
image_picker
image_cropper
flutter_image_compress
cached_network_image
shared_preferences
vibration

Структура проекта

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
├── rules/
├── services/
└── widgets/

Основные документы:

PROJECT_CONTEXT.md
ARCHITECTURE.md
README.md

Приоритет при расхождении:

исходный код
→ PROJECT_CONTEXT.md
→ ARCHITECTURE.md
→ README.md

Firebase

Используются:

Firebase Authentication;

Cloud Firestore;

Firebase Security Rules;

Firebase Storage;

Firebase Cloud Messaging;

Cloud Functions for Firebase.

Основные Cloud Functions:

sendMessageNotification
createFirstPrivateImageUploadGrant

Основные Rules-файлы:

firestore.rules
storage.rules

Rules emulator tests находятся в:

test/rules/

Сборка и проверки

Flutter

flutter.bat pub get
flutter.bat analyze
flutter.bat test
flutter.bat build apk --release

Cloud Functions

npm.cmd --prefix functions run build
npm.cmd --prefix functions run lint

Известное lint-предупреждение:

SUPPORTED TYPESCRIPT VERSIONS: >=3.3.1 <5.2.0
YOUR TYPESCRIPT VERSION: 6.0.3

Оно не остановило build или lint.

Firebase deploy

firebase.cmd deploy --only functions
firebase.cmd deploy --only firestore
firebase.cmd deploy --only storage

Одна функция:

firebase.cmd deploy --only functions:createFirstPrivateImageUploadGrant

Git

git.exe status --short
git.exe diff
git.exe diff --check
git.exe add
git.exe commit
git.exe push

Flutter может менять generated plugin files:

linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake

После серии Flutter-проверок их можно восстановить:

git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake

Проверенные сценарии v0.7.0

На эмуляторе и физическом Android-телефоне проверено:

меню вложений из четырёх пунктов;

выбор изображения из галереи;

фотографирование камерой;

редактор;

crop;

отмена редактора;

индикатор подготовки и загрузки;

блокировка повторного нажатия;

image message в существующем private chat;

первая фотография новому контакту;

отсутствие пустого private chat;

правильные пропорции;

время сообщения;

отображение у собеседника;

загрузка после перезапуска;

preview Фотография;

полноэкранный просмотр;

zoom;

перемещение;

двойное нажатие;

системный back;

автопрокрутка;

автопрокрутка при открытой виртуальной клавиатуре.

Известные ограничения

Push-нажатие пока не открывает конкретный чат.

Image messages в групповых чатах не заявлены завершёнными.

Файлы и голосовые сообщения пока не реализованы.

Геопозиция и контакт временно удалены из меню.

Spaces будут проектироваться как внутренние приложения.

Нет production retention cleanup для логически удалённых image assets.

App Check ещё не завершён как production-hardening этап.

Перед внешним production-релизом нужна отдельная release signing setup.

Необходимо продолжать контролировать Firebase Storage usage и Firestore reads.

Roadmap

Ближайшие направления после выпуска v0.7.0:

Стабилизация image messages и исправление найденных реальных ошибок.

Навигация из push непосредственно в нужный чат.

Групповые image messages.

Файлы.

Голосовые сообщения.

Retention cleanup для удалённых media assets.

Production hardening: App Check, signing, расширенные emulator tests.

Дальнейшее развитие UI: темы, фоны, формы пузырей, анимации.

Внутренние приложения Epistola вместо обычного типа чата Spaces.

Roadmap может уточняться отдельными этапами. Новые функции не должны добавляться ценой нарушения существующих архитектурных гарантий.

Рабочий процесс

Общение и координация — на русском языке.

Команды выполняются в PowerShell.

Используются явные executable-имена:

flutter.bat

firebase.cmd

npm.cmd

git.exe

Изменения делаются небольшими проверяемыми шагами.

Перед commit выполняются analyze, профильные tests и diff --check.

Перед релизом выполняются полный test suite и release APK build.

Изменённый пользовательский сценарий проверяется вручную.

Случайно изменённые generated plugin files не включаются в feature commits.

Учитывается Firebase free-tier и пилотная группа 40–50 пользователей.

Оригиналы изображений без необходимости не загружаются.

Лицензия

Проект является внутренним продуктом и не публикуется в pub.dev.