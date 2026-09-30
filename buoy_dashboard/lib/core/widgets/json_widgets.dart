import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common_widgets.dart';

// ================= DYNAMIC JSON RENDERING =================
// Any new key / section in the JSON is displayed automatically.

/// Renders ANY map. Nested maps -> cards, lists -> tables/chips,
/// primitive values -> metric rows.
class JsonView extends StatelessWidget {
  const JsonView({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final prim = <String, dynamic>{};
    data.forEach((k, v) {
      if (v is! Map && v is! List) prim[k] = v;
    });

    final cards = <Widget>[];
    int i = 0;
    if (prim.isNotEmpty) {
      cards.add(FadeRise(
          index: i++, child: SectionCard(title: 'At a glance', data: prim)));
    }
    data.forEach((k, v) {
      if (v is Map) {
        cards.add(FadeRise(
          index: i++,
          child: SectionCard(
              title: labelFor(k),
              sectionKey: k,
              data: Map<String, dynamic>.from(v)),
        ));
      } else if (v is List) {
        cards.add(FadeRise(
          index: i++,
          child: Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(labelFor(k), style: display(context, 16)),
              const SizedBox(height: 12),
              ListValue(list: v),
            ]),
          ),
        ));
      }
    });

    return LayoutBuilder(builder: (ctx, cons) {
      final cols = cons.maxWidth > 1100
          ? 3
          : cons.maxWidth > 680
              ? 2
              : 1;
      final w = (cons.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.title,
      required this.data,
      this.sectionKey = ''});
  final String title, sectionKey;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final accent = sectionColor(context.c, sectionKey);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: display(context, 16))),
          Text('${data.length}', style: mutedStyle(context, size: 11)),
        ]),
        const SizedBox(height: 12),
        ...data.entries.map((e) {
          final v = e.value;
          if (v is Map) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SectionCard(
                  title: labelFor(e.key),
                  sectionKey: e.key,
                  data: Map<String, dynamic>.from(v)),
            );
          }
          if (v is List) {
            return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListValue(list: v));
          }
          return MetricRow(keyName: e.key, value: v);
        }),
      ]),
    );
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.keyName, required this.value});
  final String keyName;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget valueWidget;
    if (value is String) {
      final text = value as String;
      final col = statusColor(c, text);
      final isStatus = col != c.muted;
      valueWidget = isStatus
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: col.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(text,
                  style: numStyle(context,
                      size: 12, color: col, w: FontWeight.w600)),
            )
          : Flexible(
              child: Text(text,
                  textAlign: TextAlign.right,
                  style: numStyle(context, size: 13)));
    } else {
      final unit = unitFor(keyName);
      valueWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value is num ? '$value' : formatValue(value, keyName),
                style: numStyle(context, size: 14, w: FontWeight.w600)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(unit, style: mutedStyle(context, size: 11)),
            ],
          ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        Expanded(
            child:
                Text(labelFor(keyName), style: mutedStyle(context, size: 13))),
        valueWidget,
      ]),
    );
  }
}

class ListValue extends StatelessWidget {
  const ListValue({super.key, required this.list});
  final List list;

  @override
  Widget build(BuildContext context) {
    if (list.isNotEmpty && list.every((e) => e is Map)) {
      return DynamicTable(rows: list);
    }
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in list)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: context.c.sunken, borderRadius: BorderRadius.circular(6)),
          child: Text('$e', style: numStyle(context, size: 12)),
        ),
    ]);
  }
}

/// Table whose columns are built from the keys of the rows.
class DynamicTable extends StatelessWidget {
  const DynamicTable(
      {super.key, required this.rows, this.hide = const {}, this.cell});
  final List rows;
  final Set<String> hide;
  final Widget? Function(Map row, String key)? cell;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text('No data', style: mutedStyle(context));
    final keys = <String>[];
    for (final r in rows) {
      for (final k in (r as Map).keys) {
        final ks = k.toString();
        if (!keys.contains(ks) && !hide.contains(ks)) keys.add(ks);
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 42,
        columnSpacing: 36,
        horizontalMargin: 4,
        dividerThickness: .6,
        headingTextStyle: mutedStyle(context),
        columns: keys.map((k) => DataColumn(label: Text(labelFor(k)))).toList(),
        rows: rows.map((r) {
          final m = r as Map;
          return DataRow(
            cells: keys
                .map((k) => DataCell(
                      cell?.call(m, k) ??
                          Text(formatValue(m[k], k),
                              style: numStyle(context, size: 13)),
                    ))
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}
