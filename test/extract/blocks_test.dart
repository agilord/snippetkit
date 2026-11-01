import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  group('blocks', () {
    test('finds fenced blocks with language and info', () {
      const text =
          'intro\n```dart title="x"\nvoid main() {}\nfoo();\n```\nmid\n'
          '~~~\nplain\n~~~\nend';
      final blocks = Source(text).blocks().toList();
      expect(blocks.length, 2);
      expect(blocks[0].name, 'dart');
      expect(blocks[0].info, 'title="x"');
      expect(blocks[0].body, 'void main() {}\nfoo();');
      expect(blocks[0].closed, isTrue);
      expect(
        text.substring(blocks[0].bodyStart, blocks[0].bodyEnd),
        blocks[0].body,
      );
      expect(
        text.substring(blocks[0].start, blocks[0].end),
        startsWith('```dart'),
      );
      expect(text.substring(blocks[0].start, blocks[0].end), endsWith('```'));
      expect(blocks[1].name, isNull);
      expect(blocks[1].body, 'plain');
    });

    test('longer fences can contain shorter ones', () {
      const text = '````md\n```\ninner\n```\n````\n';
      final b = Source(text).blocks().single;
      expect(b.name, 'md');
      expect(b.body, '```\ninner\n```');
    });

    test('unclosed fence runs to the end', () {
      final b = Source('x\n```json\n{"a": 1}\n').blocks().single;
      expect(b.closed, isFalse);
      expect(b.body, '{"a": 1}');
    });

    test('empty body, CRLF, and non-fences', () {
      expect(Source('```\n```').blocks().single.body, '');
      expect(
        Source('```py\r\na\r\nb\r\n```\r\n').blocks().single.body,
        'a\r\nb',
      );
      expect(Source('use `code` and ``` inline').blocks(), isEmpty);
      expect(Source('').blocks(), isEmpty);
    });
  });

  group('blocks(tags)', () {
    test('finds tagged blocks with attributes', () {
      const text = 'a <answer id="1">42</answer> b <note>n</note>';
      final blocks = Source(text).blocks(tags: ['*']).toList();
      expect(blocks.map((b) => b.name), ['answer', 'note']);
      expect(blocks[0].info, 'id="1"');
      expect(blocks[0].body, '42');
      expect(
        text.substring(blocks[0].start, blocks[0].end),
        '<answer id="1">42</answer>',
      );
    });

    test('filters by tag name case-insensitively', () {
      const text = '<A>1</A><b>2</b>';
      expect(Source(text).blocks(tags: ['a']).single.body, '1');
    });

    test('balances nested same-name tags and keeps outer only', () {
      final b = Source('<x>a<x>b</x>c</x>').blocks(tags: ['*']).toList();
      expect(b.single.body, 'a<x>b</x>c');
    });

    test('skips unclosed, self-closing and non-tags', () {
      expect(Source('<br> <hr/> 1 < 2 <p>open').blocks(tags: ['*']), isEmpty);
      final b = Source('<p>open')
          .blocks(tags: ['*'], includeUnclosed: true)
          .single;
      expect(b.closed, isFalse);
      expect(b.body, 'open');
    });
  });

  group('think', () {
    test('think and withoutThink', () {
      const text = '<think>hmm\n</think>\n\nThe answer.';
      expect(Source(text).think.single.body, 'hmm\n');
      expect(Source(text).withoutThink, 'The answer.');
    });

    test('handles truncated and orphan-closing reasoning', () {
      expect(Source('Answer.<think>still goin').withoutThink, 'Answer.');
      expect(Source('<think>x').think.single.closed, isFalse);
      expect(Source('reasoning...</think>\nAnswer.').withoutThink, 'Answer.');
    });

    test('multiple blocks and untouched text', () {
      expect(
        Source('a<think>1</think>b<thinking>2</thinking>c').withoutThink,
        'abc',
      );
      expect(
        Source('  no thinking here  ').withoutThink,
        '  no thinking here  ',
      );
    });
  });
}
