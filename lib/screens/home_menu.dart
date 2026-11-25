// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme.dart';
import 'perfect_diction_screen.dart';
import 'practice_pick_screen.dart';
import 'recordings_screen.dart';
import 'script_manage_screen.dart';

/// 스토어에 낼 때 기능이 생기기 전까지 퍼펙트딕션을 숨기려면
/// `--dart-define=SHOW_PERFECT_DICTION=false`로 빌드한다.
const showPerfectDictionByDefault =
    bool.fromEnvironment('SHOW_PERFECT_DICTION', defaultValue: true);

/// 시작 화면 다음의 메인 메뉴: 발음연습 / 원고관리 / 녹음관리 / 퍼펙트딕션.
class HomeMenu extends StatelessWidget {
  const HomeMenu({super.key, this.showPerfectDiction = showPerfectDictionByDefault});
  final bool showPerfectDiction;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MenuCard(
        label: '발음연습',
        description: '원고를 골라 바로 녹음',
        icon: Icons.mic_none,
        onTap: () => _open(context, const PracticePickScreen()),
      ),
      _MenuCard(
        label: '원고관리',
        description: '원고와 폴더 정리',
        icon: Icons.article_outlined,
        onTap: () => _open(context, const ScriptManageScreen()),
      ),
      _MenuCard(
        label: '녹음관리',
        description: '지난 연습 녹음',
        icon: Icons.graphic_eq,
        onTap: () => _open(context, const RecordingsScreen()),
      ),
      if (showPerfectDiction)
        _MenuCard(
          label: '퍼펙트딕션',
          description: '준비 중',
          icon: Icons.auto_awesome_outlined,
          dimmed: true,
          onTap: () => _open(context, const PerfectDictionScreen()),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Diction',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('오늘도 또렷하게, 온에어.', style: TextStyle(color: Palette.muted)),
              const SizedBox(height: 28),
              Expanded(
                // 카드 두 줄이 화면 높이 안에 모두 들어가도록 비율을 맞춘다 (가로 화면 포함).
                child: LayoutBuilder(builder: (context, c) {
                  const gap = 14.0;
                  final cellW = (c.maxWidth - gap) / 2;
                  final cellH = (c.maxHeight - gap) / 2;
                  return GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: (cellW / cellH).clamp(0.6, 3.0),
                    physics: const NeverScrollableScrollPhysics(),
                    children: cards,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
    this.dimmed = false,
  });
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Material(
        color: dimmed ? Palette.background : Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Palette.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dimmed ? Palette.line : Palette.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: dimmed ? Palette.muted : Palette.background),
                ),
                const Spacer(),
                Text(label,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: dimmed ? Palette.muted : Palette.ink)),
                const SizedBox(height: 4),
                Text(description,
                    style: TextStyle(
                        fontSize: 13, color: dimmed ? Palette.red : Palette.muted)),
              ],
            ),
          ),
        ),
      );
}
