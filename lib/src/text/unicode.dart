/// Replacement for a single UTF-16 code unit under typographic folding, or
/// `null` if it is kept as is (`''` means the unit is dropped).
String? foldUnicodeUnit(int cu) {
  if (cu < 0xA0) return null;
  if (cu >= 0xFF01 && cu <= 0xFF5E) return String.fromCharCode(cu - 0xFEE0);
  switch (cu) {
    case 0x2018 || 0x2019 || 0x201A || 0x201B || 0x2032 || 0x02BC:
      return "'";
    case 0x201C || 0x201D || 0x201E || 0x201F || 0x2033 || 0x00AB || 0x00BB:
      return '"';
    case >= 0x2010 && <= 0x2015 || 0x2212:
      return '-';
    case 0x2026:
      return '...';
    case 0x00A0 ||
        0x1680 ||
        >= 0x2000 && <= 0x200A ||
        0x202F ||
        0x205F ||
        0x3000:
      return ' ';
    case 0x00AD || 0x200B || 0x200C || 0x200D || 0x2060 || 0xFEFF:
      return '';
    case 0xFB00:
      return 'ff';
    case 0xFB01:
      return 'fi';
    case 0xFB02:
      return 'fl';
    case 0xFB03:
      return 'ffi';
    case 0xFB04:
      return 'ffl';
    case 0xFB05 || 0xFB06:
      return 'st';
  }
  return null;
}

/// Folds typographic Unicode variants to plain ASCII: curly quotes, dashes,
/// ellipsis, exotic spaces, full-width ASCII and `fi`-style ligatures.
/// Zero-width characters and soft hyphens are removed.
///
/// This is not full NFKC: accents are left untouched.
String normalizeUnicode(String text) {
  final sb = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    sb.write(foldUnicodeUnit(text.codeUnitAt(i)) ?? text[i]);
  }
  return sb.toString();
}
