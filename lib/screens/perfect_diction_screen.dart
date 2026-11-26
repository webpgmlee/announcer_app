// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/challenge_repository.dart';
import '../data/models.dart';
import '../data/twisters.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/script_browser.dart';
import 'challenge_screen.dart';

/// 퍼펙트딕션: 잰말놀이(1~3단계, 별을 모아 다음 단계)와 내 원고로 도전한다.
class PerfectDictionScreen extends ConsumerWidget {
  const PerfectDictionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best =
        ref.watch(challengeBestProvider).value ??
        const <String, ChallengeBest>{};
    final twisterStars = {
      for (final t in twisters) t.id: best[twisterKey(t.id)]?.stars ?? 0,
    };
    final collected = twisterStars.values.fold(0, (a, b) => a + b);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('퍼펙트딕션'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '★ $collected / ${twisters.length * 3}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Palette.ink,
            indicatorColor: Palette.ink,
            tabs: [
              Tab(text: '잰말놀이'),
              Tab(text: '내 원고'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TwisterList(best: best, stars: twisterStars),
            _MyScripts(best: best),
          ],
        ),
      ),
    );
  }
}

Future<void> _openChallenge(
  BuildContext context,
  WidgetRef ref, {
  required String key,
  required String title,
  required String body,
  required double pace,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChallengeScreen(
        challengeKey: key,
        title: title,
        body: body,
        pace: pace,
      ),
    ),
  );
  ref.invalidate(challengeBestProvider);
}

class _TwisterList extends ConsumerWidget {
  const _TwisterList({required this.best, required this.stars});
  final Map<String, ChallengeBest> best;
  final Map<String, int> stars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];
    for (final stage in [1, 2, 3]) {
      final open = stageUnlocked(stage, stars);
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stage단계 · 목표 ${stagePace(stage).round()}음절/분',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Palette.muted,
                ),
              ),
              if (!open)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🔒 ${stage - 1}단계에서 별 $starsToUnlock개를 모으면 열려요 '
                    '(지금 ${starsInStage(stage - 1, stars)}개)',
                    style: const TextStyle(fontSize: 13, color: Palette.faint),
                  ),
                ),
            ],
          ),
        ),
      );
      for (final t in twisters.where((t) => t.stage == stage)) {
        final b = best[twisterKey(t.id)];
        children.add(
          _ChallengeCard(
            title: t.title,
            preview: t.body,
            best: b,
            locked: !open,
            onTap: () {
              if (!open) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('앞 단계에서 별을 5개 모아 주세요')),
                  );
                return;
              }
              _openChallenge(
                context,
                ref,
                key: twisterKey(t.id),
                title: t.title,
                body: t.body,
                pace: stagePace(stage),
              );
            },
          ),
        );
      }
    }
    return ListView(
      key: const ValueKey('twister-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: children,
    );
  }
}

class _MyScripts extends ConsumerWidget {
  const _MyScripts({required this.best});
  final Map<String, ChallengeBest> best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsProvider).value ?? const <Script>[];
    if (scripts.isEmpty) {
      return const Center(
        child: Text(
          '원고관리에서 원고를 추가해 주세요',
          style: TextStyle(color: Palette.muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final s in scripts)
          _ChallengeCard(
            title: displayTitle(s.title),
            preview: s.body.trim().split('\n').first,
            best: best[scriptKey(s.id!)],
            onTap: () async {
              final pace = await ref.read(settingsRepositoryProvider).pace();
              if (!context.mounted) return;
              await _openChallenge(
                context,
                ref,
                key: scriptKey(s.id!),
                title: displayTitle(s.title),
                body: s.body,
                pace: pace,
              );
            },
          ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.title,
    required this.preview,
    required this.onTap,
    this.best,
    this.locked = false,
  });
  final String title;
  final String preview;
  final ChallengeBest? best;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stars = best?.stars ?? 0;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Palette.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Icon(
                              i < stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 20,
                              color: i < stars
                                  ? const Color(0xFFF2B300)
                                  : Palette.line,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        best == null ? '-' : '${best!.score}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                  if (locked) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Palette.faint,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
