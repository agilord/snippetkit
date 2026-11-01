import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

String render(List<DiffSegment> d) => d.map((s) => s.toString()).join('|');

void main() {
  test('identical text is one equal segment', () {
    final d = diffWords('a b c', 'a b c');
    expect(d.single.kind, DiffKind.equal);
  });

  test('replacement shows delete then insert', () {
    expect(
      render(diffWords('the quick brwn fox', 'the quick brown fox')),
      '= "the quick "|- "brwn"|+ "brown"|= " fox"',
    );
  });

  test('insertions and deletions', () {
    expect(
      render(diffWords('over the dog', 'over the lazy dog')),
      '= "over the"|+ " lazy"|= " dog"',
    );
    expect(
      render(diffWords('over the very lazy dog', 'over the lazy dog')),
      '= "over the"|- " very"|= " lazy dog"',
    );
  });

  test('punctuation and whitespace', () {
    expect(render(diffWords('a,  b', 'a, b')), '= "a, b"');
    expect(render(diffWords('end.', 'end!')), '= "end"|- "."|+ "!"');
  });

  test('ignoreCase', () {
    expect(diffWords('Hello World', 'hello world').length, 5);
    final d = diffWords('Hello World', 'hello world', ignoreCase: true);
    expect(d.single.kind, DiffKind.equal);
    expect(d.single.before, 'Hello World');
    expect(d.single.after, 'hello world');
  });

  test('empty inputs', () {
    expect(diffWords('', ''), isEmpty);
    expect(render(diffWords('', 'x')), '+ "x"');
    expect(render(diffWords('x', '')), '- "x"');
  });

  test('Hit.diff', () {
    const source = 'The quick brown fox jumps.';
    final m = Source(source).normalize().find('quick brwn fox').single;
    expect(
      render(m.diff('quick brwn fox')),
      '= "quick "|- "brwn"|+ "brown"|= " fox"',
    );
  });
}
