import 'package:audioplayers/audioplayers.dart';

/// Tiny sound-effects engine backed by bundled WAV assets. Each effect keeps its
/// own reusable [AudioPlayer]. All calls fail silently if audio is unavailable.
class Sfx {
  static bool muted = false;
  static final Map<String, AudioPlayer> _players = {};

  static AudioPlayer _player(String name) {
    return _players.putIfAbsent(name, () {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      return p;
    });
  }

  static Future<void> _play(String name, {double rate = 1.0, double volume = 1.0}) async {
    if (muted) return;
    try {
      final p = _player(name);
      await p.stop();
      await p.setPlaybackRate(rate); // pitch/speed
      await p.setVolume(volume);
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {
      // Audio not available on this device/build — ignore.
    }
  }

  /// Dice rattle; pitch/speed scales with the fling [velocity] (px/sec).
  static void dice(double velocity) {
    final norm = (velocity / 4000.0).clamp(0.0, 1.0);
    _play('dice', rate: 0.9 + norm * 0.7, volume: 0.9);
  }

  static void move() => _play('move', volume: 0.5);
  static void capture() => _play('capture', volume: 1.0);
  static void win() => _play('win', volume: 0.9);
}
