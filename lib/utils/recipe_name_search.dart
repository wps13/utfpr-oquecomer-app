/// Normaliza caixa e acentos comuns a nomes em português, incluindo texto
/// Unicode decomposto (como `a` seguido por um acento combinante).
String normalizeRecipeName(String text) {
  const accents = 'áàâãäåéèêëíìîïóòôõöúùûüçñýÿ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucnyy';
  final result = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036f) continue;
    final character = String.fromCharCode(rune);
    final index = accents.indexOf(character);
    result.write(index < 0 ? character : plain[index]);
  }
  return result.toString().trim();
}
