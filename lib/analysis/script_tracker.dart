import 'dart:typed_data';

import 'script_layout.dart';

/// 이보다 크게 앞으로 튀는 위치는 연속 두 번 같은 근처로 나올 때만 받아들인다.
const maxJumpUnits = 30;

/// 두 번의 결과를 "같은 근처"로 볼 거리.
const jumpConfirmTolerance = 5;

/// 들린 글 단위 대비 편집 비용이 이 비율을 넘으면 믿지 않는다 (다른 글을 읽는 중).
const maxAlignCostRatio = 0.5;

/// 들린 글 전체를 원고 앞부분에 맞춘다(원고 뒤쪽은 비용 없이 남김).
/// 들린 글 끝이 닿은 원고 단위 위치와 그때의 편집 비용을 돌려준다.
/// 비용이 같으면 앞쪽 위치를 고른다 (앞서 나가지 않도록).
({int end, int cost}) alignHeardEnd(List<String> script, List<String> heard) {
  final n = script.length, m = heard.length;
  // prev[i] = 원고 앞 i단위와 들린 글 앞 j단위의 편집 거리 (j를 한 줄씩 진행)
  var prev = Int32List(n + 1);
  for (var i = 0; i <= n; i++) {
    prev[i] = i;
  }
  for (var j = 1; j <= m; j++) {
    final cur = Int32List(n + 1)..[0] = j;
    for (var i = 1; i <= n; i++) {
      final sub = prev[i - 1] + (script[i - 1] == heard[j - 1] ? 0 : 1);
      final del = cur[i - 1] + 1; // 원고 단위를 건너뜀
      final ins = prev[i] + 1; // 들린 단위가 원고에 없음
      var best = sub < del ? sub : del;
      if (ins < best) best = ins;
      cur[i] = best;
    }
    prev = cur;
  }
  var end = 0;
  for (var i = 1; i <= n; i++) {
    if (prev[i] < prev[end]) end = i;
  }
  return (end: end, cost: prev[end]);
}

/// 녹음 중 원고의 어디를 읽는지 따라간다. 위치는 원고 읽는 소리 단위(음절) 기준이다.
class ScriptTracker {
  ScriptTracker(String body) : _units = readUnits(body);

  final List<String> _units;
  int _position = 0;
  int? _pendingJump;

  int get total => _units.length;
  int get position => _position;
  double get progress => total == 0 ? 0 : _position / total;

  /// 실시간 인식이 내놓은 "지금까지 들린 전체 글".
  void onHeard(String fullText) {
    if (total == 0) return;
    final heard = readUnits(fullText);
    if (heard.isEmpty) return;
    final r = alignHeardEnd(_units, heard);
    if (r.cost > heard.length * maxAlignCostRatio) return;
    _moveTo(r.end);
  }

  /// 실시간 인식이 늦을 때 목소리 시간으로 추정한 위치.
  void onEstimate(int units) {
    final target = units.clamp(0, total);
    if (target > _position) _position = target;
    _pendingJump = null;
  }

  void _moveTo(int target) {
    if (target <= _position) {
      _pendingJump = null;
      return;
    }
    if (target - _position > maxJumpUnits) {
      final pending = _pendingJump;
      if (pending != null && (pending - target).abs() <= jumpConfirmTolerance) {
        _position = target;
        _pendingJump = null;
      } else {
        _pendingJump = target;
      }
      return;
    }
    _position = target;
    _pendingJump = null;
  }
}
