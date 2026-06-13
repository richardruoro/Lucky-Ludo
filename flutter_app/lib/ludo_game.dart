import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Turn / colour order.
const List<String> kPlayers = ['red', 'green', 'yellow', 'blue'];

const Map<String, Color> kColors = {
  'red': Color(0xFFCB3A2A),
  'green': Color(0xFF4E9D33),
  'yellow': Color(0xFFE9C320),
  'blue': Color(0xFF2E72B6),
};

const Map<String, String> kNames = {
  'red': 'Red',
  'green': 'Green',
  'yellow': 'Yellow',
  'blue': 'Blue',
};

/// 52-cell shared track as [row, col] grid coordinates on a 15x15 board.
const List<List<int>> kTrack = [
  [6, 0], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
  [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
  [0, 7],
  [0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
  [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14],
  [7, 14],
  [8, 14], [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
  [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
  [14, 7],
  [14, 6], [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
  [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0],
  [7, 0],
];

const Map<String, int> kStartIndices = {
  'red': 1, 'green': 14, 'yellow': 27, 'blue': 40,
};

const Set<int> kSafeIndices = {1, 8, 14, 21, 27, 34, 40, 47};

const Map<String, List<List<int>>> kYards = {
  'red': [[2, 2], [2, 3], [3, 2], [3, 3]],
  'green': [[2, 11], [2, 12], [3, 11], [3, 12]],
  'yellow': [[11, 11], [11, 12], [12, 11], [12, 12]],
  'blue': [[11, 2], [11, 3], [12, 2], [12, 3]],
};

const Map<String, List<List<int>>> kHomePaths = {
  'red': [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
  'green': [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
  'yellow': [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
  'blue': [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
};

const Map<String, List<int>> kHomeEnd = {
  'red': [7, 6], 'green': [6, 7], 'yellow': [7, 8], 'blue': [8, 7],
};

/// Maps a token's step to a [row, col] board cell.
/// step 0 = yard, 1..51 = track, 52..56 = home column, 57 = home goal.
List<int> tokenCell(String color, int tokenIndex, int step) {
  if (step == 0) return kYards[color]![tokenIndex];
  if (step == 57) return kHomeEnd[color]!;
  if (step >= 52) return kHomePaths[color]![step - 52];
  final startIdx = kStartIndices[color]!;
  final trackIdx = (startIdx + (step - 1)) % 52;
  return kTrack[trackIdx];
}

/// Offline Kenyan-sheng commentary buckets.
class _Sheng {
  static final intro = [
    'Mambo vipi wadau! Stakes ziko juu — leo ni pesa otas!',
    'Karibuni kwa meza ya wenye nguvu. May the best mjanja win!',
    'Tumeanza! Dau limewekwa, sasa ni dice na akili.',
  ];
  static final capture = [
    'Aiii! Umemrudisha base, amebaki anashangaa!',
    'Kichinjio! That capture just shifted the whole pesa equation.',
    'Token imerudi nyumbani bila kupiga hodi. Pure ujanja!',
  ];
  static final nomove = [
    'Dice imekataa kabisa — hakuna move.',
    'Zero moves! Hiyo dice imekuangusha leo.',
    'Hakuna pa kwenda. Round ingine itakuwa yako.',
  ];
  static final trash = [
    'Wewe na hizo token za base? Toa kafala icheze!',
    'Stake yangu iko juu coz najua nitachukua zote!',
    'Cheque ya leo inakuja kwangu. Andaeni M-Pesa!',
    'Nitawamaliza polepole kama bundles za usiku.',
    'Six ingine tena? Dice inanijua!',
  ];
}

/// Core game model. A [ChangeNotifier] so the UI rebuilds on every change.
class LudoGame extends ChangeNotifier {
  final _rng = Random();

  // Configuration.
  Map<String, String> roles = {
    'red': 'human', 'green': 'computer', 'yellow': 'computer', 'blue': 'computer',
  };
  Map<String, int> stakes = {'red': 10, 'green': 30, 'yellow': 50, 'blue': 100};
  Map<String, double> wallets = {
    'red': 1000, 'green': 1000, 'yellow': 1000, 'blue': 1000,
  };

  // Runtime state.
  List<String> active = List.of(kPlayers);
  Map<String, List<int>> tokens = {
    for (final c in kPlayers) c: [0, 0, 0, 0],
  };
  int turnIndex = 0;
  int dice = 1;
  int rollCount = 0; // bumps on every roll so the dice widget can animate.
  String phase = 'idle'; // idle | waiting-for-roll | waiting-for-move | animating | game-over
  int _sixes = 0;
  List<int> eligible = [];
  String? winner;
  bool fullSim = false; // every seat AI (Simulate)
  bool simMode = false; // turbo, no sound
  bool muted = false;
  String commentary = 'Karibuni! Set your stakes, then Play or Simulate.';
  final List<String> log = [];

  // Match-result ledger (filled in at settlement).
  double lastPool = 0;
  Map<String, double> settleDelta = {};

  Timer? _aiTimer;
  Timer? _moveTimer;

  String get current => kPlayers[turnIndex];
  bool get isHumanTurn => roles[current] == 'human' && !fullSim;
  bool get started => phase != 'idle';

  /// Total pot = sum of every active player's committed stake.
  int get totalPool => active.fold(0, (sum, c) => sum + stakes[c]!);

  /// Stakes can be edited before a match or after a result — never mid-game.
  bool get canEditStakes => phase == 'idle' || phase == 'game-over';

  int _spd(int ms) => simMode ? 6 : ms;

  void _log(String m) {
    log.add(m);
    if (log.length > 40) log.removeAt(0);
  }

  void _say(List<String> bucket) {
    commentary = bucket[_rng.nextInt(bucket.length)];
  }

  void toggleMute() {
    muted = !muted;
    notifyListeners();
  }

  void trashTalk() {
    _say(_Sheng.trash);
    notifyListeners();
  }

  /// + / - stake controls from the wallet cards.
  void adjustStake(String color, int delta) {
    if (!canEditStakes) return;
    stakes[color] = (stakes[color]! + delta).clamp(1, 100000);
    notifyListeners();
  }

  void _cancelTimers() {
    _aiTimer?.cancel();
    _moveTimer?.cancel();
  }

  /// Start a match. [simulate] = all-AI turbo run.
  void start({required bool simulate}) {
    _cancelTimers();
    simMode = simulate;
    fullSim = simulate;

    active = [];
    for (final c in kPlayers) {
      if (simulate && roles[c] != 'disabled') roles[c] = 'computer';
      if (roles[c] != 'disabled') active.add(c);
    }
    if (active.length < 2) {
      commentary = 'Select at least 2 players in Settings.';
      notifyListeners();
      return;
    }

    tokens = {for (final c in kPlayers) c: [0, 0, 0, 0]};
    turnIndex = kPlayers.indexOf(active.first);
    dice = 1;
    _sixes = 0;
    eligible = [];
    winner = null;
    settleDelta = {};
    lastPool = 0;
    phase = 'waiting-for-roll';
    log.clear();
    _log('Match initialised · pool KES $totalPool');
    _say(_Sheng.intro);
    notifyListeners();
    _maybeAutoplay();
  }

  // ---- ANIMATION / FEEDBACK ----

  /// Audio + haptic feedback whose intensity scales with the fling velocity.
  /// SystemSound has no pitch control without an audio plugin, so we APPROXIMATE
  /// a louder/faster rattle by firing more click "ticks" the harder the fling.
  void _rollFeedback(double velocity) {
    if (simMode) return;
    if (!muted) {
      // 3 ticks for a soft tap, up to ~12 for a hard fling, spaced 40ms apart.
      final ticks = (3 + (velocity / 300).clamp(0, 9)).round();
      for (var i = 0; i < ticks; i++) {
        Timer(Duration(milliseconds: i * 40), () {
          if (!muted) SystemSound.play(SystemSoundType.click);
        });
      }
    }
    // Vibration strength tiers based on the swipe speed (px/sec).
    if (velocity > 1800) {
      HapticFeedback.heavyImpact();
    } else if (velocity > 800) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Called by the dice widget after a fling; [velocity] is the swipe speed.
  void flingRoll(double velocity) {
    if (phase == 'waiting-for-roll' && isHumanTurn) rollDice(velocity: velocity);
  }

  void rollDice({double velocity = 0}) {
    if (phase != 'waiting-for-roll') return;
    dice = _rng.nextInt(6) + 1;
    rollCount++;
    _rollFeedback(velocity);

    if (dice == 6) {
      _sixes++;
      if (_sixes == 3) {
        commentary = '${kNames[current]} threw three sixes — turn forfeited!';
        _log('Three sixes — turn forfeited');
        _sixes = 0;
        _nextTurn();
        notifyListeners();
        return;
      }
      commentary = '${kNames[current]} flung a 6! Roll again.';
    } else {
      _sixes = 0;
      commentary = '${kNames[current]} flung a $dice.';
    }
    _log('${kNames[current]} rolled $dice');
    _evaluate();
    notifyListeners();
  }

  void _evaluate() {
    final color = current;
    final moves = <int>[];
    final steps = tokens[color]!;
    for (var i = 0; i < 4; i++) {
      final s = steps[i];
      if (s == 0) {
        if (dice == 6) moves.add(i);
      } else if (s + dice <= 57) {
        moves.add(i);
      }
    }
    eligible = moves;

    if (eligible.isEmpty) {
      _log('No moves for ${kNames[color]}');
      _say(_Sheng.nomove);
      _aiTimer = Timer(Duration(milliseconds: _spd(1100)), () {
        if (dice == 6) {
          phase = 'waiting-for-roll';
          notifyListeners();
          _maybeAutoplay();
        } else {
          _nextTurn();
          notifyListeners();
        }
      });
      return;
    }

    phase = 'waiting-for-move';
    if (eligible.length == 1) {
      final only = eligible.first;
      _aiTimer = Timer(Duration(milliseconds: _spd(700)), () => move(only));
    } else if (!isHumanTurn) {
      _aiTimer = Timer(Duration(milliseconds: _spd(800)), _aiChoose);
    } else {
      commentary = '${kNames[color]}: tap a glowing piece to move.';
    }
  }

  void _aiChoose() {
    if (phase != 'waiting-for-move') return;
    final color = current;
    var best = eligible.first;
    var bestScore = -1e9;
    for (final idx in eligible) {
      final cur = tokens[color]![idx];
      final next = cur == 0 ? 1 : cur + dice;
      var score = 0.0;
      if (next == 57) score += 1500;

      final nc = tokenCell(color, idx, next);
      if (next > 0 && next < 52) {
        final gi = (kStartIndices[color]! + (next - 1)) % 52;
        if (!kSafeIndices.contains(gi)) {
          for (final opp in kPlayers) {
            if (opp == color) continue;
            final os = tokens[opp]!;
            for (var oi = 0; oi < 4; oi++) {
              if (os[oi] > 0 && os[oi] < 52) {
                final oc = tokenCell(opp, oi, os[oi]);
                if (oc[0] == nc[0] && oc[1] == nc[1]) score += 2000;
              }
            }
          }
        }
      }
      if (cur == 0 && dice == 6) score += 800;
      score += next * 1.5 + _rng.nextDouble() * 5;
      if (score > bestScore) {
        bestScore = score;
        best = idx;
      }
    }
    move(best);
  }

  /// Move a token. Human taps drive this for multi-choice turns.
  void move(int idx) {
    if (phase != 'waiting-for-move') return;
    if (!eligible.contains(idx)) return;
    final color = current;
    final start = tokens[color]![idx];
    final end = start == 0 ? 1 : start + dice;

    phase = 'animating';
    eligible = [];
    notifyListeners();

    if (simMode) {
      tokens[color]![idx] = end;
      notifyListeners();
      _conclude(idx, end);
      return;
    }

    var step = start;
    void hop() {
      if (step < end) {
        step = step == 0 ? 1 : step + 1;
        tokens[color]![idx] = step;
        if (!muted) SystemSound.play(SystemSoundType.click);
        notifyListeners();
        _moveTimer = Timer(const Duration(milliseconds: 140), hop);
      } else {
        _conclude(idx, end);
      }
    }

    hop();
  }

  void _conclude(int idx, int finalStep) {
    final color = current;
    var extra = false;

    if (finalStep == 57) {
      _log('${kNames[color]} piece ${idx + 1} reached home');
      if (tokens[color]!.every((s) => s == 57)) {
        _win(color);
        return;
      }
    }

    if (finalStep > 0 && finalStep < 52) {
      final fc = tokenCell(color, idx, finalStep);
      final gi = (kStartIndices[color]! + (finalStep - 1)) % 52;
      if (!kSafeIndices.contains(gi)) {
        for (final opp in kPlayers) {
          if (opp == color) continue;
          final os = tokens[opp]!;
          for (var oi = 0; oi < 4; oi++) {
            if (os[oi] > 0 && os[oi] < 57) {
              final oc = tokenCell(opp, oi, os[oi]);
              if (oc[0] == fc[0] && oc[1] == fc[1]) {
                os[oi] = 0;
                extra = true;
                if (!muted && !simMode) HapticFeedback.mediumImpact();
                _log('${kNames[color]} captured ${kNames[opp]}!');
                _say(_Sheng.capture);
              }
            }
          }
        }
      }
    }

    if (dice == 6 || extra) {
      phase = 'waiting-for-roll';
      notifyListeners();
      _maybeAutoplay();
    } else {
      _nextTurn();
      notifyListeners();
    }
  }

  void _nextTurn() {
    var i = active.indexOf(current);
    i = (i + 1) % active.length;
    turnIndex = kPlayers.indexOf(active[i]);
    _sixes = 0;
    phase = 'waiting-for-roll';
    _maybeAutoplay();
  }

  void _maybeAutoplay() {
    if (phase == 'game-over') return;
    final isComputer = roles[current] == 'computer' || fullSim;
    if (isComputer && phase == 'waiting-for-roll') {
      _aiTimer = Timer(Duration(milliseconds: _spd(900)), rollDice);
    }
  }

  void _win(String color) {
    winner = color;
    phase = 'game-over';
    settleDelta = {}; // cleared until the ledger runs
    commentary = 'Calculating payouts…';
    _log('${kNames[color]} reached home first');
    notifyListeners();
    // Brief delay so the "Calculating payouts…" status is visible first.
    Timer(Duration(milliseconds: simMode ? 250 : 750), () {
      _settleLedger(color);
      commentary = '${kNames[color]} won KES ${lastPool.toStringAsFixed(0)}!';
      notifyListeners();
    });
  }

  // ============================================================
  // WALLET LEDGER  (plain-English explanation)
  //
  //  1. Total Pool  = the sum of every active player's committed stake.
  //  2. The WINNER collects the whole pool. Because the winner also put in
  //     their own stake, their NET wallet change is (pool - their stake).
  //  3. Every LOSER permanently loses exactly their committed stake.
  //
  //  This is zero-sum: the cash the losers put in is exactly what the winner
  //  takes out, so the four wallets together never gain or lose money.
  // ============================================================
  void _settleLedger(String winnerColor) {
    final pool = totalPool.toDouble();
    lastPool = pool;
    settleDelta = {};
    for (final c in active) {
      if (c == winnerColor) {
        final net = pool - stakes[c]!; // collected pool minus own committed stake
        wallets[c] = wallets[c]! + net;
        settleDelta[c] = net;
        _log('${kNames[c]} +KES ${net.toStringAsFixed(0)} (won pot)');
      } else {
        final loss = stakes[c]!.toDouble(); // permanent deduction of the stake
        wallets[c] = wallets[c]! - loss;
        settleDelta[c] = -loss;
        _log('${kNames[c]} -KES ${loss.toStringAsFixed(0)} (lost stake)');
      }
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
