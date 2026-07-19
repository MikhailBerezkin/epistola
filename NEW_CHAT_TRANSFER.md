# Epistola — Transfer to New Chat

Скопируй сообщение ниже в новый чат и приложи `PROJECT_CONTEXT.md`.

---

Продолжаем разработку проекта **Epistola** — корпоративного мессенджера на Flutter и Firebase.

Сначала внимательно прочитай приложенный `PROJECT_CONTEXT.md`. Он является главным handoff-документом. При расхождении приоритет: исходный код репозитория → PROJECT_CONTEXT.md → ARCHITECTURE.md → README.md.

## Репозиторий и точка старта

```text
Repository: MikhailBerezkin/epistola
Branch: fix/v0.6.2.1-security-foundation
Last functional commit: 0e42c4e feat: clear private chat for current user
Base main commit: 4fa8693 feat(media): create media storage foundation
Last stable tag: v0.6.2-media-foundation
Firebase project: epistola-434b7
Android package: com.epistola.app
```

Текущая ветка опережает `main` на 6 функциональных коммитов. Рабочее дерево после последнего коммита было чистым.

## Что только что завершено

1. Текст сообщений нормализуется, пустые сообщения запрещены, максимум 4096 символов.
2. Новый private chat не создаётся при простом выборе пользователя.
3. Если чата нет, открывается `PrivateChatDraftScreen`.
4. Chat document и первое message создаются одной транзакцией только при первом сообщении.
5. Firestore Rules требуют корректный `firstMessageId` и проверяют транзакцию через `getAfter()`.
6. Реализовано «Удалить личный чат у себя» через `clearedAtByUser.{uid}` без физического удаления сообщений.
7. После очистки старая история скрыта только для этого пользователя.
8. Новое сообщение возвращает чат в список.
9. Всё проверено на физическом Android-телефоне и чистой Firebase-базе.
10. Группы, роли, добавление участников, moderator, передача прав и защита последнего администратора работают.

Проверки:

```text
flutter analyze → No issues found
flutter test → 14 tests passed
flutter build apk --debug → успешно
Firestore Rules deploy → успешно
```

## Важное решение о роли owner

`owner` уже существует как заготовка роли с максимальным приоритетом. Сейчас основной поток групп использует `admin`, но owner нельзя удалять, переименовывать или упрощать. Будущее расширение должно сохранить текущую защиту последнего администратора.

## Следующий рекомендуемый этап

Сначала проанализируй текущий код ветки, особенно:

```text
lib/services/chat/chat_messages_service.dart
lib/services/chat/chat_private_service.dart
lib/services/chat_service.dart
firestore.rules
```

Главный следующий технический долг: обычный `sendMessage()` сейчас выполняет две записи — message document, затем `lastMessage/lastMessageAt`. Нужно спроектировать безопасную атомарную запись через batch или transaction и соответствующие Firestore Rules, не ломая:

- группы и permissions;
- mute/ban;
- private chat clear/restore;
- первое атомарное сообщение;
- нормализацию текста;
- unread/lastRead.

Перед внесением изменений дай краткий план, объясни, какие файлы меняем и почему. Работай маленькими проверяемыми шагами. После каждого шага давай команды `dart format`, `flutter analyze`, `flutter test`, `git diff --check`, но не предлагай commit до ручной проверки.

После атомарной отправки нужно обновить README.md и ARCHITECTURE.md, решить вопрос merge/tag `v0.6.2.1 Security Foundation`, и только затем переходить к чистой `v0.6.3 Avatar Foundation`.

Avatar Foundation должна использовать:

```text
user_avatars/{uid}/v{version}/thumb.jpg
user_avatars/{uid}/v{version}/full.jpg
avatarProvider
avatarThumbUrl
avatarFullUrl
avatarThumbStoragePath
avatarFullStoragePath
avatarVersion
avatarUpdatedAt
```

В private chat аватар всегда определяется через UID другого участника. Общий `avatarUrl` в chat document запрещён.

---