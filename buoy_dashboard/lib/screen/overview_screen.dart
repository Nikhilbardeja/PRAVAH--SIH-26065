import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../provider/data_provider.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    final c = context.c;
    final f = d.fleet;
    final stats = Map<String, dynamic>.from(f['stats'] ?? {});
    final buoys = [
      for (final b in (f['buoys'] as List? ?? [])) Map<String, dynamic>.from(b)
    ];
    final alert = f['alert'] as Map?;
    final sat = Map<String, dynamic>.from(f['satellite_link'] ?? {});

    return LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 900;
      final plot = FadeRise(
        index: 2,
        child: Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fleet position — Antarctic Circle reference',
                style: display(context, 15)),
            const SizedBox(height: 12),
            AspectRatio(
                aspectRatio: 1.2,
                child: CustomPaint(painter: _PolarPainter(buoys, c))),
          ]),
        ),
      );
      final side = Column(children: [
        for (int i = 0; i < buoys.length; i++)
          FadeRise(
              index: 3 + i,
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BuoyCard(
                    b: buoys[i],
                    selected: buoys[i]['id'] == d.selectedBuoy,
                    onTap: buoys[i]['latitude'] == null
                        ? null
                        : () => d.selectBuoy('${buoys[i]['id']}'),
                  ))),
        if (sat.isNotEmpty)
          FadeRise(index: 3 + buoys.length, child: _SatelliteCard(sat: sat)),
      ]);

      return ListView(padding: const EdgeInsets.all(20), children: [
        if (alert != null) ...[
          FadeRise(
            index: 0,
            child: Callout(
              color: c.alert,
              tint: true,
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${alert['title'] ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '${alert['message'] ?? ''}'),
                  ]),
                  style: TextStyle(color: c.text, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FadeRise(index: 1, child: _StatsRow(stats: stats)),
        const SizedBox(height: 16),
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: plot),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: side),
              ])
            : Column(children: [plot, const SizedBox(height: 16), side]),
        const SizedBox(height: 80),
      ]);
    });
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cons) {
        final int cols =
            max(1, min(stats.length, (cons.maxWidth / 170).floor()));
        final w = (cons.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final e in stats.entries)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(color: context.c.line, width: 2))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelFor(e.key),
                          style: mutedStyle(context, size: 11)),
                      const SizedBox(height: 2),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: e.value is num
                                  ? AnimatedNumber(
                                      value: e.value as num,
                                      decimals: (e.value as num) ==
                                              (e.value as num).roundToDouble()
                                          ? 0
                                          : 1,
                                      style: display(context, 26))
                                  : Text('${e.value}',
                                      overflow: TextOverflow.ellipsis,
                                      style: display(context, 26)),
                            ),
                            const SizedBox(width: 3),
                            Text(e.value is num ? unitFor(e.key) : '',
                                style: mutedStyle(context, size: 12)),
                          ]),
                    ]),
              ),
            ),
        ]);
      });
}

/// A compact ring showing battery percentage — reads at a glance,
/// and its color already tells you the buoy's status.
class _BatteryRing extends StatelessWidget {
  const _BatteryRing({required this.pct, required this.color});
  final num pct;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0).toDouble()),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (_, v, __) => SizedBox(
          width: 40,
          height: 40,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: 1,
              strokeWidth: 3.5,
              color: context.c.line,
              backgroundColor: Colors.transparent,
            ),
            CircularProgressIndicator(
              value: v,
              strokeWidth: 3.5,
              color: color,
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
            Text('${pct.round()}',
                style: numStyle(context, size: 11, w: FontWeight.w700)),
          ]),
        ),
      );
}

class _BuoyCard extends StatelessWidget {
  const _BuoyCard({required this.b, this.selected = false, this.onTap});
  final Map<String, dynamic> b;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = statusColor(c, b['status']);
    final battery = b['battery_pct'];
    final scheduled = battery == null;
    final name = (b['name'] ?? '').toString();
    final tagline = (b['tagline'] ?? '').toString();
    final statusLabel = formatValue(b['status'], 'status');

