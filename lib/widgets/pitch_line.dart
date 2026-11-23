import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/intonation.dart';
import '../analysis/pitch.dart';

/// 그릴 점이 너무 많으면 이 개수 정도로 줄인다 (5분 = 3만 점).
const _maxPoints = 1500;

/// 목소리 높낮이 선. 높이는 반음 단위(로그 스케일)로 그려 남녀 목소리 모두 비슷하게 보인다.
/// [report]가 있으면 단조 구간은 회색 띠, 문장 끝 올림은 주황 세로선으로 표시한다.
/// [window]가 있으면 마지막 그 시간만 보여준다 (녹음 중 실시간 표시용).
class PitchLine extends StatelessWidget {
  const PitchLine({
    super.key,
    required this.pitch,
    this.report,
    this.window,
    this.cursor,
    this.height = 140,
  });

  final List<PitchPoint> pitch;
  final IntonationReport? report;
  final Duration? window;
  final Duration? cursor;
  final double height;

  static double _st(double hz) => 12 * log(hz / 100) / ln2;
  static double _sec(Duration d) => d.inMilliseconds / 1000;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = pitch.isEmpty ? 0.0 : _sec(pitch.last.t);
    final minX = window == null ? 0.0 : max(0.0, last - _sec(window!));
    final maxX = window == null ? max(last, 1.0) : max(last, _sec(window!));

    final visible = window == null
        ? pitch
        : pitch.where((p) => _sec(p.t) >= minX).toList();
    final step = max(1, (visible.length / _maxPoints).ceil());
    final spots = <FlSpot>[];
    for (var i = 0; i < visible.length; i += step) {
      final p = visible[i];
      spots.add(p.hz == null ? FlSpot.nullSpot : FlSpot(_sec(p.t), _st(p.hz!)));
    }
    final ys = spots.where((s) => s != FlSpot.nullSpot).map((s) => s.y);
    final minY = ys.isEmpty ? 0.0 : ys.reduce(min) - 2;
    final maxY = ys.isEmpty ? 24.0 : ys.reduce(max) + 2;

    return SizedBox(
      height: height,
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
            for (final r in report?.flatRanges ?? const <DurationRange>[])
              VerticalRangeAnnotation(
                x1: _sec(r.start),
                x2: _sec(r.end),
                color: scheme.onSurface.withValues(alpha: 0.12),
              ),
          ]),
          extraLinesData: ExtraLinesData(verticalLines: [
            for (final t in report?.risingEnds ?? const <Duration>[])
              VerticalLine(x: _sec(t), color: Colors.orange, strokeWidth: 2),
            if (cursor != null)
              VerticalLine(x: _sec(cursor!), color: scheme.primary, strokeWidth: 1),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2.5,
              color: scheme.primary,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
