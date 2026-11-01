enum DiffKind { equal, delete, insert }

/// A run of the same [kind] in a word diff.
///
/// [before] is the text from the first input (empty for inserts), [after]
/// from the second (empty for deletes). For equal runs both are set and may
/// differ in case or whitespace.
class DiffSegment {
  final DiffKind kind;
  final String before;
  final String after;

  const DiffSegment(this.kind, this.before, this.after);

  @override
  String toString() => switch (kind) {
    DiffKind.equal => '= "$after"',
    DiffKind.delete => '- "$before"',
    DiffKind.insert => '+ "$after"',
  };
}

final _token = RegExp(r'\s+|[\p{L}\p{N}_]+|[^\s\p{L}\p{N}_]', unicode: true);
final _allSpace = RegExp(r'^\s');

/// Word-level diff turning [a] (e.g. a quote) into [b] (e.g. its fuzzy
/// match), based on the longest common subsequence of word, punctuation and
/// whitespace tokens. Whitespace runs always compare equal; [ignoreCase]
/// makes words compare case-insensitively.
List<DiffSegment> diffWords(String a, String b, {bool ignoreCase = false}) {
  final ta = _token.allMatches(a).map((m) => m[0]!).toList();
  final tb = _token.allMatches(b).map((m) => m[0]!).toList();
  String key(String t) => _allSpace.hasMatch(t)
      ? ' '
      : ignoreCase
      ? t.toLowerCase()
      : t;
  final ka = ta.map(key).toList();
  final kb = tb.map(key).toList();

  final n = ta.length;
  final m = tb.length;
  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      lcs[i][j] = ka[i - 1] == kb[j - 1]
          ? lcs[i - 1][j - 1] + 1
          : lcs[i - 1][j] >= lcs[i][j - 1]
          ? lcs[i - 1][j]
          : lcs[i][j - 1];
    }
  }

  // Walk backwards; inserts are taken first so that, read forwards, a
  // replacement shows as delete followed by insert.
  final ops = <DiffSegment>[];
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && ka[i - 1] == kb[j - 1]) {
      ops.add(DiffSegment(DiffKind.equal, ta[i - 1], tb[j - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j])) {
      ops.add(DiffSegment(DiffKind.insert, '', tb[j - 1]));
      j--;
    } else {
      ops.add(DiffSegment(DiffKind.delete, ta[i - 1], ''));
      i--;
    }
  }

  final merged = <DiffSegment>[];
  for (final op in ops.reversed) {
    if (merged.isNotEmpty && merged.last.kind == op.kind) {
      final last = merged.removeLast();
      merged.add(
        DiffSegment(op.kind, last.before + op.before, last.after + op.after),
      );
    } else {
      merged.add(op);
    }
  }
  return merged;
}
