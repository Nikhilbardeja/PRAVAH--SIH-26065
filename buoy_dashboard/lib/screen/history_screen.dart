import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../provider/data_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Set<String>? _sel;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    final c = context.c;
    final rows = [
      for (final r in (d.history['rows'] as List? ?? []))
        Map<String, dynamic>.from(r)
    ];
    if (rows.isEmpty) {
      return Center(child: Text('No history', style: mutedStyle(context)));
    }
    final numeric = rows.first.keys.where((k) => rows.first[k] is num).toList();
    final labelKey = rows.first.keys
        .firstWhere((k) => rows.first[k] is String, orElse: () => '');
    _sel ??= numeric.take(2).toSet();
    _sel!.removeWhere((k) => !numeric.contains(k));
    final selKeys = numeric.where(_sel!.contains).toList();
    Color colorOf(String k) => c.palette[numeric.indexOf(k) % c.palette.length];

    // Normalise each series to its own range so different units share one chart.
    List<FlSpot> spotsFor(String k) {
      final v = rows.map((r) => ((r[k] as num?) ?? 0).toDouble()).toList();
      final mn = v.reduce(min), mx = v.reduce(max);
      final double range = mx - mn == 0 ? 1.0 : mx - mn;
      return [
        for (int i = 0; i < v.length; i++)
          FlSpot(i.toDouble(), (v[i] - mn) / range * .8 + .1)
      ];
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      FadeRise(
          index: 0,
          child: Text('14-day history — ${d.history['buoy'] ?? d.selectedBuoy}',
              style: display(context, 18))),
      const SizedBox(height: 12),
      FadeRise(
        index: 1,
        child: Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in numeric)
                GestureDetector(
                  onTap: () => setState(() {
                    if (_sel!.contains(k)) {
                      _sel!.remove(k);
                    } else {
                      _sel!.add(k);
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sel!.contains(k)
                          ? colorOf(k).withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _sel!.contains(k) ? colorOf(k) : c.line),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: colorOf(k),
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text('${labelFor(k)} ${unitFor(k)}',
                          style: TextStyle(fontSize: 12, color: c.text)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: selKeys.isEmpty
                  ? Center(
                      child:
                          Text('Select a series', style: mutedStyle(context)))
                  : LineChart(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      LineChartData(
                        minX: 0,
                        maxX: (rows.length - 1).toDouble(),
                        minY: 0,
                        maxY: 1,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: true,
                          horizontalInterval: .25,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: c.line, strokeWidth: 1),
                          getDrawingVerticalLine: (_) => FlLine(
                              color: c.line.withValues(alpha: .4),
                              strokeWidth: 1,
                              dashArray: [3, 4]),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 26,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= rows.length || v != i) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                      labelKey.isEmpty
                                          ? '$i'
                                          : '${rows[i][labelKey]}',
                                      style: mutedStyle(context, size: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          getTouchedSpotIndicator: (bar, idx) => idx
                              .map((_) => TouchedSpotIndicatorData(
                                    FlLine(
                                        color: c.muted.withValues(alpha: .5),
                                        strokeWidth: 1,
                                        dashArray: [4, 4]),
                                    FlDotData(
                                        getDotPainter: (s, p, b, i) =>
                                            FlDotCirclePainter(
                                                radius: 5,
                                                color: b.color ?? c.teal,
                                                strokeWidth: 2,
                                                strokeColor: c.panel)),
                                  ))
                              .toList(),
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => c.sunken,
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (spots) => spots.map((s) {
                              final k = selKeys[s.barIndex];
                              final row = rows[s.x.toInt()];
                              final head =
                                  s == spots.first && labelKey.isNotEmpty
                                      ? '${row[labelKey]}\n'
                                      : '';
                              return LineTooltipItem(
                                  '$head${labelFor(k)}: ${formatValue(row[k], k)}',
                                  numStyle(context,
                                      size: 12, color: colorOf(k)));
                            }).toList(),
                          ),
                        ),
                        lineBarsData: [
                          for (final k in selKeys)
                            LineChartBarData(
                              spots: spotsFor(k),
                              isCurved: true,
                              curveSmoothness: .3,
                              preventCurveOverShooting: true,
                              color: colorOf(k),
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                getDotPainter: (s, p, b, i) =>
                                    FlDotCirclePainter(
                                        radius: 2.8,
                                        color: c.panel,
                                        strokeColor: colorOf(k),
                                        strokeWidth: 1.8),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorOf(k).withValues(alpha: .22),
                                    colorOf(k).withValues(alpha: 0)
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
                'Each series is scaled to its own range — tap/hover for real values.',
                style: mutedStyle(context, size: 11)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              for (final k in selKeys)
                SizedBox(
                    width: 290,
                    child: _SummaryChip(k: k, rows: rows, color: colorOf(k))),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      FadeRise(index: 2, child: Panel(child: DynamicTable(rows: rows))),
      const SizedBox(height: 80),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.k, required this.rows, required this.color});
  final String k;
  final List<Map<String, dynamic>> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = rows.map((r) => ((r[k] as num?) ?? 0).toDouble()).toList();
    final avg = v.reduce((a, b) => a + b) / v.length;
    String f(double x) => formatValue(double.parse(x.toStringAsFixed(2)), k);
    return Callout(
      color: color,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelFor(k), style: mutedStyle(context, size: 11)),
            Text(
                'min ${f(v.reduce(min))} · avg ${f(avg)} · max ${f(v.reduce(max))}',
                style: numStyle(context, size: 12)),
          ]),
    );
  }
}
