import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// A phone has no keys to print on the buttons and needs a 48dp target, so the
/// same label is simply set larger and quieter there.
bool get touchLayout => Platform.isAndroid || Platform.isIOS;

/// Desktop rows are set to the label's printed rhythm; a touch screen needs a
/// 48dp target, so the same rhythm is simply printed larger there.
double get laneHeight => touchLayout ? 48 : Metrics.row;

/// The barred edge of an airmail label, in one ink. It is what makes the
/// window read as a piece of addressed post before a single word is read.
class BarredEdge extends StatelessWidget {
  const BarredEdge({super.key, this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return SizedBox(
      height: Metrics.barredEdge,
      width: double.infinity,
      child: CustomPaint(painter: _BarredPainter(c.ink, flip)),
    );
  }
}

class _BarredPainter extends CustomPainter {
  _BarredPainter(this.ink, this.flip);

  final Color ink;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink;
    const period = 26.0;
    final slant = size.height * 1.15;
    for (var x = -slant; x < size.width + period; x += period) {
      final path = Path();
      if (flip) {
        path.moveTo(x, size.height);
        path.lineTo(x + period * 0.55, size.height);
        path.lineTo(x + period * 0.55 + slant, 0);
        path.lineTo(x + slant, 0);
      } else {
        path.moveTo(x, 0);
        path.lineTo(x + period * 0.55, 0);
        path.lineTo(x + period * 0.55 + slant, size.height);
        path.lineTo(x + slant, size.height);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BarredPainter old) => old.ink != ink || old.flip != flip;
}

/// A printed section legend: the letter, the name, and — at the right — the one
/// count that section owns. Nothing on the label is labelled twice.
class Legend extends StatelessWidget {
  const Legend({
    super.key,
    required this.letter,
    required this.name,
    this.tally,
    this.trailing,
  });

  final String letter;
  final String name;
  final String? tally;

  /// The one control that belongs to this section, printed on its legend line.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.legendGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            letter,
            style: press(color: c.ink, weight: FontWeight.w700),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(name, style: press(color: c.inkMid)),
          ),
          if (tally != null)
            Text(tally!, style: typed(size: 11, color: c.inkFaint)),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// A ruled box: where the form expects something to be filled in.
class Well extends StatelessWidget {
  const Well({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 5),
    this.emphasis = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// The box the keyboard is pointed at right now.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.well,
        border: Border.all(
          color: emphasis ? c.ink : c.rule,
          width: emphasis ? 1.2 : Metrics.hairline,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// A square tick, inked solid when it is on. No tint, no switch, no motion.
class TickBox extends StatelessWidget {
  const TickBox({super.key, required this.on, this.size = Metrics.tick});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TickPainter(on: on, ink: c.ink, stroke: c.mark, out: c.onInk),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({
    required this.on,
    required this.ink,
    required this.stroke,
    required this.out,
  });

  final bool on;
  final Color ink;
  final Color stroke;
  final Color out;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (on) {
      canvas.drawRect(r, Paint()..color = ink);
      final p = Paint()
        ..color = out
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.71)
        ..lineTo(size.width * 0.78, size.height * 0.29);
      canvas.drawPath(path, p);
    } else {
      canvas.drawRect(
        r.deflate(0.6),
        Paint()
          ..color = stroke
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.on != on || old.ink != ink || old.stroke != stroke;
}

/// The remove mark: two strokes on the tick's hairline, so the label keeps one
/// drawn vocabulary and never borrows a glyph from a font.
class CrossMark extends StatelessWidget {
  const CrossMark({super.key, required this.strong, this.size = 12});

  final bool strong;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CrossPainter(strong ? c.ink : c.mark)),
    );
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.ink != ink;
}

enum Frank { idle, ready, sending, delivered, held }

/// The postmark. Dormant it is a hairline ring; sending, its rim inks around
/// as the bytes go; delivered, the whole disc is struck solid. It is the only
/// place in the app where something is drawn rather than printed.
class Postmark extends StatefulWidget {
  const Postmark({
    super.key,
    required this.state,
    required this.progress,
    this.size = 48,
  });

  final Frank state;
  final double progress;
  final double size;

  @override
  State<Postmark> createState() => _PostmarkState();
}

class _PostmarkState extends State<Postmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 190),
    value: 1,
  );

