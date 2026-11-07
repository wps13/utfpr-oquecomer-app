import '../../utils/recipe_name_search.dart';

/// Alimento guardado na despensa a partir de um escaneamento de imagem.
///
/// O [id] é o nome normalizado (sem acentos, caixa ou espaços repetidos) e
/// identifica o item: o mesmo alimento escaneado de novo não gera outro item.
/// O [name] mantém a grafia original, para exibição.
class PantryItem {
  PantryItem({required String name, required this.scannedAt})
    : name = name.trim(),
      id = idFor(name);

  factory PantryItem.fromJson(Map<String, Object?> json) {
    final name = json['nome'];
    final scannedAt = json['escaneado_em'];
    if (name is! String || name.trim().isEmpty || scannedAt is! String) {
      throw const FormatException('Item de despensa inválido.');
    }
    return PantryItem(name: name, scannedAt: DateTime.parse(scannedAt));
  }

  /// Chave de comparação: "Pimentão  Verde " e "pimentao verde" são o mesmo
  /// alimento. Plural e sinônimos não são tratados. Vazio se não há texto.
  static String idFor(String name) =>
      normalizeRecipeName(name).replaceAll(RegExp(r'\s+'), ' ');

  final String id;
  final String name;
  final DateTime scannedAt;

  Map<String, Object?> toJson() => {
    'nome': name,
    'escaneado_em': scannedAt.toUtc().toIso8601String(),
  };

  PantryItem copyWithScannedAt(DateTime scannedAt) =>
      PantryItem(name: name, scannedAt: scannedAt);

  @override
  bool operator ==(Object other) =>
      other is PantryItem &&
      other.id == id &&
      other.name == name &&
      other.scannedAt == scannedAt;

  @override
  int get hashCode => Object.hash(id, name, scannedAt);

  @override
  String toString() => 'PantryItem($name, $scannedAt)';
}
