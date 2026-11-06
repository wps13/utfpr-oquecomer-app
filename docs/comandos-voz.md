# Captura e interpretação de comandos — APP-43 / TT09

O serviço usa `speech_to_text` e seleciona o identificador de **português do
Brasil** disponibilizado pelo dispositivo (`pt_BR` ou `pt-BR`). Não usa Gemini,
chave de API ou servidor próprio. O serviço de fala do sistema pode depender de
internet; reconhecimento offline não é garantido.

## Componentes e injeção

- `VoiceRecognitionEngine` isola o plugin; `SpeechToTextEngine` implementa essa
  fronteira nativa. Os testes usam um motor simulado.
- `VoiceCaptureService` permite `start`, `stop`, `duringPlayback` e `dispose`,
  expõe transcrições finais, estados e falhas de domínio por streams.
- `DeviceVoiceCaptureService` é registrado em `main.dart` com Provider, de forma
  preguiçosa. Há somente uma instância por app, pois o plugin conserva os
  callbacks da primeira inicialização bem-sucedida.
- `VoiceCommandInterpreter` faz correspondência de frases completas com aliases
  normalizados. O mapa de aliases pode ser ampliado pelo construtor.
- `VoiceCommandsViewModel` recebe o serviço por injeção, converte transcrições em
  `Stream<VoiceCommand>` e está disponível no escopo da rota de mãos livres.
  Criar a ViewModel não inicia escuta nem solicita permissões.

A [APP-48](modo-maos-livres.md) conecta esse serviço à tela de produção, aos
passos da receita e ao leitor da APP-42. `HandsFreeModeViewModel` cria e consome
`VoiceCommandsViewModel` no escopo da rota. A entrada pelo botão Iniciar ativa a
escuta; sair da tela, cobri-la com outra rota ou enviar o app ao segundo plano
interrompe a captura. Voltar exige uma nova ativação explícita.

## Comandos

| Intenção de domínio | Exemplos aceitos |
| --- | --- |
| `resume` | continuar, continue, retomar, pode continuar |
| `pause` | parar, pare, pausar, pausa |
| `nextStep` | próximo passo, próximo, avançar, passo seguinte |
| `previousStep` | passo anterior, anterior, voltar, retroceder |
| `exit` | sair, saia, fechar |
| `exitMode` | sair do modo, sair do modo mãos livres, encerrar modo |

Caixa, acentuação (inclusive Unicode decomposto), pontuação e espaços repetidos
são normalizados. A frase inteira precisa corresponder a um alias: `não parar`,
`continuar cozinhando o arroz` ou dois comandos na mesma frase são ignorados.
`sair` e `sair do modo` permanecem intenções distintas. Ambos encerram a captura
na ViewModel; decidir a navegação é responsabilidade do consumidor.

`parar` emite `pause`, mas mantém o microfone disponível para um futuro
`continuar`. A pausa da leitura não deve ser confundida com sair do modo.
Resultados parciais e finais duplicados na mesma sessão não emitem comandos.
O mesmo comando pode ser falado novamente em outra sessão.
O adaptador habilita resultados parciais no motor para acompanhar a atividade
de fala e atualizar o relógio de silêncio do SDK. O serviço só publica o texto
final; a pausa solicitada ao SDK é de dois segundos, sujeita aos limites do SO.

## Leitura em voz alta

O consumidor mantém a captura suspensa até a conclusão real de cada áudio:

```dart
await voiceViewModel.duringPlayback(
  () => reader.readToCompletion(stepText),
);
```

`reader.readToCompletion` no exemplo representa a operação completa de leitura.
Na APP-48, essa ponte fica em `HandsFreeModeViewModel.readStep`: `speak()` do
serviço da APP-42 retorna ao iniciar o áudio, e a mudança de `SpeechStatus`
conclui o Future mantido dentro de `duringPlayback`. Pausa, troca de passo e
saída também liberam esse Future, sem reativar o microfone antes de parar o áudio.

O serviço cancela a captura antes de chamar a reprodução, bloqueia callbacks
atrasados e retoma somente após o Future terminar. Leituras sobrepostas mantêm a
escuta suspensa até a última terminar. `stop()`, descarte ou segundo plano durante
a leitura impedem retomada automática. Falha ao desligar o reconhecedor impede
iniciar o áudio. Se a reprodução falhar, a suspensão é liberada no `finally`.

Enquanto o áudio está sendo reproduzido, comandos também não são captados. Não
há interrupção da leitura pela fala simultânea (barge-in) neste contrato.
A proteção é testada com reprodução simulada. A validação do leitor integrado
com áudio e microfone reais deve seguir o [roteiro da APP-48](modo-maos-livres.md).

## Sessões, permissões e falhas

