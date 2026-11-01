import '../text/range.dart';
import 'blocks.dart';

/// A `key: value` field found in semi-structured text.
class Field extends Span {
  /// The key as written, without bullets, bold markers or the colon.
  final String key;

  /// The trimmed value; indented continuation lines are joined with `\n`.
  final String value;

  /// The whole field, key through value ([start]..[end]).
  final String text;

  Field(this.key, this.value, this.text, super.start, super.end);

  @override
  String toString() => 'Field($key: $value)';
}

final _fieldLine = RegExp(
  r'^([ \t]*)(?:[-*+•][ \t]+)?(?:\*\*|__)?(\p{L}[\p{L}\p{N} _\-/]{0,39}?)'
  r'(?:\*\*|__)?[ \t]*:(?:\*\*|__)?(?=\s|$)[ \t]*(.*)$',
  unicode: true,
);
final _listLine = RegExp(r'^([ \t]*)(\d{1,3}[.)]|[-*+•])[ \t]+(.*)$');

/// `key: value` fields in [text], also as `- Key: v`, `**Key:** v` or
/// `**Key**: v`; repeated keys are all returned, in order.
///
/// Values continue over following lines indented deeper than the key line
/// (such lines are not reported as fields; call this again on the value to
/// read nested fields). With [keys], only those keys are returned
/// (case-insensitive). Prose such as `Note that this works: yes` also looks
/// like a field, so filter by [keys] when the template is known.
List<Field> extractFields(String text, {Iterable<String>? keys}) {
  final wanted = keys?.map((k) => k.trim().toLowerCase()).toSet();
  final lines = _lines(text);
  final result = <Field>[];
  for (var i = 0; i < lines.length; i++) {
    final (ls, le) = lines[i];
    final m = _fieldLine.firstMatch(text.substring(ls, le));
    if (m == null) continue;
    final indent = m.group(1)!.length;
    final parts = [m.group(3)!.trim()];
    var end = le;
    while (i + 1 < lines.length) {
      final (ns, ne) = lines[i + 1];
      final line = text.substring(ns, ne);
      if (line.trim().isEmpty || _indentOf(line) <= indent) break;
      parts.add(line.trim());
      end = ne;
      i++;
    }
    final key = m.group(2)!.trim();
    if (wanted != null && !wanted.contains(key.toLowerCase())) continue;
    result.add(
      Field(
        key,
        parts.where((p) => p.isNotEmpty).join('\n'),
        text.substring(ls + indent, _trimEnd(text, ls + indent, end)),
        ls + indent,
        _trimEnd(text, ls + indent, end),
      ),
    );
  }
  return result;
}

/// Numbered (`1.`, `2)`) and bulleted (`-`, `*`, `+`, `•`) list items in
/// [text], in order, nested items included, as [BlockType.listItem] blocks
/// named by their marker (`1.`, `-`).
///
/// An item continues over following non-marker lines indented deeper than
/// its marker line.
List<Block> extractItems(String text) {
  final lines = _lines(text);
  final result = <Block>[];
  for (var i = 0; i < lines.length; i++) {
    final (ls, le) = lines[i];
    final m = _listLine.firstMatch(text.substring(ls, le));
    if (m == null) continue;
    final indent = m.group(1)!.length;
    final parts = [m.group(3)!.trim()];
    var end = le;
    while (i + 1 < lines.length) {
      final (ns, ne) = lines[i + 1];
      final line = text.substring(ns, ne);
      if (line.trim().isEmpty ||
          _indentOf(line) <= indent ||
          _listLine.hasMatch(line)) {
        break;
      }
      parts.add(line.trim());
      end = ne;
      i++;
    }
    final end2 = _trimEnd(text, ls + indent, end);
    result.add(
      Block(
        type: BlockType.listItem,
        name: m.group(2),
        info: null,
        body: parts.where((p) => p.isNotEmpty).join('\n'),
        text: text.substring(ls + indent, end2),
        start: ls + indent,
        end: end2,
        bodyStart: ls + m.end - m.group(3)!.length,
        bodyEnd: end2,
        closed: true,
      ),
    );
  }
  return result;
}

int _indentOf(String line) {
  var n = 0;
  while (n < line.length && (line[n] == ' ' || line[n] == '\t')) {
    n++;
  }
  return n;
}

int _trimEnd(String text, int start, int end) {
  while (end > start && (text[end - 1] == ' ' || text[end - 1] == '\t')) {
    end--;
  }
  return end;
}

/// Line `(start, end)` offsets, excluding line terminators.
List<(int, int)> _lines(String text) {
  final result = <(int, int)>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 10 || c == 13) {
      result.add((start, i));
      if (c == 13 && i + 1 < text.length && text.codeUnitAt(i + 1) == 10) i++;
      start = i + 1;
    }
  }
  result.add((start, text.length));
  return result;
}
