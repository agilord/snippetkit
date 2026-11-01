import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  group('lines', () {
    final loc = Source('ab\ncd\r\nef\rg\n');

    test('maps offsets to positions', () {
      expect(loc.lineCount, 5);
      expect(loc.positionOf(0), const TextPosition(0, 0));
      expect(loc.positionOf(2), const TextPosition(0, 2));
      expect(loc.positionOf(3), const TextPosition(1, 0));
      expect(loc.positionOf(7), const TextPosition(2, 0));
      expect(loc.positionOf(10), const TextPosition(3, 0));
      expect(loc.positionOf(12), const TextPosition(4, 0));
    });

    test('maps positions to offsets', () {
      expect(loc.offsetOf(1, 1), 4);
      expect(loc.offsetOf(2, 2), 9);
      for (var o = 0; o <= 12; o++) {
        final p = loc.positionOf(o);
        if (o != 6) expect(loc.offsetOf(p.line, p.column), o);
      }
    });

    test('line ranges exclude terminators', () {
      expect(loc.lineRange(1), const Span(3, 5));
      expect(loc.lineRange(4), const Span(12, 12));
    });

    test('validates arguments', () {
      expect(() => loc.positionOf(13), throwsRangeError);
      expect(() => loc.positionOf(-1), throwsRangeError);
      expect(() => loc.offsetOf(0, 3), throwsRangeError);
      expect(() => loc.lineRange(5), throwsRangeError);
    });

    test('empty source', () {
      expect(Source('').positionOf(0), const TextPosition(0, 0));
    });
  });

  group('normalize', () {
    test('strict by default; options are independent', () {
      const text = 'Caf\u00e9  “Bar”';
      expect(Source(text).isNormalized, isFalse);
      expect(Source(text).normalize().isNormalized, isTrue);
      expect(
        Source(text)
            .normalize(
              caseSensitive: true,
              collapseWhitespace: false,
              unicode: false,
            )
            .isNormalized,
        isFalse,
      );
      Hit one(Source s, String q) => s.find(q, fuzzy: false).single;
      expect(one(Source(text).normalize(), 'café "bar"').text, text);
      expect(
        Source(text).normalize(unicode: false).find('café "bar"', fuzzy: false),
        isEmpty,
      );
      expect(
        Source(text).normalize(caseSensitive: true).find('café', fuzzy: false),
        isEmpty,
      );
    });

    test('shares the text; offsets refer to the original', () {
      final s = Source('a\n\n b');
      final n = s.normalize();
      expect(n.text, same(s.text));
      expect(n.positionOf(4).toString(), '2:1');
      expect(n.find('a b').single.text, 'a\n\n b');
    });
  });

  test('coverage by paragraph; other boundaries are rejected', () {
    final s = Source('One fact. Two facts.\n\nThree.').normalize();
    final r = s.coverage('One fact. Nope.\n\nThree.', by: Boundary.paragraph);
    expect(r.segments.map((e) => e.text), ['One fact. Nope.', 'Three.']);
    expect(r.grounded.map((e) => e.text), ['Three.']);
    expect(() => s.coverage('x', by: Boundary.word), throwsArgumentError);
  });

  test('findEach without fuzzy', () {
    final s = Source('the lazy dog').normalize();
    expect(
      s.findEach(['lazy dag', 'lazy dog'], fuzzy: false).map((e) => e.length),
      [0, 1],
    );
    expect(s.findEach(['lazy dag']).single, hasLength(1));
  });
}
