# Modo mãos livres — APP-48 / US10

Abra uma receita e toque em **Iniciar**, no cartão Modo cozinha. A tela carrega
os passos e solicita o microfone somente após essa entrada. No iOS, solicita
também o reconhecimento de fala. Não há captura ao abrir o app ou visualizar
somente o detalhe de uma receita.

## Comportamento

- O primeiro passo aparece sem leitura automática. Quando o indicador mostrar
  **Ouvindo**, diga **continuar** para ouvi-lo desde o início.
- **Próximo passo / avançar** e **passo anterior / voltar** mudam o passo e leem
  seu texto. Os limites não retornam ao início nem saem da receita.
- **Parar / pausar** mantém o passo atual. **Continuar** relê desde o começo;
  a APP-42 não oferece retomada exata no ponto da pausa.
- **Sair / sair do modo** encerra captura e leitura e volta à tela anterior.
- Frases fora da lista de comandos são ignoradas. A normalização e os sinônimos
  seguem o [interpretador da APP-43](comandos-voz.md).
- **Durante a leitura, o microfone fica suspenso** para evitar que a voz do app
  dispare comandos. A escuta volta ao terminar o áudio. Não há interrupção por
  fala simultânea: para pausar enquanto o app lê, use **Pausar leitura** na tela.
- Os botões de leitura e navegação continuam disponíveis se a permissão for
  negada ou o reconhecimento estiver indisponível. A tela explica a falha;
  recusas permanentes oferecem **Abrir configurações**. Após conceder acesso
  nos ajustes, volte e toque em **Ativar comandos de voz**.
- Sair da tela, abrir outra rota por cima dela, bloquear o aparelho ou colocar
  o app em segundo plano encerra os recursos. Ao retornar, a reativação da voz
  é explícita. O passo atual permanece ao voltar do segundo plano.
- Receitas sem passos e falhas ao carregar não iniciam o microfone. O carregamento
  reutiliza o catálogo e a cópia dos favoritos, como a tela de detalhes.

## Organização

`HandsFreeModeViewModel` recebe os repositórios e serviços por injeção. Reutiliza
`RecipeDetailsViewModel` para carregar e separar os passos e
`VoiceCommandsViewModel` para interpretar o reconhecimento. A tela cuida da
navegação, sem lógica de áudio no widget.

A ponte de leitura mantém `VoiceCaptureService.duringPlayback` aberto até a
conclusão real do áudio, observando `SpeechService.status`: `speak()` confirma
somente o início. Leituras substituídas e canceladas liberam seus Futures;
nenhuma suspensão fica retida ao sair. Uma nova leitura mantém a captura
suspensa enquanto interrompe a anterior. Erros esperados aparecem na tela e os
inesperados usam `ErrorReporter` com mensagens fixas, sem transcrição ou receita.

A base desta branch inclui o serviço de leitura da **APP-42 / PR #31**, anterior
ao commit que adicionou seu painel temporário de debug. O PR #31 precisa ser
integrado à develop antes do merge da APP-48. A APP-43 já está na develop.

## Executar e testar

Na raiz, com os arquivos locais já preenchidos conforme o README:

```sh
flutter pub get
flutter run -d RQCX4046PXD \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=config/gemini.local.json
```

Esse comando abre o app normal; não usa `tool/voice_smoke.dart`. A captura usa o
reconhecedor do sistema, sem Gemini. O aparelho precisa ter reconhecimento e voz
em português do Brasil disponíveis. Reconhecimento offline não é garantido.

Testes automatizados sem microfone ou serviços reais:

```sh
flutter test test/ui/hands_free_mode test/routing/router_test.dart
flutter analyze --no-pub --fatal-infos --fatal-warnings
flutter test --no-pub --coverage
dart run coverde check 80 --input=coverage/lcov.info --file-coverage-log-level=none
```

No iOS, instale CocoaPods (`brew install cocoapods`) antes de compilar:
`flutter_tts` 4.2.5 usa Pods, enquanto os outros plugins compatíveis continuam no
SwiftPM. O Podfile está versionado. Consulte também os guias de
[leitura](leitura-em-voz.md) e [permissões](permissoes.md).

### Roteiro no aparelho

1. Abra o app, depois uma receita: não deve aparecer uso de microfone.
2. Toque em Iniciar e autorize o microfone. No iOS, autorize o reconhecimento.
   Confira **Ouvindo** e o primeiro passo.
3. Diga **continuar**; espere a leitura terminar. Confira **Lendo o passo**
   durante o áudio e **Ouvindo** depois, sem executar comandos da própria leitura.
4. Quando estiver ouvindo, diga **próximo passo**, **passo anterior**, **avançar**,
   **parar** e **continuar**, aguardando o fim de cada leitura. Confira os passos
   e o retorno da escuta. Repita o mesmo comando em sessões diferentes.
5. Durante uma leitura, toque em **Pausar leitura**. Confira a retomada da escuta.
   Diga continuar e confirme que o passo recomeça.
6. Diga uma frase que não seja comando; o passo deve permanecer o mesmo.
7. Diga **sair do modo**. Confira a volta ao detalhe e o fim do uso do microfone.
8. Entre novamente; teste Voltar, segundo plano e bloqueio durante uma leitura.
   Ao retornar, a voz deve ficar desativada até nova ativação.
9. Negue a permissão; confira a explicação e os controles manuais. Com recusa
   permanente, teste o atalho de configurações e a reativação após conceder acesso.
10. Teste uma receita sem passos, erro ao carregar e limites primeiro/último passo.

Os testes simulados não substituem a validação de áudio real no Android e no iOS.

### Verificações desta implementação

- Suíte completa: 444 testes aprovados, cobertura global de 88,99%.
- Após acrescentar os dois cenários de navegação: 54 testes do fluxo aprovados.
- Análise estática sem avisos e formatação conferida.
- Android ARM64: APK debug compilado.
- iOS: release sem assinatura compilado com Xcode 27.1 e CocoaPods 1.17.0.
- Teste de áudio e microfone reais integrado à tela: pendente no Android e iOS.
