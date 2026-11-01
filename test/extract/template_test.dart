import 'package:snippetkit/snippetkit.dart';
import 'package:test/test.dart';

void main() {
  group('fields', () {
    test('plain, bulleted and bold keys', () {
      const t =
          'Name: Ada\n- Role: Engineer\n**City:** London\n'
          '**Age**: 36\nsee http://x.y and 10:30 here';
      final f = Source(t).fields();
      expect(
        [for (final x in f) (x.key, x.value)],
        [
          ('Name', 'Ada'),
          ('Role', 'Engineer'),
          ('City', 'London'),
          ('Age', '36'),
        ],
      );
      expect(t.substring(f[0].start, f[0].end), 'Name: Ada');
      expect(t.substring(f[1].start, f[1].end), '- Role: Engineer');
    });

    test('continuation lines, repeats and key filter', () {
      const t = 'Summary:\n  first\n  second\nTag: a\nTag: b\nOther: x';
      final f = Source(t).fields();
      expect(f.first.value, 'first\nsecond');
      expect([for (final x in f) x.key], ['Summary', 'Tag', 'Tag', 'Other']);
      expect(
        [
          for (final x in Source(t).fields(keys: ['tag'])) x.value,
        ],
        ['a', 'b'],
      );
    });
  });

  group('listItems', () {
    test('numbered and bulleted with nesting', () {
      const t =
          'Intro\n1. One\n   wrapped\n2) Two\n- bullet\n  - nested\n'
          '1.5 million is not an item\n';
      final items = Source(t).listItems;
      expect(
        [for (final i in items) (i.name, i.body)],
        [
          ('1.', 'One\nwrapped'),
          ('2)', 'Two'),
          ('-', 'bullet'),
          ('-', 'nested'),
        ],
      );
      expect(items.every((i) => i.type == BlockType.listItem), isTrue);
      expect(t.substring(items[1].start, items[1].end), '2) Two');
    });
  });
}
