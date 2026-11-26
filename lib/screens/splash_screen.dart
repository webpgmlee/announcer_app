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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 폰에서 애니메이션을 꺼 두면(삼성 절전 모드·애니메이션 제거 등) Flutter는 애니메이션 시간을
  // 5%로 줄인다. 시작 화면은 "보여주는 시간"을 이 컨트롤러로 재므로, 시간은 그대로 지킨다.
  late final _c = AnimationController(
    vsync: this,
    duration: splashDuration,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: _fadeIn,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _hold),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: _fadeOut,
    ),
  ]).animate(_c);
  late final Animation<double> _scale = Tween(begin: 0.94, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(
        0,
        _fadeIn / (_fadeIn + _hold + _fadeOut),
        curve: Curves.easeOut,
      ),
    ),
  );
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_goNext);
  }

  void _goNext() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 애니메이션을 꺼 둔 사용자에게는 나타나고 사라지는 효과 없이 바로 또렷하게 보여준다.
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _goNext,
      child: Scaffold(
        backgroundColor: Palette.background,
        body: Center(
          child: FadeTransition(
            opacity: still ? kAlwaysCompleteAnimation : _opacity,
            child: ScaleTransition(
              scale: still ? kAlwaysCompleteAnimation : _scale,
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
}
