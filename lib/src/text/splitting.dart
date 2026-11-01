import 'range.dart';

final _paragraphBreak = RegExp(r'\n(?:[ \t\r]*\n)+');
final _space = RegExp(r'\s');

bool _isTerminator(String s, int i) => '.!?…'.contains(s[i]);
bool _isCloser(String s, int i) => '"\')]}»”’'.contains(s[i]);

/// Paragraph ranges of [text]: runs of text separated by blank lines.
///
/// Ranges exclude surrounding whitespace; empty paragraphs are skipped.
List<Span> splitParagraphs(String text) {
  final result = <Span>[];
  void add(int start, int end) {
    while (start < end && _space.hasMatch(text[start])) {
      start++;
    }
    while (end > start && _space.hasMatch(text[end - 1])) {
      end--;
    }
    if (start < end) result.add(Span(start, end));
  }

  var from = 0;
  for (final m in _paragraphBreak.allMatches(text)) {
    add(from, m.start);
    from = m.end;
  }
  add(from, text.length);
  return result;
}

/// Sentence ranges of [text], in order.
///
/// A sentence ends at `.`, `!`, `?` or `…` (plus closing quotes/brackets)
/// followed by whitespace, or at a paragraph break. Abbreviations such as
/// "Dr." are not recognized. Ranges exclude surrounding whitespace.
List<Span> splitSentences(String text) {
  final result = <Span>[];
  for (final p in splitParagraphs(text)) {
    var start = p.start;
    var i = p.start;
    while (i < p.end) {
      if (_isTerminator(text, i)) {
        var j = i + 1;
        while (j < p.end && _isCloser(text, j)) {
          j++;
        }
        if (j >= p.end || _space.hasMatch(text[j])) {
          result.add(Span(start, j));
          while (j < p.end && _space.hasMatch(text[j])) {
            j++;
          }
          start = j;
          i = j;
          continue;
        }
      }
      i++;
    }
    if (start < p.end) result.add(Span(start, p.end));
  }
  return result;
}
