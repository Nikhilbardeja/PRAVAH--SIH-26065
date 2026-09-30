import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card: 10px radius, 1px hairline, no shadow.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 16, this.color});
  final Widget child;
  final double padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color ?? context.c.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.c.line),
        ),
        child: child,
      );
}

/// Left-border accent callout. Needs a bounded width (wrap in SizedBox inside Wrap).
class Callout extends StatelessWidget {
  const Callout(
      {super.key, required this.color, required this.child, this.tint = false});
  final Color color;
  final Widget child;
  final bool tint;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: tint ? color.withValues(alpha: .10) : context.c.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: tint ? color.withValues(alpha: .35) : context.c.line),
          ),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 3, color: color),
              Expanded(
                  child:
                      Padding(padding: const EdgeInsets.all(14), child: child)),
            ]),
          ),
        ),
      );
}

/// One staggered fade-rise on first build (80ms stagger, 500ms ease).
class FadeRise extends StatefulWidget {
  const FadeRise({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<FadeRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0, .04), end: Offset.zero).animate(_a),
          child: widget.child,
        ),
      );
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});
  final List values;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(64, 24),
      painter: _SparkPainter(
          values.map((e) => (e as num).toDouble()).toList(), color));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color);
  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final mn = v.reduce(min), mx = v.reduce(max);
    final double range = (mx - mn) == 0 ? 1.0 : mx - mn;
    final p = Path();
    for (int i = 0; i < v.length; i++) {
      final x = i / (v.length - 1) * s.width;
      final y = s.height - (v[i] - mn) / range * s.height;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.v != v;
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Callout(
              color: context.c.alert,
              tint: true,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not reach the buoy server',
                        style: display(context, 16)),
                    const SizedBox(height: 6),
                    Text(message, style: mutedStyle(context)),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: onRetry, child: const Text('Try again')),
                    Text(
                        'Tip: use the button in the corner to switch to sample data.',
                        style: mutedStyle(context, size: 11)),
                  ]),
            ),
          ),
        ),
      );
}

/// Canvas text helper used by custom painters.
void drawText(Canvas canvas, String text, Offset at, Color color, double size,
    {bool bold = false, bool center = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

/// The Pravah mark: a simple current/flow glyph, drawn (no image asset
/// needed). Swap for the real icon by giving PravahMark an `asset` path
/// once artwork is ready — everything that uses this widget picks it up
/// automatically.
class PravahMark extends StatelessWidget {
  const PravahMark({super.key, this.size = 28, this.color, this.asset});
  final double size;
  final Color? color;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Image.asset(asset!, width: size, height: size);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(color ?? context.c.teal)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.11
      ..strokeCap = StrokeCap.round;
    // Three flowing current lines, tightest at the front — reads as
    // motion/water without needing any imagery.
    for (int i = 0; i < 3; i++) {
      final y = s.height * (0.28 + i * 0.24);
      final amp = s.height * (0.10 - i * 0.015);
      final path = Path()..moveTo(s.width * 0.06, y);
      path.quadraticBezierTo(s.width * 0.32, y - amp, s.width * 0.55, y);
      path.quadraticBezierTo(
          s.width * 0.78, y + amp, s.width * 0.97, y - amp * .4);
      canvas.drawPath(path, p..color = color.withValues(alpha: 1.0 - i * 0.28));
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A dot that breathes gently — used to signal "this is live".
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: widget.size + _c.value * 10,
            height: widget.size + _c.value * 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.28 * (1 - _c.value))),
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: widget.color),
          ),
        ]),
      );
}

/// Smoothly tweens between successive numeric values instead of snapping,
/// so a live poll update feels like a reading, not a page reload.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(
      {super.key,
      required this.value,
      required this.style,
      this.decimals = 0,
      this.suffix = ''});
  final num value;
  final TextStyle style;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: value.toDouble(), end: value.toDouble()),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (_, v, __) =>
            Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
      );
}

/// Wraps any widget with a hover highlight (desktop/web) and a gentle
/// press-scale (all platforms), so interactive elements feel interactive
/// before the user even taps them.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 10,
    this.hoverColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? hoverColor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1.0,
          duration: Motion.fast,
          child: AnimatedContainer(
            duration: Motion.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: _hover && active
                  ? (widget.hoverColor ??
                      context.c.teal.withValues(alpha: 0.05))
                  : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fade + slight rise between two widgets - used for page/tab switches so
/// navigation feels continuous instead of cutting instantly.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child, required this.keyed});
  final Widget child;
  final Key keyed;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.normal,
        switchInCurve: Motion.curve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (w, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .02), end: Offset.zero)
                .animate(anim),
            child: w,
          ),
        ),
        child: KeyedSubtree(key: keyed, child: child),
      );
}
