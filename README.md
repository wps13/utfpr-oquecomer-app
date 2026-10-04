# o_que_comer_app

Projeto Flutter para o app 'O que Comer'.

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