import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/utils/recipe_name_search.dart';

void main() {
  const cases = {
    'PÃO DE AÇÚCAR': 'pao de acucar',
    'Crème brûlée': 'creme brulee',
    'LIMÃO': 'limao',
    ' A\u0301gua e macarra\u0303o ': 'agua e macarrao',
    '  Bolo de cenoura  ': 'bolo de cenoura',
    '': '',
    ' \t\n ': '',
    'Doce & salgado': 'doce & salgado',
  };
  for (final entry in cases.entries) {
    test('normaliza ${entry.key}', () {
      expect(normalizeRecipeName(entry.key), entry.value);
    });
  }
}
