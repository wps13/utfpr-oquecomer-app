import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/data/services/permissions/permission_service.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/main.dart';
import 'package:o_que_comer_app/ui/core/ui/permission_action.dart';
import 'package:o_que_comer_app/ui/core/view_models/permission_viewmodel.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';

class FakePermissionService implements PermissionService {
  PermissionAccess status = PermissionAccess.denied;
  PermissionAccess requestResult = PermissionAccess.granted;
  bool settingsOpened = true;
  int checks = 0;
  int requests = 0;
  int settingsCalls = 0;

  @override
  Future<PermissionAccess> check(AppPermission permission) async {
    checks++;
    return status;
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) async {
    requests++;
    return requestResult;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return settingsOpened;
  }
}

void main() {
  late FakePermissionService service;
  late List<PermissionAccess> authorized;

  setUp(() {
    service = FakePermissionService();
    authorized = [];
  });

  Future<void> pumpAction(
    WidgetTester tester, {
    AppPermission permission = AppPermission.camera,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PermissionAction(
          viewModel: PermissionViewModel(permissionService: service),
          permission: permission,
          onAuthorized: (access) async => authorized.add(access),
          builder: (context, onPressed) => ElevatedButton(
            onPressed: onPressed,
            child: const Text('Usar recurso'),
          ),
        ),
      ),
    ),
  );

  Future<void> activate(WidgetTester tester) async {
    await tester.tap(find.text('Usar recurso'));
    await tester.pumpAndSettle();
  }

  testWidgets('app starts without a native permission request', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>(create: (_) => FakeCatalogRepository()),
          Provider<FavoritesRepository>(
            create: (_) => InMemoryFavoritesRepository(),
          ),
          Provider<PermissionService>.value(value: service),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Favoritos'), findsOneWidget);
    expect(service.checks, 0);
    expect(service.requests, 0);
    expect(service.settingsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounting an action does not even check permissions', (
    tester,
  ) async {
    await pumpAction(tester);
    expect(service.checks, 0);
    expect(service.requests, 0);
    expect(authorized, isEmpty);
  });

  final rationales = {
    AppPermission.camera: 'câmera para tirar fotos',
    AppPermission.locationWhenInUse: 'opções de comida',
    AppPermission.microphone: 'microfone para captar sua voz',
    AppPermission.photos: 'suas fotos para que você escolha',
  };
  for (final entry in rationales.entries) {
    testWidgets('explains ${entry.key} in Portuguese before requesting', (
      tester,
    ) async {
      await pumpAction(tester, permission: entry.key);
      await activate(tester);
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(service.requests, 0);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(service.requests, 1);
      expect(authorized, [PermissionAccess.granted]);
    });
  }

  testWidgets('canceling the rationale never calls the native request', (
    tester,
  ) async {
    await pumpAction(tester);
    await activate(tester);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(authorized, isEmpty);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
      isTrue,
    );
  });

  testWidgets('denial explains the result and leaves the action usable', (
    tester,
  ) async {
    service.requestResult = PermissionAccess.denied;
    await pumpAction(tester);
    await activate(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Você pode continuar usando o app'),
      findsOneWidget,
    );
    expect(find.text('Abrir configurações'), findsNothing);
    expect(authorized, isEmpty);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await activate(tester);
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permanent denial opens settings only after explicit action', (
    tester,
  ) async {
    service.requestResult = PermissionAccess.permanentlyDenied;
    await pumpAction(tester);
    await activate(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('O acesso foi bloqueado'), findsOneWidget);
    expect(service.settingsCalls, 0);
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    expect(service.settingsCalls, 1);
    expect(authorized, isEmpty);

    service.status = PermissionAccess.granted;
    await activate(tester);
    expect(service.checks, 2);
    expect(authorized, [PermissionAccess.granted]);
  });

  testWidgets('failure to open settings displays recovery instructions', (
    tester,
  ) async {
    service.status = PermissionAccess.permanentlyDenied;
    service.settingsOpened = false;
    await pumpAction(tester);
    await activate(tester);
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível abrir as configurações'),
      findsOneWidget,
    );
    expect(service.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limited access reaches the feature without another prompt', (
    tester,
  ) async {
    service.status = PermissionAccess.limited;
    await pumpAction(tester, permission: AppPermission.photos);
    await activate(tester);
    expect(authorized, [PermissionAccess.limited]);
    expect(service.requests, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final status in [
    PermissionAccess.restricted,
    PermissionAccess.unavailable,
  ]) {
    testWidgets('$status blocks the feature with an explanation', (
      tester,
    ) async {
      service.status = status;
      await pumpAction(tester);
      await activate(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Abrir configurações'), findsNothing);
      expect(service.requests, 0);
      expect(authorized, isEmpty);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
