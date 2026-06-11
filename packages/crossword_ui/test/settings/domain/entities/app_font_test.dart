import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('there are 9 fonts and Patrick Hand is the default', () {
    expect(AppFont.values.length, 9);
    expect(AppFont.defaultFont, AppFont.patrickHand);
  });

  test('each font exposes a non-empty Google family and display name', () {
    for (final font in AppFont.values) {
      expect(font.googleFamily, isNotEmpty);
      expect(font.displayName, isNotEmpty);
    }
  });

  test('fromName round-trips a valid enum name', () {
    expect(AppFont.fromName(AppFont.caveat.name), AppFont.caveat);
  });

  test('fromName falls back to the default for null or unknown names', () {
    expect(AppFont.fromName(null), AppFont.defaultFont);
    expect(AppFont.fromName('not-a-font'), AppFont.defaultFont);
  });
}
