import 'extract/blocks.dart';
import 'extract/json.dart';
import 'extract/template.dart';
import 'quote/coverage.dart';
import 'quote/fuzzy.dart';
import 'quote/match.dart';
import 'text/boundaries.dart';
import 'text/chunking.dart';
import 'text/range.dart';
import 'text/splitting.dart';
import 'text/unicode.dart';

/// How a [Source] and its quotes are compared; see [Source.normalize].
class _Normalization {
  final bool caseSensitive;
  final bool collapseWhitespace;
  final bool unicode;

  const _Normalization({
    this.caseSensitive = false,
    this.collapseWhitespace = true,
    this.unicode = true,
  });

  bool get isIdentity => caseSensitive && !collapseWhitespace && !unicode;
}

/// A text to search and extract from.
///
/// Offsets, positions and hits always refer to the original [text]. A plain
/// `Source` compares strictly; [normalize] returns a lenient view of the
/// same text, prepared once for many lookups.
class Source {
  final String text;

  final _Normalization? _normalization;

  final List<int> _lineStarts;
  late final _Normalized _norm = _normalizeText(text, _normalization);

  Source(this.text) : _normalization = null, _lineStarts = _indexLines(text);

  Source._(this.text, this._normalization, this._lineStarts);

  /// The same text, compared ignoring case ([caseSensitive]), whitespace runs
  /// ([collapseWhitespace]) and typographic Unicode ([unicode], see
  /// [normalizeUnicode]); each ignored by default.
  Source normalize({
    bool caseSensitive = false,
    bool collapseWhitespace = true,
    bool unicode = true,
  }) => Source._(
    text,
    _Normalization(
      caseSensitive: caseSensitive,
      collapseWhitespace: collapseWhitespace,
      unicode: unicode,
    ),
    _lineStarts,
  );

  /// Whether lookups are lenient (see [normalize]).
  bool get isNormalized => !(_normalization?.isIdentity ?? true);

  int get length => text.length;

  /// The part of [text] covered by [range].
  String slice(Span range) => range.textIn(text);

  // Lines end with `\n`, `\r\n` or `\r`; columns count UTF-16 code units.

  int get lineCount => _lineStarts.length;

  /// Zero-based line/column of [offset] (up to `length`).
  TextPosition positionOf(int offset) {
    RangeError.checkValueInInterval(offset, 0, text.length, 'offset');
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return TextPosition(lo, offset - _lineStarts[lo]);
  }

  /// Offset of [line]/[column] (inverse of [positionOf]).
  int offsetOf(int line, int column) {
    final range = lineRange(line);
    RangeError.checkValueInInterval(column, 0, range.length, 'column');
    return range.start + column;
  }

  /// [line] without its terminator.
  Span lineRange(int line) {
    RangeError.checkValueInInterval(line, 0, lineCount - 1, 'line');
    final start = _lineStarts[line];
    var end = line + 1 < lineCount ? _lineStarts[line + 1] : text.length;
    while (end > start) {
      final c = text.codeUnitAt(end - 1);
      if (c != 0x0A && c != 0x0D) break;
      end--;
    }
    return Span(start, end);
  }

  // Structure.

  /// [range] widened to the enclosing [boundary], without surrounding
  /// whitespace. Sentences end at `.`, `!`, `?` or `…` (plus closing
  /// quotes/brackets) before whitespace, or at a blank line; abbreviations
  /// such as "Dr." are not recognized. Paragraphs are separated by blank lines.
  Span expand(Span range, Boundary boundary) =>
      expandToBoundary(text, range.start, range.end, boundary);

  /// Sentences in order (see [expand]).
  late final List<Span> sentences = splitSentences(text);

  /// Paragraphs in order.
  late final List<Span> paragraphs = splitParagraphs(text);

  /// Chunks of at most [maxLength] UTF-16 code units, cut at the coarsest
  /// boundary (paragraph, line, sentence, word) in the window's second half,
  /// else hard. Chunks tile the text, unless [overlap] > 0: each then starts
  /// about [overlap] units before the previous one ended, at a word start.
  List<Chunk> chunks({required int maxLength, int overlap = 0}) =>
      splitChunks(text, maxLength: maxLength, overlap: overlap);

  /// Every JSON object and array in order (not the ones nested in them).
  /// Unless [lenient] is false, comments and trailing commas are tolerated
  /// (see [repairJson]).
  Iterable<Object> jsonValues({bool lenient = true}) =>
      extractJson(text, lenient: lenient);

  /// Fenced code blocks (``` or ~~~), or with [tags] the `<tag>…</tag>`
  /// blocks of those tags (case-insensitive, `'*'` for any).
  ///
  /// Unterminated fences and, with [includeUnclosed], unclosed tags run to the
  /// end of the text (`closed == false`). Tags of the same name are balanced;
  /// nested blocks are not returned separately.
  Iterable<Block> blocks({
    Iterable<String>? tags,
    bool includeUnclosed = false,
  }) => tags == null
      ? extractCodeBlocks(text)
      : extractTagBlocks(text, tags: tags, includeUnclosed: includeUnclosed);

  /// `<think>` and `<thinking>` blocks; an unclosed one (truncated output)
  /// runs to the end of the text.
  Iterable<Block> get think => extractThinkBlocks(text);

  /// [text] without [think] blocks, and without anything before a leading
  /// orphan `</think>` (pre-filled templates). Trimmed if changed.
  String get withoutThink => stripThinkBlocks(text);

