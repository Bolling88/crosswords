import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_cubit.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  Map<String, dynamic>? captured;

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
  }) async {
    captured = {
      'width': width,
      'height': height,
      'maxWordLen': maxWordLen,
      'seedWords': seedWords,
      'languageCode': languageCode,
      'randomSeed': randomSeed,
      'maxSeconds': maxSeconds,
      'pictureCols': pictureCols,
      'pictureRows': pictureRows,
    };
    throw _StopAfterCapture();
  }

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() => throw UnimplementedError();
}

class _StopAfterCapture implements Exception {}

void main() {
  group('GeneratePuzzleCubit', () {
    test('max seconds stepper clamps within bounds', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService(), generatedPuzzleTitle: 'Korsord');
      // default 30 -> repeatedly decrement past the floor.
      for (var i = 0; i < 20; i++) {
        cubit.decrementMaxSeconds();
      }
      expect(cubit.state.maxSeconds, GenerateState.minMaxSeconds);
      for (var i = 0; i < 60; i++) {
        cubit.incrementMaxSeconds();
      }
      expect(cubit.state.maxSeconds, GenerateState.maxMaxSeconds);
      cubit.close();
    });

    test('picture cols clamp to grid width and never below zero', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService(), generatedPuzzleTitle: 'Korsord');
      cubit.selectSize(11);
      for (var i = 0; i < 20; i++) {
        cubit.incrementPictureCols();
      }
      expect(cubit.state.pictureCols, 11);
      // shrinking the grid clamps pictures down.
      cubit.selectSize(11); // already 11; now ensure decrement floor
      for (var i = 0; i < 20; i++) {
        cubit.decrementPictureCols();
      }
      expect(cubit.state.pictureCols, 0);
      cubit.close();
    });

    test('selectSize clamps existing picture dims down to new size', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService(), generatedPuzzleTitle: 'Korsord');
      cubit.selectSize(17);
      for (var i = 0; i < 17; i++) {
        cubit.incrementPictureCols();
        cubit.incrementPictureRows();
      }
      expect(cubit.state.pictureCols, 17);
      cubit.selectSize(11);
      expect(cubit.state.pictureCols, 11);
      expect(cubit.state.pictureRows, 11);
      cubit.close();
    });

    test('generate forwards all fields including parsed random seed', () async {
      final service = _FakeService();
      final cubit =
          GeneratePuzzleCubit(service: service, generatedPuzzleTitle: 'Korsord');
      cubit.selectSize(17);
      cubit.selectMaxWordLen(8);
      cubit.incrementMaxSeconds(); // 30 -> 35
      cubit.seedWordsController.text = 'katt, hund';
      cubit.randomSeedController.text = '42';

      await cubit.generate();

      expect(service.captured?['width'], 17);
      expect(service.captured?['maxWordLen'], 8);
      expect(service.captured?['maxSeconds'], 35);
      expect(service.captured?['languageCode'], 'sv');
      expect(service.captured?['randomSeed'], 42);
      expect(service.captured?['seedWords'], ['KATT', 'HUND']);
      cubit.close();
    });

    test('blank random seed is forwarded as null', () async {
      final service = _FakeService();
      final cubit =
          GeneratePuzzleCubit(service: service, generatedPuzzleTitle: 'Korsord');
      cubit.randomSeedController.text = '   ';

      await cubit.generate();

      expect(service.captured?['randomSeed'], isNull);
      cubit.close();
    });
  });
}
