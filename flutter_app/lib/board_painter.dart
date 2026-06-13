import 'dart:math';
import 'package:flutter/material.dart';
import 'ludo_game.dart';

/// Paints the classic wooden Ludo board: plank background, circular crayon-fill
/// corner yards, colored home-arrows, a pinwheel centre, safe stars and pawns.
class BoardPainter extends CustomPainter {
  final LudoGame game;
  BoardPainter(this.game);

  // Palette
  static const _board = Color(0xFFE7CFA0);
  static const _cell = Color(0xFFEAD6AC);
  static const _line = Color(0xFF8A5A2E);
  static const _border = Color(0xFF5A3A1E);

  late double _u; // cell size

  Offset _p(double rc, double cc) => Offset(cc * _u, rc * _u);

  @override
  void paint(Canvas canvas, Size size) {
    _u = size.width / 15.0;

    _paintWood(canvas, size);
    _paintGrid(canvas);
    _paintHomeArms(canvas);
    _paintCentre(canvas);
    _paintYards(canvas);
    _paintStars(canvas);
    _paintTokens(canvas);

    // Outer frame
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.18
      ..color = _border;
    canvas.drawRect(Offset.zero & size, frame);
  }

  void _paintWood(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _board);
    // Faint vertical plank seams for a wood feel.
    final seam = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var x = 1; x < 15; x++) {
      if (x % 3 == 0) {
        canvas.drawLine(Offset(x * _u, 0), Offset(x * _u, size.height), seam);
      }
    }
  }

  void _paintGrid(Canvas canvas) {
    final fill = Paint()..color = _cell;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, _u * 0.05)
      ..color = _line;
    for (var r = 0; r < 15; r++) {
      for (var c = 0; c < 15; c++) {
        final onCross = (r >= 6 && r <= 8) || (c >= 6 && c <= 8);
        if (!onCross) continue;
        final rect = Rect.fromLTWH(c * _u, r * _u, _u, _u);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      }
    }
  }

  void _paintHomeArms(Canvas canvas) {
    kHomePaths.forEach((color, cells) {
      final paint = Paint()..color = kColors[color]!;
      for (final cell in cells) {
        final rect = Rect.fromLTWH(cell[1] * _u, cell[0] * _u, _u, _u);
        canvas.drawRect(rect, paint);
      }
      // Tint the entry/start cell on the ring too.
      final s = kStartIndices[color]!;
      final sc = kTrack[s];
      canvas.drawRect(
        Rect.fromLTWH(sc[1] * _u, sc[0] * _u, _u, _u),
        Paint()..color = kColors[color]!.withOpacity(0.85),
      );
    });

    // Direction arrows pointing toward the centre.
    _arrow(canvas, 7, 2, _Dir.right, 'red');
    _arrow(canvas, 2, 7, _Dir.down, 'green');
    _arrow(canvas, 7, 12, _Dir.left, 'yellow');
    _arrow(canvas, 12, 7, _Dir.up, 'blue');
  }

  void _arrow(Canvas canvas, int r, int c, _Dir dir, String color) {
    final cx = (c + 0.5) * _u;
    final cy = (r + 0.5) * _u;
    final s = _u * 0.30;
    final path = Path();
    switch (dir) {
      case _Dir.right:
        path.moveTo(cx - s, cy - s);
        path.lineTo(cx + s, cy);
        path.lineTo(cx - s, cy + s);
        break;
      case _Dir.left:
        path.moveTo(cx + s, cy - s);
        path.lineTo(cx - s, cy);
        path.lineTo(cx + s, cy + s);
        break;
      case _Dir.up:
        path.moveTo(cx - s, cy + s);
        path.lineTo(cx, cy - s);
        path.lineTo(cx + s, cy + s);
        break;
      case _Dir.down:
        path.moveTo(cx - s, cy - s);
        path.lineTo(cx, cy + s);
        path.lineTo(cx + s, cy - s);
        break;
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _paintCentre(Canvas canvas) {
    final cx = 7.5 * _u, cy = 7.5 * _u;
    final tl = _p(6, 6), tr = _p(6, 9), br = _p(9, 9), bl = _p(9, 6);
    final centre = Offset(cx, cy);

    void tri(Offset a, Offset b, String color) {
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = kColors[color]!);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, _u * 0.04)
          ..color = _border.withOpacity(0.5),
      );
    }

    tri(tl, tr, 'red'); // top edge → red goal
    tri(tr, br, 'blue'); // right edge → blue goal
    tri(br, bl, 'yellow'); // bottom edge → yellow goal
    tri(bl, tl, 'green'); // left edge → green goal
  }

  // ---- Corner yards ----
  Offset _circleCentre(String color) => yardCircleCentre(color, _u);
  List<Offset> _holeOffsets() => yardHoleOffsets(_u);
  Offset _holeCentre(String color, int i) => _circleCentre(color) + _holeOffsets()[i];

  void _paintYards(Canvas canvas) {
    final radius = 2.7 * _u;
    for (final color in kPlayers) {
      final centre = _circleCentre(color);
      // white outer ring
      canvas.drawCircle(centre, radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.10
          ..color = _border.withOpacity(0.55),
      );
      // colored disc
      final disc = radius - _u * 0.28;
      canvas.drawCircle(centre, disc, Paint()..color = kColors[color]!);

      // crayon hatch
      canvas.save();
      final clip = Path()..addOval(Rect.fromCircle(center: centre, radius: disc));
      canvas.clipPath(clip);
      final hatch = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = _u * 0.10;
      for (var k = -6; k <= 6; k++) {
        final dx = k * _u * 0.5;
        canvas.drawLine(
          centre + Offset(dx - disc, -disc),
          centre + Offset(dx + disc, disc),
          hatch,
        );
      }
      canvas.restore();

      // 4 token holes
      for (final off in _holeOffsets()) {
        final hc = centre + off;
        canvas.drawCircle(hc, _u * 0.78, Paint()..color = Colors.white);
        canvas.drawCircle(
          hc,
          _u * 0.78,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * 0.06
            ..color = _border.withOpacity(0.45),
        );
      }
    }
  }

  void _paintStars(Canvas canvas) {
    final paint = Paint()..color = const Color(0x55000000);
    for (final gi in kSafeIndices) {
      final cell = kTrack[gi];
      // Skip start cells (already colored) to reduce clutter.
      _star(canvas, (cell[0] + 0.5) * _u, (cell[1] + 0.5) * _u, _u * 0.28, paint);
    }
  }

  void _star(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = (i.isEven) ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final x = cx + rad * cos(a);
      final y = cy + rad * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ---- Tokens ----
  void _paintTokens(Canvas canvas) {
    // Group tokens by their pixel home so stacks fan out.
    final groups = <String, List<List<dynamic>>>{};
    for (final color in game.active) {
      final steps = game.tokens[color]!;
      for (var i = 0; i < 4; i++) {
        final step = steps[i];
        final pos = tokenDrawPos(color, i, step, _u);
        final key = '${pos.dx.round()}_${pos.dy.round()}';
        (groups[key] ??= []).add([color, i, pos, step]);
      }
    }

    groups.forEach((_, list) {
      for (var n = 0; n < list.length; n++) {
        final color = list[n][0] as String;
        final idx = list[n][1] as int;
        var pos = list[n][2] as Offset;
        if (list.length > 1) {
          final ang = n * (2 * pi / list.length);
          pos = pos + Offset(cos(ang), sin(ang)) * (_u * 0.28);
        }
        _pawn(canvas, pos, color, idx, list.length > 1);
      }
    });
  }

  void _pawn(Canvas canvas, Offset c, String color, int idx, bool small) {
    final r = (small ? 0.42 : 0.62) * _u;
    final highlight = game.started &&
        game.current == color &&
        game.eligible.contains(idx) &&
        game.isHumanTurn &&
        game.phase == 'waiting-for-move';

    if (highlight) {
      // Bright pulsing-style halo so it's obvious which pieces are tappable.
      canvas.drawCircle(c, r + _u * 0.34,
          Paint()..color = const Color(0xFFFFE08A).withOpacity(0.55));
      canvas.drawCircle(c, r + _u * 0.20,
          Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        r + _u * 0.20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.06
          ..color = const Color(0xFFFFB300),
      );
    }
    canvas.drawCircle(c, r, Paint()..color = kColors[color]!);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.10
        ..color = const Color(0xFF20140A),
    );
    // glossy highlight
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.28,
        Paint()..color = Colors.white.withOpacity(0.45));

    final tp = TextPainter(
      text: TextSpan(
        text: '${idx + 1}',
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 0.9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

enum _Dir { up, down, left, right }

// ---- Shared board geometry (used by painter + tap hit-testing) ----

Offset yardCircleCentre(String color, double u) {
  switch (color) {
    case 'green':
      return Offset(3 * u, 3 * u); // top-left
    case 'red':
      return Offset(12 * u, 3 * u); // top-right
    case 'yellow':
      return Offset(3 * u, 12 * u); // bottom-left
    default:
      return Offset(12 * u, 12 * u); // blue, bottom-right
  }
}

List<Offset> yardHoleOffsets(double u) => [
      Offset(-1.15 * u, -1.15 * u),
      Offset(1.15 * u, -1.15 * u),
      Offset(-1.15 * u, 1.15 * u),
      Offset(1.15 * u, 1.15 * u),
    ];

/// Where a token is actually drawn (yard hole for step 0, else cell centre).
Offset tokenDrawPos(String color, int idx, int step, double u) {
  if (step == 0) return yardCircleCentre(color, u) + yardHoleOffsets(u)[idx];
  final cell = tokenCell(color, idx, step);
  return Offset((cell[1] + 0.5) * u, (cell[0] + 0.5) * u);
}