O plugin é destinado a comandos curtos. Android e iOS encerram sessões por
silêncio e limites próprios. O serviço reinicia as sessões enquanto o modo está
ativo, com um intervalo mínimo de 400 ms. Isso mantém a disponibilidade entre
comandos, mas não garante captura sem intervalos ou remove os sons do sistema.
Veja as [limitações documentadas pelo pacote](https://pub.dev/packages/speech_to_text).

`notListening` e `done` podem anteceder o resultado final ou o erro do motor. O
serviço mantém uma janela de até três segundos para receber esses eventos. Cada
frase final rearma a captura após 400 ms, mesmo sem outro aviso de encerramento.
Silêncio/no match gera `noSpeech` e nova sessão com intervalo fixo, sem aumentar
as lacunas após longos períodos sem comandos. Falhas transitórias têm até três
novas tentativas;
falhas persistentes interrompem a escuta e permitem ativação manual posterior.
Operações nativas são serializadas e resultados de sessões antigas são ignorados.

As permissões só são verificadas/solicitadas em `start()`:

- Android reutiliza `RECORD_AUDIO` e `INTERNET` e declara a consulta ao serviço
  `android.speech.RecognitionService`. O Bluetooth está desabilitado no plugin,
  sem novas permissões de Bluetooth ou de segundo plano.
- iOS reutiliza `NSMicrophoneUsageDescription` e acrescenta
  `NSSpeechRecognitionUsageDescription`, em português. A autorização adicional
  usa `AppPermission.speechRecognition` pelo `PermissionService` existente;
  no Android ela não solicita outra permissão.
- Os plugins compatíveis no iOS usam Swift Package Manager; o leitor
  `flutter_tts` usa CocoaPods. Para builds iniciados pelo
  Xcode, consulte a configuração de descoberta do Info.plist no
  [guia de permissões](permissoes.md).

**Ao atualizar um checkout que já compilava iOS antes da APP-43**, invalide o
cache de pacotes/DerivedData desse workspace e recompile. O plugin pode conservar
`PERMISSION_SPEECH_RECOGNIZER=0` do build anterior mesmo com a nova justificativa
no app compilado. O valor esperado é `PERMISSION_SPEECH_RECOGNIZER=1`.
Esse procedimento após mudanças no Info.plist é descrito no
[guia oficial do permission_handler](https://github.com/Baseflow/flutter-permission-handler/blob/main/permission_handler/README.md).
Preserve os caches dos outros projetos. A limpeza é de arquivos gerados pelo
Xcode e não exige modificar o código do plugin. O Podfile do leitor da APP-42
é independente dessa configuração de permissões.

`VoiceFailure` diferencia microfone negado, autorização de fala negada, motor
indisponível, pt-BR indisponível, ausência de fala, falha do motor e erro
inesperado. A recusa permanente é preservada em `permissionAccess` e
`canOpenSettings` permite apresentar um atalho para `PermissionService.openSettings()`.
Falhas esperadas não são enviadas ao Crashlytics. As inesperadas usam o
`ErrorReporter` existente com erro sanitizado, sem áudio, transcrição ou mensagem
nativa arbitrária. Falha no reporter não causa crash.

## Validação

Testes sem hardware:

```sh
flutter test test/domain/voice test/data/services/voice test/ui/hands_free_mode
flutter test --coverage
flutter analyze --fatal-infos --fatal-warnings
dart run coverde check 80 --input=coverage/lcov.info --file-coverage-log-level=none
```

Teste manual isolado, sem chaves Firebase/Gemini e sem modificar a tela do app:

```sh
flutter devices
flutter run -d ID_DO_DISPOSITIVO -t tool/voice_smoke.dart
```

1. Use um celular com reconhecedor em pt-BR. Toque em **Iniciar** e autorize.
2. Fale os seis comandos e sinônimos da tabela, com pausas entre eles. Confira
   a intenção exibida e que **parar** permite dizer **continuar** depois.
   A tela também mostra a última frase final reconhecida e o nível de áudio,
   em unidades do reconhecedor, para conferir a entrada do microfone.
3. Fale uma frase fora da lista: o contador de comandos não deve aumentar.
4. Espere o silêncio encerrar uma sessão e diga outro comando após a retomada.
5. Diga **sair** ou **sair do modo**: a captura deve parar. Reative pelo botão
   para testar outro ciclo.
6. Encerre pelo botão ou envie o app para segundo plano. Não deve haver retomada
   automática. Volte e inicie explicitamente para continuar.
7. Negue as permissões e confira a mensagem. Recusa permanente apresenta
   **Abrir configurações**. Dispositivo sem reconhecedor deve mostrar falha
   distinta de permissão negada, sem crash.

O entrypoint manual usa `DisabledErrorReporter`, mantém a última frase e o nível
de áudio apenas em memória e dispensa a inicialização Dart do Firebase. A
configuração Firebase nativa do projeto continua presente, incluindo sua
política de coleta em release. No app normal, a injeção usa o `ErrorReporter`
global, definido na APP-19.

Builds nativos do entrypoint manual, para conferir o plugin sem credenciais:

```sh
flutter build apk --release -t tool/voice_smoke.dart
flutter build ios --release --no-codesign -t tool/voice_smoke.dart
```

Se houver timeout do AAPT2 ao compilar recursos Android, a validação local pode
ser repetida com menos workers e heap limitado. Esta foi a configuração usada
para validar o APK ARM64 neste card:

```sh
GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false -Dorg.gradle.jvmargs=-Xmx2g' \
  flutter build apk --release --target-platform=android-arm64 \
    -t tool/voice_smoke.dart
```

Essas opções do [Gradle](https://docs.gradle.org/current/userguide/build_environment.html)
valem para essa execução. O APK ARM64 atende aparelhos como o Android usado na
validação do projeto; outros destinos precisam da arquitetura correspondente.

Compilar não valida o reconhecimento real nem o diálogo de autorização. O
teste com fala precisa ser executado em dispositivo com microfone e serviço de
reconhecimento configurados. A execução em iPhone também requer assinatura.
