import 'dart:convert';

/// Extracts every JSON object and array found in [text], in order of
/// appearance, tolerating fenced code blocks and surrounding prose.
///
/// Scans the whole text, tracking strings and nesting to find each value's
/// end. Values nested inside a returned value are not returned separately;
/// bracketed text that is not valid JSON is skipped. With [lenient] (the
/// default) `//` and `/* */` comments and trailing commas are tolerated, see
/// [repairJson]. Returns an empty iterable if nothing is found. Never throws.
Iterable<Object> extractJson(String text, {bool lenient = true}) sync* {
  var i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c != _openBrace && c != _openBracket) {
      i++;
      continue;
    }
    final end = _findEnd(text, i, lenient);
    if (end != -1) {
      final value = _tryDecode(text.substring(i, end), lenient);
      if (value != null) {
        yield value;
        i = end;
        continue;
      }
    }
    i++;
  }
}

Object? _tryDecode(String json, bool lenient) {
  try {
    return jsonDecode(json) as Object?;
  } on FormatException {
    if (!lenient) return null;
  }
  try {
    return jsonDecode(repairJson(json)) as Object?;
  } on FormatException {
    return null;
  }
}

/// Makes near-JSON strict: strips `//` and `/* */` comments (outside
/// strings) and trailing commas before `}` or `]`.
String repairJson(String json) {
  final noComments = StringBuffer();
  var inString = false;
  for (var i = 0; i < json.length; i++) {
    final c = json.codeUnitAt(i);
    if (inString) {
      noComments.writeCharCode(c);
      if (c == _backslash && i + 1 < json.length) {
        noComments.writeCharCode(json.codeUnitAt(++i));
      } else if (c == _quote) {
        inString = false;
      }
    } else if (c == _slash && json.startsWith('//', i)) {
      final nl = json.indexOf('\n', i);
      i = nl == -1 ? json.length : nl - 1;
    } else if (c == _slash && json.startsWith('/*', i)) {
      final close = json.indexOf('*/', i + 2);
      i = close == -1 ? json.length : close + 1;
      noComments.write(' ');
    } else {
      if (c == _quote) inString = true;
      noComments.writeCharCode(c);
    }
  }

  final text = noComments.toString();
  final out = StringBuffer();
  inString = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      out.writeCharCode(c);
      if (c == _backslash && i + 1 < text.length) {
        out.writeCharCode(text.codeUnitAt(++i));
      } else if (c == _quote) {
        inString = false;
      }
      continue;
    }
    if (c == _comma) {
      var j = i + 1;
      while (j < text.length && text[j].trim().isEmpty) {
        j++;
      }
      if (j < text.length &&
          (text.codeUnitAt(j) == _closeBrace ||
              text.codeUnitAt(j) == _closeBracket)) {
        continue;
      }
    }
    if (c == _quote) inString = true;
    out.writeCharCode(c);
  }
  return out.toString();
}

const _openBrace = 0x7B; // {
const _openBracket = 0x5B; // [
const _closeBrace = 0x7D; // }
const _closeBracket = 0x5D; // ]
const _quote = 0x22; // "
const _backslash = 0x5C; // \
const _slash = 0x2F; // /
const _comma = 0x2C; // ,

/// Returns the exclusive end of the balanced bracket group starting at
/// [start], or -1 if it is not balanced.
int _findEnd(String text, int start, bool lenient) {
  final stack = <int>[];
  var inString = false;
  for (var i = start; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      if (c == _backslash) {
        i++;
      } else if (c == _quote) {
        inString = false;
      }
      continue;
    }
    switch (c) {
      case _quote:
        inString = true;
      case _slash when lenient && text.startsWith('//', i):
        final nl = text.indexOf('\n', i);
        if (nl == -1) return -1;
        i = nl;
      case _slash when lenient && text.startsWith('/*', i):
        final close = text.indexOf('*/', i + 2);
        if (close == -1) return -1;
        i = close + 1;
      case _openBrace:
        stack.add(_closeBrace);
      case _openBracket:
        stack.add(_closeBracket);
      case _closeBrace || _closeBracket:
        if (stack.isEmpty || stack.removeLast() != c) return -1;
        if (stack.isEmpty) return i + 1;
    }
  }
  return -1;
}
