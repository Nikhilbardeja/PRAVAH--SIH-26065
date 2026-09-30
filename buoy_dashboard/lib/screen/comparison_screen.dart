import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../provider/data_provider.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    final c = context.c;
    final buoys = [
      for (final b in (d.comparison['buoys'] as List? ?? []))
        Map<String, dynamic>.from(b)
    ];
    final radar = [
      for (final r in (d.comparison['radar'] as List? ?? []))
        Map<String, dynamic>.from(r)
    ];
    final colors = [c.teal, c.aurora, c.alert, c.wave, c.solar];
    final deltaKeys = <String>{
      for (final b in buoys) ...b.keys.where((k) => k.endsWith('_delta'))
    };

    final legend =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (int i = 0; i < buoys.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: colors[i % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${buoys[i]['buoy']}  ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        fontSize: 13)),
                TextSpan(
                    text: '${buoys[i]['note'] ?? ''}',
                    style: mutedStyle(context, size: 11)),
              ])),
            ),
          ]),
        ),
    ]);

    return ListView(padding: const EdgeInsets.all(20), children: [
      FadeRise(
        index: 0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comparing the fleet', style: display(context, 18)),
          Text('${d.comparison['subtitle'] ?? ''}', style: mutedStyle(context)),
        ]),
      ),
      const SizedBox(height: 12),
      FadeRise(
        index: 1,
        child: Panel(
          child: LayoutBuilder(builder: (ctx, cons) {
            final radarW = Radar3D(
                series: radar, colors: colors, size: min(300.0, cons.maxWidth));
            return cons.maxWidth > 640
                ? Row(children: [
                    radarW,
                    const SizedBox(width: 24),
                    Expanded(child: legend)
                  ])
                : Column(children: [radarW, legend]);
          }),
        ),
      ),
      const SizedBox(height: 16),
      FadeRise(
        index: 2,
        child: Panel(
          child: DynamicTable(
            rows: buoys,
            hide: {'note', ...deltaKeys},
            cell: (row, k) {
              final dk = '${k}_delta';
              if (row[dk] is num) {
                final dv = row[dk] as num;
                final col = dv >= 0 ? c.aurora : c.alert;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: col.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatValue(row[k], k),
                        style: numStyle(context, size: 13)),
                    const SizedBox(width: 4),
                    Text('${dv >= 0 ? '▲' : '▼'}${dv.abs()}',
                        style: numStyle(context, size: 11, color: col)),
                  ]),
                );
              }
              if (k == 'status') {
                return Text('${row[k]}',
                    style:
                        TextStyle(fontSize: 13, color: statusColor(c, row[k])));
              }
              return null;
            },
          ),
        ),
      ),
      const SizedBox(height: 80),
    ]);
  }
}

/// Radar chart with intro grow animation + tilted, slowly rotating 3D view
/// where each buoy is a separate layer floating at a different depth.
class Radar3D extends StatefulWidget {
  const Radar3D(
      {super.key, required this.series, required this.colors, this.size = 280});
  final List<Map<String, dynamic>> series;
  final List<Color> colors;
  final double size;

  @override
  State<Radar3D> createState() => _Radar3DState();
}

class _Radar3DState extends State<Radar3D> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))
        ..repeat();
  bool _is3D = true;

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (widget.series.isEmpty) {
      return Text('No radar data', style: mutedStyle(context));
    }
    final axes = (widget.series.first['values'] as Map)
        .keys
        .map((e) => e.toString())
        .toList();
    final s = widget.size;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox.square(
        dimension: s,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _is3D ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          builder: (ctx, k, _) => AnimatedBuilder(
            animation: Listenable.merge([_intro, _spin]),
            builder: (ctx, __) {
              final double t = Curves.easeOutBack
                  .transform(_intro.value)
                  .clamp(0.0, 1.1)
                  .toDouble();
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(0.95 * k)
                ..rotateZ(_spin.value * 2 * pi * k);
              return Transform(
                alignment: Alignment.center,
                transform: m,
                child: Stack(children: [
                  CustomPaint(
                      size: Size.square(s), painter: _GridPainter(axes, c)),
                  for (int i = 0; i < widget.series.length; i++)
                    Transform(
                      transform: Matrix4.translationValues(
                          0, 0, -(i + 1) * 24.0 * k * t),
                      child: CustomPaint(
                        size: Size.square(s),
                        painter: _PolyPainter(
                          [
                            for (final a in axes)
                              (((widget.series[i]['values'] as Map)[a]
                                          as num?) ??
                                      0)
                                  .toDouble()
                          ],
                          widget.colors[i % widget.colors.length],
                          t,
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ),
      TextButton.icon(
        onPressed: () => setState(() {
          _is3D = !_is3D;
          if (_is3D) {
            _spin.repeat();
          } else {
            _spin.stop();
          }
        }),
        icon: Icon(_is3D ? Icons.view_in_ar : Icons.crop_square,
            size: 16, color: c.teal),
        label: Text(_is3D ? '3D view' : '2D view',
            style: TextStyle(color: c.teal, fontSize: 12)),
      ),
    ]);
  }
}

Offset _pt(Offset ctr, double r, int i, int n) {
  final a = -pi / 2 + i * 2 * pi / n;
  return ctr + Offset(cos(a) * r, sin(a) * r);
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.axes, this.c);
  final List<String> axes;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    final ctr = size.center(Offset.zero);
    final R = size.width / 2 - 34;
    final p = Paint()
      ..color = c.muted.withValues(alpha: .3)
      ..style = PaintingStyle.stroke;
    for (int ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final q = _pt(ctr, R * ring / 4, i, n);
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path..close(), p);
    }
    for (int i = 0; i < n; i++) {
      canvas.drawLine(ctr, _pt(ctr, R, i, n), p);
      drawText(canvas, labelFor(axes[i]), _pt(ctr, R + 18, i, n), c.muted, 10,
          center: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _PolyPainter extends CustomPainter {
  _PolyPainter(this.values, this.color, this.t);
  final List<double> values;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final ctr = size.center(Offset.zero);
    final R = size.width / 2 - 34;
    final path = Path();
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final double v = values[i].clamp(0.0, 1.0).toDouble();
      final q = _pt(ctr, R * v * t, i, n);
      pts.add(q);
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .18));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (final q in pts) {
      canvas.drawCircle(q, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
