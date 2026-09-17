import 'package:ember_streak/ember_streak.dart';
import 'package:flutter/material.dart';

void main() => runApp(const EmberDemo());

const _bg = Color(0xFF050505);
const _panel = Color(0xFF0E0E10);
const _line = Color(0x1AFFFFFF);
const _muted = Color(0xFFA1A1AA);
const _accent = Color(0xFFF97316);

class EmberDemo extends StatelessWidget {
  const EmberDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ember — streak counter for Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _accent, surface: _panel),
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  // Today is Thursday (index 3); Mon–Wed are done.
  static const _today = 3;
  int _count = 12;
  bool _doneToday = false;
  List<bool> _week = const [true, true, true, false, false, false, false];
  String _log = 'Today isn’t logged yet — the flame is low.';

  void _logToday() {
    if (_doneToday) return;
    setState(() {
      _doneToday = true;
      _count++;
      _week = [for (var i = 0; i < 7; i++) _week[i] || i == _today];
      _log = 'Logged. Streak is $_count.';
    });
  }

  void _breakStreak() => setState(() {
    _count = 0;
    _doneToday = false;
    _week = const [true, false, false, false, false, false, false];
    _log = 'Missed a day. The flame went out.';
  });

  void _nearMilestone() => setState(() {
    _count = 29;
    _doneToday = false;
    _week = const [true, true, true, false, false, false, false];
    _log = 'At 29. Log today to reach 30.';
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMBER · FLUTTER',
                    style: TextStyle(
                      color: Color(0xFF71717A),
                      letterSpacing: 3.5,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A streak you\ncan feel burning.',
                    style: TextStyle(fontSize: 44, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.8),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'The flame flickers while the streak is alive, burns low when today is still open, flares when you log, throws sparks at milestones and smokes out when it breaks.',
                    style: TextStyle(color: _muted, fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  _Card(
                    children: [
                      Center(
                        child: EmberStreak(
                          count: _count,
                          week: _week,
                          today: _today,
                          doneToday: _doneToday,
                          onMilestone: (m) => setState(() => _log = '🎉 $m-day milestone!'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: _doneToday ? null : _logToday,
                              child: Text(_doneToday ? 'Logged today' : 'Log today'),
                            ),
                            OutlinedButton(
                              onPressed: _count == 0 ? null : _breakStreak,
                              child: const Text('Break streak'),
                            ),
                            OutlinedButton(onPressed: _nearMilestone, child: const Text('Jump to 29')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _Card(
                    children: [
                      Text('Other habits', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 18),
                      Wrap(
                        spacing: 28,
                        runSpacing: 20,
                        children: [
                          EmberStreak(count: 64, unit: 'days of water', flameSize: 56, numberStyle: _small),
                          EmberStreak(
                            count: 5,
                            unit: 'days of reading',
                            doneToday: false,
                            flameSize: 56,
                            numberStyle: _small,
                            atRiskHint: null,
                            flameColors: [Color(0xFF7C3AED), Color(0xFF3B82F6), Color(0xFF67E8F9), Color(0xFFECFEFF)],
                          ),
                          EmberStreak(count: 0, unit: 'days of running', flameSize: 56, numberStyle: _small),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _line),
                    ),
                    child: Text(
                      _log,
                      style: const TextStyle(fontFamily: 'monospace', color: _muted, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MIT © 2026 Yagnik Barasiya · github.com/YagnikBarasiya23/ember_streak',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _small = TextStyle(color: Color(0xFFF4F4F5), fontSize: 28, fontWeight: FontWeight.w800, height: 1);

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
