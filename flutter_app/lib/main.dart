import 'dart:math';
import 'package:flutter/material.dart';
import 'ludo_game.dart';
import 'board_painter.dart';

void main() {
  // Show a readable red box (with the error text) instead of a blank/grey area
  // if any widget throws while building in a release build — makes bugs visible.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFFB3261E),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              'UI error:\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
  runApp(const LudoApp());
}

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
                // Fixed, non-scrolling layout so flinging the dice never scrolls
                // the page and everything always fits the screen.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(),
                      const SizedBox(height: 6),
                      _statusBanner(),
                      const SizedBox(height: 8),
                      // Board takes all remaining vertical space (and shrinks to
                      // fit on short screens).
                      Expanded(child: _boardArea()),
                      const SizedBox(height: 8),
                      _controls(),
                      const SizedBox(height: 8),
                      _wallets(),
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

  // Pixel centres of every on-board piece (so the dice can settle clear of them).
  List<Offset> _piecePixels(double side) {
    final u = side / 15.0;
    final pts = <Offset>[];
    for (final c in game.active) {
      final steps = game.tokens[c]!;
      for (var i = 0; i < 4; i++) {
        pts.add(tokenDrawPos(c, i, steps[i], u));
      }
    }
    return pts;
  }

  // ---- Board ----
  Widget _boardArea() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            // Wooden bezel frame around the board, matching the app icon.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC0894C), Color(0xFF7A4E26)],
              ),
              border: Border.all(color: const Color(0xFF4A2E16), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(13),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = c.maxWidth;
                  final u = side / 15.0;
                  final canFling = game.started &&
                      game.isHumanTurn &&
                      game.phase == 'waiting-for-roll';
                  return Stack(
                    children: [
                      GestureDetector(
                        // Tap fallback: select a piece (when a move is pending)
                        // or, if it's your turn to roll, do a bounce-spin roll.
                        onTapDown: (d) {
                          if (!game.isHumanTurn) return;
                          if (game.phase == 'waiting-for-move') {
                            int? hit;
                            double best = u * 0.9;
                            for (final idx in game.eligible) {
                              final step = game.tokens[game.current]![idx];
                              final pos =
                                  tokenDrawPos(game.current, idx, step, u);
                              final dist = (pos - d.localPosition).distance;
                              if (dist < best) {
                                best = dist;
                                hit = idx;
                              }
                            }
                            if (hit != null) game.move(hit);
                          } else if (game.phase == 'waiting-for-roll') {
                            game.flingRoll(650 + Random().nextDouble() * 250);
                          }
                        },
                        child: CustomPaint(
                          size: Size(side, side),
                          painter: BoardPainter(game),
                        ),
                      ),
                      // The dice lives ON the board and is flung across it in
                      // the swipe direction — it stays on the board and settles
                      // clear of any piece you might need to play.
                      Positioned.fill(
                        child: BoardDice(
                          side: side,
                          value: game.dice,
                          rollId: game.rollCount,
                          enabled: canFling,
                          color: game.started
                              ? kColors[game.current]!
                              : const Color(0xFF4E9D33),
                          avoid: _piecePixels(side),
                          onRoll: (velocity, dir) => game.flingRoll(velocity),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Controls (compact Play/Simulate row; status is in the banner) ----
  Widget _controls() {
    return Row(
      children: [
        Expanded(
          child: _actionButton('Play', const Color(0xFF2E8B57),
              () => game.start(simulate: false)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton('Simulate', const Color(0xFF3F51B5),
              () => game.start(simulate: true)),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 42,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: color, padding: EdgeInsets.zero),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kNames[c]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kColors[c])),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            'KES ${game.wallets[c]!.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
//  BOARD DICE — a die that is FLUNG ACROSS THE BOARD.
//
//  Swipe it and it travels in the swipe direction, a distance proportional to
//  the swipe speed, spinning as it goes. It is clamped to the board so it never
//  leaves it, and it settles on a spot that is clear of every playing piece so
//  it never hides a piece you might need to move. A tap does a short random
//  hop. The fair face value is decided by the game model; this only animates it.
// ============================================================================
class BoardDice extends StatefulWidget {
  final double side; // board pixel size
  final int value; // final face from the model
  final int rollId; // bumps each roll → triggers the animation
  final bool enabled; // only the human, on their roll turn
  final Color color; // the current player's colour
  final List<Offset> avoid; // piece centres (px) the die must not land on
  final void Function(double velocity, Offset direction) onRoll;

  const BoardDice({
    super.key,
    required this.side,
    required this.value,
    required this.rollId,
    required this.enabled,
    required this.color,
    required this.avoid,
    required this.onRoll,
  });

  @override
  State<BoardDice> createState() => _BoardDiceState();
}

class _BoardDiceState extends State<BoardDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();

  // Resting / travel positions in board FRACTIONS (0..1), so they survive
  // board resizes. Start near the bottom-centre.
  Offset _fromFrac = const Offset(0.5, 0.80);
  Offset _toFrac = const Offset(0.5, 0.80);
  double _spins = 0;
  double? _pendingVelocity;
  Offset? _pendingDir;

  double get _size => widget.side * 0.14;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant BoardDice old) {
    super.didUpdateWidget(old);
    if (widget.rollId != old.rollId) {
      _animate(_pendingVelocity ?? 900, _pendingDir ?? _randomDir());
      _pendingVelocity = null;
      _pendingDir = null;
    }
  }

  Offset _randomDir() =>
      Offset(_rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1);

  Offset _currentFrac() =>
      Offset.lerp(_fromFrac, _toFrac, Curves.easeOut.transform(_ctrl.value))!;

  // ---- PHYSICS: swipe velocity → travel distance / spins / duration ----
  void _animate(double velocity, Offset dir) {
    const double maxSpeed = 4000.0;
    final double speed = velocity.clamp(0.0, maxSpeed);
    final double norm = speed / maxSpeed; // 0..1 swipe energy

    // Travel across the board: a flick ≈ 16% of the board, a hard fling ≈ 70%.
    final double travel = 0.16 + norm * 0.55;
    final double spins = 2.0 + norm * 5.0;
    final int durationMs = (450 + norm * 750).round();

    final double len = dir.distance;
    final Offset unit = len == 0 ? _randomDir() : dir / len;

    final Offset start = _currentFrac();
    final Offset desired = start + unit * travel;
    final Offset target = _settleClearOfPieces(desired);

    setState(() {
      _fromFrac = start;
      _toFrac = target;
      _spins = spins;
    });
    _ctrl.duration = Duration(milliseconds: durationMs);
    _ctrl.forward(from: 0);
  }

  // Clamp to the board and nudge to the nearest spot clear of every piece.
  Offset _settleClearOfPieces(Offset desired) {
    final side = widget.side;
    final double m = (_size / 2 + 4) / side; // keep fully on the board
    final double tokenR = 0.62 * (side / 15.0);
    final double minDist = _size / 2 + tokenR + 4;

    Offset clamp(Offset f) => Offset(
          f.dx.clamp(m, 1 - m),
          f.dy.clamp(m, 1 - m),
        );
    bool ok(Offset f) {
      final c = Offset(f.dx * side, f.dy * side);
      for (final a in widget.avoid) {
        if ((a - c).distance < minDist) return false;
      }
      return true;
    }

    final base = clamp(desired);
    if (ok(base)) return base;
    // Spiral outward from the desired spot to find the closest free position.
    for (double rad = 0.06; rad <= 0.7; rad += 0.05) {
      for (int a = 0; a < 12; a++) {
        final ang = a * pi / 6;
        final cand =
            clamp(Offset(base.dx + cos(ang) * rad, base.dy + sin(ang) * rad));
        if (ok(cand)) return cand;
      }
    }
    return base;
  }

  void _fling(double velocity, Offset dir) {
    if (!widget.enabled) return;
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
    final size = _size;
    final half = size / 2;
    final frac = _currentFrac();
    final centre = Offset(frac.dx * widget.side, frac.dy * widget.side);
    final rotation = _spins * 2 * pi * Curves.easeOut.transform(_ctrl.value);
    final int face = (_ctrl.isAnimating && _ctrl.value < 0.82)
        ? ((_ctrl.value * 40).floor() % 6) + 1
        : widget.value;

    return Stack(
      children: [
        Positioned(
          left: centre.dx - half,
          top: centre.dy - half,
          width: size,
          height: size,
          // Only grab touches when it's your turn to roll, so taps on a piece
          // can still get through when it isn't.
          child: IgnorePointer(
            ignoring: !widget.enabled,
            child: GestureDetector(
              onTap: () => _fling(750 + _rng.nextDouble() * 250, _randomDir()),
              onPanStart: (_) {},
              onPanEnd: (d) {
                final v = d.velocity.pixelsPerSecond; // |v| = sqrt(vx²+vy²)
                _fling(v.distance, Offset(v.dx, v.dy));
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.enabled
                      ? widget.color.withOpacity(0.22)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.enabled ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Transform.rotate(
                  angle: rotation,
                  child: DiceFace(value: face, size: size, color: widget.color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A die face coloured to match the current player, with adaptive pips.
class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  final Color color;
  const DiceFace({
    super.key,
    required this.value,
    required this.size,
    this.color = const Color(0xFF4E9D33),
  });

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.28)!;
    final dark = Color.lerp(color, Colors.black, 0.16)!;
    // White pips on dark dice, dark pips on light dice (e.g. yellow).
    final pip = color.computeLuminance() > 0.55
        ? const Color(0xFF2A1C0C)
        : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CustomPaint(painter: _PipPainter(value, pip)),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int value;
  final Color pipColor;
  _PipPainter(this.value, this.pipColor);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = pipColor;
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
  bool shouldRepaint(covariant _PipPainter old) =>
      old.value != value || old.pipColor != pipColor;
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
