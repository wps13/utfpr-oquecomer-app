import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/pantry_item.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/inventory/view_models/inventory_viewmodel.dart';

import '../../../../testing/fakes/fake_pantry_repository.dart';

void main() {
  late FakePantryRepository repository;
  late InventoryViewModel viewModel;

  setUp(() {
    repository = FakePantryRepository();
    viewModel = InventoryViewModel(repository: repository);
  });

  tearDown(() => viewModel.dispose());

  test('carrega os itens da despensa', () async {
    final item = PantryItem(
      name: 'Tomate',
      scannedAt: DateTime.utc(2026, 5, 1),
    );
    repository.items.add(item);

    await viewModel.load();

    expect(viewModel.state, ViewState.success);
    expect(viewModel.items, [item]);
  });

  test('remove o item da lista e do repositório', () async {
    final item = PantryItem(
      name: 'Tomate',
      scannedAt: DateTime.utc(2026, 5, 1),
    );
    repository.items.add(item);
    await viewModel.load();

    await viewModel.remove(item.id);

    expect(viewModel.items, isEmpty);
    expect(repository.removedIds, [item.id]);
  });

  test('restaura o item e exibe erro quando a remoção falha', () async {
    final item = PantryItem(
      name: 'Tomate',
      scannedAt: DateTime.utc(2026, 5, 1),
    );
    repository.items.add(item);
    await viewModel.load();
    repository.error = Exception('falhou');

    await viewModel.remove(item.id);

    expect(viewModel.state, ViewState.error);
    expect(viewModel.items, [item]);
    expect(viewModel.errorMessage, contains('falhou'));
  });
}
