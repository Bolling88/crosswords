import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final CrosswordUiL10n _l10n = lookupCrosswordUiL10n(const Locale('sv'));

const List<LocalizationsDelegate<dynamic>> _delegates = [
  CrosswordUiL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> _locales = [Locale('sv'), Locale('en')];

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
        locale: const Locale('sv'),
        localizationsDelegates: _delegates,
        supportedLocales: _locales,
        home: RepositoryProvider<PuzzleGenerationService>.value(
          value: _FakeServiceWithGenerate(),
          child: GenerateScreen(
            gameplayBuilder: (_, puzzle) =>
                Scaffold(body: Text('PLAYING ${puzzle.title}')),
          ),
        ),
      ),
    );

    expect(find.text(_l10n.generateTitle), findsOneWidget);

    await tester.ensureVisible(find.text(_l10n.generateAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.generateAction));
    await tester.pumpAndSettle();

    expect(
      find.text('PLAYING ${_l10n.generatedPuzzleTitle}'),
      findsOneWidget,
    );
  });

  testWidgets('renders new field labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: _delegates,
        supportedLocales: _locales,
        home: RepositoryProvider<PuzzleGenerationService>.value(
          value: _FakeService(),
          child: GenerateScreen(gameplayBuilder: (_, _) => const SizedBox()),
        ),
      ),
    );

    expect(find.text(_l10n.generateLanguageLabel), findsOneWidget);
    expect(find.text(_l10n.generateMaxSecondsLabel), findsOneWidget);
    expect(find.text(_l10n.generatePictureColsLabel), findsOneWidget);
    expect(find.text(_l10n.generatePictureRowsLabel), findsOneWidget);
    expect(find.text(_l10n.generateRandomSeedLabel), findsOneWidget);
  });
}
