import 'package:ember_streak/ember_streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required int count,
  bool doneToday = true,
  List<bool> week = const [true, true, true, false, false, false, false],
  bool reduceMotion = false,
  ValueChanged<int>? onMilestone,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Center(
        child: EmberStreak(count: count, doneToday: doneToday, week: week, today: 3, onMilestone: onMilestone),
      ),
    ),
  ),
);

String _label(WidgetTester tester) => tester.getSemantics(find.byType(EmberStreak)).label;

void main() {
  group('logic', () {
    test('status follows the count and today', () {
      expect(emberStatusFor(count: 0, doneToday: false), EmberStatus.out);
      expect(emberStatusFor(count: 0, doneToday: true), EmberStatus.out);
      expect(emberStatusFor(count: 5, doneToday: true), EmberStatus.lit);
      expect(emberStatusFor(count: 5, doneToday: false), EmberStatus.atRisk);
    });

    test('milestones are reached only going up', () {
      const m = [3, 7, 14, 30];
      expect(milestoneCrossed(2, 3, m), 3);
      expect(milestoneCrossed(3, 4, m), isNull);
      expect(milestoneCrossed(29, 30, m), 30);
      expect(milestoneCrossed(30, 29, m), isNull);
      expect(milestoneCrossed(30, 30, m), isNull);
      // A jump past several reports the highest.
      expect(milestoneCrossed(0, 20, m), 14);
    });

    test('flame stays inside its box and sits on the bottom', () {
      const size = Size(100, 100);
      for (var t = 0.0; t < 5; t += 0.37) {
        final b = flamePath(size, t, seed: t).getBounds();
        expect(b.left, greaterThanOrEqualTo(-1));
        expect(b.right, lessThanOrEqualTo(101));
        expect(b.top, greaterThanOrEqualTo(-1));
        expect(b.bottom, closeTo(96, 1));
      }
      final low = flamePath(size, 0, intensity: 0.5).getBounds();
      final high = flamePath(size, 0).getBounds();
      expect(low.height, lessThan(high.height));
    });
  });

  group('widget', () {
    testWidgets('reads the count, week and risk', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(count: 12, doneToday: false));
      expect(_label(tester), '12 day streak, 3 of 7 days this week. Log today to keep it');
      expect(find.text('Log today to keep it'), findsOneWidget);

      await tester.pumpWidget(_app(count: 12, week: const [true, true, true, true, false, false, false]));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_label(tester), '12 day streak, 4 of 7 days this week');
      expect(find.text('Log today to keep it'), findsNothing);
      handle.dispose();
    });

    testWidgets('number pops and milestones fire once', (tester) async {
      final hits = <int>[];
      await tester.pumpWidget(_app(count: 29, onMilestone: hits.add));
      await tester.pumpWidget(_app(count: 30, onMilestone: hits.add));
      await tester.pump(const Duration(milliseconds: 150));
      expect(hits, [30]);
      final lifts = tester
          .widgetList<Transform>(find.ancestor(of: find.byType(AnimatedSwitcher), matching: find.byType(Transform)))
          .map((t) => t.transform.getTranslation().y);
      expect(lifts.any((y) => y < 0), isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('30'), findsOneWidget);

      await tester.pumpWidget(_app(count: 31, onMilestone: hits.add));
      await tester.pump(const Duration(seconds: 1));
      expect(hits, [30]);
    });

    testWidgets('going out stops the flame after the smoke', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(count: 8));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(_app(count: 0, week: const []));
      expect(_label(tester), '0 day streak. No active streak');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
      handle.dispose();
    });

    testWidgets('reduced motion never animates', (tester) async {
      final hits = <int>[];
      await tester.pumpWidget(_app(count: 6, reduceMotion: true, doneToday: false, onMilestone: hits.add));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_app(count: 7, reduceMotion: true, onMilestone: hits.add));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(hits, [7]);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('painter draws every state without throwing', (tester) async {
      for (final heat in [0.0, 0.2, 0.7, 1.0, 1.2]) {
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(96, 96),
            painter: EmberPainter(
              time: 1.3,
              heat: heat,
              flare: 0.5,
              sparks: 0.4,
              smoke: 0.5,
              colors: const [Color(0xFFE11D48), Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFFFF7D6)],
              atRisk: heat == 0.7,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
