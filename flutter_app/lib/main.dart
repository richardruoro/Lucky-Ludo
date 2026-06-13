import 'dart:math';
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

  // Match Summary overlay handling.
  String? _shownWinner;
  bool _summaryDismissed = false;

  @override
  void initState() {
    super.initState();
    // Rebuild on every model change and manage the summary overlay flags.
    game.addListener(_onGameChanged);
  }

  void _onGameChanged() {
    if (!mounted) return;
    setState(() {
      if (game.winner != null &&
          game.settleDelta.isNotEmpty &&
          _shownWinner != game.winner) {
        _shownWinner = game.winner;
        _summaryDismissed = false;
      }
      if (game.winner == null) {
        _shownWinner = null;
        _summaryDismissed = false;
      }
    });
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  bool get _showSummary =>
      game.winner != null && game.settleDelta.isNotEmpty && !_summaryDismissed;

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
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(),
                      const SizedBox(height: 6),
                      _statusBanner(),
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
                ),
                if (_showSummary) _matchSummary(),
              ],
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

  // ---- Status banner (updates dynamically with match state) ----
  Widget _statusBanner() {
    final calculating = game.commentary.contains('Calculating');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (calculating)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Flexible(
            child: Text(
              game.commentary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1B6B2E),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
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
                // Tap fallback: tapping the board either selects a piece (when a
                // move is pending) or, if it's your turn to roll, triggers the
                // standard bounce-and-spin roll.
                onTapDown: (d) {
                  if (!game.isHumanTurn) return;
                  if (game.phase == 'waiting-for-move') {
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
                  } else if (game.phase == 'waiting-for-roll') {
                    // Soft "tap" velocity → gentle bounce-spin.
                    game.flingRoll(650 + Random().nextDouble() * 250);
                  }
                },
                child: Container(
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
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Controls (turn + fling dice + Play/Simulate) ----
  Widget _controls() {
    final color = kColors[game.current]!;
    final canFling = game.started &&
        game.isHumanTurn &&
        game.phase == 'waiting-for-roll';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _panel(),
            child: Row(
              children: [
                FlingDice(
                  value: game.dice,
                  rollId: game.rollCount,
                  enabled: canFling,
                  size: 50,
                  onRoll: (velocity, dir) => game.flingRoll(velocity),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        canFling
                            ? 'Fling or tap the dice to roll'
                            : (game.started
                                ? (game.isHumanTurn
                                    ? 'Tap a glowing piece'
                                    : 'Computer thinking…')
                                : 'Press Play or Simulate'),
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
            backgroundColor: color, padding: EdgeInsets.zero),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  // ---- Wallets with +/- stake controls ----
  Widget _wallets() {
    final editable = game.canEditStakes;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Wallets & stakes',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black54)),
              const Spacer(),
              Text('Pool KES ${game.totalPool}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF8A5A1E))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: kPlayers.map((c) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
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
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stepBtn(Icons.remove, editable,
                              () => game.adjustStake(c, -5)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('${game.stakes[c]}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                          _stepBtn(Icons.add, editable,
                              () => game.adjustStake(c, 5)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (!editable)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Stakes lock once a match is running.',
                  style: TextStyle(fontSize: 9, color: Colors.black45)),
            ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF8A5A2E) : const Color(0xFFBDB0A0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  // ---- Match Summary modal overlay ----
  Widget _matchSummary() {
    final w = game.winner!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.62),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFE0A100), size: 44),
              const SizedBox(height: 6),
              const Text('Match Summary',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                '${kNames[w]} won KES ${game.lastPool.toStringAsFixed(0)}!',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: kColors[w]),
              ),
              const SizedBox(height: 12),
              // Per-player ledger breakdown.
              ...game.active.map((c) {
                final d = game.settleDelta[c] ?? 0;
                final gain = d >= 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: kColors[c], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(kNames[c]!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const Spacer(),
                      Text(
                        '${gain ? '+' : '-'}KES ${d.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: gain
                              ? const Color(0xFF1B6B2E)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('(KES ${game.wallets[c]!.toStringAsFixed(0)})',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _summaryDismissed = true),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => game.start(simulate: game.simMode),
                      child: const Text('Play again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          'Fling (swipe) or tap the dice to roll. Roll a 6 to leave the yard. '
          'Land on an opponent (off a star) to send it home. Get all four '
          'pieces home to win the pot.\n\n'
          'Set stakes with the +/- buttons before a match. Play = you take '
          'Red\'s turns (set others to Human in Settings for pass-and-play). '
          'Simulate = all AI, rushed in seconds.',
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
                            onChanged: (v) => setLocal(
                                () => game.roles[c] = v ?? 'computer'),
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

// ============================================================================
//  FLING DICE  — physics-based, swipe-to-roll die.
//
//  Gestures:
//   * Drag (pan): the die follows your finger; on release we read the swipe
//     velocity from the gesture and "throw" the die.
//   * Tap: a soft default velocity → a gentle bounce-and-spin.
//
//  The actual face value is decided by the game model (fair RNG); this widget
//  only VISUALISES the roll. The harder you fling, the more spins, the longer
//  the animation, and the further the die lurches in the swipe direction.
// ============================================================================
class FlingDice extends StatefulWidget {
  final int value; // final face from the model
  final int rollId; // bumps each roll → triggers the animation
  final bool enabled; // only the human, on their roll turn
  final double size;
  final void Function(double velocity, Offset direction) onRoll;

  const FlingDice({
    super.key,
    required this.value,
    required this.rollId,
    required this.enabled,
    required this.size,
    required this.onRoll,
  });

  @override
  State<FlingDice> createState() => _FlingDiceState();
}

class _FlingDiceState extends State<FlingDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();

  double _spins = 0; // total rotations for the current roll
  Offset _throw = Offset.zero; // peak lurch offset (returns to zero each roll)
  double? _pendingVelocity; // captured at gesture, used when rollId changes
  Offset? _pendingDir;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant FlingDice old) {
    super.didUpdateWidget(old);
    // A new roll happened (ours via gesture, or the AI's) — animate it.
    if (widget.rollId != old.rollId) {
      _runAnimation(
        _pendingVelocity ?? 700, // default velocity for AI / programmatic rolls
        _pendingDir ?? _randomDir(),
      );
      _pendingVelocity = null;
      _pendingDir = null;
    }
  }

  Offset _randomDir() => Offset(_rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1);

  // ---- PHYSICS: turn a swipe velocity into spins / duration / throw ----
  void _runAnimation(double velocity, Offset dir) {
    const double maxSpeed = 4000.0; // px/sec treated as "max power"
    final double speed = velocity.clamp(0.0, maxSpeed);
    final double norm = speed / maxSpeed; // 0..1 normalised swipe energy

    // Rotations: a gentle tap ≈ 2 turns, a hard fling ≈ 7 turns.
    final double spins = 2.0 + norm * 5.0;
    // Duration: harder flings roll for longer (0.5s .. 1.4s).
    final int durationMs = (500 + norm * 900).round();
    // Throw distance: how far the die lurches along the swipe (8px .. 30px).
    // Kept small so the die always springs back to its slot — never drifts off.
    final double throwDistance = 8.0 + norm * 22.0;

    // Normalise the direction vector (guard against a zero-length swipe).
    final double len = dir.distance;
    final Offset unit = len == 0 ? _randomDir() : dir / len;

    setState(() {
      _spins = spins;
      _throw = unit * throwDistance;
    });
    _ctrl.duration = Duration(milliseconds: durationMs);
    _ctrl.forward(from: 0);
  }

  void _fling(double velocity, Offset dir) {
    if (!widget.enabled) return;
    // Remember the swipe so didUpdateWidget can replay it once the model rolls.
    _pendingVelocity = velocity;
    _pendingDir = dir;
    widget.onRoll(velocity, dir);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double t = Curves.easeOut.transform(_ctrl.value);
    final double rotation = _spins * 2 * pi * t; // eases out to a stop
    // Out-and-back lurch: 0 → small peak at mid-roll → back to 0. There is NO
    // persistent offset, so the die can never wander away from its slot.
    final double lurch = sin(_ctrl.value * pi);
    final Offset offset = _throw * lurch;

    // While spinning, flick through faces; settle on the real value at the end.
    final int face = (_ctrl.isAnimating && _ctrl.value < 0.82)
        ? ((_ctrl.value * 40).floor() % 6) + 1
        : widget.value;

    return GestureDetector(
      // Tap = soft bounce-spin. Swipe = velocity-driven fling (read on pan end).
      onTap: () => _fling(700 + _rng.nextDouble() * 250, _randomDir()),
      onPanStart: (_) {},
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond; // px/sec swipe velocity
        // |v| = sqrt(vx^2 + vy^2)  (handled by Offset.distance)
        _fling(v.distance, Offset(v.dx, v.dy));
      },
      child: Container(
        // Highlight ring so it's obvious the die is the thing you roll.
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.enabled
              ? const Color(0x333C9A3C)
              : Colors.transparent,
          border: Border.all(
            color: widget.enabled
                ? const Color(0xFF3C9A3C)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: (widget.enabled || _ctrl.isAnimating) ? 1.0 : 0.85,
              child: DiceFace(value: face, size: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

/// A green die face with white pips.
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
