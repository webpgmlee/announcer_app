// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// 시안의 색 (스펙 3.6).
abstract final class Palette {
  static const background = Color(0xFFF5F3EE);
  static const surface = Color(0xFFFBFAF7);
  static const ink = Color(0xFF1B1B1B);
  static const faint = Color(0xFFB3AFA8);
  static const muted = Color(0xFF8A867F);
  static const line = Color(0xFFDCD8D0);
  static const red = Color(0xFFE5483B);
  static const blue = Color(0xFF2F6BF0);
  static const emphasis = Color(0xFFC8D5FF);
  static const memo = Color(0xFFFDE3E1);
  static const memoText = Color(0xFFC0392B);
  static const okChip = Color(0xFFE3F1DF);
  static const okChipText = Color(0xFF2E6B2A);
}

/// 밝은 화면 하나만 쓴다 (스펙 3.6). 글꼴은 시스템 고딕을 가는 굵기로 쓴다.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.ink,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.ink,
    onPrimary: Colors.white,
    surface: Palette.background,
    onSurface: Palette.ink,
    error: Palette.red,
    surfaceContainerHighest: Palette.surface,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Palette.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.background,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
      dragHandleColor: Palette.line,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line),
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
  );
}
