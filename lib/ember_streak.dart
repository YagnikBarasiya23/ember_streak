/// Ember — a streak counter with a living flame. MIT © 2026 Yagnik Barasiya.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How the streak stands today.
enum EmberStatus {
  /// Logged today: full flame.
  lit,

  /// Streak alive but today not logged yet: a low, pulsing flame.
  atRisk,

  /// No streak: the flame is out.
  out,
}

/// Works out the status from the count and whether today is done.
EmberStatus emberStatusFor({required int count, required bool doneToday}) {
  if (count <= 0) return EmberStatus.out;
  return doneToday ? EmberStatus.lit : EmberStatus.atRisk;
}

/// The milestone reached when a streak goes from [previous] to [next], if any.
int? milestoneCrossed(int previous, int next, List<int> milestones) {
  if (next <= previous) return null;
  int? reached;
  for (final m in milestones) {
    if (previous < m && next >= m) reached = m;
  }
  return reached;
}

/// The outline of a flame in a [size] box at [time] seconds.
///
/// [intensity] (0–1.3) scales its height; [seed] gives each layer its own
/// rhythm. The base sits on the bottom edge and the tip sways with the time.
Path flamePath(Size size, double time, {double intensity = 1, double seed = 0, double widthFactor = 1}) {
  // Smaller flames are also narrower, so a low flame still reads as a flame.
  final w = size.width * 0.44 * widthFactor * (0.55 + 0.45 * intensity.clamp(0.0, 1.0));
  final h = size.height * 0.8 * intensity.clamp(0.0, 1.3);
  final cx = size.width / 2;
  final base = size.height * 0.96;
  double wobble(double speed, double phase, double amount) => math.sin(time * speed + seed * 7 + phase) * amount;

  final sway = wobble(3.1, 0, w * 0.18) + wobble(7.3, 1.3, w * 0.06);
  final tip = Offset(cx + sway, base - h - wobble(5.2, 2.1, h * 0.04).abs());
  final belly = base - h * 0.34;
  final bulge = w * (1 + wobble(4.4, 0.7, 0.05));

  return Path()
    ..moveTo(cx, base)
    // Left side: round belly, then a narrowing neck up to the tip.
    ..cubicTo(
      cx - bulge * 1.02,
      base,
      cx - bulge * 1.02,
      belly + wobble(6.1, 3, h * 0.03),
      cx - bulge * 0.72,
      belly - h * 0.12,
    )
    ..cubicTo(
      cx - bulge * 0.42,
      belly - h * 0.28 + wobble(8.3, 1, h * 0.03),
      tip.dx - w * 0.12,
      tip.dy + h * 0.24,
      tip.dx,
      tip.dy,
    )
    // Right side back down.
    ..cubicTo(
      tip.dx + w * 0.16,
      tip.dy + h * 0.28,
      cx + bulge * 0.48,
      belly - h * 0.3 + wobble(7.1, 2.4, h * 0.03),
      cx + bulge * 0.74,
      belly - h * 0.1,
    )
    ..cubicTo(cx + bulge * 1.02, belly + wobble(5.3, 0.4, h * 0.03), cx + bulge * 1.02, base, cx, base)
    ..close();
}

/// A streak counter: flame, number, and the days of the current week.
///
/// ```dart
/// EmberStreak(
///   count: 12,
///   week: const [true, true, true, true, false, false, false],
///   today: 4,
///   doneToday: false,
/// )
/// ```
class EmberStreak extends StatefulWidget {
  const EmberStreak({
    super.key,
    required this.count,
    this.week = const [],
    this.today,
    this.doneToday = true,
    this.flameSize = 96,
    this.milestones = const [3, 7, 14, 30, 50, 100, 365],
    this.dayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    this.unit = 'day streak',
    this.numberStyle = const TextStyle(color: Color(0xFFF4F4F5), fontSize: 44, fontWeight: FontWeight.w800, height: 1),
    this.unitStyle = const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, fontWeight: FontWeight.w500),
    this.flameColors = const [Color(0xFFE11D48), Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFFFF7D6)],
    this.dayColor = const Color(0xFFF97316),
    this.emptyDayColor = const Color(0x1FFFFFFF),
    this.atRiskHint = 'Log today to keep it',
    this.onMilestone,
  });

  /// Current streak length.
  final int count;

  /// Which days of the week are done, in [dayLabels] order.
  final List<bool> week;

  /// Index of today in [week]; gets a ring.
  final int? today;

  /// Whether today counts yet. With a count above zero, `false` means at risk.
  final bool doneToday;

  final double flameSize;

  /// Streak lengths that set off sparks when reached.
  final List<int> milestones;

  final List<String> dayLabels;

  /// Shown under the number.
  final String unit;
  final TextStyle numberStyle;
  final TextStyle unitStyle;

  /// Outer to inner flame colours.
  final List<Color> flameColors;

  final Color dayColor;
  final Color emptyDayColor;

  /// Shown when the streak is at risk; `null` hides it.
  final String? atRiskHint;

  /// Called when [count] reaches one of [milestones].
  final ValueChanged<int>? onMilestone;

  @override
  State<EmberStreak> createState() => _EmberStreakState();
}

