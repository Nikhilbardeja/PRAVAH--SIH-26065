import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/core.dart';
import 'provider/data_provider.dart';
import 'provider/theme_provider.dart';
import 'screen/shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => DataProvider()..load()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pravah',
      theme: buildTheme(AppColors.light, Brightness.light),
      darkTheme: buildTheme(AppColors.dark, Brightness.dark),
      themeMode: tp.mode,
      home: const ShellScreen(),
    );
  }
}
