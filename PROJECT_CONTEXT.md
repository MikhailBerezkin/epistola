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
v0.7.0 — Image Message Foundation
```

Стабильный `main`:

```text
commit: 192f565
tag: v0.7.0
```

Текущая рабочая ветка:

```text
feat/v0.7.1-push-deep-link-foundation
```

Текущий этап:

```text
v0.7.1 — Push Deep Link Foundation
```

Состояние этапа:

```text
функциональный контур реализован
→ профильные тесты пройдены
→ полный analyze пройден
→ полный test suite пройден
→ release APK собран
→ APK установлен на физический Android-телефон
→ private и group deep links вручную проверены
→ документация обновляется перед commit/release
```

Итоговые проверки:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 409 tests passed

flutter.bat build apk --release
→ успешно, 55.3 MB

git.exe diff --check
→ без вывода
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Cloud Functions, Firestore Rules и Storage Rules на текущем этапе не менялись. Firebase deploy для `v0.7.1` не требуется.

Рабочее дерево до обновления документации содержит только Push Deep Link Foundation:

```text
M  lib/main.dart
M  lib/services/notification_service.dart
?? lib/domain/models/push_deep_link_request.dart
?? lib/services/push/
?? test/domain/models/push_deep_link_request_test.dart
?? test/services/push/
```

Generated plugin files восстановлены и не должны входить в feature commit.

## 2. Цель этапа

После нажатия на notification открыть именно тот private или group chat, к которому относится сообщение.

До `v0.7.1`:

```text
notification tap
→ приложение открывается
→ пользователь остаётся на главном экране
```

После `v0.7.1`:

```text
notification tap
→ payload validation
→ auth + membership validation
→ destination resolution
→ ChatScreen
```

Требования:

- foreground, background, terminated и cold start;
- private и group chats;
- чужой или удалённый chat не открывается;
- приложение не падает;
- один tap не создаёт duplicate route;
- тот же chat можно открыть снова после закрытия route;
- без постоянных Firestore listeners;
- без ненужного изменения server contract.

## 3. Серверный контракт

Cloud Function `sendMessageNotification` уже передавала:

```text
data: {
  chatId
}
```

Принятое решение:

```text
не менять functions/src/index.ts
не выполнять Firebase deploy
использовать существующий data.chatId
```

## 4. PushDeepLinkRequest

Файл:

```text
lib/domain/models/push_deep_link_request.dart
```

Ответственность:

- `chatId` из `RemoteMessage.data`;
- `chatId` из local payload;
- только String;
- `trim()`;
- reject empty;
- reject `/`;
- value equality;
- отсутствие зависимостей Flutter/Firebase.

Методы:

```text
fromRemoteData
fromLocalPayload
tryParseChatId
```

Тесты:

```text
test/domain/models/push_deep_link_request_test.dart
8 tests
```

Проверены valid remote/local, whitespace, missing, non-string, empty, slash, equality и `toString`.

## 5. PushDeepLinkResolver

Файл:

```text
lib/services/push/push_deep_link_resolver.dart
```

Injected dependencies:

```text
currentUserIdProvider
loadChat
loadUser
```

Firebase factory:

```text
PushDeepLinkResolver.firebase()
```

Алгоритм:

```text
current UID
→ chats/{chatId}
→ memberIds
→ type
→ private: ChatPeerResolver + AppUser
→ group: name
→ PushDeepLinkDestination
```

Поддерживаются:

```text
private
group
```

Возвращает `null`, если:

- нет auth;
- chat отсутствует;
- `memberIds` некорректен;
- current user не member;
- type неизвестен;
- private chat не содержит peer.

Private title:

```text
peer.name
→ peer.email
→ stored chat name
→ Личный чат
```

Group fallback:

```text
Без названия
```

Тесты:

```text
test/services/push/push_deep_link_resolver_test.dart
9 tests
```

## 6. PushDeepLinkCoordinator

Файл:

```text
lib/services/push/push_deep_link_coordinator.dart
```

Coordinator не зависит от Flutter Navigator.

Ответственность:

- pending queue;
- navigation readiness;
- queue deduplication;
- sequential resolve;
- destination opener;
- unavailable/error callbacks;
- duplicate route protection;
- retry после ошибки;
- повторное открытие после закрытия route.

Структуры:

```text
Queue<PushDeepLinkRequest> _pendingRequests
Set<String> _queuedChatIds
Set<String> _openedChatIds
```

Методы:

```text
handle
flush
clearPending
```

Cold-start guarantee:

```text
request до Navigator
→ queue
→ markNavigationReady
→ flush
→ resolver
→ route
```

Тесты:

```text
test/services/push/push_deep_link_coordinator_test.dart
6 tests
```

## 7. PushDeepLinkNavigation

Файл:

```text
lib/services/push/push_deep_link_navigation.dart
```

Flutter adapter содержит:

```text
GlobalKey<NavigatorState>
PushDeepLinkResolver
PushDeepLinkCoordinator
```

Lifecycle:

```text
markNavigationReady()
markNavigationUnavailable()
```

Open flow:

```text
Navigator.push<void>
→ MaterialPageRoute<void>
→ ChatScreen
```

Private destination передаёт `peerUser`. Group destination передаёт `peerUser: null`.

Unavailable chat не открывает route. Errors логируются только в debug.

## 8. main.dart integration

Изменён:

```text
lib/main.dart
```

Startup:

```text
WidgetsFlutterBinding.ensureInitialized
→ Firebase.initializeApp
→ background handler
→ PushDeepLinkNavigation
→ NotificationService.initialize(coordinator)
→ AppSettings.loadThemeMode
→ runApp
→ NotificationService.startMessaging
```

`MaterialApp` получает `navigatorKey`.

После первого frame вызывается `markNavigationReady()`. При dispose — `markNavigationUnavailable()`.

## 9. NotificationService integration

Изменён:

```text
lib/services/notification_service.dart
```

Initialize contract:

```text
NotificationService.initialize(
  deepLinkCoordinator: ...
)
```

Remote tap:

```text
FirebaseMessaging.onMessageOpenedApp
→ PushDeepLinkRequest.fromRemoteData
→ coordinator.handle
```

Cold start:

```text
FirebaseMessaging.getInitialMessage
→ request
→ coordinator.handle
```

Foreground:

```text
FirebaseMessaging.onMessage
→ local notification
→ payload: request.chatId
```

Local tap:

```text
NotificationResponse.payload
→ PushDeepLinkRequest.fromLocalPayload
→ coordinator.handle
```

NotificationService не читает chat document, не проверяет membership и не создаёт `ChatScreen` напрямую.

## 10. Ручные проверки

Физический телефон — получатель. Android Emulator — отправитель.

### 10.1 Private background

```text
app свёрнуто
→ private push
→ правильные title/body
→ tap
→ нужный private chat
→ duplicate route отсутствует
```

### 10.2 Private terminated / cold start

```text
app удалено из recent tasks
→ push
→ tap
→ app запускается
→ нужный private chat открывается
```

### 10.3 Group chat

```text
group push
→ tap
→ нужный group chat
```

### 10.4 Foreground local notification

```text
app открыто
→ message
→ local notification
→ tap
→ нужный chat
```

### 10.5 Из другого chat screen

```text
открыт chat A
→ push chat B
→ tap
→ chat B
→ back возвращает назад
```

### 10.6 Delayed tap

```text
notification получено
→ прошло время
→ tap
→ нужный chat открывается
```

Итог пользователя:

```text
уведомление пришло: да
имя и текст правильные: да
нужный чат открылся: да
двойного открытия нет: да
```

## 11. Автоматические проверки

Профильная серия:

```powershell
flutter.bat test `
  test/domain/models/push_deep_link_request_test.dart `
  test/services/push/push_deep_link_resolver_test.dart `
  test/services/push/push_deep_link_coordinator_test.dart
```

