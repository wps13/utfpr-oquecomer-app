import 'package:flutter/material.dart';

/// Imagem da receita com placeholder enquanto carrega ou se falhar.
class RecipeImage extends StatelessWidget {
  const RecipeImage({this.url, this.iconSize = 44, super.key});

  final String? url;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final uri = url == null ? null : Uri.tryParse(url!);
    final placeholder = Semantics(
      label: 'Imagem indisponível',
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryFixed,
        child: Center(
          child: Icon(
            Icons.restaurant,
            size: iconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return placeholder;
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (_, error, stack) => placeholder,
    );
  }
}
