import 'range.dart';

/// A kind of text boundary a range can be expanded to.
enum Boundary { word, line, sentence, paragraph }

/// Expands `[start, end)` of [source] to the enclosing [boundary].
///
/// Sentences end at `.`, `!`, `?` or `…` (plus closing quotes/brackets)
/// followed by whitespace, or at a blank line; abbreviations such as "Dr."
/// are not recognized. Paragraphs are separated by blank lines. Results never
/// include surrounding whitespace for sentences and paragraphs.
Span expandToBoundary(String source, int start, int end, Boundary boundary) {
  RangeError.checkValidRange(start, end, source.length);
  return switch (boundary) {
    Boundary.word => _word(source, start, end),
    Boundary.line => _line(source, start, end),
    Boundary.sentence => Span(
      _sentenceStart(source, start),
      _sentenceEnd(source, start, end),
    ),
    Boundary.paragraph => _paragraph(source, start, end),
  };
}

final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);
final _space = RegExp(r'\s');

bool _isSpace(String s, int i) => _space.hasMatch(s[i]);
bool _isNewline(String s, int i) => s[i] == '\n' || s[i] == '\r';
bool _isTerminator(String s, int i) => '.!?…'.contains(s[i]);
bool _isCloser(String s, int i) => '"\')]}»”’'.contains(s[i]);

Span _word(String s, int start, int end) {
  while (start > 0 && _wordChar.hasMatch(s[start - 1])) {
    start--;
  }
  while (end < s.length && _wordChar.hasMatch(s[end])) {
    end++;
  }
  return Span(start, end);
}

Span _line(String s, int start, int end) {
  while (start > 0 && !_isNewline(s, start - 1)) {
    start--;
  }
  while (end < s.length && !_isNewline(s, end)) {
    end++;
  }
  return Span(start, end);
}

/// Whether the line break at [k] is followed by a blank line.
bool _blankLineAfter(String s, int k) {
  var j = k + 1;
  while (j < s.length && (s[j] == ' ' || s[j] == '\t' || s[j] == '\r')) {
    j++;
  }
  return j < s.length && s[j] == '\n';
}

Span _paragraph(String s, int start, int end) {
  var p = 0;
  for (var k = start - 1; k >= 0; k--) {
    if (s[k] == '\n') {
      var j = k - 1;
      while (j >= 0 && (s[j] == ' ' || s[j] == '\t' || s[j] == '\r')) {
        j--;
      }
      if (j < 0 || s[j] == '\n') {
        p = k + 1;
        break;
      }
    }
  }
  while (p < start && _isSpace(s, p)) {
    p++;
  }
  var e = s.length;
  for (var k = end; k < s.length; k++) {
    if (s[k] == '\n' && _blankLineAfter(s, k)) {
      e = k;
      break;
    }
  }
  while (e > end && _isSpace(s, e - 1)) {
    e--;
  }
  return Span(p, e);
}

int _sentenceStart(String s, int start) {
  for (var p = start; p > 0; p--) {
    if (p >= s.length || _isSpace(s, p) || !_isSpace(s, p - 1)) continue;
    var q = p - 1;
    var newlines = 0;
    while (q >= 0 && _isSpace(s, q)) {
      if (s[q] == '\n') newlines++;
      q--;
    }
    if (newlines >= 2 || q < 0) return p;
    while (q >= 0 && _isCloser(s, q)) {
      q--;
    }
    if (q >= 0 && _isTerminator(s, q)) return p;
  }
  return 0;
}

int _sentenceEnd(String s, int start, int end) {
  int trim(int e) {
    while (e > end && _isSpace(s, e - 1)) {
      e--;
    }
    return e;
  }

  for (var i = end > start ? end - 1 : start; i < s.length; i++) {
    if (_isTerminator(s, i)) {
      var j = i + 1;
      while (j < s.length && _isCloser(s, j)) {
        j++;
      }
      if (j >= s.length || _isSpace(s, j)) return j;
    } else if (s[i] == '\n' && _blankLineAfter(s, i)) {
      return trim(i);
    }
  }
  return trim(s.length);
}
