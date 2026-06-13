import 'package:flutter/material.dart';
import 'ludo_game.dart';
import 'board_painter.dart';

void main() => runApp(const LudoApp());

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lucky Ludo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5A2B)),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final LudoGame game = LudoGame();

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC9A36B), Color(0xFFB68A50)],
          ),
        ),
        child: CustomPaint(
          painter: _PlankPainter(),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: game,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _toolbar(),
                        const SizedBox(height: 6),
                        _commentary(),
                        const SizedBox(height: 8),
                        _boardArea(),
                        const SizedBox(height: 10),
                        _controls(),
                        const SizedBox(height: 10),
                        _wallets(),
                        const SizedBox(height: 10),
                        _logPanel(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Toolbar ----
  Widget _toolbar() {
    return Row(
      children: [
        _woodButton(Icons.settings, _openSettings),
        const SizedBox(width: 8),
        _woodButton(
          game.muted ? Icons.volume_off : Icons.volume_up,
          () => game.toggleMute(),
        ),
        const Spacer(),
        const Text(
          'LUCKY LUDO',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF3C2410),
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        _woodButton(Icons.bolt, () => game.trashTalk()),
        const SizedBox(width: 8),
        _woodButton(Icons.help_outline, _openRules),
      ],
    );
  }

  Widget _woodButton(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFB07A41), Color(0xFF7A4E26)],
          ),
          border: Border.all(color: const Color(0xFF4A2E16), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: const Color(0xFFF4E3C4), size: 22),
      ),
    );
  }

  // ---- Commentary ----
  Widget _commentary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: Text(
        game.commentary,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF1B6B2E),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  // ---- Board ----
  Widget _boardArea() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final side = c.maxWidth;
              final u = side / 15.0;
              return GestureDetector(
                onTapDown: (d) {
                  if (!game.isHumanTurn || game.phase != 'waiting-for-move') {
                    return;
                  }
                  int? hit;
                  double best = u * 0.9;
                  for (final idx in game.eligible) {
                    final step = game.tokens[game.current]![idx];
                    final pos = tokenDrawPos(game.current, idx, step, u);
                    final dist = (pos - d.localPosition).distance;
                    if (dist < best) {
                      best = dist;
                      hit = idx;
                    }
                  }
                  if (hit != null) game.move(hit);
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 14,
                            offset: Offset(0, 8),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomPaint(
                        size: Size(side, side),
                        painter: BoardPainter(game),
                      ),
                    ),
                    if (game.winner != null) _winnerOverlay(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _winnerOverlay() {
    final w = game.winner!;
    final payout = game.payoutFor(w);
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFE0A100), size: 40),
              const SizedBox(height: 6),
              Text('${kNames[w]} wins!',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'Take-home KES ${payout['takeHome']!.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Color(0xFF1B6B2E), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => game.start(simulate: game.simMode),
                child: const Text('Play again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Controls ----
  Widget _controls() {
    final color = kColors[game.current]!;
    return Row(
      children: [
        // Turn + dice
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _panel(),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => game.handleDiceTap(),
                  child: DiceFace(value: game.dice, size: 46),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.started ? '${kNames[game.current]} to move' : 'Ready',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        game.started
                            ? (game.isHumanTurn
                                ? (game.phase == 'waiting-for-roll'
                                    ? 'Tap dice to roll'
                                    : 'Tap a glowing piece')
                                : 'Computer thinking…')
                            : 'Press Play or Simulate',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _actionButton('Play', const Color(0xFF2E8B57),
                () => game.start(simulate: false)),
            const SizedBox(height: 6),
            _actionButton('Simulate', const Color(0xFF3F51B5),
                () => game.start(simulate: true)),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 104,
      height: 38,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  // ---- Wallets ----
  Widget _wallets() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet balances',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: kPlayers.map((c) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6ECD9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kColors[c]!, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(kNames[c]!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kColors[c])),
                      Text('KES ${game.wallets[c]!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      Text('stake ${game.stakes[c]}',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.black45)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---- Log ----
  Widget _logPanel() {
    final lines = game.log.reversed.take(5).toList();
    return Container(
      width: double.infinity,
      height: 78,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xCC1C1206),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((l) => Text(l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFE9D9B6),
                    fontSize: 10,
                    fontFamily: 'monospace')))
            .toList(),
      ),
    );
  }

  BoxDecoration _panel() => BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22000000)),
      );

  // ---- Dialogs ----
  void _openRules() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to play'),
        content: const Text(
          'Roll a 6 to leave the yard. Land on an opponent (off a star) to '
          'send it home. Get all four pieces home to win the pot.\n\n'
          'Play = you take Red\'s turns (set others to Human in Settings for '
          'pass-and-play). Simulate = all AI, rushed in seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Match settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: kPlayers.map((c) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: kColors[c], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 58, child: Text(kNames[c]!)),
                          DropdownButton<String>(
                            value: game.roles[c],
                            items: const [
                              DropdownMenuItem(
                                  value: 'human', child: Text('Human')),
                              DropdownMenuItem(
                                  value: 'computer', child: Text('AI')),
                              DropdownMenuItem(
                                  value: 'disabled', child: Text('Off')),
                            ],
                            onChanged: (v) =>
                                setLocal(() => game.roles[c] = v ?? 'computer'),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 56,
                            child: TextFormField(
                              initialValue: '${game.stakes[c]}',
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Stake'),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n > 0) game.stakes[c] = n;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A simple green die face with pips.
class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  const DiceFace({super.key, required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5FBF5F), Color(0xFF3C9A3C)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CustomPaint(painter: _PipPainter(value)),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int value;
  _PipPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    final r = size.width * 0.09;
    final a = size.width * 0.26, b = size.width * 0.5, c = size.width * 0.74;
    void dot(double x, double y) => canvas.drawCircle(Offset(x, y), r, p);
    final v = value.clamp(1, 6);
    if (v.isOdd) dot(b, b);
    if (v >= 2) {
      dot(a, a);
      dot(c, c);
    }
    if (v >= 4) {
      dot(a, c);
      dot(c, a);
    }
    if (v == 6) {
      dot(a, b);
      dot(c, b);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) => old.value != value;
}

/// Faint wood-plank seams behind the whole screen.
class _PlankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final seam = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1.4;
    const plank = 46.0;
    for (double x = plank; x < size.width; x += plank) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seam);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
