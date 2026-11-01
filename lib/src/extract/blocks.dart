import '../text/range.dart';

enum BlockType { code, tag, listItem }

/// A fenced code block, a `<tag>…</tag>` block or a list item found in a text.
class Block extends Span {
  final BlockType type;

  /// Language of a code block, the tag name, or the marker of a list item
  /// (`1.`, `-`); `null` if absent.
  final String? name;

  /// Rest of the fence info string, or the tag attributes; `null` if absent.
  final String? info;

  /// Content between the delimiters (of a list item: the trimmed content,
  /// continuation lines joined with `\n`).
  final String body;

  /// The whole block, delimiters included ([start]..[end]).
  final String text;

  /// Range of [body] in the source text.
  final int bodyStart, bodyEnd;

  /// `false` if the closing delimiter is missing (e.g. truncated output).
  final bool closed;

  const Block({
    required this.type,
    required this.name,
    required this.info,
    required this.body,
    required this.text,
    required int start,
    required int end,
    required this.bodyStart,
    required this.bodyEnd,
    required this.closed,
  }) : super(start, end);

  @override
  String toString() => 'Block($type, $name, $start..$end)';
}

final _fenceOpen = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*([^\s`~]*)[ \t]*(.*)$');
final _fenceClose = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');

/// Finds fenced code blocks (``` or ~~~) in [text]. An unterminated fence
/// yields a block running to the end of the text with `closed == false`.
Iterable<Block> extractCodeBlocks(String text) sync* {
  final n = text.length;
  var pos = 0;

  // Returns [start, end, next] of the line at [from] (end excludes terminator).
  (int, int, int) lineAt(int from) {
    final nl = text.indexOf('\n', from);
    final next = nl == -1 ? n : nl + 1;
    var end = nl == -1 ? n : nl;
    if (end > from && text.codeUnitAt(end - 1) == 0x0D) end--;
    return (from, end, next);
  }

  while (pos < n) {
    final (_, openEnd, bodyStart) = lineAt(pos);
    final open = _fenceOpen.firstMatch(text.substring(pos, openEnd));
    final fence = open?[1];
    final rest = open == null ? '' : '${open[2]}${open[3]}';
    if (open == null || (fence![0] == '`' && rest.contains('`'))) {
      pos = bodyStart;
      continue;
    }

    var scan = bodyStart;
    var bodyEnd = n;
    var end = n;
    var closed = false;
    while (scan < n) {
      final (s, e, next) = lineAt(scan);
      final close = _fenceClose.firstMatch(text.substring(s, e));
      if (close != null &&
          close[1]![0] == fence[0] &&
          close[1]!.length >= fence.length) {
        bodyEnd = s;
        end = e;
        closed = true;
        scan = next;
        break;
      }
      scan = next;
    }
    if (bodyEnd > bodyStart && text.codeUnitAt(bodyEnd - 1) == 0x0A) {
      bodyEnd--;
    }
    if (bodyEnd > bodyStart && text.codeUnitAt(bodyEnd - 1) == 0x0D) bodyEnd--;
    final language = open[2]!;
    final info = open[3]!.trim();
    yield Block(
      type: BlockType.code,
      name: language.isEmpty ? null : language,
      info: info.isEmpty ? null : info,
      body: text.substring(bodyStart, bodyEnd),
      text: text.substring(pos, end),
      start: pos,
      end: end,
      bodyStart: bodyStart,
      bodyEnd: bodyEnd,
      closed: closed,
    );
    pos = scan;
  }
}

final _tagOpen = RegExp(r'<([A-Za-z][\w:.-]*)((?:\s[^<>]*)?)>');

/// Finds `<tag>…</tag>` blocks in [text], optionally only for [tags]
/// (case-insensitive; `'*'` matches any tag). Same-name nesting is balanced;
/// nested blocks are not returned separately. Unclosed tags are skipped, unless [includeUnclosed]
/// is set, in which case they run to the end of the text.
Iterable<Block> extractTagBlocks(
  String text, {
  Iterable<String>? tags,
  bool includeUnclosed = false,
}) sync* {
  var wanted = tags?.map((t) => t.toLowerCase()).toSet();
  if (wanted != null && wanted.contains('*')) wanted = null;
  var pos = 0;
  while (true) {
    final open = _tagOpen.allMatches(text, pos).firstOrNull;
    if (open == null) return;
    final name = open[1]!;
    final attrs = (open[2] ?? '').trim();
    if (wanted != null && !wanted.contains(name.toLowerCase()) ||
        attrs.endsWith('/')) {
      pos = open.end;
      continue;
    }

    final tagRe = RegExp(
      '<(/?)${RegExp.escape(name)}(?=[\\s>/])[^<>]*>',
      caseSensitive: false,
    );
    var depth = 1;
    Match? close;
    for (final m in tagRe.allMatches(text, open.end)) {
      if (m[1] == '/') {
        if (--depth == 0) {
          close = m;
          break;
        }
      } else if (!m[0]!.endsWith('/>')) {
        depth++;
      }
    }
    if (close == null && !includeUnclosed) {
      pos = open.end;
      continue;
    }
    final bodyEnd = close?.start ?? text.length;
    final end = close?.end ?? text.length;
    yield Block(
      type: BlockType.tag,
      name: name,
      info: attrs.isEmpty ? null : attrs,
      body: text.substring(open.end, bodyEnd),
      text: text.substring(open.start, end),
      start: open.start,
      end: end,
      bodyStart: open.end,
      bodyEnd: bodyEnd,
      closed: close != null,
    );
    pos = end;
  }
}

const _defaultThinkTags = ['think', 'thinking'];

/// Finds reasoning blocks (`<think>…</think>`); an unclosed one, as left by
/// truncated output, runs to the end of the text.
Iterable<Block> extractThinkBlocks(
  String text, {
  Iterable<String> tags = _defaultThinkTags,
}) => extractTagBlocks(text, tags: tags, includeUnclosed: true);

/// Removes reasoning blocks from [text]. Also drops everything up to a
/// leading orphan closing tag (models whose template pre-fills `<think>`).
/// If anything was removed the result is trimmed.
String stripThinkBlocks(
  String text, {
  Iterable<String> tags = _defaultThinkTags,
}) {
  final blocks = extractThinkBlocks(text, tags: tags).toList();
  final alternatives = tags.map(RegExp.escape).join('|');
  final orphan = RegExp(
    '</(?:$alternatives)\\s*>',
    caseSensitive: false,
  ).firstMatch(text);

  var from = 0;
  if (orphan != null && (blocks.isEmpty || orphan.start < blocks.first.start)) {
    from = orphan.end;
  }
  if (from == 0 && blocks.isEmpty) return text;

  final sb = StringBuffer();
  for (final b in blocks) {
    sb.write(text.substring(from, b.start));
    from = b.end;
  }
  sb.write(text.substring(from));
  return sb.toString().trim();
}
