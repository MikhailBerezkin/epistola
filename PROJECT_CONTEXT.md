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
v0.7.2 — Chat Date Separator Foundation
```

Стабильный `main`:

```text
release merge commit: 7d8357a
tag: v0.7.2
```

Текущая ветка:

```text
main
```

Последний завершённый этап:

```text
v0.7.2 — Chat Date Separator Foundation
```

Состояние этапа:

```text
форматирование календарных дат реализовано
→ постоянные разделители дней реализованы
→ плавающая дата при прокрутке реализована
→ пагинация через несколько дней проверена
→ удаление старых сообщений исправлено
→ профильные тесты пройдены
→ полный analyze пройден
→ полный test suite пройден
→ release APK собран
→ feature commits отправлены
→ release merge 7d8357a создан в main
→ release tag v0.7.2
```

Feature commits:

```text
2d34cfc feat(chat): add date separators and scroll indicator
bffea4f fix(chat): hide paginated messages immediately
```

Release merge:

```text
7d8357a merge: release v0.7.2 Chat Date Separator Foundation
```

Итоговые проверки:

```text
flutter.bat analyze
→ No issues found

flutter.bat test
→ 423 tests passed

flutter.bat build apk --release
→ успешно, 55.3 MB

git.exe diff --check
→ без вывода
```

Release APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Cloud Functions, Firestore Rules и Storage Rules на текущем этапе не менялись. Firebase deploy для `v0.7.2` не требуется.

Generated plugin files восстановлены и не входят в release commits.

## 2. Цель этапа v0.7.2

Добавить календарную структуру истории сообщений:

```text
первое видимое сообщение дня
→ постоянный разделитель

пользователь прокручивает историю
→ плавающая дата верхнего видимого сообщения
```

Требования:

- `Сегодня`;
- `Вчера`;
- дата без года в текущем году;
- дата с годом для другого года;
- разделитель только один раз на день;
- плавающая дата меняется во время непрерывного scroll;
- индикатор остаётся видимым во время inertia;
- после остановки исчезает с задержкой;
- pagination не создаёт duplicate separators;
- удаление сообщения перестраивает разделитель;
- никаких новых Firebase operations.

## 3. ChatDateFormatter

Файл:

```text
lib/helpers/chat_date_formatter.dart
```

Ответственность:

- `isSameDay`;
- `startsNewDay`;
- `Сегодня`;
- `Вчера`;
- русские названия месяцев;
- скрытие текущего года;
- добавление другого года;
- локальный календарный день.

Тесты:

```text
test/helpers/chat_date_formatter_test.dart
10 tests
```

Проверены:

- сегодня;
- вчера;
- граница месяца;
- граница года;
- текущий год;
- другой год;
- сравнение времени внутри одного дня;
- первое сообщение;
- переход между днями;
- отсутствие разделителя внутри одного дня.

## 4. Постоянный разделитель

Файл:

```text
lib/widgets/chat/chat_date_separator.dart
```

`ChatDateSeparator`:

- центрирован;
- компактный;
- использует `surfaceContainerHighest`;
- поддерживает тему;
- имеет скругление;
- имеет лёгкую тень;
- не содержит Firebase logic.

`MessageItem` принимает nullable:

```text
dateLabel
```

Разделитель находится внутри существующей анимации сообщения. Если сообщение скрывается, его date separator схлопывается вместе с ним.

## 5. Расчёт разделителей

`MessagesList` строит:

```text
Map<messageId, dateLabel>
```

Алгоритм:

```text
sorted messages
→ skip deletedForEveryone
→ skip hiddenForCurrentUser
→ skip locally hidden
→ compare current visible date with previous visible date
→ assign label to first visible message of day
```

Граница Firestore page не является календарной границей. После загрузки старой страницы labels пересчитываются по всей локально загруженной истории.

## 6. Плавающая дата

Файлы:

```text
lib/widgets/chat/chat_scroll_date_indicator.dart
lib/widgets/messages_list.dart
```

Используются:

```text
ScrollController
NotificationListener<ScrollNotification>
GlobalKey viewport
GlobalKey per message item
post-frame date calculation
```

Плавающий label берётся из первого видимого message item, пересекающего верхнюю probe line.

Это поддерживает элементы переменной высоты:

- короткий текст;
- длинный текст;
- изображение;
- анимация удаления.

Lifecycle:

```text
drag start
→ show

