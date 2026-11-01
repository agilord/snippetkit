import 'dart:math';

import 'range.dart';

/// A slice `[start, end)` of the chunked text.
class Chunk extends Span {
  final String text;

  const Chunk(super.start, super.end, this.text);

  @override
  String toString() => 'Chunk($start..$end)';
}

final _paragraphBreak = RegExp(r'\n[ \t\r]*\n\s*');
final _lineBreak = RegExp(r'\n');
final _sentenceBreak = RegExp('[.!?…]["\')\\]”’»]*\\s+');
final _wordBreak = RegExp(r'\s+');
final _space = RegExp(r'\s');

/// Splits [text] into chunks of at most [maxLength] UTF-16 code units.
///
/// Cuts at the coarsest boundary available in the second half of the window
/// (paragraph, line, sentence, word), else cuts hard. With `overlap == 0`
/// the chunks tile the text exactly; otherwise each chunk starts about
/// [overlap] units before the previous one ended (snapped to a word start).
/// Offsets map back to [text].
List<Chunk> splitChunks(
  String text, {
  required int maxLength,
  int overlap = 0,
}) {
  if (maxLength < 2) throw ArgumentError.value(maxLength, 'maxLength');
  if (overlap < 0 || overlap >= maxLength) {
    throw ArgumentError.value(overlap, 'overlap', 'must be in [0, maxLength)');
  }
  final n = text.length;
  final chunks = <Chunk>[];
  var pos = 0;
  while (pos < n) {
    final limit = min(pos + maxLength, n);
    final cut = limit == n ? n : _findCut(text, pos, limit, maxLength);
    chunks.add(Chunk(pos, cut, text.substring(pos, cut)));
    if (cut >= n) break;
    pos = overlap == 0 ? cut : _overlapStart(text, pos, cut, overlap);
  }
  return chunks;
}

int _findCut(String text, int pos, int limit, int maxLength) {
  final minCut = pos + max(1, maxLength ~/ 2);
  final window = text.substring(pos, limit);
  for (final re in [_paragraphBreak, _lineBreak, _sentenceBreak, _wordBreak]) {
    var best = -1;
    for (final m in re.allMatches(window)) {
      final e = pos + m.end;
      if (e >= minCut && e <= limit) best = e;
    }
    if (best != -1) return best;
  }
  return _isHighSurrogate(text.codeUnitAt(limit - 1)) ? limit - 1 : limit;
}

int _overlapStart(String text, int pos, int cut, int overlap) {
  var next = cut - overlap;
  if (next <= pos) return cut;
  if (_isLowSurrogate(text.codeUnitAt(next))) next++;
  var k = next;
  if (!_space.hasMatch(text[k - 1])) {
    while (k < cut && !_space.hasMatch(text[k])) {
      k++;
    }
  }
  while (k < cut && _space.hasMatch(text[k])) {
    k++;
  }
  if (k < cut) next = k;
  return next;
}

bool _isHighSurrogate(int cu) => cu >= 0xD800 && cu <= 0xDBFF;
bool _isLowSurrogate(int cu) => cu >= 0xDC00 && cu <= 0xDFFF;
