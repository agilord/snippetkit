/// Non-overlapping approximate occurrences of [q] in [s] within [maxDist]
/// edits, as `(distance, start, end)` ordered by start.
///
/// Edit distance with an early cutoff: about O(n * k) for `k` allowed edits,
/// instead of O(n * m). The best-scoring candidate wins any overlap.
List<(int, int, int)> fuzzySearch(String s, String q, int maxDist) {
  final m = q.length;
  final n = s.length;
  if (m == 0 || n == 0 || maxDist < 0) return const [];
  final cap = maxDist + 1; // stands for "more than maxDist"

  // Column-wise DP: dist[i] = best edit distance of q[0..i) against a
  // substring of the source ending at the current position (capped);
  // begin[i] is where that substring starts. Only rows up to `last` (the
  // last row within maxDist) can lead to a match, so later rows are skipped.
  var dist = List<int>.generate(m + 1, (i) => i < cap ? i : cap);
  var begin = List<int>.filled(m + 1, 0);
  var nextDist = List<int>.filled(m + 1, cap);
  var nextBegin = List<int>.filled(m + 1, 0);
  var last = m < maxDist ? m : maxDist;
  final candidates = <(int, int, int)>[];

  for (var j = 1; j <= n; j++) {
    final c = s.codeUnitAt(j - 1);
    nextDist[0] = 0;
    nextBegin[0] = j;
    final top = last + 1 < m ? last + 1 : m;
    for (var i = 1; i <= top; i++) {
      var d = dist[i - 1] + (q.codeUnitAt(i - 1) == c ? 0 : 1);
      var b = begin[i - 1];
      final skipSource = dist[i] + 1;
      if (skipSource < d) {
        d = skipSource;
        b = begin[i];
      }
      final skipQuote = nextDist[i - 1] + 1;
      if (skipQuote < d) {
        d = skipQuote;
        b = nextBegin[i - 1];
      }
      nextDist[i] = d;
      nextBegin[i] = b;
    }
    if (top < m) nextDist[top + 1] = cap;
    last = top;
    while (last > 0 && nextDist[last] > maxDist) {
      last--;
    }
    if (last == m && nextBegin[m] < j) {
      candidates.add((nextDist[m], nextBegin[m], j));
    }
    final td = dist;
    dist = nextDist;
    nextDist = td;
    final tb = begin;
    begin = nextBegin;
    nextBegin = tb;
  }

  // Best candidates first; earlier end wins ties.
  final order = List<int>.generate(candidates.length, (i) => i)
    ..sort((a, b) {
      final c = candidates[a].$1.compareTo(candidates[b].$1);
      return c != 0 ? c : a.compareTo(b);
    });
  final accepted = <(int, int, int)>[];
  for (final idx in order) {
    final c = candidates[idx];
    if (accepted.every((a) => c.$3 <= a.$2 || c.$2 >= a.$3)) accepted.add(c);
  }
  accepted.sort((a, b) => a.$2.compareTo(b.$2));
  return accepted;
}
