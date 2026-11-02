/// A API do catálogo devolve ingredientes como um único texto separado por
/// vírgulas e o modo de preparo como um parágrafo numerado ("1. ... 2. ...").
/// Estas funções quebram esses textos em itens para exibição.
library;

/// Separa por vírgula seguida de espaço, fora de parênteses. Vírgula decimal
/// ("1,5 kg") não tem espaço depois e é preservada.
List<String> splitIngredients(List<String> ingredients) => [
  for (final entry in ingredients) ..._splitOutsideParentheses(entry),
];

/// Separa parágrafos numerados ("1. ... 2. ...") em passos, sem o número.
/// Também aceita passos em linhas separadas. Sem esses padrões, mantém o texto.
List<String> splitSteps(List<String> steps) => [
  for (final entry in steps) ..._splitStep(entry),
];

Iterable<String> _splitOutsideParentheses(String text) sync* {
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '(') depth++;
    if (char == ')' && depth > 0) depth--;
    final isSeparator =
        char == ',' &&
        depth == 0 &&
        i + 1 < text.length &&
        text[i + 1].trim().isEmpty;
    if (isSeparator) {
      final item = buffer.toString().trim();
      if (item.isNotEmpty) yield item;
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) yield last;
}

/// "1." ou "1)" no início do texto ou depois de espaço, seguido de espaço.
/// Os espaços ficam fora do match para números vizinhos não se "engolirem".
final _stepNumber = RegExp(r'(?<=^|\s)(\d{1,2})[.)](?=\s)');

Iterable<String> _splitStep(String text) sync* {
  // Só vale a numeração em sequência (1, 2, 3...): números soltos no texto,
  // como "a 180. Depois", não abrem um passo novo.
  final matches = <RegExpMatch>[];
  for (final match in _stepNumber.allMatches(text)) {
    if (int.parse(match.group(1)!) == matches.length + 1) matches.add(match);
  }
  final numbered = matches.length >= 2;
  if (numbered) {
    for (var i = 0; i < matches.length; i++) {
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final step = text.substring(matches[i].end, end).trim();
      if (step.isNotEmpty) yield step;
    }
    return;
  }
  for (final line in text.split('\n')) {
    final step = line.trim();
    if (step.isNotEmpty) yield step;
  }
}
