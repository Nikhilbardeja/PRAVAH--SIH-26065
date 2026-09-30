import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../provider/data_provider.dart';

/// Shows the latest (Version 1) reading. Fully dynamic -
/// any new key / section from the server appears automatically.
class LiveDataScreen extends StatelessWidget {
  const LiveDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    return ListView(padding: const EdgeInsets.all(20), children: [
      FadeRise(
        index: 0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Latest reading — ${d.selectedBuoy}', style: display(context, 18)),
          const SizedBox(height: 2),
          Text('A live snapshot from the buoy, refreshed automatically.',
              style: mutedStyle(context)),
        ]),
      ),
      const SizedBox(height: 16),
      if (d.latest.isEmpty)
        Text('No data', style: mutedStyle(context))
      else
        JsonView(data: d.latest),
      const SizedBox(height: 80),
    ]);
  }
}
