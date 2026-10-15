import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/ui/home/view_models/home_viewmodel.dart';

void main() {
  group('HomeViewModel tests', () {
    final viewModel = HomeViewModel();

    test('should create instance correctly', () {
      expect(viewModel.toString(), isNotEmpty);
    });
  });
}
