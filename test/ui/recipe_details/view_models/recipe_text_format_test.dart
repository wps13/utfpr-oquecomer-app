import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/ui/recipe_details/view_models/recipe_text_format.dart';

void main() {
  group('splitIngredients', () {
    test('splits the single comma-separated text sent by the API', () {
      expect(
        splitIngredients([
          '500g de peito de frango em cubos, 1 cebola, sal e pimenta a gosto',
        ]),
        [
          '500g de peito de frango em cubos',
          '1 cebola',
          'sal e pimenta a gosto',
        ],
      );
    });

    test('keeps decimal commas and commas inside parentheses', () {
      expect(
        splitIngredients(['1,5 kg de batata, 2 ovos (cozidos, picados)']),
        ['1,5 kg de batata', '2 ovos (cozidos, picados)'],
      );
    });

    test('keeps lists that are already split', () {
      expect(splitIngredients(['Massa', 'Carne moída']), [
        'Massa',
        'Carne moída',
      ]);
    });
  });

  group('splitSteps', () {
    test('splits a numbered paragraph and removes the numbers', () {
      expect(
        splitSteps([
          '1. Tempere o frango. 2. Aqueça o óleo a 180°C. 3. Sirva quente.',
        ]),
        ['Tempere o frango.', 'Aqueça o óleo a 180°C.', 'Sirva quente.'],
      );
    });

    test('accepts "1)" numbering and numbers above nine', () {
      final text = [for (var i = 1; i <= 10; i++) '$i) Passo $i.'].join(' ');
      final steps = splitSteps([text]);

      expect(steps, hasLength(10));
      expect(steps.last, 'Passo 10.');
    });

    test('splits steps on separate lines', () {
      expect(splitSteps(['Misture.\nAsse.\n']), ['Misture.', 'Asse.']);
    });

    test('does not break quantities that look like numbers', () {
      expect(splitSteps(['Asse por 25 min a 180 graus.']), [
        'Asse por 25 min a 180 graus.',
      ]);
    });

    test('keeps lists that are already split', () {
      expect(splitSteps(['Cozinhe.', 'Monte.']), ['Cozinhe.', 'Monte.']);
    });
  });
}
