# o_que_comer_app

Projeto Flutter para o app 'O que Comer'.

Configuração, uso e validação do [Firebase e Crashlytics (APP-19)](docs/firebase-crashlytics.md).

Configuração, contratos e testes da [integração Gemini (APP-31)](docs/gemini.md).

Configuração, contratos e testes do [catálogo de receitas (APP-24)](docs/catalogo-receitas.md).

Fluxo da página inicial e [seleção de receitas por categoria (APP-25)](docs/categorias-catalogo.md).

Uso e validação da [busca de receitas por nome (APP-26)](docs/busca-catalogo.md).

Captura, interpretação e testes de [comandos de voz do modo mãos livres (APP-43)](docs/comandos-voz.md).

Configuração e uso do serviço de permissões: [APP-23 / TT14](docs/permissoes.md).

Configuração e uso do serviço de localização: [localização](docs/localizacao.md).

Uso e validação da [leitura em voz alta (APP-42)](docs/leitura-em-voz.md).

Armazenamento e regras de duplicidade dos [alimentos escaneados na despensa (APP-40)](docs/despensa-escaneamento.md).

Preparação do Xcode e execução no iOS: [guia de desenvolvimento](docs/desenvolvimento-ios.md).

## Executar localmente

Na primeira configuração, crie os arquivos locais a partir dos exemplos:

```sh
flutter pub get
cp -n config/firebase.example.json config/firebase.local.json
cp -n config/gemini.example.json config/gemini.local.json
```

