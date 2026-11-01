import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  const source =
      'The quick brown fox\njumps over the lazy dog. '
      'The quick brown fox sleeps.';

  group('find (exact)', () {
    test('finds all verbatim occurrences', () {
      final all = Source(source).find('quick brown fox', fuzzy: false);
      expect(all.map((e) => e.start), [4, 49]);
      expect(all.every((m) => m.isExact && m.score == 1.0), isTrue);
      expect(all.first.text, 'quick brown fox');
    });

    test('includes overlapping occurrences', () {
      expect(Source('aaaa').find('aa', fuzzy: false).map((e) => e.start), [
        0,
        1,
        2,
      ]);
    });

    test('no match', () {
      expect(Source(source).find('purple cat', fuzzy: false), isEmpty);
      expect(Source(source).find('', fuzzy: false), isEmpty);
    });

    test('whitespace normalization maps back to original offsets', () {
      expect(Source(source).find('fox jumps', fuzzy: false), isEmpty);
      final m = Source(source)
          .normalize(caseSensitive: true, unicode: false)
          .find('fox  jumps', fuzzy: false);
      expect(m.single.text, 'fox\njumps');
    });

    test('case-insensitive', () {
      expect(Source(source).find('LAZY DOG', fuzzy: false), isEmpty);
      final m = Source(source)
          .normalize(collapseWhitespace: false, unicode: false)
          .find('LAZY DOG', fuzzy: false);
      expect(m.single.text, 'lazy dog');
    });
  });

  group('find (fuzzy)', () {
    test('tolerates typos', () {
      final m = Source(source)
          .normalize()
          .find('jumps ovr the lazy dag')
          .single;
      expect(m.text, 'jumps over the lazy dog');
      expect(m.isExact, isFalse);
      expect(m.score, greaterThan(0.8));
    });

    test('tolerates rewrapped whitespace and case', () {
      final m = Source(source)
          .normalize()
          .find('THE QUICK BROWN\nFOX JUMPS', minScore: 0.9)
          .single;
      expect(m.text, 'The quick brown fox\njumps');
      expect(m.score, 1.0);
    });

    test('returns every non-overlapping occurrence in order', () {
      final all = Source(source).normalize().find('quick brwn fox');
      expect(all.map((m) => m.start), [4, 49]);
      expect(all.map((m) => m.text), everyElement('quick brown fox'));
    });

    test('exact matches suppress fuzzy ones', () {
      final src = Source('cat; dog; cot; pig; cut').normalize();
      expect(src.find('cat', minScore: 0.6).map((m) => m.text), ['cat']);
      expect(src.find('cxt', minScore: 0.6).map((m) => m.text), [
        'cat',
        'cot',
        'cut',
      ]);
    });

    test('empty below threshold', () {
      expect(
        Source(source).normalize().find('completely unrelated sentence'),
        isEmpty,
      );
      expect(Source('').normalize().find('abc'), isEmpty);
    });

    test('minScore controls strictness', () {
      expect(
        Source(source).normalize().find('lazy dag', minScore: 0.9),
        isEmpty,
      );
      expect(
        Source(source).normalize().find('lazy dag', minScore: 0.8).single.text,
        'lazy dog',
      );
    });
  });

  group('find (fallback)', () {
    test('prefers exact', () {
      final m = Source(source).normalize().find('brown fox');
      expect(m.map((e) => e.start), [10, 55]);
      expect(m.every((e) => e.isExact), isTrue);
    });

    test('normalized exact first, then fuzzy', () {
      expect(
        Source(source).normalize().find('Fox JUMPS').single.isExact,
        isTrue,
      );
      final f = Source(source).normalize().find('the lazy dag.').single;
      expect(f.isExact, isFalse);
      expect(f.text, 'the lazy dog.');
    });

    test('empty when absent', () {
      expect(Source(source).normalize().find('zzzzzzzzzzzz'), isEmpty);
    });
  });
}
