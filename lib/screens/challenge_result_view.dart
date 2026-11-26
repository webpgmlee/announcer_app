// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/compare.dart';
import '../analysis/diction_score.dart';
import '../theme.dart';
import '../widgets/marked_script.dart';

/// 퍼펙트딕션 도전 결과: 딕션 점수(올라가는 효과), 별, PERFECT, 정확도·속도, 다르게 들린 단어.
/// 발음을 평가한다는 표현은 쓰지 않는다 (폰 안의 음성 인식 기준이라 미세한 발음은 판단하지 못한다).
class ChallengeResultView extends StatelessWidget {
  const ChallengeResultView({
    super.key,
    required this.score,
    required this.targetPace,
    required this.onRetry,
    required this.onExit,
    this.marks,
    this.newBest = false,
    this.message,
  });

  final DictionScore score;
  final double targetPace;
  final List<WordMark>? marks;
  final bool newBest;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              if (score.perfect)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PERFECT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: score.total),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '$v',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
              ),
              const Text('딕션 점수', style: TextStyle(color: Palette.muted)),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < score.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: i < score.stars
                          ? const Color(0xFFF2B300)
                          : Palette.line,
                    ),
                ],
              ),
              if (newBest) ...[
                const SizedBox(height: 6),
                const Chip(
                  label: Text('최고 기록!'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Row(
          label: '정확도 (음성 인식 기준)',
          value: Text(
            '${score.accuracy.round()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          fill: score.accuracy / 100,
        ),
        const SizedBox(height: 12),
        _Row(
          label: '속도',
          value: Text(
            '${score.measuredPace.round()}음절/분 (목표 ${targetPace.round()})',
            style: const TextStyle(fontSize: 15),
          ),
          fill: score.speed / 100,
        ),
        if (marks != null && marks!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('다르게 들린 단어', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          MarkedScript(marks: marks!),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 도전'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: onExit,
          child: const Text('목록으로'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.fill});
  final String label;
  final Widget value;
  final double fill;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(color: Palette.muted)),
          const Spacer(),
          value,
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fill.clamp(0.0, 1.0),
          minHeight: 8,
          color: Palette.ink,
          backgroundColor: Palette.line,
        ),
      ),
    ],
  );
}
