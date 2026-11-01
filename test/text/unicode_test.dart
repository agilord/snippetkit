import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeUnicode folds typographic characters', () {
    expect(
      normalizeUnicode('“Hi” – it’s a ﬁne day… ＡＢＣ x​y'),
      '"Hi" - it\'s a fine day... ABC xy',
    );
    expect(normalizeUnicode('plain ascii é'), 'plain ascii é');
  });

  test('find matches across typographic differences', () {
    const source = 'He said “it’s a well‑known fact” — really.';
    final m = Source(source)
        .normalize(caseSensitive: true, collapseWhitespace: false)
        .find('it\'s a well-known fact', fuzzy: false);
    expect(m.single.text, 'it’s a well‑known fact');
    expect(
      Source(source).find('it\'s a well-known fact', fuzzy: false),
      isEmpty,
    );
    expect(
      Source(source).normalize().find('"it\'s a well-known fact"').single.start,
      8,
    );
  });

  test('offsets stay correct when folding changes length', () {
    const source = 'Wait… the ﬁnal ﬂight';
    final m = Source(source).normalize().find('the final flight').single;
    expect(m.text, 'the ﬁnal ﬂight');
    expect(m.isExact, isTrue);
    final e = Source(source)
        .normalize(caseSensitive: true, collapseWhitespace: false)
        .find('...', fuzzy: false)
        .single;
    expect(e.text, '…');
  });
}
