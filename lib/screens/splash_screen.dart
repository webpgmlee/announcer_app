// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme.dart';

/// 시작 화면 전체 길이: 페이드인 0.8초, 또렷하게 머무름 2.5초, 페이드아웃 0.7초.
const splashDuration = Duration(milliseconds: 4000);
const _fadeIn = 800.0;
const _hold = 2500.0;
const _fadeOut = 700.0;

/// 앱을 켜면 아이콘과 "My Diction"이 나타났다 사라진 뒤 [next]로 넘어간다.
/// 화면을 누르면 기다리지 않고 바로 넘어간다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: splashDuration);
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: _fadeIn),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _hold),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: _fadeOut),
  ]).animate(_c);
  late final Animation<double> _scale = Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(
      parent: _c,
      curve: const Interval(0, _fadeIn / (_fadeIn + _hold + _fadeOut), curve: Curves.easeOut)));
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_goNext);
  }

  void _goNext() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => widget.next,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext,
        child: Scaffold(
          backgroundColor: Palette.background,
          body: Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icon/icon.png',
                      key: const ValueKey('splash-icon'),
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'My Diction',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                        color: Palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
