# Leitura em voz alta

`SpeechService` lê textos em voz alta com o motor de síntese de voz do aparelho,
por meio do pacote `flutter_tts`. É usado no modo mãos livres para ler o passo
atual da receita. A implementação `DeviceSpeechService` é registrada no
`MultiProvider` e pode ser injetada em qualquer ViewModel:

```dart
final speech = context.read<SpeechService>();
await speech.speak('Pique a cebola em cubos pequenos.');
await speech.pause();
await speech.stop();
speech.status; // ValueListenable<SpeechStatus>: idle, speaking ou paused
```

## Comportamento

- O motor é preparado no primeiro `speak`, não na abertura do app. O idioma é
  `pt-BR`, a velocidade `0.5` (ritmo normal no Android e no iOS) e o tom `1.0`.
  Esses valores podem ser alterados por `SpeechConfig` no construtor.
- Cada `speak` interrompe a leitura anterior antes de começar. Um texto novo
  substitui o anterior sem sobreposição de áudio, e um texto solicitado antes
  de outro terminar de iniciar é descartado.
- `pause` e `stop` interrompem a leitura imediatamente e nunca lançam exceção.
  Não há retomada: depois de pausar, o próximo `speak` lê o texto desde o
  início, pois o Android e o iOS retomam de formas diferentes.
- Um texto vazio apenas interrompe a leitura atual.
- A leitura é interrompida quando o app vai para segundo plano ou a tela é
  bloqueada.
- No iOS, a leitura toca mesmo com o aparelho no modo silencioso e abaixa o
  volume de outros áudios enquanto fala.

## Falhas

`speak` lança falhas de domínio, que a ViewModel deve tratar:

- `SpeechEngineUnavailableFailure`: não há motor de voz no aparelho, o plugin
  falhou ou o motor não respondeu dentro do tempo limite (5 s por chamada);
- `SpeechLanguageUnavailableFailure`: a voz em português não está instalada;
- `SpeechPlaybackFailure`: o motor recusou o texto.

Falhas de inicialização não ficam em cache; a próxima leitura tenta preparar o
motor novamente. No Android, essa nova tentativa recria a conexão com o motor
(`setEngine`), pois a conexão que falhou não se recupera sozinha. Assim, se o
usuário instalar ou reativar o motor de voz com o app aberto, a leitura volta a
funcionar sem reiniciar o app. Erros que o motor informa durante a leitura
encerram a leitura e devolvem o estado para `idle`.

## Modo mãos livres

A [APP-48](modo-maos-livres.md) conecta `SpeechService` aos passos da receita
com `HandsFreeModeViewModel`. A ViewModel mantém o reconhecedor de comandos
suspenso até o status da leitura indicar conclusão, pausa ou cancelamento; o
retorno de `speak()` sozinho não significa que o áudio terminou. Ao sair, cobrir
a tela ou enviar o app ao segundo plano, captura e leitura são interrompidas.

`HandsFreeViewModel`, introduzida na APP-42, continua disponível como consumidor
simples do serviço para contextos que precisam apenas de leitura.

## Configuração das plataformas

- Android: o `AndroidManifest.xml` declara a ação
  `android.intent.action.TTS_SERVICE` em `<queries>`. Sem ela, o Android 11+
  não encontra o motor de voz.
- iOS: a síntese não exige permissão nem entrada adicional no `Info.plist`.
  `flutter_tts` 4.2.5 ainda usa CocoaPods. O projeto mantém `ios/Podfile` e os
  includes de Pods nos `.xcconfig`, junto dos demais plugins via SwiftPM.
  Instale CocoaPods (`brew install cocoapods`) antes do primeiro build iOS e
  abra `ios/Runner.xcworkspace` ao usar o Xcode.

## Testes

Os testes de `test/data/services/speech/` usam um `TtsEngine` falso. ViewModels
que dependem da leitura usam `FakeSpeechService`, de `testing/fakes/`.

Para validar no aparelho:

1. No Android, confirme em **Configurações > Sistema > Idiomas e entrada >
   Saída de conversão de texto em voz** que há um motor (por exemplo, Serviços
   de voz do Google) com a voz em português do Brasil instalada.
2. Para simular a ausência do motor, desative esse aplicativo nas configurações
   do aparelho. A leitura deve falhar com `SpeechEngineUnavailableFailure`, sem
   encerrar o app.
3. No iOS, o simulador e os aparelhos já incluem vozes em português do Brasil.
