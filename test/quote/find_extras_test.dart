import 'dart:math';

import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

int _naiveBest(String s, String q) {
  var best = q.length;
  for (var a = 0; a <= s.length; a++) {
    for (var b = a; b <= s.length; b++) {
      best = min(best, _lev(q, s.substring(a, b)));
    }
  }
  return best;
}

int _lev(String a, String b) {
  var prev = List.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(
        min(prev[j] + 1, cur[j - 1] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

void main() {
  test('fuzzy finds the optimal distance (random)', () {
    final r = Random(7);
    String gen(int n) =>
        String.fromCharCodes(List.generate(n, (_) => 97 + r.nextInt(3)));
    for (var i = 0; i < 300; i++) {
      final s = gen(4 + r.nextInt(12));
      final q = gen(3 + r.nextInt(6));
      final src = Source(s).normalize(collapseWhitespace: false);
      final matches = src.find(q, minScore: 0.0);
      final best = _naiveBest(s, q);
      final got = matches.isEmpty
          ? q.length
          : matches.map((m) => m.distance).reduce(min);
      expect(got, best, reason: '$s / $q');
      for (final m in matches) {
        expect(m.text, s.substring(m.start, m.end));
      }
    }
  });

  test('findEach is aligned; distinct avoids shared passages', () {
    const text = 'Alpha beta gamma delta. Alpha beta gamma delta.';
    final src = Source(text).normalize();
    final quotes = ['alpha beta gamma delta', 'ALPHA BETA GAMMA DELTA', 'zzz'];
    final all = src.findEach(quotes);
    expect(all.map((m) => m.length), [2, 2, 0]);
    final d = src.findEach(quotes, distinct: true);
    expect(d.map((m) => m.length), [1, 1, 0]);
    expect(d[0].single.start, 0);
    expect(d[1].single.start, 24);
    expect(src.findEach(quotes, distinct: true).length, 3);
  });

  test('coverage', () {
    const source =
        'Dart is a client-optimized language. It compiles to native code.';
    const answer =
        'Dart is a client optimized language. It runs on Mars. '
        'It compiles to native code.';
    final report = Source(source).normalize().coverage(answer);
    expect(
      [for (final s in report.segments) s.isGrounded],
      [true, false, true],
    );
    expect(report.ungrounded.single.text, 'It runs on Mars.');
    expect(report.grounded.first.best!.score, greaterThan(0.9));
    expect(report.ratio, closeTo(1 - 16 / answer.length, 0.05));
    expect(Source(source).normalize().coverage('').ratio, 0);
  });
}
