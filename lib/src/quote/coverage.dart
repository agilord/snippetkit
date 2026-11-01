import '../text/range.dart';
import 'match.dart';

/// A piece of the checked text and where it was found in the source.
class CoverageSegment extends Span {
  final String text;

  /// All source matches of [text]; empty if ungrounded.
  final List<Hit> matches;

  CoverageSegment(super.start, super.end, this.text, this.matches);

  bool get isGrounded => matches.isNotEmpty;

  /// The highest-scoring match (earliest on ties), if any.
  Hit? get best {
    Hit? best;
    for (final m in matches) {
      if (best == null || m.score > best.score) best = m;
    }
    return best;
  }
}

/// Which parts of a text are grounded in a source.
class Coverage {
  final List<CoverageSegment> segments;

  Coverage(this.segments);

  List<CoverageSegment> get grounded => [
    for (final s in segments)
      if (s.isGrounded) s,
  ];

  List<CoverageSegment> get ungrounded => [
    for (final s in segments)
      if (!s.isGrounded) s,
  ];

  /// Share of the segment text (by length) that is grounded, in `[0, 1]`;
  /// `0` when there are no segments.
  double get ratio {
    var total = 0;
    var covered = 0;
    for (final s in segments) {
      total += s.length;
      if (s.isGrounded) covered += s.length;
    }
    return total == 0 ? 0 : covered / total;
  }
}