Preencha os valores conforme os guias de [Firebase](docs/firebase-crashlytics.md#variáveis-de-compilação)
e [Gemini](docs/gemini.md#configuração-local). Se já possui os arquivos preenchidos,
use-os diretamente. Os arquivos `*.local.json` são ignorados pelo Git.

Com um emulador iniciado ou celular conectado, execute:

```sh
flutter run \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=config/gemini.local.json
```

Para escolher um dispositivo, consulte `flutter devices` e acrescente
`-d <id-do-dispositivo>` ao comando. Os arquivos não são carregados automaticamente;
os argumentos precisam ser fornecidos a cada execução ou configurados no IDE.

Os testes unitários e a análise estática não exigem os arquivos locais:

```sh
flutter analyze
flutter test
```

### Pipeline de qualidade

O workflow **Pull Request Quality** roda em pull requests destinadas à branch
`develop`. Ele instala as dependências e executa, nesta ordem, a verificação de
formatação (`dart format`), a análise estática (`flutter analyze`) e os testes
automatizados com cobertura (`flutter test --coverage`). Em pull requests, o
pipeline verifica a cobertura com o `coverde` (mínimo de 80%) e publica ou
atualiza um comentário com o percentual obtido. O pipeline falha se a
formatação, a análise, qualquer teste ou o limite de cobertura falhar.

## Convenções de Git

### Commits

Este projeto segue o padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/) (semantic commit). Formato:

Tipos mais usados:

| Tipo       | Quando usar                                              |
|------------|----------------------------------------------------------|
| `feat`     | Nova funcionalidade                                      |
| `fix`      | Correção de bug                                          |
| `docs`     | Alterações apenas em documentação                        |
| `style`    | Formatação, sem mudança de lógica (ex.: `dart format`)   |
| `refactor` | Refatoração sem alterar comportamento                    |
| `perf`     | Melhoria de performance                                  |
| `test`     | Criação ou ajuste de testes                              |
| `build`    | Mudanças no build ou dependências (ex.: `pubspec.yaml`)  |
| `ci`       | Mudanças em pipelines de CI/CD                           |
| `chore`    | Tarefas gerais que não afetam o código de produção       |

Exemplos:

```
feat(login): adiciona autenticação com biometria
fix(cart): corrige cálculo do valor total
refactor(home): extrai widget de card para componente
```


### Branches

O nome da branch deve seguir o padrão:

`[tipo]/APP-[número da task]`


Onde `[tipo]` é um dos tipos de commit listados acima e `[número da task]` é o identificador da task no board.

Exemplos:

```
feat/APP-123
fix/APP-456
refactor/APP-789
```


### Fluxo resumido

1. Crie a branch a partir da `develop` seguindo o padrão acima.
2. Faça commits pequenos e semânticos.
3. Abra o Pull Request referenciando a task (`APP-123`).

## Arquitetura

O projeto segue o padrão MVVM, como recomendado na documentação oficial.

[Guide to architecture](https://docs.flutter.dev/app-architecture/guide)

### Estrutura das pastas

```
|_ lib/
|   |_ ui/ # Parte visual
|   |   |_ core/
|   |   |   |_ themes/ # arquivos de tema
|   |   |   |   |_ colors.dart
|   |   |   |   |_ theme.dart
|   |   |   |_ ui/ # widgets compartilhados
|   |   |_ feature A
|   |   |   |_ view_models/ # Comunicação entre UI e dados
|   |   |   |   |_ feature_a_viewmodel.dart
|   |   |   |_ widgets/
|   |   |   |   |_ feature_a_screen.dart
|   |   |   |   |_ feature_a_widget.dart
|   |_ domain/  # Representação dos dados
|   |   |_ models/
|   |   |   |_ example_model.dart
|   |   |_ use_cases/ 
|   |   |   |_ example_use_case.dart # Usado para combinar repositórios 
|   |_ data/ # Manipulação de dados e apis externas
|   |   |_ repositories/
|   |   |   |_ example_repository.dart
|   |   |_ services/
|   |   |   |_ example_service.dart
|   |   |_ model/
|   |   |   |_ api_model.dart
|   |_ config/ # configurações gerais do app
|   |_ utils/ # Utilitários gerais
|   |_ routing/ # Rotas do app
|   |_ main.dart
|_ test/ # Testes unitários e de widgets
|   |_ data/
|   |_ domain/
|   |_ ui/
|   |_ utils/
|_ testing/ # Mocks e classes necessárias para executar testes
|   |_ fakes/
|   |_ models/
```

### Resumo das camadas
- UI: responsável pelo o que o usuário vê, seja a nível de telas ou componentes (view), consumindo dados por um intermediário (view model)
- Domain: indica como um dado é representado, quais propriedades ele tem. Exemplo: um objeto `Usuário` pode ter nome, email.
- Data: responsável por manipular os dados, sejam recebidos de apis externas ou não, sendo a fonte da verdade, os dados daqui vão para a UI, usando os modelos do Domain.

![Diagrama](assets/diagrama_arquitetura.png)

## Convenções de estado

O estado do app usa `provider` com `ChangeNotifier` como base das ViewModels.
A `FavoritesViewModel` (`lib/ui/favorites/`) é o exemplo a ser seguido.

- Cada tela ou fluxo tem a sua própria ViewModel.
- Widgets não chamam API, banco local ou LLM. Isso é feito pelos repositórios, usados pela ViewModel.
- Os repositórios são injetados pelo construtor da ViewModel.
- A ViewModel é criada com `ChangeNotifierProvider(create: ...)`, nunca dentro do `build`.
- Providers globais (repositórios e serviços) ficam declarados no topo do app, acima do `MaterialApp` (ou `MaterialApp.router`, quando as rotas forem configuradas).
- `context.watch` só é usado dentro do `build`; em callbacks use `context.read`.
- `notifyListeners()` é chamado sempre que o estado mudar, mas nunca durante o `build`.
- Carregamentos iniciais são disparados no `initState` ou em um callback.
- Estado efêmero de UI (aba selecionada, campo de texto, chips em edição) fica em `StatefulWidget`. Só o estado compartilhado entre telas vai para ViewModel.
- Operações assíncronas usam estado explícito, com o enum `ViewState` (`loading`, `success`, `error`).
- Testes de ViewModel rodam sem renderizar widgets, com repositórios falsos de `testing/fakes/`.
## Configuração de chaves e URLs

As chaves são fornecidas por arquivos locais ou `--dart-define`. As URLs públicas
do catálogo e do Gemini têm valores padrão, com substituição opcional por
`CATALOG_BASE_URL` e `GEMINI_BASE_URL`. Para personalizar a configuração, copie
`env.example.json` para `env.json` (ignorado pelo Git) e rode:

```bash
flutter run \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=env.json
```

Variáveis: `CATALOG_BASE_URL`, `GEMINI_BASE_URL`, `GEMINI_API_KEY`.
Os logs de requisição só são habilitados em modo debug.
