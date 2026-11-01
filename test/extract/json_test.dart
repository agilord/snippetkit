import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  group('jsonValues', () {
    test('parses a clean JSON object', () {
      expect(Source('{"a": "hello", "b": "world"}').jsonValues(), [
        {'a': 'hello', 'b': 'world'},
      ]);
    });

    test('parses a clean JSON array', () {
      expect(Source('[1, 2, 3]').jsonValues(), [
        [1, 2, 3],
      ]);
    });

    test('tolerates fenced code blocks', () {
      expect(
        Source(
          'Here is the result:\n```json\n{"a": "hello"}\n```\nAnything else?',
        ).jsonValues(),
        [
          {'a': 'hello'},
        ],
      );
      expect(Source('```\n{"a": "hello"}\n```').jsonValues(), [
        {'a': 'hello'},
      ]);
    });

    test('tolerates surrounding prose', () {
      expect(Source('Sure: {"a": "hello"} Hope that helps.').jsonValues(), [
        {'a': 'hello'},
      ]);
      expect(Source('The values are: [1, 2, 3]. All done.').jsonValues(), [
        [1, 2, 3],
      ]);
    });

    test('does not return nested values separately', () {
      expect(Source('prefix {"a": [1, 2]} suffix').jsonValues(), [
        {
          'a': [1, 2],
        },
      ]);
    });

    test('returns multiple values in order', () {
      expect(Source('a {"x": 1} b [2, {"y": 3}] c {"z": []}').jsonValues(), [
        {'x': 1},
        [
          2,
          {'y': 3},
        ],
        {'z': []},
      ]);
    });

    test('handles brackets and escapes inside strings', () {
      expect(Source(r'{"a": "}]\"{", "b": "\\"} [1]').jsonValues(), [
        {'a': '}]"{', 'b': r'\'},
        [1],
      ]);
    });

    test('skips invalid and unbalanced bracketed text', () {
      expect(Source('{"a": } then {"b": 1}').jsonValues(), [
        {'b': 1},
      ]);
      expect(Source('[ not json ] [1]').jsonValues(), [
        [1],
      ]);
      expect(Source('{ unclosed [1, 2]').jsonValues(), [
        [1, 2],
      ]);
    });

    test('returns nothing when no JSON is present', () {
      expect(Source('Sorry, I cannot help with that.').jsonValues(), isEmpty);
      expect(Source('} then {').jsonValues(), isEmpty);
      expect(Source('').jsonValues(), isEmpty);
    });
  });

  group('lenient', () {
    test('tolerates comments and trailing commas', () {
      const text = '''Here:
{
  // the name
  "a": 1, /* inline } ] */
  "b": [1, 2,],
  "url": "http://x.y/z",
}''';
      expect(Source(text).jsonValues(), [
        {
          'a': 1,
          'b': [1, 2],
          'url': 'http://x.y/z',
        },
      ]);
    });

    test('strict mode skips such values', () {
      expect(Source('{"a": 1,}').jsonValues(lenient: false), isEmpty);
      expect(Source('[1, 2, ] [3]').jsonValues(lenient: false), [
        [3],
      ]);
    });

    test('unterminated comment is skipped', () {
      expect(Source('{"a": 1 /* oops }').jsonValues(), isEmpty);
    });

    test('repairJson leaves strings alone', () {
      expect(
        repairJson('{"a": "x, // not a comment ,]", /* c */ "b": 1,}'),
        '{"a": "x, // not a comment ,]",   "b": 1}',
      );
    });
  });
}
