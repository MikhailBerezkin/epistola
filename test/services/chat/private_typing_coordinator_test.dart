import 'dart:async';

import 'package:epistola/services/chat/private_typing_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateTypingCoordinator', () {
    test('rejects a negative start delay', () {
      expect(
        () => PrivateTypingCoordinator(
          startTyping: () async {},
          stopTyping: () async {},
          startDelay: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive inactivity delay', () {
      expect(
        () => PrivateTypingCoordinator(
          startTyping: () async {},
          stopTyping: () async {},
          inactivityDelay: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('publishes typing only after the debounce delay', (
      tester,
    ) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 100),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('П');

      await tester.pump(const Duration(milliseconds: 99));

      expect(calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(calls, <String>['start']);

      coordinator.dispose();
    });

    testWidgets(
      'does not publish typing when text is cleared before debounce',
      (tester) async {
        final calls = <String>[];

        final coordinator = PrivateTypingCoordinator(
          startTyping: () async {
            calls.add('start');
          },
          stopTyping: () async {
            calls.add('stop');
          },
          startDelay: const Duration(milliseconds: 100),
          inactivityDelay: const Duration(seconds: 1),
        );

        coordinator.handleTextChanged('П');
        coordinator.handleTextChanged('');

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(calls, isEmpty);

        coordinator.dispose();
      },
    );

    testWidgets('multiple letters produce only one typing start', (
      tester,
    ) async {
      var startCalls = 0;

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          startCalls += 1;
        },
        stopTyping: () async {},
        startDelay: const Duration(milliseconds: 100),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('П');
      coordinator.handleTextChanged('Пр');
      coordinator.handleTextChanged('При');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(startCalls, 1);

      coordinator.handleTextChanged('Прив');
      coordinator.handleTextChanged('Приве');

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(startCalls, 1);

      coordinator.dispose();
    });

    testWidgets('stops typing after inactivity', (tester) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(milliseconds: 300),
      );

      coordinator.handleTextChanged('Сообщение');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(calls, <String>['start']);

      await tester.pump(const Duration(milliseconds: 249));

      expect(calls, <String>['start']);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(calls, <String>['start', 'stop']);

      coordinator.dispose();
    });

    testWidgets('continued input restarts inactivity timeout', (tester) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(milliseconds: 300),
      );

      coordinator.handleTextChanged('П');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 150));

      coordinator.handleTextChanged('Пр');

      await tester.pump(const Duration(milliseconds: 299));
      await tester.pump();

      expect(calls, <String>['start']);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(calls, <String>['start', 'stop']);

      coordinator.dispose();
    });

    testWidgets('clearing published text stops typing immediately', (
      tester,
    ) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('Текст');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      coordinator.handleTextChanged('');

      await tester.pump();

      expect(calls, <String>['start', 'stop']);

      coordinator.dispose();
    });

    testWidgets('stopNow cancels pending start without remote writes', (
      tester,
    ) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 100),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('Текст');

      await coordinator.stopNow();

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(calls, isEmpty);

      coordinator.dispose();
    });

    testWidgets('stopNow removes an already published state', (tester) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('Текст');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      await coordinator.stopNow();

      expect(calls, <String>['start', 'stop']);

      coordinator.dispose();
    });

    testWidgets('serializes stop behind an active start operation', (
      tester,
    ) async {
      final calls = <String>[];
      final startCompleter = Completer<void>();

      final coordinator = PrivateTypingCoordinator(
        startTyping: () {
          calls.add('start');
          return startCompleter.future;
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('Текст');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(calls, <String>['start']);

      coordinator.handleTextChanged('');

      await tester.pump();

      expect(calls, <String>['start']);

      startCompleter.complete();

      await tester.pump();
      await tester.pump();

      expect(calls, <String>['start', 'stop']);

      coordinator.dispose();
    });

    testWidgets('dispose cancels pending timers', (tester) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 100),
        inactivityDelay: const Duration(milliseconds: 300),
      );

      coordinator.handleTextChanged('Текст');
      coordinator.dispose();

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(calls, isEmpty);
    });

    testWidgets('reports an action error without breaking later operations', (
      tester,
    ) async {
      final errors = <Object>[];
      var startCalls = 0;

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          startCalls += 1;

          if (startCalls == 1) {
            throw StateError('First start failed');
          }
        },
        stopTyping: () async {},
        onError: (error, stackTrace) {
          errors.add(error);
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
      );

      coordinator.handleTextChanged('П');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(startCalls, 1);

      coordinator.handleTextChanged('Пр');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(startCalls, 2);
      expect(errors, hasLength(1));

      coordinator.dispose();
    });

    testWidgets('refreshes published typing state with heartbeat', (
      tester,
    ) async {
      var startCalls = 0;

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          startCalls += 1;
        },
        stopTyping: () async {},
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
        heartbeatDelay: const Duration(milliseconds: 100),
      );

      coordinator.handleTextChanged('Текст');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(startCalls, 1);

      await tester.pump(const Duration(milliseconds: 99));

      expect(startCalls, 1);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(startCalls, 2);

      coordinator.dispose();
    });

    testWidgets('stops heartbeat after text is cleared', (tester) async {
      final calls = <String>[];

      final coordinator = PrivateTypingCoordinator(
        startTyping: () async {
          calls.add('start');
        },
        stopTyping: () async {
          calls.add('stop');
        },
        startDelay: const Duration(milliseconds: 50),
        inactivityDelay: const Duration(seconds: 1),
        heartbeatDelay: const Duration(milliseconds: 100),
      );

      coordinator.handleTextChanged('Текст');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(calls, <String>['start', 'start']);

      coordinator.handleTextChanged('');

      await tester.pump();

      expect(calls, <String>['start', 'start', 'stop']);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(calls, <String>['start', 'start', 'stop']);

      coordinator.dispose();
    });
  });
}