  @override
  void didUpdateWidget(Postmark old) {
    super.didUpdateWidget(old);
    // The press happens twice: when the stamp is picked up, and when it lands.
    if (old.state != widget.state &&
        (widget.state == Frank.sending ||
            widget.state == Frank.delivered ||
            widget.state == Frank.held)) {
      _press.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  String get _word => switch (widget.state) {
    Frank.idle => 'IDLE',
    Frank.ready => 'READY',
    Frank.sending => '${(widget.progress * 100).clamp(0, 99).round()}%',
    Frank.delivered => 'SENT',
    Frank.held => 'HELD',
  };

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')} ${_months[now.month - 1]}';
    return AnimatedBuilder(
      animation: _press,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_press.value);
        return Transform.scale(
          scale: 1 + (1 - t) * 0.22,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _PostmarkPainter(
                state: widget.state,
                progress: widget.progress,
                word: _word,
                date: date,
                ink: c.ink,
                faint: c.mark,
                out: c.onInk,
                landed: t,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter({
    required this.state,
    required this.progress,
    required this.word,
    required this.date,
    required this.ink,
    required this.faint,
    required this.out,
    required this.landed,
  });

  final Frank state;
  final double progress;
  final String word;
  final String date;
  final Color ink;
  final Color faint;
  final Color out;
  final double landed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final struck = state == Frank.delivered;
    final live = state != Frank.idle;
    final markColor = struck ? out : (live ? ink : faint);

    if (struck) {
      canvas.drawCircle(centre, r + 1, Paint()..color = ink);
    }

    final held = state == Frank.held;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = struck ? out : (held ? ink : faint)
      ..strokeWidth = held ? 1.8 : 1.2;
    canvas.drawCircle(centre, r, ring);
    canvas.drawCircle(
      centre,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = struck ? out : (held ? ink : faint)
        ..strokeWidth = held ? 1.4 : 0.9,
    );

    if (state == Frank.sending || state == Frank.ready) {
      final sweep = state == Frank.ready ? 0.0 : progress.clamp(0.0, 1.0);
      if (sweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: r),
          -math.pi / 2,
          2 * math.pi * sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = ink
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = 2.6,
        );
      }
    }

    void line(String text, double dy, double fontSize, FontWeight weight) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: typed(
            size: fontSize,
            color: markColor,
            weight: weight,
            tracking: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, centre + Offset(-tp.width / 2, dy - tp.height / 2));
    }

    line(word, -5.5, 9, FontWeight.w700);
    canvas.drawLine(
      centre + Offset(-r + 7, 1),
      centre + Offset(r - 7, 1),
      Paint()
        ..color = markColor
        ..strokeWidth = 0.8,
    );
    line(date, 7.5, 7.5, FontWeight.w400);
  }

  @override
  bool shouldRepaint(_PostmarkPainter old) =>
      old.state != state ||
      old.progress != progress ||
      old.word != word ||
      old.ink != ink ||
      old.landed != landed;
}

/// A printed action. Solid is struck in ink and holds the label's one
/// irreversible act; outline is everything else.
class PressButton extends StatefulWidget {
  const PressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.cap,
    this.solid = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The key that does the same thing, printed on the button the way a form
  /// prints its instructions.
  final String? cap;
  final bool solid;
  final bool dense;

  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    final enabled = widget.onPressed != null;
    final solid = widget.solid && enabled;
    final fg = solid
        ? c.onInk
        : enabled
        ? c.ink
        : c.inkFaint;
    final bg = solid
        ? c.ink
        : (_hover && enabled ? c.well : Colors.transparent);

    return FocusableActionDetector(
      enabled: enabled,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          height: widget.dense ? 28 : 34,
          padding: EdgeInsets.symmetric(horizontal: widget.dense ? 12 : 16),
          decoration: BoxDecoration(
            color: bg,
            // Hover and focus are a heavier strike of the same rule: this world
            // has no second colour to spend on them.
            border: Border.all(
              color: enabled ? c.ink : c.rule,
              width: solid ? 1.2 : (_hover || _focus ? 1.6 : Metrics.hairline),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // An inked block shows its hover the way a hand stamp shows its
              // shoulder: a knocked-out rule just inside the edge.
              if (solid && (_hover || _focus))
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.onInk, width: 1),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: press(
                      size: widget.dense ? 9.5 : 10.5,
                      color: fg,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (widget.cap != null && !touchLayout) ...[
                    const SizedBox(width: 9),
                    Text(
                      widget.cap!,
                      style: press(
                        size: widget.dense ? 8.5 : 9,
                        color: fg.withValues(alpha: 0.62),
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A hairline that separates two printed zones.
class Rule extends StatelessWidget {
  const Rule({super.key, this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return Container(
      height: Metrics.hairline,
      color: strong ? c.rule : c.ruleFaint,
    );
  }
}

/// The send's progress, printed straight onto the rule above the franking row.
class ProgressRule extends StatelessWidget {
  const ProgressRule({super.key, required this.value, required this.active});

  final double value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          Container(height: 2, color: c.rule),
          if (active)
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(height: 2, color: c.ink),
            ),
        ],
      ),
    );
  }
}
