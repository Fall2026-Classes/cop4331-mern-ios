import 'package:flutter/material.dart';

import 'api.dart';
import 'auth_screens.dart';
import 'diary_screen.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  runApp(ReelTalkApp(loggedIn: Api.token != null));
}

class ReelTalkApp extends StatelessWidget {
  const ReelTalkApp({super.key, this.loggedIn = false});
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
    ).copyWith(primary: kAccent, onPrimary: Colors.black, surface: kSurface, error: kDanger);

    return MaterialApp(
      title: 'ReelTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(backgroundColor: kSurface, foregroundColor: kText, elevation: 0),
        cardTheme: const CardThemeData(color: kSurface, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
        ),
      ),
      home: loggedIn ? const DiaryScreen() : const LoginScreen(),
    );
  }
}
