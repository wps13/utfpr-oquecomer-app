import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_test/hive_ce_test.dart';
import 'package:o_que_comer_app/data/repositories/pantry_repository.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';

class _RecordingErrorReporter implements ErrorReporter {
  final errors = <Object>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async => errors.add(error);
}

class _FailingBox implements PantryBox {
  @override
  Iterable<Object?> get values => throw StateError('leitura');

  @override
  Object? get(String key) => null;

  @override
  Future<void> putAll(Map<String, Map<String, Object?>> entries) async =>
      throw StateError('escrita');
}

void main() {
  late Box<dynamic> box;
  late DateTime now;
  late _RecordingErrorReporter reporter;
  late LocalPantryRepository repository;

  LocalPantryRepository build(PantryBox pantryBox) => LocalPantryRepository(
    box: pantryBox,
    errorReporter: reporter,
    now: () => now,
  );

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox<dynamic>('pantry');
    now = DateTime.utc(2026, 5, 1, 12);
    reporter = _RecordingErrorReporter();
    repository = build(HivePantryBox(box));
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('começa vazia', () async {
    expect(await repository.getItems(), isEmpty);
  });

  test('guarda cada alimento com nome e data do escaneamento', () async {
    await repository.saveScanned(['Tomate', 'Ovo']);

    final items = await repository.getItems();

    expect(items.map((item) => item.name), unorderedEquals(['Tomate', 'Ovo']));
    expect(items.every((item) => item.scannedAt == now), isTrue);
  });

  test('alimento repetido não duplica e mantém o nome original', () async {
    await repository.saveScanned(['Pimentão Verde']);
    now = DateTime.utc(2026, 5, 2);

    await repository.saveScanned(['pimentao  verde ', 'PIMENTÃO VERDE']);

    final items = await repository.getItems();
    expect(items, hasLength(1));
    expect(items.single.name, 'Pimentão Verde');
    expect(box.length, 1);
  });

  test('repetir o alimento atualiza a data do escaneamento', () async {
    await repository.saveScanned(['Tomate', 'Ovo']);
    now = DateTime.utc(2026, 5, 3);

    await repository.saveScanned(['tomate']);

    final items = await repository.getItems();
    expect(items.map((item) => item.name), ['Tomate', 'Ovo']);
    expect(items.first.scannedAt, DateTime.utc(2026, 5, 3));
    expect(items.last.scannedAt, DateTime.utc(2026, 5, 1, 12));
  });

  test('ordena do escaneamento mais recente para o mais antigo', () async {
    await repository.saveScanned(['Cebola']);
    now = DateTime.utc(2026, 5, 2);
    await repository.saveScanned(['Batata', 'Alho']);

    final items = await repository.getItems();

    // Mesma data: desempate pelo nome.
    expect(items.map((item) => item.name), ['Alho', 'Batata', 'Cebola']);
  });

  test('ignora nomes vazios e não grava nada para lista vazia', () async {
    await repository.saveScanned(['  ', '']);
    await repository.saveScanned(const []);

    expect(await repository.getItems(), isEmpty);
  });

  test(
    'itens continuam disponíveis depois de reabrir o armazenamento',
    () async {
      await repository.saveScanned(['Tomate', 'Ovo']);

      await box.close();
      final reopened = await Hive.openBox<dynamic>('pantry');
      final items = await build(HivePantryBox(reopened)).getItems();

      expect(
        items.map((item) => item.name),
        unorderedEquals(['Tomate', 'Ovo']),
      );
      expect(items.first.scannedAt, now);
    },
  );

  test('registro ilegível é sobrescrito ao escanear o alimento', () async {
    await box.put('tomate', {'nome': 1});

    await repository.saveScanned(['Tomate']);

    final items = await repository.getItems();
    expect(items.single.name, 'Tomate');
  });

  test('registro ilegível na leitura é reportado e propagado', () async {
    await box.put('tomate', 'texto');

    await expectLater(repository.getItems(), throwsFormatException);
    expect(reporter.errors.single, isA<PantryStorageError>());
  });

  test('falha ao gravar é reportada e propagada', () async {
    final failing = build(_FailingBox());

    await expectLater(failing.saveScanned(['Tomate']), throwsStateError);
    await expectLater(failing.getItems(), throwsStateError);

    expect(reporter.errors.map((error) => error.toString()), [
      'PantryStorageError(write)',
      'PantryStorageError(read)',
    ]);
  });

  group('InMemoryPantryBox', () {
    test('guarda e deduplica como o armazenamento em disco', () async {
      final memory = build(InMemoryPantryBox());

      await memory.saveScanned(['Tomate', 'tomate', 'Ovo']);
      await memory.saveScanned(['ÓVO']);

      final items = await memory.getItems();
      expect(
        items.map((item) => item.name),
        unorderedEquals(['Tomate', 'Ovo']),
      );
    });
  });
}
