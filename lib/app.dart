// material_ui 패키지로 옮기기 전까지 프레임워크의 material을 쓴다.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'screens/home_menu.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

export 'providers.dart';

class AnnouncerApp extends StatelessWidget {
  const AnnouncerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'My Diction',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(next: HomeMenu()),
      );
}
