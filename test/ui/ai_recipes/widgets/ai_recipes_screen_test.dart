import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/ai_repository.dart';
import 'package:o_que_comer_app/data/services/location/location_service.dart';
import 'package:o_que_comer_app/data/services/permissions/permission_service.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/ai_recipes_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_pantry_repository.dart';

class _FakeAiRepository implements AiRepository {
  @override
  Future<Recipe> generateRecipe(
    List<String> ingredients, {
    int servings = 2,
    String? location,
  }) async => throw UnimplementedError();

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) async => const [];
}

class _FakePermissionService implements PermissionService {
  PermissionAccess access;
  int checks = 0;
  int requests = 0;

  _FakePermissionService(this.access);

  @override
  Future<PermissionAccess> check(AppPermission permission) async {
    checks++;
    return access;
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) async {
    requests++;
    return access;
  }

  @override
  Future<bool> openSettings() async => false;
}

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.location);

  final String location;
  int requests = 0;

  @override
  Future<String> getCurrentLocation() async {
    requests++;
    return location;
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakePermissionService permissionService,
    required _FakeLocationService locationService,
  }) => tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AiRecipesViewModel(
            repository: _FakeAiRepository(),
            pantryRepository: FakePantryRepository(),
          ),
        ),
        Provider<PermissionService>.value(value: permissionService),
        Provider<LocationService>.value(value: locationService),
      ],
      child: const MaterialApp(home: AiRecipesScreen()),
    ),
  );

  testWidgets('loads and displays the device location', (tester) async {
    final permission = _FakePermissionService(PermissionAccess.granted);
    final location = _FakeLocationService('Curitiba, PR');
    await pumpScreen(
      tester,
      permissionService: permission,
      locationService: location,
    );

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();

    expect(find.text('Curitiba, PR'), findsOneWidget);
    expect(find.text('Localização usada:'), findsNothing);
    expect(permission.checks, 1);
    expect(location.requests, 1);
  });

  testWidgets('asks for confirmation before requesting denied permission', (
    tester,
  ) async {
    final permission = _FakePermissionService(PermissionAccess.denied);
    final location = _FakeLocationService('Curitiba, PR');
    await pumpScreen(
      tester,
      permissionService: permission,
      locationService: location,
    );

    await tester.tap(find.text('Usar minha localização'));
    await tester.pump();
    expect(find.text('Permitir localização?'), findsOneWidget);
    expect(permission.requests, 0);
    expect(location.requests, 0);

    await tester.tap(find.text('Não permitir'));
    await tester.pump();
    expect(find.text('Localização indisponível'), findsOneWidget);
    expect(permission.requests, 0);
    expect(location.requests, 0);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
  });
}
