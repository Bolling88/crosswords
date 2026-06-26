import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() => throw UnimplementedError();
}

class _FakeServiceWithGenerate implements PuzzleGenerationService {
  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) async =>
      CrosswordPuzzle(
        rows: 1,
        cols: 1,
        cells: const {},
        words: const [],
        title: title,
        languageCode: languageCode,
      );

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() async => generate(
        width: 1,
        height: 1,
        maxWordLen: 6,
        title: 'bundled',
      );
}

void main() {
  testWidgets('shows controls and navigates on generate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<PuzzleGenerationService>.value(
          value: _FakeServiceWithGenerate(),
          child: GenerateScreen(
            gameplayBuilder: (_, puzzle) =>
                Scaffold(body: Text('PLAYING ${puzzle.title}')),
          ),
        ),
      ),
    );

    expect(find.text(Strings.generateTitle), findsOneWidget);

    await tester.ensureVisible(find.text(Strings.generateAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.generateAction));
    await tester.pumpAndSettle();

    expect(
      find.text('PLAYING ${Strings.generatedPuzzleTitle}'),
      findsOneWidget,
    );
  });

  testWidgets('renders new field labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<PuzzleGenerationService>.value(
          value: _FakeService(),
          child: GenerateScreen(gameplayBuilder: (_, _) => const SizedBox()),
        ),
      ),
    );

    expect(find.text(Strings.generateLanguageLabel), findsOneWidget);
    expect(find.text(Strings.generateMaxSecondsLabel), findsOneWidget);
    expect(find.text(Strings.generatePictureColsLabel), findsOneWidget);
    expect(find.text(Strings.generatePictureRowsLabel), findsOneWidget);
    expect(find.text(Strings.generateRandomSeedLabel), findsOneWidget);
  });
}
