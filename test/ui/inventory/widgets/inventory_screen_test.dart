import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/pantry_item.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/inventory/view_models/inventory_viewmodel.dart';
import 'package:o_que_comer_app/ui/inventory/widgets/inventory_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_pantry_repository.dart';

void main() {
  late FakePantryRepository repository;
  late InventoryViewModel viewModel;

  setUp(() {
    repository = FakePantryRepository();
    viewModel = InventoryViewModel(repository: repository);
  });

  tearDown(() => viewModel.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InventoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exibe botão de voltar na app bar', (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('exibe estado vazio quando não há alimentos', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Sua despensa está vazia'), findsOneWidget);
  });

  testWidgets('confirma antes de remover e atualiza a lista', (tester) async {
    repository.items.add(
      PantryItem(name: 'Tomate', scannedAt: DateTime.utc(2026, 5, 1)),
    );
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Remover Tomate'));
    await tester.pumpAndSettle();

    expect(find.text('Remover alimento?'), findsOneWidget);
    expect(find.text('Tomate'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remover Tomate'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover Tomate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Sua despensa está vazia'), findsOneWidget);
    expect(repository.removedIds, ['tomate']);
  });
}
