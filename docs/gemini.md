# Gemini — APP-31

A integração usa REST (`models.generateContent`) com o pacote `http` e duas
operações em `AiRepository`: `generateRecipe` e `identifyFoods`. Não existem
chamadas na abertura do app. A futura ViewModel chama cada operação quando
o usuário aciona o recurso.

O transporte desta integração fica em `JsonApiClient`. O `ApiClient` baseado em
Dio e seus clientes de catálogo/Gemini também são preservados para os contratos
introduzidos pelo APP-20.

## Configuração local

Crie uma chave de API no [Google AI Studio](https://aistudio.google.com/api-keys)
com a conta que terá acesso ao projeto e à API. O acesso ao aplicativo Gemini
pela universidade não substitui a chave exigida pela Gemini API. Se a conta
institucional impedir o acesso ao AI Studio, confirme a liberação com o
administrador/professor.

Copie o exemplo sem credenciais:

```sh
cp config/gemini.example.json config/gemini.local.json
```

Edite **somente** `config/gemini.local.json` e preencha `GEMINI_API_KEY`.
Esse arquivo está no `.gitignore`; não envie a chave em mensagens ou commits.
Confira a regra sem exibir o conteúdo:

```sh
git check-ignore config/gemini.local.json
flutter run \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=config/gemini.local.json
```

Prepare também `config/firebase.local.json` conforme a
[configuração Firebase do APP-19](firebase-crashlytics.md#variáveis-de-compilação).
O app inicializa o Firebase, por isso recebe os dois arquivos. Os testes unitários
e o teste manual isolado do Gemini não inicializam o Firebase e continuam sem
exigir esse arquivo adicional.

O app ainda não possui a tela de IA. Esse comando apenas fornece a configuração;
o teste manual abaixo é o caminho para validar chamadas reais neste card.
Não há carregamento automático de `.env`: a configuração utiliza
`String.fromEnvironment`, via `--dart-define` ou `--dart-define-from-file`.

O padrão é `gemini-3.5-flash-lite`, com suporte a imagens e saída estruturada,
temperatura `0.4`, limite de saída de `4096` tokens e timeout de `30` segundos.
`GEMINI_MODEL` permite escolher outro modelo compatível disponível no projeto.
Parâmetros e timeout podem ser substituídos por `GeminiConfig` na composição.
O limite de tokens pode interromper uma geração; saídas truncadas são rejeitadas.

A chave segue no header `x-goog-api-key`, nunca na URL. O arquivo local evita
versioná-la, mas valores de `dart-define` são incorporados ao binário e podem
ser extraídos. Um proxy para proteger a chave está fora do escopo deste card.

## Injeção nas ViewModels

`AiDependencies` concentra a composição do cliente HTTP, serviço e repositório.
Recebe o mesmo `ErrorReporter` inicializado no APP-19. Criá-lo não faz chamadas
nem exige uma chave preenchida; a falta de configuração é tratada no uso.

O `main` registra `AiRepository` via Provider e fecha as dependências no dispose.
As futuras telas podem injetar `context.read<AiRepository>()` no construtor de
suas ViewModels. O exemplo abaixo mostra a composição para uso isolado:

```dart
final ai = AiDependencies(errorReporter: errorReporter);
// Injete ai.repository pelo construtor da futura ViewModel.
// final viewModel = RecipeAiViewModel(aiRepository: ai.repository);
try {
  final recipe = await ai.repository.generateRecipe(['ovos', 'tomate']);
  // Exiba recipe usando o mesmo contrato do catálogo.
} on AiFailure catch (failure) {
  // A ViewModel pode expor failure.message e decidir pelo failure.kind.
} finally {
  ai.close();
}
```

Mantenha a instância viva durante o ciclo de vida de seu proprietário e chame
`close` ao encerrá-lo. Se fornecer `http.Client` próprio, ele também será fechado
por `AiDependencies.close`. Para testes, o cliente e o repositório são injetáveis.

Para fotos, chame `identifyFoods(imageBytes: bytes, mimeType: 'image/jpeg')`.
São aceitas imagens JPEG, PNG e WebP, não vazias, até **10 MiB** antes do Base64,
para manter o corpo abaixo do limite de envio inline. Captura, seleção,
compressão e permissões ficam a cargo da funcionalidade de tela (outro card).
Uma foto sem alimentos reconhecíveis retorna uma lista vazia, sem erro.

## Contratos e erros

Os prompts estão em `lib/data/services/ai/gemini_prompts.dart`. O serviço pede
JSON estruturado com `generationConfig.responseFormat.text`, incluindo o schema
de `gemini_schemas.dart`. Todos os textos são solicitados em português do Brasil.
O repositório valida os tipos, campos obrigatórios e valores positivos antes de
entregar os dados. A instrução de idioma depende da resposta do modelo; não há
detecção automática de idioma.

`Recipe` é o modelo compartilhado criado neste card para o futuro catálogo:
`id`, `title`, `description`, `ingredients` (com quantidades), `steps`,
`preparationMinutes`, `servings` e `source` (`catalog` ou `ai`). Listas são
imutáveis e `toJson`/`fromJson` preservam o contrato para futuros favoritos.
Cada geração recebe um ID aleatório local de 128 bits com prefixo `ai_`.
Não existe um modelo paralelo para receitas de IA nem persistência automática.

| `AiFailureKind` | Situação |
| --- | --- |
| `connection` | Falha do cliente HTTP, incluindo socket/DNS sem internet |
| `timeout` | Prazo local excedido ou HTTP 408/504 |
| `quotaExceeded` | HTTP 429; sem repetição automática que consuma mais cota |
| `configuration` | Chave/modelo/configuração inválidos ou HTTP 400/401/403/404 |
| `unavailable` | HTTP 5xx, exceto 504 |
| `invalidInput` | Lista de ingredientes ou foto inválida antes da requisição |
| `emptyResponse` | Corpo, candidatos ou texto de saída vazios |
| `invalidResponse` | JSON/envelope/campos inválidos ou resposta truncada |
| `blocked` | Bloqueio de entrada/saída informado pelo Gemini |
| `unexpected` | Outros status HTTP e falhas inesperadas |

Todos expõem mensagem em português. Apenas falhas inesperadas são reportadas
como não fatais ao `ErrorReporter`, com operação, tipo de erro e stack trace.
Não são enviados mensagem original, resposta, ingredientes, bytes ou chave.
As regras de envio em release/debug são as do APP-19. Falha na telemetria não
substitui o erro de domínio entregue à ViewModel.

## Validação

Testes com HTTP simulado, sem chave nem consumo de cota:

```sh
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test tool
```

Teste manual opcional com a API real (consome cota, não executado no CI):

```sh
flutter test tool/gemini_smoke_test.dart \
  --dart-define-from-file=config/gemini.local.json
```

Para testar uma foto, crie a pasta abaixo e coloque nela uma imagem de alimentos
com o nome `alimentos.jpg` (JPEG). O conteúdo de `local/gemini/` é ignorado pelo
Git, assim como a chave local. A pasta precisa ser criada em cada checkout:

```sh
mkdir -p local/gemini
```

Execute apenas o teste de foto:

```sh
flutter test tool/gemini_smoke_test.dart \
  --plain-name="API real identifica alimentos em uma foto local" \
  --dart-define-from-file=config/gemini.local.json \
  --dart-define=GEMINI_SMOKE_IMAGE=local/gemini/alimentos.jpg
```

O caminho pode ser alterado para outro JPEG, PNG ou WebP de até 10 MiB.
O teste exibe os alimentos identificados no terminal para comparação com a foto;
uma lista vazia é informada explicitamente. A imagem é enviada à API Gemini
somente ao executar esse teste.

Revise o conteúdo em português retornado ao testar a API real. Os testes
simulados verificam o contrato, as instruções de idioma, o envio da foto e os
erros; não comprovam a qualidade de identificação/receita do modelo real.

## Validação realizada

- Geração, parsing e falhas cobertos por 47 testes adicionados no APP-31,
  executados junto à suíte das demais funcionalidades.
- Geração de receita e identificação de alimentos por foto validadas com a API
  real pelo teste manual, usando a configuração local do desenvolvedor.
- App compilado, instalado e iniciado em debug no emulador Pixel 8 e em um
  Samsung SM-S911B com Android 16 (API 36).
- Chave de API e foto de validação mantidas em caminhos ignorados pelo Git.

## Referências oficiais

- [REST e formato de resposta](https://ai.google.dev/api/generate-content)
- [Gemini 3.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite)
- [Chaves de API e acesso ao projeto](https://ai.google.dev/gemini-api/docs/api-key)
- [Imagens e limites de envio inline](https://ai.google.dev/gemini-api/docs/image-understanding)