scroll update / overscroll / inertia
→ keep visible
→ update date

scroll end
→ wait 1200 ms
→ fade out
```

Смена даты:

```text
AnimatedSwitcher
FadeTransition
SlideTransition
```

Появление и исчезновение:

```text
AnimatedOpacity
```

## 7. Координация overlays

`MessagesList` использует Stack:

```text
message ListView
loading older indicator
floating date indicator
```

Если floating date видима, loading older indicator смещается ниже и не перекрывает её.

## 8. Пагинация

Сохранены invariants:

```text
page size: 20
descending Firestore query
chronological local order
merge by document ID
one older request at a time
scroll position preservation
near-bottom-only autoscroll
```

Проверено вручную:

- загрузка старых страниц;
- несколько календарных дней;
- отсутствие duplicate labels;
- отсутствие скачка позиции;
- продолжение работы плавающей даты.

## 9. Исправление удаления старых сообщений

Проблема:

```text
realtime listener
→ только последние 20 сообщений

older pages
→ загружены one-shot query
→ не получают дальнейшие realtime changes
```

Симптом:

```text
delete peer old message for self
→ Firestore update successful
→ old local snapshot remained visible
→ message disappeared only after reopening chat
```

Исправление:

```text
Set<String> _locallyHiddenMessageIds
```

После успешного `deleteMessageForCurrentUser`:

```text
messageId added locally
→ MessagePresentation.hiddenForCurrentUser
→ MessageItem collapse animation
→ date label rebuild
```

То же локальное схлопывание применяется после успешного `deleteMessageForEveryone`.

Дополнительные Firestore reads не добавлены.

Bugfix commit:

```text
bffea4f fix(chat): hide paginated messages immediately
```

Ручная проверка:

```text
peer old message disappears immediately
own message delete for self works
own message delete for everyone works
date separator moves to next visible message
single-message day separator disappears
message stays hidden after reopening
```

## 10. Widget tests

Файл:

```text
test/widgets/chat/chat_date_widgets_test.dart
```

Проверено:

- `ChatDateSeparator` показывает label;
- floating indicator видим при включённой visibility;
- floating indicator имеет opacity 0 после hide;
- label меняется через `AnimatedSwitcher`.

Итог:

```text
4 widget tests
```

## 11. Автоматические проверки

Профильная серия:

```powershell
flutter.bat test `
  test/helpers/chat_date_formatter_test.dart `
  test/widgets/chat/chat_date_widgets_test.dart
```

```text
14 tests passed
```

Полная серия:

```text
flutter.bat analyze → No issues found
flutter.bat test → 423 tests passed
flutter.bat build apk --release → 55.3 MB
```

Ожидаемый диагностический вывод image tests:

```text
Corrupt JPEG data: 2 extraneous bytes before marker 0xd9
Shell: JPEG datastream contains no image
```

Это не падение suite, а тест повреждённых JPEG.

## 12. Generated files

Flutter меняет:

```text
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugins.cmake
```

После последней Flutter-серии они восстановлены:

```powershell
git.exe restore -- `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugins.cmake
```

После восстановления:

```text
git.exe status --short
→ без вывода

git.exe diff --check
→ без вывода
```

## 13. Deploy state

Не изменялись:

```text
functions/src/index.ts
firestore.rules
storage.rules
```

Не выполнять Firebase deploy для `v0.7.2`.

## 14. Стоимость v0.7.2

Chat date labels вычисляются локально поверх уже загруженных документов.

Добавлено:

