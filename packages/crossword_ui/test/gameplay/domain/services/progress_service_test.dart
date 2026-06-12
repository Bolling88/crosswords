import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProgressService> service([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    return ProgressService(prefs: await SharedPreferences.getInstance());
  }

  test('read returns null when nothing is stored', () async {
    expect((await service()).read('t'), isNull);
  });

  test('save/read round-trips inputs and revealed cells', () async {
    final sut = await service();
    const snapshot = ProgressSnapshot(
      userInputs: {(0, 1): 'A', (2, 3): 'Ö'},
      revealedCells: {(2, 3)},
    );

    await sut.save('t', snapshot);

    expect(sut.read('t'), snapshot);
  });

  test('saving an empty snapshot removes the stored entry', () async {
    final sut = await service();
    await sut.save('t', const ProgressSnapshot(userInputs: {(0, 0): 'A'}));

    await sut.save('t', const ProgressSnapshot());

    expect(sut.read('t'), isNull);
  });

  test('clear removes the stored entry', () async {
    final sut = await service();
    await sut.save('t', const ProgressSnapshot(userInputs: {(0, 0): 'A'}));

    await sut.clear('t');

    expect(sut.read('t'), isNull);
  });

  test('corrupt stored data falls back to null', () async {
    final sut = await service({'progress_t': 'not json'});

    expect(sut.read('t'), isNull);
  });
}
