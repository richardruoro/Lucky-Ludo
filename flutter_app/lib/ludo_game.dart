import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Turn / colour order (matches the original web build).
const List<String> kPlayers = ['red', 'green', 'yellow', 'blue'];

/// Vivid crayon-ish palette to echo the wooden-board screenshot.
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

/// Offline Kenyan-sheng commentary buckets (ported from the web build).
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
    'Dice imekataa kabisa — hakuna move. Unangoja tu.',
    'Zero moves! Hiyo dice imekuangusha leo.',
    'Hakuna pa kwenda. Panga mawazo, round ingine itakuwa yako.',
  ];
  static final victory = [
    'Game imeisha! Mshindi anabeba mzigo, KRA wanabeba ushuru!',
    'Tumemaliza! Winner ametoka na takehome poa. Heshima!',
    'Finito! Pesa imehama mfuko. Mshindi aende kupiga nyama choma.',
  ];
  static final generic = [
    'Bodi inawaka moto! Kila move ni pesa.',
    'Hii match iko sawa. Endeleeni kupiga dice, taxman ako macho.',
    'Stakes hizi si za kuchezea — focus, msije lia kwa kona.',
  ];
  static final trash = [
    'Wewe na hizo token za base? Acha kuogopa, toa kafala icheze!',
    'Stake yangu iko juu coz najua nitachukua zote!',
    'Mnacheza poa, lakini cheque ya leo inakuja kwangu.',
    'Sina haraka — nitawamaliza polepole kama bundles za usiku.',
    'Six ingine tena? Dice inanijua. Mko hapo kwa formality tu!',
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
  bool rolling = false;
  String phase = 'idle'; // idle | waiting-for-roll | waiting-for-move | animating | game-over
  int _sixes = 0;
  List<int> eligible = [];
  String? winner;
  bool fullSim = false; // every seat AI (Simulate)
  bool simMode = false; // turbo, no sound
  bool muted = false;
  String commentary = 'Karibuni! Press Play to take Red, or Simulate to watch.';
  final List<String> log = [];

  Timer? _aiTimer;
  Timer? _moveTimer;

  String get current => kPlayers[turnIndex];
  bool get isHumanTurn => roles[current] == 'human' && !fullSim;
  bool get started => phase != 'idle';

  int _spd(int ms) => simMode ? 6 : ms;

  void _sound(SystemSoundType s) {
    if (muted || simMode) return;
    SystemSound.play(s);
  }

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
    phase = 'waiting-for-roll';
    log.clear();
    _log('Match initialised');
    _log(simulate ? 'Turbo simulation — rushing the match' : 'Play mode — your move, boss');
    _say(_Sheng.intro);
    notifyListeners();
    _maybeAutoplay();
  }

  void handleDiceTap() {
    if (phase == 'waiting-for-roll' && isHumanTurn) rollDice();
  }

  void rollDice() {
    if (phase != 'waiting-for-roll') return;
    dice = _rng.nextInt(6) + 1;
    _sound(SystemSoundType.click);
    _log('${kNames[current]} rolled $dice');

    if (dice == 6) {
      _sixes++;
      if (_sixes == 3) {
        _log('Three sixes — turn forfeited');
        _sixes = 0;
        _nextTurn();
        notifyListeners();
        return;
      }
    } else {
      _sixes = 0;
    }
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
        _sound(SystemSoundType.click);
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
                _sound(SystemSoundType.alert);
                _log('Captured ${kNames[opp]} piece!');
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
    if (!simMode && _rng.nextInt(3) == 0) _say(_Sheng.generic);
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
    _settle(color);
    _say(_Sheng.victory);
    _log('${kNames[color]} wins the pot!');
    notifyListeners();
  }

  /// Pot + KRA-style tax settlement, mirrored from the web build.
  void _settle(String winnerColor) {
    final winStake = stakes[winnerColor]!.toDouble();
    var pool = winStake;
    for (final c in active) {
      if (c == winnerColor) continue;
      pool += min(winStake, stakes[c]!.toDouble());
    }
    final com = pool * 0.10;
    final exc = pool * 0.125;
    final netW = pool - com - exc;
    final taxW = max(0.0, netW - winStake);
    final wht = taxW * 0.20;
    final takeHome = netW - wht;

    wallets[winnerColor] = wallets[winnerColor]! + (takeHome - winStake);
    for (final c in active) {
      if (c == winnerColor) continue;
      wallets[c] = wallets[c]! - min(winStake, stakes[c]!.toDouble());
    }
  }

  /// Payout preview for the given colour if they were to win 1st.
  Map<String, double> payoutFor(String color) {
    final myStake = stakes[color]!.toDouble();
    var pool = myStake;
    for (final c in active) {
      if (c == color) continue;
      pool += min(myStake, stakes[c]!.toDouble());
    }
    final com = pool * 0.10;
    final exc = pool * 0.125;
    final netW = pool - com - exc;
    final taxW = max(0.0, netW - myStake);
    final wht = taxW * 0.20;
    return {'pool': pool, 'takeHome': netW - wht};
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