    return Pressable(
      onTap: onTap,
      borderRadius: 10,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: scheduled
              ? c.sunken
              : (selected ? c.teal.withValues(alpha: 0.06) : c.panel),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? c.teal : c.line, width: selected ? 1.4 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (!scheduled) ...[
                  PulsingDot(color: col, size: 7),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(name.isEmpty ? '${b['id']}' : name,
                      overflow: TextOverflow.ellipsis,
                      style: display(context, 16,
                          color: scheduled ? c.muted : null)),
                ),
              ]),
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(tagline,
                    style: display(context, 11.5,
                        italic: true, color: c.muted, w: FontWeight.w400)),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: c.sunken, borderRadius: BorderRadius.circular(4)),
                  child: Text('${b['id']}',
                      style: numStyle(context,
                          size: 10, color: c.muted, w: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(statusLabel,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle(context, size: 11)),
                ),
              ]),
            ]),
          ),
          if (b['trend'] is List) ...[
            Sparkline(
                values: b['trend'], color: col == c.aurora ? c.teal : col),
            const SizedBox(width: 14),
          ],
          if (battery != null) _BatteryRing(pct: battery as num, color: col),
        ]),
      ),
    );
  }
}

class _SatelliteCard extends StatelessWidget {
  const _SatelliteCard({required this.sat});
  final Map<String, dynamic> sat;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final used = sat['todays_uplink_b'], limit = sat['uplink_limit_b'];
    final rest = Map<String, dynamic>.of(sat)
      ..removeWhere((k, _) =>
          k == 'title' || k == 'todays_uplink_b' || k == 'uplink_limit_b');
    return Panel(
      color: c.sunken,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.satellite_alt_rounded, size: 15, color: c.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${sat['title'] ?? 'Satellite link'}',
                  style: display(context, 13))),
        ]),
        const SizedBox(height: 10),
        if (used is num && limit is num && limit != 0) ...[
          Row(children: [
            Expanded(
                child: Text("Today's uplink",
                    style: TextStyle(fontSize: 13, color: c.text))),
            Text('$used / $limit B', style: numStyle(context, size: 13)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: 0, end: (used / limit).toDouble().clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: c.teal,
                  backgroundColor: c.line),
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (final e in rest.entries) MetricRow(keyName: e.key, value: e.value),
      ]),
    );
  }
}

class _PolarPainter extends CustomPainter {
  _PolarPainter(this.buoys, this.c);
  final List<Map<String, dynamic>> buoys;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = size.center(Offset.zero);
    final R = min(size.width, size.height) / 2 - 20;
    double r(double lat) => (90 - lat.abs()) / 45 * R;
    final line = Paint()
      ..color = c.muted.withValues(alpha: .15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(ctr, R, line);
    line.color = c.muted.withValues(alpha: .35);
    canvas.drawCircle(ctr, r(60), line);
    canvas.drawCircle(ctr, r(66.56), line);
    final rr = r(80);
    for (int a = 0; a < 72; a += 2) {
      canvas.drawArc(Rect.fromCircle(center: ctr, radius: rr), a * pi / 36,
          pi / 72, false, line);
    }
    canvas.drawLine(ctr.translate(-R, 0), ctr.translate(R, 0), line);
    canvas.drawLine(ctr.translate(0, -R), ctr.translate(0, R), line);
    drawText(canvas, '60°S', ctr.translate(0, -r(60) - 10), c.muted, 11,
        center: true);
    drawText(canvas, 'Antarctic Circle', ctr.translate(0, -r(66.56) + 12),
        c.muted, 10,
        center: true);

    for (final b in buoys) {
      final lat = (b['latitude'] as num?)?.toDouble();
      final lon = (b['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final ang = lon * pi / 180;
      final p = ctr + Offset(sin(ang) * r(lat), -cos(ang) * r(lat));
      final col = statusColor(c, b['status']);
      canvas.drawCircle(p, 11, Paint()..color = col.withValues(alpha: .18));
      canvas.drawCircle(p, 6.5, Paint()..color = col);
      final label = (b['name'] ?? b['id']).toString();
      drawText(canvas, label, p + const Offset(12, -16), c.text, 13,
          bold: true);
      drawText(
          canvas,
          '${lat.abs().round()}°S · ${formatValue(b['status'], 'status')}',
          p + const Offset(12, 0),
          c.muted,
          11);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
