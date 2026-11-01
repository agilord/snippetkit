import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  const text =
      'Alpha beta gamma. Delta epsilon zeta.\n\n'
      'Eta theta iota kappa. Lambda mu nu xi omicron.\n'
      'Pi rho sigma tau upsilon phi chi psi omega.';

  test('tiles the text exactly without overlap', () {
    for (final size in [10, 25, 40, 80]) {
      final chunks = Source(text).chunks(maxLength: size);
      expect(chunks.map((c) => c.text).join(), text, reason: '$size');
      expect(chunks.every((c) => c.text.length <= size), isTrue);
      for (final c in chunks) {
        expect(text.substring(c.start, c.end), c.text);
      }
    }
  });

  test('prefers paragraph, then sentence boundaries', () {
    final chunks = Source(text).chunks(maxLength: 45);
    expect(chunks.first.text, 'Alpha beta gamma. Delta epsilon zeta.\n\n');
    expect(chunks[1].text, endsWith('kappa. '));
  });

  test('does not cut inside words when whitespace is available', () {
    final chunks = Source(text).chunks(maxLength: 14);
    for (final c in chunks.take(chunks.length - 1)) {
      expect(c.text, matches(RegExp(r'\s$')), reason: c.text);
    }
  });

  test('overlap repeats text and starts on a word', () {
    final chunks = Source(text).chunks(maxLength: 30, overlap: 10);
    expect(chunks.length, greaterThan(2));
    for (var i = 1; i < chunks.length; i++) {
      expect(chunks[i].start, lessThan(chunks[i - 1].end));
      expect(chunks[i].start, greaterThan(chunks[i - 1].start));
      expect(text[chunks[i].start - 1], matches(RegExp(r'\s')));
    }
    expect(chunks.last.end, text.length);
  });

  test('hard cut without whitespace, never splitting surrogates', () {
    final chunks = Source('x' * 25).chunks(maxLength: 10);
    expect(chunks.map((c) => c.text.length), [10, 10, 5]);
    final emoji = Source('😀' * 6).chunks(maxLength: 5);
    expect(emoji.map((c) => c.text).join(), '😀' * 6);
    expect(emoji.every((c) => c.text.length.isEven), isTrue);
  });

  test('edge cases', () {
    expect(Source('').chunks(maxLength: 10), isEmpty);
    expect(Source('short').chunks(maxLength: 10).single.text, 'short');
    expect(() => Source('a').chunks(maxLength: 1), throwsArgumentError);
    expect(
      () => Source('a').chunks(maxLength: 5, overlap: 5),
      throwsArgumentError,
    );
  });
}
