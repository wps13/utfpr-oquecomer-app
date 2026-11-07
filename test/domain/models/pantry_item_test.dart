import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/pantry_item.dart';

void main() {
  group('idFor', () {
    test('ignora caixa, acentos e espaços nas pontas e repetidos', () {
      expect(PantryItem.idFor('Pimentão  Verde '), 'pimentao verde');
      expect(PantryItem.idFor('pimentao verde'), 'pimentao verde');
      expect(PantryItem.idFor('  AÇÚCAR\tMASCAVO '), 'acucar mascavo');
    });

    test('trata acento combinante (Unicode decomposto)', () {
      expect(PantryItem.idFor('Feijão'), PantryItem.idFor('feijao'));
    });

    test('não trata plural nem sinônimos', () {
      expect(PantryItem.idFor('tomates'), isNot(PantryItem.idFor('tomate')));
    });

    test('texto vazio gera id vazio', () {
      expect(PantryItem.idFor('   '), isEmpty);
    });
  });

  test('guarda o nome original sem espaços nas pontas', () {
    final item = PantryItem(
      name: '  Pimentão Verde ',
      scannedAt: DateTime.utc(2026, 1, 1),
    );

    expect(item.name, 'Pimentão Verde');
    expect(item.id, 'pimentao verde');
  });

  test('converte de e para JSON', () {
    final item = PantryItem(
      name: 'Tomate',
      scannedAt: DateTime.utc(2026, 3, 4, 10, 30),
    );

    expect(item.toJson(), {
      'nome': 'Tomate',
      'escaneado_em': '2026-03-04T10:30:00.000Z',
    });
    expect(PantryItem.fromJson(item.toJson()), item);
  });

  test('rejeita JSON inválido', () {
    for (final json in <Map<String, Object?>>[
      {},
      {'nome': 'Tomate'},
      {'nome': '  ', 'escaneado_em': '2026-01-01T00:00:00.000Z'},
      {'nome': 1, 'escaneado_em': '2026-01-01T00:00:00.000Z'},
    ]) {
      expect(() => PantryItem.fromJson(json), throwsFormatException);
    }
  });

  test('copyWithScannedAt mantém nome e id e troca só a data', () {
    final item = PantryItem(name: 'Ovo', scannedAt: DateTime.utc(2026, 1, 1));

    final updated = item.copyWithScannedAt(DateTime.utc(2026, 2, 1));

    expect(updated.name, 'Ovo');
    expect(updated.id, item.id);
    expect(updated.scannedAt, DateTime.utc(2026, 2, 1));
    expect(updated, isNot(item));
  });
}
