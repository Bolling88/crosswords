import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Disable network fetching so google_fonts resolves synchronously from
    // assets. The font files themselves are not bundled in tests, so the async
    // load silently no-ops rather than firing network requests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // The font-load future is fire-and-forget; the TextStyle fields we care
  // about (fontSize, fontWeight, color) are set synchronously before the
  // background fetch starts. We use testWidgets + pumpAndSettle to drain any
  // pending microtasks so the post-test failure does not bleed through.

  testWidgets('answerLetter applies the given size and weight', (tester) async {
    final style = AppTextStyles.answerLetter(20, family: 'Caveat');

    expect(style.fontSize, 20);
    expect(style.fontWeight?.value, isNotNull);
  });

  testWidgets('answerLetter works with no family (default font)', (tester) async {
    final style = AppTextStyles.answerLetter(18);

    expect(style.fontSize, 18);
  });

  testWidgets('clue applies the given size with and without a family', (tester) async {
    expect(AppTextStyles.clue(12, family: 'Kalam').fontSize, 12);
    expect(AppTextStyles.clue(12).fontSize, 12);
  });
}
