import '../source.dart';
import '../text/boundaries.dart';
import '../text/diff.dart';
import '../text/range.dart';

/// A located occurrence of a quote inside a source text.
class Hit extends Span {
  /// The matched slice of the original source text.
  final String text;

  /// Similarity in `[0, 1]`; `1.0` for exact (after optional normalization)
  /// matches.
  final double score;

  /// Number of edits (insert/delete/substitute) between the quote and the
  /// normalized match; `0` for exact matches.
  final int distance;

  Hit({
    required int start,
    required int end,
    required this.text,
    required this.score,
    required this.distance,
  }) : super(start, end);

  bool get isExact => distance == 0;

  /// This match widened to the enclosing [boundary] of [source].
  Hit expand(Source source, Boundary boundary) {
    final r = source.expand(this, boundary);
    return Hit(
      start: r.start,
      end: r.end,
      text: source.slice(r),
      score: score,
      distance: distance,
    );
  }

  /// Word-level diff from [quote] to the matched [text].
  List<DiffSegment> diff(String quote, {bool ignoreCase = false}) =>
      diffWords(quote, text, ignoreCase: ignoreCase);

  @override
  String toString() => 'Hit($start..$end, score: ${score.toStringAsFixed(3)})';
}
