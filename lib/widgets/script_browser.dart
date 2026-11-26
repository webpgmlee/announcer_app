// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/karaoke.dart';
import '../analysis/syllables.dart';
import '../data/models.dart';
import '../data/practice_state.dart';
import '../providers.dart';
import '../theme.dart';

/// 목록 선택값: 연습 중 / 전체 / 폴더 없음 / 폴더 번호.
const _practicing = -2;
const _all = -1;
const _noFolder = 0;

const _levelNames = {1: '초급', 2: '중급', 3: '고급'};
const _levelColors = {
  1: (bg: Color(0xFFE3F1DF), fg: Color(0xFF2E6B2A)),
  2: (bg: Color(0xFFFFF1C9), fg: Color(0xFF8A5A00)),
  3: (bg: Color(0xFFFDE3E1), fg: Color(0xFFB3261E)),
};

/// 제목 앞의 "초급 · " 같은 난이도 말머리는 배지로 보여주므로 빼고 쓴다.
String displayTitle(String title) => title.replaceFirst(RegExp(r'^(초급|중급|고급) · '), '');

String readingTime(int syllables) {
  final secs = (syllables * 60 / defaultPace).round();
  if (secs < 60) return '약 $secs초';
  final m = secs ~/ 60, s = secs % 60;
  return s == 0 ? '약 $m분' : '약 $m분 $s초';
}

/// 한글은 글자마다 줄이 바뀔 수 있어, 낱말 안의 글자 사이에 줄바꿈 금지 문자(U+2060)를 넣는다.
/// 줄은 띄어쓰기와 줄바꿈에서만 바뀐다.
String keepWords(String text) => text
    .split('\n')
    .map((line) => line.split(' ').map((w) => w.split('').join('⁠')).join(' '))
    .join('\n');

String _day(DateTime t) =>
    '${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';

/// 원고 목록 (원고관리·발음연습 공용).
/// 검색, 연습 중 버튼, 분야(폴더) 칩, 난이도 묶음, 카드로 보여준다.
/// 연습 중인 원고는 분야 목록에서 빠지고 "연습 중"에서만 보인다.
class ScriptBrowser extends ConsumerStatefulWidget {
  const ScriptBrowser({super.key, required this.onOpen, this.trailing});

  final void Function(Script script) onOpen;

  /// 카드 오른쪽에 둘 것 (원고관리의 메뉴 등). 없으면 화살표.
  final Widget Function(Script script, bool practicing)? trailing;

  @override
  ConsumerState<ScriptBrowser> createState() => _ScriptBrowserState();
}

