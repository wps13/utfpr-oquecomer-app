import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe_category.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/home/view_models/home_viewmodel.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';

void main() {
  late FakeCatalogRepository repository;
  late HomeViewModel vm;

  setUp(() {
    repository = FakeCatalogRepository();
    vm = HomeViewModel(repository: repository);
  });
  tearDown(() => vm.dispose());

  test('carrega todas as categorias fornecidas pelo repositório', () async {
    repository.categories = [
      const RecipeCategory('doce'),
      const RecipeCategory('nova'),
    ];
    expect(vm.state, ViewState.loading);
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.categories, repository.categories);
    expect(() => vm.categories.clear(), throwsUnsupportedError);
  });

  test('lista vazia é sucesso', () async {
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.categories, isEmpty);
    expect(vm.errorMessage, isNull);
  });

  test('falha de conexão permite uma nova tentativa bem-sucedida', () async {
    repository.loadCategories = () async => throw const NoConnectionFailure();
    await vm.load();
    expect(vm.state, ViewState.error);
    expect(vm.errorMessage, const NoConnectionFailure().message);
    repository.loadCategories = null;
    repository.categories = [const RecipeCategory('salgado')];
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.errorMessage, isNull);
    expect(repository.categoryCalls, 2);
  });

  test(
    'resposta antiga não substitui o resultado da consulta mais recente',
    () async {
      final first = Completer<List<RecipeCategory>>();
      repository.loadCategories = () => first.future;
      final pending = vm.load();
      repository.loadCategories = () async => [const RecipeCategory('doce')];
      await vm.load();
      first.complete([const RecipeCategory('salgado')]);
      await pending;
      expect(vm.categories, [const RecipeCategory('doce')]);
    },
  );

  test(
    'navegar para fora durante a consulta não notifica uma VM descartada',
    () async {
      final pending = Completer<List<RecipeCategory>>();
      repository.loadCategories = () => pending.future;
      final disposedVm = HomeViewModel(repository: repository);
      final loading = disposedVm.load();
      disposedVm.dispose();
      pending.complete([const RecipeCategory('doce')]);
      await expectLater(loading, completes);
    },
  );
}
