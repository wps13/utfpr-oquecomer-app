/// Categoria identificada pelo campo `tipo` retornado pelo catálogo.
class RecipeCategory {
  const RecipeCategory(this.id);

  final String id;

  String get label => switch (id) {
    'doce' => 'Doce',
    'salgado' => 'Salgado',
    'agridoce' => 'Agridoce',
    _ => id.isEmpty ? 'Categoria' : '${id[0].toUpperCase()}${id.substring(1)}',
  };

  @override
  bool operator ==(Object other) => other is RecipeCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
