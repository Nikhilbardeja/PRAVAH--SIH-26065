import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/core.dart';
import '../provider/data_provider.dart';

class InterpretationScreen extends StatelessWidget {
  const InterpretationScreen({super.key});

  List<Map<String, dynamic>> _list(dynamic v) => [
        for (final e in (v as List? ?? [])) Map<String, dynamic>.from(e),
      ];

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    final c = context.c;
    final data = d.interpretation;
    final insights = _list(data['insights']);
    final energy = _list(data['energy_by_month']);
    final coupling = _list(data['coupling']);
    final daylight = _list(data['daylight']);
    final note = data['note'] as Map?;

    Color tone(dynamic t) => switch ('$t') {
          'alert' => c.alert,
          'solar' => c.solar,
          'wave' => c.wave,
          'aurora' => c.aurora,
          _ => c.teal,
        };

    final TextStyle axis = mutedStyle(context, size: 10);
    FlTitlesData titles({
      required Widget Function(double, TitleMeta) bottom,
      bool left = true,
    }) =>
        FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: left,
              reservedSize: 34,
              getTitlesWidget: (v, m) => Text(m.formattedValue, style: axis),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: bottom,
            ),
          ),
        );

    String labelKeyOf(List<Map<String, dynamic>> l) => l.isEmpty
        ? ''
        : l.first.keys.firstWhere(
            (k) => l.first[k] is String,
            orElse: () => '',
          );
    List<String> numKeysOf(List<Map<String, dynamic>> l) =>
        l.isEmpty ? [] : l.first.keys.where((k) => l.first[k] is num).toList();
    double numOf(dynamic v) => ((v as num?) ?? 0).toDouble();

    // ---------- Energy (stacked, dynamic series) ----------
    final eLabel = labelKeyOf(energy);
    final eKeys = numKeysOf(energy);
    final energyChart = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['energy_title'] ?? 'Energy generation'}',
            style: display(context, 15),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              for (int i = 0; i < eKeys.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      color: colorForSeries(c, eKeys[i], i),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      labelFor(eKeys[i]),
                      style: mutedStyle(context, size: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: energy.isEmpty
                ? const SizedBox()
                : BarChart(
                    swapAnimationDuration: const Duration(
                      milliseconds: 600,
                    ), // Changed from 'duration'
                    swapAnimationCurve: Curves.linear,
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: c.line, strokeWidth: 1),
                      ),
                      titlesData: titles(
                        bottom: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= energy.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              eLabel.isEmpty ? '$i' : '${energy[i][eLabel]}',
                              style: axis,
                            ),
                          );
                        },
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => c.sunken,
                          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                            [
                              if (eLabel.isNotEmpty) '${energy[g.x][eLabel]}',
                              ...eKeys.map(
                                (k) => '${labelFor(k)}: ${energy[g.x][k]}',
                              ),
                            ].join('\n'),
                            numStyle(context, size: 11),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < energy.length; i++)
                          () {
                            double acc = 0;
                            final items = <BarChartRodStackItem>[];
                            for (int j = 0; j < eKeys.length; j++) {
                              final v = numOf(energy[i][eKeys[j]]);
                              items.add(
                                BarChartRodStackItem(
                                  acc,
                                  acc + v,
                                  colorForSeries(c, eKeys[j], j),
                                ),
                              );
                              acc += v;
                            }
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: acc,
                                  width: 16,
                                  color: Colors.transparent,
                                  rodStackItems: items,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ],
                            );
                          }(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );

    final Widget noteCard = note == null
        ? const SizedBox()
        : Panel(
            color: c.sunken,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${note['title'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${note['body'] ?? ''}',
                  style: mutedStyle(context, size: 12),
                ),
              ],
            ),
          );

    // ---------- Scatter ----------
    final cKeys = numKeysOf(coupling);
    final Widget scatter = cKeys.length < 2
        ? Center(child: Text('No coupling data', style: mutedStyle(context)))
        : ScatterChart(
            ScatterChartData(
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: c.line, strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    FlLine(color: c.line, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(
                    '${labelFor(cKeys[0])} ${unitFor(cKeys[0])} →',
                    style: axis,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, m) =>
                        Text(m.formattedValue, style: axis),
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    '${labelFor(cKeys[1])} ${unitFor(cKeys[1])} →',
                    style: axis,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, m) =>
                        Text(m.formattedValue, style: axis),
                  ),
                ),
              ),
              scatterSpots: [
                for (final p in coupling)
                  ScatterSpot(
                    numOf(p[cKeys[0]]),
                    numOf(p[cKeys[1]]),
                    dotPainter: FlDotCirclePainter(
                      radius: 5,
                      color: c.wave.withValues(alpha: .85),
                    ),
                  ),
              ],
              scatterTouchData: ScatterTouchData(
                touchTooltipData: ScatterTouchTooltipData(
                  getTooltipColor: (_) => c.sunken,
                  getTooltipItems: (s) => ScatterTooltipItem(
                    '${labelFor(cKeys[0])}: ${s.x}\n${labelFor(cKeys[1])}: ${s.y}',
                    textStyle: numStyle(context, size: 11),
                  ),
                ),
              ),
            ),
          );

    // ---------- Daylight ----------
    final dLabel = labelKeyOf(daylight);
    final dKeys = numKeysOf(daylight);
    final Widget daylightChart = dKeys.isEmpty
        ? const SizedBox()
        : BarChart(
            swapAnimationDuration: const Duration(
              milliseconds: 600,
            ), // Changed from 'duration'
            swapAnimationCurve: Curves.linear,
            BarChartData(
              maxY: 24,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: titles(
                left: false,
                bottom: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= daylight.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dLabel.isEmpty ? '$i' : '${daylight[i][dLabel]}',
                      style: axis,
                    ),
                  );
                },
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => c.sunken,
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    formatValue(daylight[g.x][dKeys.first], dKeys.first),
                    numStyle(context, size: 11),
                  ),
                ),
              ),
              barGroups: [
                for (int i = 0; i < daylight.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: numOf(daylight[i][dKeys.first]),
                        width: 22,
                        color: c.solar,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (ctx, cons) {
        final wide = cons.maxWidth > 900;
        final cols = wide ? 3 : 1;
        final w = (cons.maxWidth - 40 - (cols - 1) * 12) / cols;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FadeRise(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data interpretation', style: display(context, 18)),
                  Text(
                    "What the fleet's readings mean, not just what they measure.",
                    style: mutedStyle(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeRise(
              index: 1,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final ins in insights)
                    SizedBox(
                      width: w,
                      child: Callout(
                        color: tone(ins['tone']),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ins['tag'] ?? ''}',
                              style: mutedStyle(context, size: 11),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${ins['title'] ?? ''} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: '${ins['body'] ?? ''}'),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.text,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeRise(
              index: 2,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: energyChart),
                        const SizedBox(width: 16),
                        SizedBox(width: 260, child: noteCard),
                      ],
                    )
                  : Column(
                      children: [
                        energyChart,
                        const SizedBox(height: 12),
                        noteCard,
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            FadeRise(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ocean — atmosphere coupling',
                    style: display(context, 15),
                  ),
                  const SizedBox(height: 8),
                  Panel(child: SizedBox(height: 240, child: scatter)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeRise(
              index: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seasonal daylight, deployment latitude',
                    style: display(context, 15),
                  ),
                  Text(
                    'Modelled sunshine hours/day by month — the primary driver of the solar curve above.',
                    style: mutedStyle(context),
                  ),
                  const SizedBox(height: 8),
                  Panel(child: SizedBox(height: 150, child: daylightChart)),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