```text
0 Firestore reads
0 Firestore writes
0 Storage operations
0 Cloud Function invocations
```

Локальное optimistic hide также не добавляет backend operation; Firestore transaction удаления уже существовала.

## 15. Security

Date separators и floating date являются presentation-only.

Локально скрытый `messageId`:

- не даёт новых прав;
- не меняет серверные данные;
- не заменяет Firestore Rules;
- очищается при смене conversation;
- после повторного открытия authoritative visibility загружается из Firestore.

Сохранены:

```text
auth
membership
role permissions
sender-only delete for everyone
private clear isolation
canonical image paths
upload grants
push payload validation
```

## 16. Сохранённые invariants

Не сломаны:

- Auth UID == users/{uid};
- deterministic private chat ID;
- отсутствие пустых private chats;
- atomic first message;
- pagination по 20;
- realtime merge;
- scroll position;
- near-bottom-only autoscroll;
- logical deletion;
- sender-only delete for everyone;
- private clear only for current user;
- roles и permissions;
- last-admin protection;
- push sender exclusion;
- image metadata и upload grant;
- rollback;
- avatar paths;
- Firebase free-tier controls.

Добавлены:

- calendar day formatting;
- permanent day separators;
- floating scroll date;
- date transition animation;
- pagination-safe date rebuild;
- immediate local hide for paginated messages.

## 17. Git-результат v0.7.2

```text
feature commits:
2d34cfc feat(chat): add date separators and scroll indicator
bffea4f fix(chat): hide paginated messages immediately

release merge:
7d8357a merge: release v0.7.2 Chat Date Separator Foundation

release tag:
v0.7.2
```

Функциональная ветка отправлена в GitHub:

```text
origin/feat/v0.7.2-chat-date-separators
```

Release merge выполнен в `main`.

После публикации `main` и тега рабочее дерево должно оставаться чистым.

## 18. Следующий этап — v0.7.3 Messaging Feedback Foundation

Этап состоит из трёх подфаз.

### 18.1 Private Read Receipt Foundation

Только private chats:

```text
✓  сообщение сохранено
✓✓ собеседник прочитал
```

Для групп галочки не добавляются.

Требования:

- text и image messages;
- только исходящие сообщения;
- экономное обновление позиции чтения;
- debounce;
- отсутствие write на каждое сообщение;
- Rules разрешают менять только собственный read state.

Оценка:

```text
2–4 часа
```

### 18.2 Group Message Reactions

Только group chats:

```text
👍 like
👎 dislike
```

На один UID хранится только одно значение:

```text
none + like → like
like + like → none
like + dislike → dislike
none + dislike → dislike
dislike + dislike → none
dislike + like → like
```

Требования:

- text и image messages;
- один user не может иметь like и dislike одновременно;
- локальное optimistic update;
- Rules позволяют менять только собственный UID;
- без push-уведомлений.

Оценка:

```text
3–5 часов
```

### 18.3 Private Typing Indicator Foundation

Только private chats через Firebase Realtime Database.

```text
first input
→ typing state set

idle / send / clear / leave
→ typing state removed

disconnect
→ onDisconnect remove
```

Без feature flag. Функция включается сразу.

Группы Realtime Database typing не используют.

Оценка:

```text
3–5 часов
```

### 18.4 Финальные проверки v0.7.3

```text
Rules tests
Flutter analyze
targeted tests
full test suite
release APK
phone + emulator
README
ARCHITECTURE
PROJECT_CONTEXT
merge
tag
push
```

Оценка всего `v0.7.3`:

```text
9–16 часов
```

## 19. Дальнейший roadmap

После `v0.7.3`:

```text
Group Image Message Foundation
File Message Foundation
Voice Message Foundation
Media Retention Cleanup Foundation
App Check / Production Hardening
Release Signing
UI Customization Foundation
```

## 20. Правила работы

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
- В каждом рабочем сообщении указывать текущий этап и ориентировочное оставшееся время.
