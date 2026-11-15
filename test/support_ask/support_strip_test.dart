import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kindbeamer/src/support/support_controller.dart';
import 'package:kindbeamer/src/support/support_copy.dart';
import 'package:kindbeamer/src/support/support_engine.dart';
import 'package:kindbeamer/src/support/support_launch.dart';
import 'package:kindbeamer/src/support/support_store.dart';
import 'package:kindbeamer/src/support/support_strip.dart';

class FakeLauncher implements SupportLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

const style = SupportStyle(
  ground: Color(0xFFE9E8E2),
  border: Color(0xFFC2C1BB),
  ink: Color(0xFF16171A),
  mid: Color(0xFF52545A),
  faint: Color(0xFF646669),
  focus: Color(0xFF16171A),
  body: TextStyle(fontSize: 13.5),
  label: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  small: TextStyle(fontSize: 12),
);

SupportController controller(FakeLauncher launcher, {int asks = 0}) =>
    SupportController(
      config: const SupportConfig(appId: 'kindbeamer', ref: 'after-delivery'),
      store: MemorySupportStore(
        SupportState(
          activeDays: 9,
          actions: 9,
          asks: asks,
          lastAskDay: asks > 0 ? '2000-01-01' : null,
        ),
      ),
      launcher: launcher,
    );

/// A real app gets Tab traversal from MaterialApp / WidgetsApp. The bare test host has to provide it:
/// the shortcut must sit ABOVE the focus scope, or a key event never reaches it.
Widget host(
  SupportController c, {
  String? lang,
  bool disableAnimations = true,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    },
    child: Actions(
      actions: {NextFocusIntent: NextFocusAction()},
      child: FocusScope(
        autofocus: true,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: SupportStrip(
                controller: c,
                copy: SupportCopy.forLanguage(lang ?? 'en', 'KindBeamer'),
                style: style,
                brightness: Brightness.light,
                lang: lang,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('invisible until the engine says so, and it reserves no space', (
    tester,
  ) async {
    final c = controller(FakeLauncher());
    await c.ready;
    await tester.pumpWidget(host(c));
    expect(find.byType(SupportStrip), findsOneWidget);
    expect(find.textContaining('free and open source'), findsNothing);
    expect(tester.getSize(find.byType(SupportStrip)).height, 0);
  });

  testWidgets(
    'shows the text without any price and offers Support and Not now',
    (tester) async {
      final c = controller(FakeLauncher());
      await c.ready;
      await tester.pumpWidget(host(c));
      await c.evaluate(momentOfValue: true);
      await tester.pump();
      expect(
        find.text(
          'KindBeamer is free and open source. Support it and get an e-book.',
        ),
        findsOneWidget,
      );
      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('NOT NOW'), findsOneWidget);
      expect(find.text("Don't ask again"), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    },
  );

  testWidgets('Support opens the checkout and the strip goes away', (
    tester,
  ) async {
    final launcher = FakeLauncher();
    final c = controller(launcher);
    await c.ready;
    await tester.pumpWidget(host(c));
    await c.evaluate(momentOfValue: true);
    await tester.pump();
    await tester.tap(find.text('SUPPORT'));
    await tester.pump();
    await tester.pump();
    expect(
      launcher.opened.single.toString(),
      'https://hackyourself.io/support/s/kindbeamer?theme=light&ref=after-delivery',
    );
    expect(find.text('SUPPORT'), findsNothing);
  });

  testWidgets('Not now hides it, keeps it counted', (tester) async {
    final c = controller(FakeLauncher());
    await c.ready;
    await tester.pumpWidget(host(c));
    await c.evaluate(momentOfValue: true);
    await tester.pump();
    await tester.tap(find.text('NOT NOW'));
    await tester.pump();
    expect(find.text('NOT NOW'), findsNothing);
    expect(c.state.asks, 1);
    expect(c.state.supporter, isFalse);
  });

  testWidgets("every ask carries a Don't ask again link that ends the asking", (
    tester,
  ) async {
    final launcher = FakeLauncher();
    final c = controller(launcher);
    await c.ready;
    await tester.pumpWidget(host(c));
    await c.evaluate(momentOfValue: true);
    await tester.pump();
    expect(find.text("Don't ask again"), findsOneWidget);
    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    expect(launcher.opened, isEmpty);
    expect(c.state.declined, isTrue);
    expect(find.text("Don't ask again"), findsNothing);
  });

  testWidgets(
    'Escape inside the strip means Not now; the keyboard can reach and press Support',
    (tester) async {
      final launcher = FakeLauncher();
      final c = controller(launcher);
      await c.ready;
      await tester.pumpWidget(host(c));
      await c.evaluate(momentOfValue: true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(launcher.opened, hasLength(1));

      final c2 = controller(FakeLauncher());
      await c2.ready;
      await tester.pumpWidget(host(c2));
      await c2.evaluate(momentOfValue: true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c2.visible, isFalse);
    },
  );

  testWidgets('Slovak copy and lang parameter', (tester) async {
    final launcher = FakeLauncher();
    final c = controller(launcher);
    await c.ready;
    await tester.pumpWidget(host(c, lang: 'sk'));
    await c.evaluate(momentOfValue: true);
    await tester.pump();
    expect(
      find.text(
        'KindBeamer je zadarmo a open source. Podpor ho a dostaneš e-knihu.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('PODPORIŤ'));
    await tester.pump();
    await tester.pump();
    expect(launcher.opened.single.queryParameters['lang'], 'sk');
  });

  testWidgets(
    'Support and Not now sit side by side, each as wide as its label',
    (tester) async {
      final c = controller(FakeLauncher());
      await c.ready;
      await tester.pumpWidget(host(c));
      await c.evaluate(momentOfValue: true);
      await tester.pump();
      final yes = tester.getRect(find.text('SUPPORT'));
      final later = tester.getRect(find.text('NOT NOW'));
      expect(later.top, closeTo(yes.top, 1), reason: 'same row');
      expect(
        later.left,
        greaterThan(yes.right),
        reason: 'Not now is to the right',
      );
      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('SUPPORT'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.width, lessThan(200), reason: 'not stretched to the strip');
    },
  );

  testWidgets('buttons are at least 44 logical pixels tall', (tester) async {
    final c = controller(FakeLauncher());
    await c.ready;
    await tester.pumpWidget(host(c));
    await c.evaluate(momentOfValue: true);
    await tester.pump();
    final box = tester.getRect(
      find
          .ancestor(of: find.text('SUPPORT'), matching: find.byType(Container))
          .first,
    );
    expect(box.height, greaterThanOrEqualTo(44));
  });
}
