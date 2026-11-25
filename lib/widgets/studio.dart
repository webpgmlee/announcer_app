import 'dart:math';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/karaoke.dart';
import '../analysis/live_metrics.dart';
import '../analysis/syllable_rate.dart';
import '../theme.dart';

/// 녹음 중이면 빨갛게 빛나는 ON AIR 표시.
class OnAirBadge extends StatelessWidget {
  const OnAirBadge({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Palette.red : Palette.faint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 2.2),
        boxShadow: active
            ? [BoxShadow(color: Palette.red.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 2)]
            : const [],
      ),
      child: Text('ON AIR',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 15)),
    );
  }
}

/// 속도(느림/적당/빠름), 크기(작게/적당/크게) 표시.
class LevelChips extends StatelessWidget {
  const LevelChips({super.key, required this.label, required this.options, this.selected});
  final String label;
  final List<String> options;
  final int? selected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Palette.muted, fontSize: 13)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Palette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == selected ? Palette.okChip : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(options[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: i == selected ? Palette.okChipText : Palette.faint,
                        )),
                  ),
              ],
            ),
          ),
        ],
      );
}

int? speedIndex(SpeedLevel? s) => s?.index;
int loudIndex(LoudLevel l) => l.index;

/// 0.1초마다의 소리 크기 막대. "크게" 범위는 빨갛다.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.bars, this.count = 40});
  final List<double> bars;
  final int count;

  @override
  Widget build(BuildContext context) {
    // 최근 막대를 오른쪽에 붙이고, 빈 자리는 점으로 채운다.
    final recent = bars.length > count ? bars.sublist(bars.length - count) : bars;
    final empty = count - recent.length;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(child: Center(child: _bar(i < empty ? null : recent[i - empty]))),
        ],
      ),
    );
  }

  Widget _bar(double? db) {
    if (db == null) {
      return Container(
          width: 3, height: 3, decoration: const BoxDecoration(color: Palette.line, shape: BoxShape.circle));
    }
    final h = ((db + 60) / 60).clamp(0.08, 1.0) * 40;
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: db > loudDb ? Palette.red : Palette.ink,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// 진행 막대. [dots]는 자주 틀리는 곳(0~1 위치).
class ScriptProgressBar extends StatelessWidget {
  const ScriptProgressBar({super.key, required this.progress, this.dots = const []});
  final double progress;
  final List<double> dots;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                    color: Palette.line, borderRadius: BorderRadius.circular(4)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: c.maxWidth * progress.clamp(0.0, 1.0),
                height: 8,
                decoration: BoxDecoration(
                    color: Palette.blue, borderRadius: BorderRadius.circular(4)),
              ),
              for (final d in dots)
                Positioned(
                  left: (c.maxWidth * d.clamp(0.0, 1.0) - 4).clamp(0.0, c.maxWidth - 8),
                  child: const CircleAvatar(radius: 4, backgroundColor: Palette.red),
                ),
            ],
          ),
        ),
      );
}

/// 테이프 릴 두 개와 가운데 녹음 버튼.
class TapeControls extends StatefulWidget {
  const TapeControls({super.key, required this.recording, required this.onPressed});
  final bool recording;
  final VoidCallback? onPressed;

  @override
  State<TapeControls> createState() => _TapeControlsState();
}

class _TapeControlsState extends State<TapeControls> with SingleTickerProviderStateMixin {
  late final _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.recording) _spin.repeat();
  }

  @override
  void didUpdateWidget(TapeControls old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.recording && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget reel() => RotationTransition(
          turns: _spin,
          child: const CustomPaint(size: Size(52, 52), painter: _ReelPainter()),
        );
    return SizedBox(
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 26,
            right: 26,
            bottom: 14,
            child: Container(height: 1.4, color: Palette.ink),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [reel(), const SizedBox.shrink(), reel()],
          ),
          Semantics(
            button: true,
            label: widget.recording ? '정지' : '녹음 시작',
            child: GestureDetector(
              key: const ValueKey('record-button'),
              onTap: widget.onPressed,
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.recording ? 26 : 30,
                  height: widget.recording ? 26 : 30,
                  decoration: BoxDecoration(
                    color: Palette.red,
                    borderRadius: BorderRadius.circular(widget.recording ? 4 : 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPainter extends CustomPainter {
  const _ReelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final p = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c, r * 0.22, p);
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + i * 2 * pi / 3;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 0.22,
          c + Offset(cos(a), sin(a)) * r * 0.82, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 노래방식 진행 속도 조절: − 350 + (1분당 음절). 녹음 중에는 꺼진다.
class PaceControl extends StatelessWidget {
  const PaceControl({
    super.key,
    required this.pace,
    required this.enabled,
    required this.onChanged,
  });
  final double pace;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Palette.ink : Palette.faint;
    Widget button(String key, IconData icon, double delta, bool can) => SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            key: ValueKey(key),
            padding: EdgeInsets.zero,
            iconSize: 18,
            color: color,
            onPressed: enabled && can ? () => onChanged(pace + delta) : null,
            icon: Icon(icon),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('속도', style: TextStyle(color: Palette.muted, fontSize: 13)),
        const SizedBox(width: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              button('pace-minus', Icons.remove, -paceStep, pace > minPace),
              Text('${pace.round()}',
                  style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              const Text('음절/분', style: TextStyle(fontSize: 11, color: Palette.muted)),
              button('pace-plus', Icons.add, paceStep, pace < maxPace),
            ],
          ),
        ),
      ],
    );
  }
}

/// 진행 시작 전 3-2-1 숫자.
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('countdown'),
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.background.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Palette.red, width: 2),
        ),
        child: Text('$value',
            style: const TextStyle(fontSize: 48, color: Palette.red, fontWeight: FontWeight.w300)),
      );
}

/// 진행 속도보다 빠르거나 느리게 읽을 때 원고 위에 잠깐 띄우는 알림.
class PaceBadge extends StatelessWidget {
  const PaceBadge({super.key, required this.feedback});
  final PaceFeedback feedback;

  static const _fast = Color(0xFFF08C00); // 주황
  static const _slow = Palette.blue;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (feedback) {
          PaceFeedback.none => const SizedBox.shrink(key: ValueKey('pace-none')),
          PaceFeedback.fast => _pill('빨라요', Icons.fast_forward_rounded, _fast),
          PaceFeedback.slow => _pill('느려요', Icons.slow_motion_video_rounded, _slow),
        },
      );

  Widget _pill(String text, IconData icon, Color color) => Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
