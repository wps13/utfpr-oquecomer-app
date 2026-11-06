import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:o_que_comer_app/data/repositories/ai_repository.dart';
import 'package:o_que_comer_app/data/repositories/pantry_repository.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/domain/models/ai_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/ai_recipes_screen.dart';
import 'package:provider/provider.dart';

/// Teste no aparelho (APP-40): o fluxo real da tela de receita com IA, com o
/// armazenamento Hive real do Android/iOS. Só a IA é simulada, para não
/// depender de rede, chave do Gemini nem de uma foto.
///
///   flutter test integration_test/pantry_scan_test.dart -d ID_DO_APARELHO
///
/// Usa um box próprio, apagado antes e depois, e não mexe nos dados do app.
const _boxName = 'pantry_integration_test';

/// PNG 1x1 válido: a tela exibe a imagem enviada.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
  'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Responde a cada escaneamento com o próximo item da fila: uma lista de
/// alimentos ou uma exceção.
class _ScriptedAiRepository implements AiRepository {
  final queue = <Object>[];

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final next = queue.removeAt(0);
    if (next is Exception) throw next;
    return next as List<String>;
  }

  @override
  Future<Recipe> generateRecipe(
    List<String> ingredients, {
    int servings = 2,
    String? location,
  }) => throw UnimplementedError();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Box<dynamic> box;
  late _ScriptedAiRepository ai;
  late LocalPantryRepository pantry;

  LocalPantryRepository open(Box<dynamic> b) => LocalPantryRepository(
    box: HivePantryBox(b),
    errorReporter: const DisabledErrorReporter(),
  );

  setUpAll(() async {
    await Hive.initFlutter();
  });

  setUp(() async {
    await Hive.deleteBoxFromDisk(_boxName);
    box = await Hive.openBox<dynamic>(_boxName);
    ai = _ScriptedAiRepository();
    pantry = open(box);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(_boxName);
  });

  /// Envia uma "foto" e toca em "Detectar ingredientes", como o usuário.
  Future<void> scan(WidgetTester tester) async {
    tester
        .element(find.byType(AiRecipesScreen))
        .read<AiRecipesViewModel>()
        .setImage(bytes: _png, mimeType: 'image/png');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detectar ingredientes'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) =>
          AiRecipesViewModel(repository: ai, pantryRepository: pantry),
      child: const MaterialApp(home: AiRecipesScreen()),
    ),
  );

  testWidgets('guarda os alimentos escaneados, sem duplicar, e persiste', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(await pantry.getItems(), isEmpty);

    // 1º escaneamento: três alimentos novos, todos com a mesma data.
    final before = DateTime.now().toUtc();
    ai.queue.add(['Tomate', 'Pimentão Verde', 'ovo']);
    await scan(tester);

    var items = await pantry.getItems();
    expect(
      items.map((i) => i.name),
      unorderedEquals(['Tomate', 'Pimentão Verde', 'ovo']),
    );
    expect(items.map((i) => i.scannedAt).toSet(), hasLength(1));
    final firstScan = items.first.scannedAt;
    expect(firstScan.isBefore(before), isFalse);
    expect(firstScan.isAfter(DateTime.now().toUtc()), isFalse);

    // 2º escaneamento: repetidos com outra grafia + um alimento novo.
    ai.queue.add(['tomate ', 'PIMENTAO  verde', 'Cebola']);
    await scan(tester);

    items = await pantry.getItems();
    expect(items, hasLength(4), reason: 'repetidos não geram novos registros');
    expect(
      items.map((i) => i.name),
      unorderedEquals(['Tomate', 'Pimentão Verde', 'ovo', 'Cebola']),
      reason: 'o nome original da primeira vez é mantido',
    );
    final byName = {for (final i in items) i.name: i.scannedAt};
    expect(byName['Tomate']!.isAfter(firstScan), isTrue);
    expect(byName['Pimentão Verde'], byName['Tomate']);
    expect(byName['Cebola'], byName['Tomate']);
    expect(byName['ovo'], firstScan, reason: 'não escaneado: data intacta');

    // 3º escaneamento falha: nada é salvo.
    ai.queue.add(const AiFailure(AiFailureKind.connection));
    await scan(tester);

    expect(
      find.text(const AiFailure(AiFailureKind.connection).message),
      findsOneWidget,
    );
    expect(await pantry.getItems(), items);

    // Os dados estão no disco: reabrir o box devolve o mesmo conteúdo, e o
    // arquivo do aparelho contém o nome com acento.
    final path = box.path!;
    await box.close();
    final bytes = await File(path).readAsBytes();
    expect(
      _contains(bytes, utf8.encode('Pimentão Verde')),
      isTrue,
      reason: 'arquivo $path',
    );

    final reopened = await Hive.openBox<dynamic>(_boxName);
    expect(await open(reopened).getItems(), items);
  });
}

bool _contains(List<int> bytes, List<int> pattern) {
  for (var i = 0; i + pattern.length <= bytes.length; i++) {
    var j = 0;
    while (j < pattern.length && bytes[i + j] == pattern[j]) {
      j++;
    }
    if (j == pattern.length) return true;
  }
  return false;
}