class _EmberStreakState extends State<EmberStreak> with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _time = ValueNotifier(0);
  // Flame size: 1 lit, ~.7 at risk, 0 out. Springs between them.
  late final AnimationController _heat = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _flare = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _sparks = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _smoke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  EmberStatus get _status => emberStatusFor(count: widget.count, doneToday: widget.doneToday);
  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static double _heatFor(EmberStatus s) => switch (s) {
    EmberStatus.lit => 1,
    EmberStatus.atRisk => 0.7,
    EmberStatus.out => 0,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _heat.value = _heatFor(_status);
    _syncTicker();
  }

  @override
  void didUpdateWidget(EmberStreak old) {
    super.didUpdateWidget(old);
    final before = emberStatusFor(count: old.count, doneToday: old.doneToday);
    final after = _status;
    final reduced = _reduced;

    if (reduced) {
      _heat.value = _heatFor(after);
    } else if (before != after) {
      _heat.animateTo(_heatFor(after), curve: after == EmberStatus.out ? Curves.easeInCubic : Curves.easeOutBack);
      if (after == EmberStatus.out) _smoke.forward(from: 0);
    }

    if (widget.count > old.count) {
      if (!reduced) {
        _flare.forward(from: 0);
        _pop.forward(from: 0);
      }
      final milestone = milestoneCrossed(old.count, widget.count, widget.milestones);
      if (milestone != null) {
        if (!reduced) _sparks.forward(from: 0);
        widget.onMilestone?.call(milestone);
      }
    }
    _syncTicker();
  }

  /// The flame only animates while there is one, and never with reduce motion.
  void _syncTicker() {
    final burning = _status != EmberStatus.out || _heat.isAnimating || _smoke.isAnimating;
    if (burning && !_reduced) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / 1e6;
    if (_status == EmberStatus.out && !_heat.isAnimating && !_smoke.isAnimating) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _heat.dispose();
    _flare.dispose();
    _sparks.dispose();
    _smoke.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final doneDays = widget.week.where((d) => d).length;
    final semantics = StringBuffer('${widget.count} ${widget.unit}');
    if (widget.week.isNotEmpty) semantics.write(', $doneDays of ${widget.week.length} days this week');
    if (status == EmberStatus.atRisk && widget.atRiskHint != null) semantics.write('. ${widget.atRiskHint}');
    if (status == EmberStatus.out) semantics.write('. No active streak');

    return Semantics(
      container: true,
      liveRegion: true,
      label: semantics.toString(),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: widget.flameSize,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_time, _heat, _flare, _sparks, _smoke]),
                    builder: (context, _) => CustomPaint(
                      painter: EmberPainter(
                        time: _time.value,
                        heat: _heat.value,
                        flare:
                            Curves.easeOut.transform(1 - (_flare.value - 0.2).abs().clamp(0.0, 0.8) / 0.8) *
                            (_flare.isAnimating ? 1 : 0),
                        sparks: _sparks.isAnimating ? _sparks.value : 0,
                        smoke: _smoke.isAnimating ? _smoke.value : 0,
                        colors: widget.flameColors,
                        atRisk: status == EmberStatus.atRisk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _pop,
                      builder: (context, child) {
                        // The number pops up and settles when the streak grows.
                        final t = _pop.value;
                        final lift = _pop.isAnimating ? math.sin(t * math.pi) : 0.0;
                        return Transform.translate(
                          offset: Offset(0, -6 * lift),
                          child: Transform.scale(scale: 1 + 0.14 * lift, alignment: Alignment.bottomLeft, child: child),
                        );
                      },
                      child: AnimatedSwitcher(
                        duration: _reduced ? Duration.zero : const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '${widget.count}',
                          key: ValueKey(widget.count),
                          style: widget.numberStyle.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: status == EmberStatus.out ? widget.unitStyle.color : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.unit, style: widget.unitStyle),
                    if (status == EmberStatus.atRisk && widget.atRiskHint != null) ...[
                      const SizedBox(height: 4),
                      _Pulse(
                        enabled: !_reduced,
                        child: Text(
                          widget.atRiskHint!,
                          style: widget.unitStyle.copyWith(color: widget.dayColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (widget.week.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.week.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _Day(
                        label: i < widget.dayLabels.length ? widget.dayLabels[i] : '',
                        done: widget.week[i],
                        today: widget.today == i,
                        color: widget.dayColor,
                        emptyColor: widget.emptyDayColor,
                        labelStyle: widget.unitStyle,
                        reduced: _reduced,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.done,
    required this.today,
    required this.color,
    required this.emptyColor,
    required this.labelStyle,
    required this.reduced,
  });

  final String label;
  final bool done;
  final bool today;
  final Color color;
  final Color emptyColor;
  final TextStyle labelStyle;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A finished day fills with a small overshoot.
        TweenAnimationBuilder<double>(
          tween: Tween(end: done ? 1 : 0),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emptyColor,
              border: today ? Border.all(color: color, width: 2) : null,
            ),
            child: Center(
              child: Transform.scale(
                scale: v.clamp(0.0, 1.2),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)],
                  ),
                  child: const Center(
                    child: CustomPaint(size: Size(12, 12), painter: _TickPainter()),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: labelStyle.copyWith(fontSize: 12, color: today ? color : null)),
      ],
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      Path()
        ..moveTo(s.width * .1, s.height * .55)
        ..lineTo(s.width * .4, s.height * .82)
        ..lineTo(s.width * .92, s.height * .2),
      Paint()
        ..color = const Color(0xFF1C1917)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => false;
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.enabled
      ? FadeTransition(opacity: Tween(begin: 1.0, end: 0.45).animate(_c), child: widget.child)
      : widget.child;
}

/// Paints the layered flame, a glow, sparks and smoke.
class EmberPainter extends CustomPainter {
  EmberPainter({
    required this.time,
    required this.heat,
    required this.flare,
    required this.sparks,
    required this.smoke,
    required this.colors,
    required this.atRisk,
  });

  final double time;
  final double heat;
  final double flare;
  final double sparks;
  final double smoke;
  final List<Color> colors;
  final bool atRisk;

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = heat * (1 + flare * 0.25) * (atRisk ? 0.94 + 0.06 * math.sin(time * 4) : 1);
    final rect = Offset.zero & size;

    if (intensity > 0.02) {
      // Warm glow under the flame.
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.72),
        size.width * 0.42 * intensity,
        Paint()
          ..color = colors[1].withValues(alpha: 0.28 * math.min(1, intensity))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.16),
      );
      // Three nested flames, each with its own flicker.
      final layers = [
        (0.0, 1.0, 1.0, [colors[0], colors[1]]),
        (1.7, 0.74, 0.7, [colors[1], colors[2]]),
        (3.1, 0.46, 0.42, [colors[2], colors[3]]),
      ];
      for (final (seed, height, width, pair) in layers) {
        final path = flamePath(size, time, intensity: intensity * height, seed: seed, widthFactor: width);
        final bounds = path.getBounds();
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [pair[0].withValues(alpha: 0.85), pair[1]],
            ).createShader(bounds.isEmpty ? rect : bounds),
        );
      }
    }

    // Sparks fly up and fade after a milestone.
    if (sparks > 0) {
      final rng = math.Random(11);
      for (var i = 0; i < 16; i++) {
        final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.8;
        final speed = 0.5 + rng.nextDouble() * 0.7;
        final d = size.height * speed * Curves.easeOut.transform(sparks);
        final p = Offset(size.width / 2, size.height * 0.55) + Offset(math.cos(angle), math.sin(angle)) * d;
        canvas.drawCircle(
          p,
          1.4 + rng.nextDouble() * 2 * (1 - sparks),
          Paint()..color = colors[2 + i % 2].withValues(alpha: (1 - sparks).clamp(0, 1)),
        );
      }
    }

    // Smoke curls up when the flame goes out.
    if (smoke > 0) {
      final fade = (1 - smoke).clamp(0.0, 1.0) * math.min(1, smoke * 6);
      for (var i = 0; i < 2; i++) {
        final x = size.width / 2 + (i == 0 ? -4 : 5);
        final top = size.height * (0.8 - 0.7 * smoke) - i * 10;
        final path = Path()..moveTo(x, size.height * 0.86);
        for (var y = size.height * 0.86; y > top; y -= 4) {
          path.lineTo(x + math.sin(y / 9 + time * 3 + i) * 5 * (1 - (y - top) / size.height), y);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.5 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // A dark wick and a faint outline of the flame show once it is out.
    if (heat < 0.3) {
      canvas.drawPath(
        flamePath(size, 0, intensity: 0.85, seed: 0),
        Paint()
          ..color = const Color(0xFF71717A).withValues(alpha: 0.26 * (1 - heat / 0.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size.width / 48)
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.9),
            width: size.width * 0.05,
            height: size.height * 0.1,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF52525B).withValues(alpha: 1 - heat / 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(EmberPainter old) =>
      old.time != time ||
      old.heat != heat ||
      old.flare != flare ||
      old.sparks != sparks ||
      old.smoke != smoke ||
      old.atRisk != atRisk ||
      old.colors != colors;
}
