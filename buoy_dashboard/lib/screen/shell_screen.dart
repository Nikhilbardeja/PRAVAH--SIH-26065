import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../provider/data_provider.dart';
import '../provider/theme_provider.dart';
import 'comparison_screen.dart';
import 'history_screen.dart';
import 'interpretation_screen.dart';
import 'live_data_screen.dart';
import 'overview_screen.dart';

class _NavPage {
  const _NavPage(this.title, this.icon, this.build);
  final String title;
  final IconData icon;
  final Widget Function() build;
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;

  final List<_NavPage> pages = [
    _NavPage(
        'Fleet overview', Icons.public_rounded, () => const OverviewScreen()),
    _NavPage(
        'Live readings', Icons.sensors_rounded, () => const LiveDataScreen()),
    _NavPage('History', Icons.show_chart_rounded, () => const HistoryScreen()),
    _NavPage('Comparison', Icons.compare_arrows_rounded,
        () => const ComparisonScreen()),
    _NavPage('Insights', Icons.tips_and_updates_rounded,
        () => const InterpretationScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DataProvider>();
    final c = context.c;

    Widget content;
    if (d.loading && d.updatedAt == null) {
      content = const _LoadingState(key: ValueKey('loading'));
    } else if (d.error != null) {
      content = ErrorPanel(
          key: const ValueKey('error'), message: d.error!, onRetry: d.load);
    } else {
      content = pages[index].build();
    }

    return Scaffold(
      extendBody: true,
      floatingActionButton:
          _SourceToggle(useMock: d.useMock, onTap: d.toggleSource),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: c.backdrop),
        child: SafeArea(
          child: LayoutBuilder(builder: (ctx, cons) {
            final wide = cons.maxWidth >= 760;
            final main = Column(children: [
              _Header(title: pages[index].title),
              if (!wide)
                _HorizontalNav(
                    pages: pages,
                    index: index,
                    onTap: (i) => setState(() => index = i)),
              if (d.loading)
                LinearProgressIndicator(
                    minHeight: 2,
                    color: c.teal,
                    backgroundColor: Colors.transparent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: SoftSwitcher(
                    keyed: ValueKey(
                        '$index-${d.useMock}-${d.selectedBuoy}-${content.key}'),
                    child: content,
                  ),
                ),
              ),
              const _Footer(),
            ]);
            if (!wide) return main;
            return Row(children: [
              _Sidebar(
                  pages: pages,
                  index: index,
                  onTap: (i) => setState(() => index = i)),
              Expanded(child: main),
            ]);
          }),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(height: 14),
          Text('Reading the buoys…', style: mutedStyle(context)),
        ]),
      );
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.useMock, required this.onTap});
  final bool useMock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FloatingActionButton.extended(
      backgroundColor: c.teal,
      foregroundColor: c.bg,
      elevation: 2,
      shape: const StadiumBorder(),
      tooltip: useMock ? 'Switch to live server data' : 'Switch to sample data',
      onPressed: onTap,
      icon: AnimatedSwitcher(
        duration: Motion.fast,
        transitionBuilder: (w, a) => RotationTransition(turns: a, child: w),
        child: Icon(useMock ? Icons.storage_rounded : Icons.cloud_done_rounded,
            key: ValueKey(useMock)),
      ),
      label: Text(useMock ? 'Sample data' : 'Live data'),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar(
      {required this.pages, required this.index, required this.onTap});
  final List<_NavPage> pages;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final buoys = (context.watch<DataProvider>().fleet['buoys'] as List? ?? []);
    final deployed =
        buoys.where((b) => b is Map && b['latitude'] != null).length;
    final online =
        buoys.where((b) => b is Map && '${b['status']}' == 'online').length;

    return Container(
      width: 232,
      decoration: BoxDecoration(
          color: c.sunken, border: Border(right: BorderSide(color: c.line))),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PravahMark(size: 26),
          const SizedBox(width: 10),
          Text('Pravah',
              style: display(context, 21, w: FontWeight.w600, color: c.teal)),
        ]),
        const SizedBox(height: 4),
        Text('Southern Ocean buoy network',
            style: mutedStyle(context, size: 11)),
        const SizedBox(height: 28),
        for (int i = 0; i < pages.length; i++)
          _SidebarItem(
              page: pages[i], selected: i == index, onTap: () => onTap(i)),
        const Spacer(),
        Divider(color: c.line),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$deployed', style: display(context, 28)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('buoys deployed', style: mutedStyle(context, size: 11)),
          ),
        ]),
        Row(children: [
          PulsingDot(color: online > 0 ? c.aurora : c.muted, size: 6),
          const SizedBox(width: 6),
          Text('$online reporting on schedule',
              style: mutedStyle(context, size: 11)),
        ]),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(
      {required this.page, required this.selected, required this.onTap});
  final _NavPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Pressable(
        onTap: onTap,
        borderRadius: 9,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? c.line : Colors.transparent),
          ),
          child: Row(children: [
            Icon(page.icon, size: 17, color: selected ? c.teal : c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(page.title,
                  style: TextStyle(
                      fontSize: 13,
                      color: selected ? c.text : c.muted,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400)),
            ),
            AnimatedOpacity(
              duration: Motion.fast,
              opacity: selected ? 1 : 0,
              child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: c.teal, shape: BoxShape.circle)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HorizontalNav extends StatelessWidget {
  const _HorizontalNav(
      {required this.pages, required this.index, required this.onTap});
  final List<_NavPage> pages;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 50,
      color: c.sunken,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Pressable(
          onTap: () => onTap(i),
          borderRadius: 8,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: i == index ? c.panel : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: i == index ? c.line : Colors.transparent)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(pages[i].icon,
                  size: 15, color: i == index ? c.teal : c.muted),
              const SizedBox(width: 7),
              Text(pages[i].title,
                  style: TextStyle(
                      fontSize: 13,
                      color: i == index ? c.text : c.muted,
                      fontWeight:
                          i == index ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = context.watch<DataProvider>();
    final tp = context.watch<ThemeProvider>();
    final dark = tp.isDark(context);
    final t = d.updatedAt;
    final time = t == null
        ? '—'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final buoys = [
      for (final b in (d.fleet['buoys'] as List? ?? []))
        Map<String, dynamic>.from(b)
    ];
    String labelOf(String id) {
      final match = buoys.where((b) => b['id'] == id);
      if (match.isEmpty) return id;
      final name = match.first['name'];
      return name == null ? id : '$id · $name';
    }

    Widget pill(String label, bool active, VoidCallback onTap) => Pressable(
          onTap: onTap,
          borderRadius: 20,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: active ? c.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? c.bg : c.muted,
                    fontWeight: FontWeight.w600)),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: display(context, 21)),
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!d.lastPollFailed && !d.useMock) ...[
                    PulsingDot(color: c.aurora, size: 6),
                    const SizedBox(width: 6),
                  ] else if (d.lastPollFailed) ...[
                    Icon(Icons.wifi_off_rounded, size: 12, color: c.alert),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      d.lastPollFailed
                          ? 'Connection lost · showing the last data from $time'
                          : '${d.fleet['region'] ?? ''} · updated $time',
                      overflow: TextOverflow.ellipsis,
                      style: display(context, 11,
                          italic: true,
                          color: d.lastPollFailed ? c.alert : c.muted,
                          w: FontWeight.w400),
                    ),
                  ),
                ]),
              ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: c.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.line)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: d.selectedBuoy,
                  isDense: true,
                  dropdownColor: c.panel,
                  icon:
                      Icon(Icons.expand_more_rounded, size: 18, color: c.muted),
                  style: TextStyle(color: c.text, fontSize: 13),
                  items: d.buoyIds
                      .map((id) =>
                          DropdownMenuItem(value: id, child: Text(labelOf(id))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) d.selectBuoy(v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                pill('Light', !dark, () => tp.setMode(ThemeMode.light)),
                pill('Dark', dark, () => tp.setMode(ThemeMode.dark)),
              ]),
            ),
            const SizedBox(width: 4),
            Pressable(
              onTap: d.load,
              borderRadius: 18,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.refresh_rounded, size: 18, color: c.muted),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.c.line))),
        child: Text(
            'Pravah — the flow of the Southern Ocean, watched in real time.',
            style: mutedStyle(context, size: 11)),
      );
}