class _ScriptBrowserState extends ConsumerState<ScriptBrowser> {
  int? _selected;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider).value ?? const <Script>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final stats = ref.watch(practiceStatsProvider).value ?? const <int, PracticeStat>{};
    final folderNames = {for (final f in folders) f.id: f.name};

    bool practicing(Script s) => isPracticing(s, stats[s.id]);
    final practicingList = scripts.where(practicing).toList()
      ..sort((a, b) => stats[b.id]!.last.compareTo(stats[a.id]!.last));

    // 처음에는 연습 중이 있으면 연습 중, 없으면 전체를 보여준다.
    var selected = _selected ?? (practicingList.isNotEmpty ? _practicing : _all);
    if (selected > _noFolder && !folders.any((f) => f.id == selected)) selected = _all;

    final q = _query.trim();
    final List<Script> shown;
    if (q.isNotEmpty) {
      shown = scripts.where((s) => s.title.contains(q) || s.body.contains(q)).toList();
    } else if (selected == _practicing) {
      shown = practicingList;
    } else {
      shown = scripts
          .where((s) => !practicing(s))
          .where((s) => switch (selected) {
                _all => true,
                _noFolder => s.folderId == null,
                _ => s.folderId == selected,
              })
          .toList();
    }
    final grouped = q.isEmpty && selected != _practicing && shown.any((s) => s.difficulty != null);

    Widget chip(String label, int value, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: icon == null
                ? null
                : Icon(icon, size: 16, color: selected == value ? Colors.white : Palette.ink),
            label: Text(label),
            selected: selected == value,
            showCheckmark: false,
            onSelected: (_) => setState(() => _selected = value),
          ),
        );

    final cards = <Widget>[];
    void addCard(Script s) => cards.add(ScriptCard(
          script: s,
          // 특정 폴더를 보고 있을 때는 폴더 이름을 다시 쓰지 않는다.
          folderName: q.isEmpty && selected > _noFolder ? null : folderNames[s.folderId],
          stat: stats[s.id],
          practicing: practicing(s),
          onTap: () => widget.onOpen(s),
          trailing: widget.trailing?.call(s, practicing(s)),
        ));
    if (grouped) {
      for (final level in [1, 2, 3, null]) {
        final inLevel = shown.where((s) => s.difficulty == level).toList();
        if (inLevel.isEmpty) continue;
        cards.add(_SectionHeader(level: level, count: inLevel.length));
        inLevel.forEach(addCard);
      }
    } else {
      shown.forEach(addCard);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '원고 검색 (제목·본문)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Palette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Palette.line),
              ),
            ),
          ),
        ),
        if (q.isEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                chip('연습 중 ${practicingList.length}', _practicing, icon: Icons.mic_none),
                chip('전체', _all),
                for (final f in folders) chip(f.name, f.id!),
                if (folders.isNotEmpty) chip('폴더 없음', _noFolder),
              ],
            ),
          ),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    q.isNotEmpty
                        ? '찾는 원고가 없어요'
                        : selected == _practicing
                            ? '아직 연습 중인 원고가 없어요'
                            : '이 폴더에는 원고가 없어요',
                    style: const TextStyle(color: Palette.muted, fontSize: 16),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: cards,
                ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.level, required this.count});
  final int? level;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        key: ValueKey('section-${level ?? 0}'),
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(
          children: [
            Text(_levelNames[level] ?? '기타',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.muted)),
            const SizedBox(width: 6),
            Text('$count', style: const TextStyle(color: Palette.faint)),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1)),
          ],
        ),
      );
}

/// 원고 카드: 난이도 배지, 제목, 첫 줄 미리보기, 음절·예상 시간·녹음 정보.
class ScriptCard extends StatelessWidget {
  const ScriptCard({
    super.key,
    required this.script,
    required this.onTap,
    this.folderName,
    this.stat,
    this.practicing = false,
    this.trailing,
  });

  final Script script;
  final VoidCallback onTap;
  final String? folderName;
  final PracticeStat? stat;
  final bool practicing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final level = script.difficulty;
    final preview = script.body.trim().split('\n').first;
    final meta = [
      '${countSyllables(script.body)}음절',
      readingTime(countSyllables(script.body)),
      if (stat == null) '녹음 없음' else '녹음 ${stat!.count}번',
      if (practicing && stat != null) '마지막 연습 ${_day(stat!.last)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: practicing ? Palette.red.withValues(alpha: 0.35) : Palette.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (level != null && _levelNames.containsKey(level)) ...[
                            LevelBadge(level: level),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(displayTitle(script.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Palette.muted, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(meta, style: const TextStyle(color: Palette.faint, fontSize: 12)),
                      if (folderName != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.folder_outlined, size: 13, color: Palette.faint),
                          const SizedBox(width: 3),
                          Text(folderName!,
                              style: const TextStyle(color: Palette.faint, fontSize: 12)),
                        ]),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right, color: Palette.faint),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 난이도 배지: 초급(초록), 중급(노랑), 고급(빨강).
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final c = _levelColors[level]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(_levelNames[level]!,
          style: TextStyle(fontSize: 12, color: c.fg, fontWeight: FontWeight.w600)),
    );
  }
}
