/// A zero-based line/column position in a text.
class TextPosition {
  final int line;
  final int column;

  const TextPosition(this.line, this.column);

  @override
  bool operator ==(Object other) =>
      other is TextPosition && other.line == line && other.column == column;

  @override
  int get hashCode => Object.hash(line, column);

  @override
  String toString() => '$line:$column';
}

/// A half-open `[start, end)` range of offsets in a text.
///
/// Base of every result type that points into the input text.
class Span {
  final int start;
  final int end;

  const Span(this.start, this.end);

  int get length => end - start;

  String textIn(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is Span &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}
