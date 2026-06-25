/// Deterministic placeholder clue prose for previewing clue-cell layout before
/// real clue text is wired through from the generator. Keyed by word id so each
/// clue stays stable across rebuilds, with varied lengths that mimic real
/// Swedish crossword clues (single words through short definitions).
///
/// This is a temporary preview affordance — remove once `Word.clueText` carries
/// authored prose for generated puzzles.
library;

const List<String> _mockClues = <String>[
  'Katt',
  'Älg',
  'Öl',
  'Tåg',
  'Ro',
  'Is',
  'Fågel',
  'Regent',
  'Verktyg',
  'Blomma',
  'Höns',
  'Snabb',
  'Stor sjö',
  'Gör deg',
  'Liten ö',
  'Ger ljus',
  'Kan vara sur',
  'Del av foten',
  'Finns i havet',
  'Gammalt vapen',
  'Mjuk metall',
  'Plats för djur',
  'Sägs vid möte',
  'Personligt pronomen',
  'Kungligt påbud',
  'Del av året',
  'Färgglad fjäril',
  'Har många ekrar',
];

/// Returns a stable mock clue for [wordId]. Deterministic: the same id always
/// maps to the same clue, so the preview does not flicker between rebuilds.
String mockClueText(String wordId) {
  var hash = 0;
  for (final unit in wordId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _mockClues[hash % _mockClues.length];
}
