import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  List<String> texts(String t, List<Span> r) => [
    for (final x in r) x.textIn(t),
  ];

  test('paragraphs', () {
    const t = '\n First line\nstill first.\n\n\n  Second.  \r\n\r\nThird';
    expect(texts(t, Source(t).paragraphs), [
      'First line\nstill first.',
      'Second.',
      'Third',
    ]);
    expect(Source('  \n\n ').paragraphs, isEmpty);
  });

  test('sentences', () {
    const t =
        'Hello world. He said "Stop!" Then left... Pi is 3.14 ok?\n\nNew para';
    expect(texts(t, Source(t).sentences), [
      'Hello world.',
      'He said "Stop!"',
      'Then left...',
      'Pi is 3.14 ok?',
      'New para',
    ]);
    expect(Source('').sentences, isEmpty);
  });

  test('sentences agree with boundary expansion', () {
    const t = 'One two. Three four! Five six';
    for (final r in Source(t).sentences) {
      final e = Source(t).expand(Span(r.start, r.start + 1), Boundary.sentence);
      expect((e.start, e.end), (r.start, r.end));
    }
  });
}
