import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async =>
      CrosswordPuzzle(
        rows: 1, cols: 1, cells: const {}, words: const [],
        title: title, languageCode: 'sv',
      );

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() async => generate(
        width: 1, height: 1, maxWordLen: 6, title: 'bundled',
      );
}

void main() {
  testWidgets('shows controls and navigates on generate', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GenerateScreen(
        service: _FakeService(),
        gameplayBuilder: (_, puzzle) =>
            Scaffold(body: Text('PLAYING ${puzzle.title}')),
      ),
    ));

    expect(find.text(Strings.generateTitle), findsOneWidget);
    expect(find.text(Strings.generateAction), findsOneWidget);

    await tester.tap(find.text(Strings.generateAction));
    await tester.pumpAndSettle();

    expect(find.text('PLAYING ${Strings.generatedPuzzleTitle}'),
        findsOneWidget);
  });
}
