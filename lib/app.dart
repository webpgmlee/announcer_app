// material_ui 패키지로 옮기기 전까지 프레임워크의 material을 쓴다.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'data/models.dart';
import 'screens/history_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/script_list_screen.dart';

export 'providers.dart';

class AnnouncerApp extends StatelessWidget {
  const AnnouncerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '아나운서 연습',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4E89)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D4E89),
            brightness: Brightness.dark,
          ),
        ),
        home: const ScriptListScreen(onOpen: openPractice),
      );
}

void openPractice(BuildContext context, Script script) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(script: script, onOpenHistory: openHistory)));

void openHistory(BuildContext context, Script script) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(script: script)));