  /// `key: value` lines (also `- Key: v`, `**Key:** v`), optionally only for
  /// [keys] (case-insensitive). Values continue over deeper-indented lines.
  /// Prose such as "Note that: yes" looks like a field, so filter with [keys].
  List<Field> fields({Iterable<String>? keys}) =>
      extractFields(text, keys: keys);

  /// Numbered and bulleted items, nested and wrapped ones included, as
  /// [BlockType.listItem] blocks named by their marker.
  List<Block> get listItems => extractItems(text);

  // Quote lookup.

  /// All occurrences of [quote]: exact ones under this source's
  /// normalization (overlaps included) or, if there are none and [fuzzy] is
  /// set, approximate ones scoring at least [minScore]
  /// (`1 - distance / quote.length`).
  ///
  /// Approximate hits are ordered and never overlap; the best score wins a
  /// conflict. Takes about O(n * k) for `k` allowed edits.
  List<Hit> find(String quote, {bool fuzzy = true, double minScore = 0.8}) {
    final q = _normalizeText(quote, _normalization).text;
    if (q.isEmpty) return const [];
    final results = <Hit>[];
    var from = 0;
    while (true) {
      final i = _norm.text.indexOf(q, from);
      if (i < 0) break;
      results.add(_hit(i, i + q.length, 0, q.length));
      from = i + 1;
    }
    if (results.isNotEmpty || !fuzzy) return results;
    final maxDist = ((1 - minScore) * q.length).floor();
    return [
      for (final (d, start, end) in fuzzySearch(_norm.text, q, maxDist))
        _hit(start, end, d, q.length),
    ];
  }

  /// [find] for each of [quotes], aligned with [quotes].
  ///
  /// With [distinct], each quote keeps only its best hit (earliest on ties)
  /// that overlaps no hit kept for an earlier quote.
  List<List<Hit>> findEach(
    Iterable<String> quotes, {
    bool fuzzy = true,
    double minScore = 0.8,
    bool distinct = false,
  }) {
    final all = [
      for (final q in quotes) find(q, fuzzy: fuzzy, minScore: minScore),
    ];
    if (!distinct) return all;
    final claimed = <Hit>[];
    return [
      for (final matches in all)
        () {
          Hit? best;
          for (final m in matches) {
            if (claimed.any((c) => m.start < c.end && c.start < m.end)) {
              continue;
            }
            if (best == null || m.score > best.score) best = m;
          }
          if (best == null) return const <Hit>[];
          claimed.add(best);
          return [best];
        }(),
    ];
  }

  /// Which parts of [answer] are found in this source: each sentence (or
  /// paragraph, with `by: Boundary.paragraph`) is looked up with [findEach].
  Coverage coverage(
    String answer, {
    double minScore = 0.8,
    bool distinct = false,
    Boundary by = Boundary.sentence,
  }) {
    final ranges = switch (by) {
      Boundary.sentence => splitSentences(answer),
      Boundary.paragraph => splitParagraphs(answer),
      _ => throw ArgumentError.value(by, 'by', 'must be sentence or paragraph'),
    };
    final pieces = [for (final r in ranges) r.textIn(answer)];
    final matches = findEach(pieces, minScore: minScore, distinct: distinct);
    return Coverage([
      for (var i = 0; i < ranges.length; i++)
        CoverageSegment(ranges[i].start, ranges[i].end, pieces[i], matches[i]),
    ]);
  }

  /// Maps a range of the normalized text back to [text].
  Hit _hit(int start, int end, int distance, int quoteLength) {
    final origin = _norm.origin;
    final os = origin == null ? start : origin[start];
    final oe = origin == null ? end : origin[end - 1] + 1;
    return Hit(
      start: os,
      end: oe,
      text: text.substring(os, oe),
      score: distance == 0 ? 1.0 : 1 - distance / quoteLength,
      distance: distance,
    );
  }

  @override
  String toString() => 'Source(${text.length} chars)';
}

List<int> _indexLines(String text) {
  final starts = [0];
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x0A) {
      starts.add(i + 1);
    } else if (c == 0x0D) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) i++;
      starts.add(i + 1);
    }
  }
  return starts;
}

class _Normalized {
  final String text;

  /// For each code unit of [text], the offset of the originating code unit in
  /// the original string; `null` if [text] is the original.
  final List<int>? origin;

  _Normalized(this.text, this.origin);
}

final _ws = RegExp(r'\s');

_Normalized _normalizeText(String input, _Normalization? n) {
  if (n == null || n.isIdentity) return _Normalized(input, null);
  final sb = StringBuffer();
  final origin = <int>[];
  var pendingSpace = -1;
  for (var i = 0; i < input.length; i++) {
    final unit =
        (n.unicode ? foldUnicodeUnit(input.codeUnitAt(i)) : null) ?? input[i];
    for (var k = 0; k < unit.length; k++) {
      var ch = unit[k];
      if (n.collapseWhitespace && _ws.hasMatch(ch)) {
        if (origin.isNotEmpty && pendingSpace < 0) pendingSpace = i;
        continue;
      }
      if (pendingSpace >= 0) {
        sb.write(' ');
        origin.add(pendingSpace);
        pendingSpace = -1;
      }
      if (!n.caseSensitive) ch = ch.toLowerCase();
      sb.write(ch);
      for (var m = 0; m < ch.length; m++) {
        origin.add(i);
      }
    }
  }
  return _Normalized(sb.toString(), origin);
}
