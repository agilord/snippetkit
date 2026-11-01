# snippetkit

Text tooling for LLM output: extract JSON, code blocks and fields, locate
quotes (exactly or fuzzily) and split text.

## Extract

```dart
final source = Source(reply);
source.jsonValues();            // every {...} / [...]; comments, trailing commas ok
source.blocks();                // ```lang fences, also unclosed ones
source.blocks(tags: ['a']);     // <a attrs>body</a>; '*' for any tag
source.think;                   // <think>/<thinking>, also truncated ones
source.withoutThink;            // the answer without reasoning
source.fields(keys: ['name']);  // "Key: v", "- Key: v", "**Key:** v"
source.listItems;               // "1. x", "- x" (nested, wrapped)
```

## Find quotes

```dart
final source = Source(text);              // strict comparison
final loose = source.normalize();         // ignores case, whitespace, typography

source.find(quote, fuzzy: false);         // exact matches only
loose.find(quote);                        // exact matches, else fuzzy ones
loose.find(quote, minScore: 0.9);         // stricter fuzzy threshold
loose.findEach(quotes, distinct: true);   // one list per quote, no shared passage
loose.coverage(answer).ratio;             // share of the answer found in the text
```

## Text structure

```dart
source.sentences; source.paragraphs;           // List<Span>
source.chunks(maxLength: 1000, overlap: 100);  // paragraph/sentence-aware
source.expand(span, Boundary.sentence);        // word, line, sentence, paragraph
source.positionOf(offset);                     // zero-based line:column
diffWords(a, b);                               // word-level DiffSegments
normalizeUnicode(text);                        // curly quotes, dashes, ligatures
```