```text
23 tests passed
```

Полная серия:

```text
flutter.bat analyze → No issues found
flutter.bat test → 409 tests passed
flutter.bat build apk --release → 55.3 MB
```

Ожидаемый диагностический вывод image tests:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это не падение suite, а проверка повреждённых JPEG.

## 12. Generated files

Flutter меняет:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake
```

Они восстановлены:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

После восстановления `git.exe diff --check` не вывел ошибок.

## 13. Deploy state

Не изменялись:

```text
functions/src/index.ts
firestore.rules
storage.rules
```

Не выполнять Firebase deploy для `v0.7.1`, если до commit не появятся server-side изменения.

## 14. Стоимость

После явного tap:

```text
1 read chat document
+ private chat: до 1 read peer user document
```

Не добавлены polling, background listener, новая Function, дополнительный push или Storage operations.

## 15. Security

`chatId` из push недоверенный.

Client resolver проверяет:

```text
auth
chat existence
memberIds
supported type
private peer
```

Client validation не заменяет Firestore Rules.

Подменённый payload не должен открыть чужой chat. Недоступный chat не создаёт route и не вызывает crash.

## 16. Сохранённые invariants

Не сломаны:

- Auth UID == users/{uid};
- deterministic private chat ID;
- отсутствие пустых private chats;
- atomic first message;
- pagination по 20;
- realtime merge;
- scroll position;
- logical deletion;
- sender-only delete for everyone;
- private clear only for current user;
- roles и permissions;
- last admin protection;
- push sender exclusion;
- image metadata и upload grant;
- rollback;
- avatar paths;
- Firebase free-tier controls.

Добавлены:

- payload validation;
- membership validation до route;
- cold-start queue;
- duplicate route protection;
- centralized private/group destination resolution.

## 17. Git-план завершения

Сначала заменить три документа и проверить:

```powershell
git.exe status --short
git.exe diff --check
git.exe diff --stat
```

Затем commit feature branch:

```powershell
git.exe add .
git.exe commit -m "feat(push): add notification deep links"
git.exe push -u origin feat/v0.7.1-push-deep-link-foundation
```

После проверки branch:

```powershell
git.exe switch main
git.exe pull --ff-only
git.exe merge --no-ff feat/v0.7.1-push-deep-link-foundation `
  -m "merge: release v0.7.1 Push Deep Link Foundation"
git.exe tag -a v0.7.1 -m "v0.7.1 Push Deep Link Foundation"
git.exe push origin main
git.exe push origin v0.7.1
```

Перед командами обязательно посмотреть реальный commit hash и working tree.

## 18. Следующий этап

После выпуска `v0.7.1`:

```text
Group Image Message Foundation
```

Перед началом:

- `main` синхронизирован;
- tag `v0.7.1` существует;
- working tree чистый;
- новая branch от `main`;
- group image scope проектируется отдельно.

Дальше:

```text
File Message Foundation
Voice Message Foundation
Media Retention Cleanup Foundation
App Check / Production Hardening
Release Signing
UI Customization Foundation
```

## 19. Правила работы

- Русский язык.
- PowerShell.
- Явные executable: `flutter.bat`, `dart.bat`, `firebase.cmd`, `npm.cmd`, `git.exe`.
- Маленькие проверяемые шаги.
- После каждого шага ждать результат.
- Большие изменения давать полным файлом.
- Не commit пользовательский сценарий до ручной проверки.
- После этапа: analyze, tests, release APK.
- Generated plugin files восстанавливать один раз в конце.
- Учитывать Firebase free-tier и 40–50 пользователей.
- Не смешивать feature work и toolchain work.
