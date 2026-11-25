// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../data/models.dart';

/// 폴더 칩 선택값: [allFolders] 전체, [noFolder] 폴더 없음, 그 밖은 폴더 번호.
const allFolders = -1;
const noFolder = 0;

bool inFolder(Script s, int selection) => switch (selection) {
      allFolders => true,
      noFolder => s.folderId == null,
      _ => s.folderId == selection,
    };

/// 전체 / 폴더들 / 폴더 없음 칩. 폴더가 하나도 없으면 아무것도 그리지 않는다.
class FolderChips extends StatelessWidget {
  const FolderChips({
    super.key,
    required this.folders,
    required this.selected,
    required this.onSelected,
  });
  final List<Folder> folders;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) return const SizedBox.shrink();
    Widget chip(String label, int value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          chip('전체', allFolders),
          for (final f in folders) chip(f.name, f.id!),
          chip('폴더 없음', noFolder),
        ],
      ),
    );
  }
}
