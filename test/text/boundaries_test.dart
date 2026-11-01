import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  const text =
      'First sentence here. Second one, with "quotes." Third!\n'
      'Still third? Yes.\n'
      '\n'
      'New paragraph, line one.\n'
      'Line two of it.\n';

  String expand(String q, Boundary b) {
    final i = text.indexOf(q);
    final r = Source(text).expand(Span(i, i + q.length), b);
    return r.textIn(text);
  }

  test('word', () {
    expect(expand('ntenc', Boundary.word), 'sentence');
    expect(expand('one', Boundary.word), 'one');
  });

  test('line', () {
    expect(expand('Second', Boundary.line), text.split('\n').first);
    expect(expand('line one', Boundary.line), 'New paragraph, line one.');
  });

  test('sentence', () {
    expect(expand('sentence here', Boundary.sentence), 'First sentence here.');
    expect(
      expand('with "quotes', Boundary.sentence),
      'Second one, with "quotes."',
    );
    expect(expand('Third', Boundary.sentence), 'Third!');
    expect(expand('Still', Boundary.sentence), 'Still third?');
    expect(expand('Yes', Boundary.sentence), 'Yes.');
    expect(expand('Line two', Boundary.sentence), 'Line two of it.');
  });

  test('sentence spanning a line break and a blank-line break', () {
    expect(
      expand('one.\nLine', Boundary.sentence),
      'New paragraph, line one.\nLine two of it.',
    );
    expect(
      Source('no end\n\nnext')
          .expand(Span(0, 2), Boundary.sentence)
          .textIn('no end\n\nnext'),
      'no end',
    );
  });

  test('sentence does not split on decimals', () {
    const t = 'Pi is 3.14 roughly. Next.';
    expect(
      Source(t).expand(Span(6, 10), Boundary.sentence).textIn(t),
      'Pi is 3.14 roughly.',
    );
  });

  test('paragraph', () {
    expect(
      expand('Second', Boundary.paragraph),
      'First sentence here. Second one, with "quotes." Third!\n'
      'Still third? Yes.',
    );
    expect(
      expand('Line two', Boundary.paragraph),
      'New paragraph, line one.\nLine two of it.',
    );
  });

  test('range spanning several units', () {
    final i = text.indexOf('Second');
    final j = text.indexOf('Still') + 2;
    expect(
      Source(text).expand(Span(i, j), Boundary.sentence).textIn(text),
      'Second one, with "quotes." Third!\nStill third?',
    );
  });

  test('validates range and handles empty text', () {
    expect(
      () => Source('abc').expand(Span(2, 5), Boundary.line),
      throwsRangeError,
    );
    expect(Source('').expand(Span(0, 0), Boundary.sentence), const Span(0, 0));
  });

  test('Hit.expand', () {
    final m = Source(text).find('with "quotes', fuzzy: false).single;
    final e = m.expand(Source(text), Boundary.sentence);
    expect(e.text, 'Second one, with "quotes."');
    expect(text.substring(e.start, e.end), e.text);
  });
}
