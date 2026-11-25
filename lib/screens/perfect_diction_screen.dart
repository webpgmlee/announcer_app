// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme.dart';

/// 퍼펙트딕션: 아직 기능이 없어 안내만 보여준다.
class PerfectDictionScreen extends StatelessWidget {
  const PerfectDictionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('퍼펙트딕션')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 56, color: Palette.muted),
                SizedBox(height: 16),
                Text('곧 만나요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                SizedBox(height: 8),
                Text('더 또렷하게 읽도록 돕는 기능을 준비하고 있어요.',
                    textAlign: TextAlign.center, style: TextStyle(color: Palette.muted)),
              ],
            ),
          ),
        ),
      );
}
