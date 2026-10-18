# Firebase e Crashlytics — APP-19

Projeto: **O Que Comer App** (`oquecomer-app`).
[Abrir console](https://console.firebase.google.com/project/oquecomer-app/overview).

Android e iOS são dois registros no mesmo projeto Firebase. Ambos usam o
identificador `br.edu.utfpr.oquecomer`. A conta responsável pode conceder acesso
aos colegas em **Configurações do projeto > Usuários e permissões**.

## Configuração

Instale as CLIs [Firebase](https://firebase.google.com/docs/cli) e
[FlutterFire](https://firebase.google.com/docs/flutter/setup) e autentique sua
conta Google pelo navegador:

```sh
firebase login
dart pub global activate flutterfire_cli
flutter pub get
flutterfire configure --project=oquecomer-app --platforms=android,ios \
  --android-package-name=br.edu.utfpr.oquecomer \
  --ios-bundle-id=br.edu.utfpr.oquecomer
```

A CLI FlutterFire precisa estar no `PATH`, inclusive para o envio dos símbolos
durante builds iOS. Ela usa a biblioteca Ruby `xcodeproj` para editar o projeto
Xcode. O projeto usa Swift Package Manager para as dependências nativas iOS.

Os arquivos `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart` e `firebase.json`
contêm a configuração pública dos apps. Eles podem ser versionados; não são
credenciais administrativas. Não versione tokens da CLI ou chaves JSON de contas
de serviço. Os logs locais e padrões comuns de contas de serviço estão no
`.gitignore`.

Não foram adicionados Analytics, Performance Monitoring ou Remote Config.

## Política de coleta

| Build | Coleta nativa | Registro pelo ErrorReporter |
| --- | --- | --- |
| Debug | Desabilitada | Desabilitado |
| Profile | Desabilitada | Desabilitado |
| Release | Habilitada | Habilitado |

No Android, o manifesto recebe o valor pelo `manifestPlaceholder` específico
do build. No iOS, o `Info.plist` recebe `CRASHLYTICS_COLLECTION_ENABLED` da
configuração Xcode (`NO`, `NO` e `YES`, respectivamente). O SDK iOS aceita esse
valor como string booleana.

Essa definição ocorre antes da inicialização do Dart. O bootstrap reforça a
política com `setCrashlyticsCollectionEnabled(kReleaseMode)` antes de instalar
os handlers. Durante a inicialização de debug/profile, também descartamos
relatórios pendentes com `deleteUnsentReports`.

Ao alternar builds durante a validação, use uma instalação limpa para não levar
relatórios de crashes nativos de uma instalação anterior para a seguinte.
O setter do SDK persiste o valor e tem precedência sobre o manifesto/Info.plist;
ao trocar de modo de build mantendo os dados, essa configuração antiga pode ser
lida antes do bootstrap Dart. Por isso a validação de ausência de envio em debug
deve começar com uma instalação limpa.

## Uso no MVVM

`main` inicializa o Firebase e instala dois handlers globais:

- `FlutterError.onError`: erros não tratados do framework Flutter.
- `PlatformDispatcher.instance.onError`: erros assíncronos não tratados no
  isolate principal.

Ambos preservam o erro e a stack e os registram como fatais. A apresentação no
console local é preservada. O `ErrorReporter` criado no bootstrap é passado ao
`MainApp` e pode ser injetado por construtor nos repositórios e ViewModels:

```dart
await errorReporter.recordError(
  error,
  stackTrace,
  reason: 'Falha inesperada ao gerar receita',
);
```

Erros tratados são não fatais por padrão. Não reporte falhas esperadas de
validação ou conectividade como crashes, nem inclua credenciais ou dados
pessoais nas mensagens. Falhas do próprio SDK ao registrar um erro não devem
interromper o fluxo nem gerar recursão no handler global.

Web e plataformas desktop recebem `DisabledErrorReporter`; o card configura
somente Android e iOS. Erros de outros isolates precisam ser encaminhados
explicitamente ao isolate principal quando essas funcionalidades existirem.

## Testes e validação no console

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

O último comando valida a compilação iOS sem assinatura. A execução release no
iPhone requer um aparelho físico, Team de assinatura e provisionamento no Xcode.

Há um entry point separado para gerar erros de teste. Ele não aparece na
navegação normal e exige uma flag explícita:

```sh
flutter run --release -d <id-do-dispositivo> \
  --target=tool/crashlytics_smoke_test.dart \
  --dart-define=ENABLE_CRASHLYTICS_SMOKE_TEST=true
```

1. Confirme que a tela mostra **Coleta nativa: true** em release.
2. Gere um erro tratado, um erro Flutter e um erro assíncrono pelos botões.
3. Use **Forçar crash nativo** e reabra o app para enviar o relatório.
4. Confira os eventos `APP-19` no
   [Crashlytics](https://console.firebase.google.com/project/oquecomer-app/crashlytics).
   O processamento pode levar alguns minutos.
5. Repita em debug, em uma instalação limpa: a coleta deve aparecer como
   **false** e os erros não devem ser enviados.

No iOS, teste crashes nativos com o debugger desconectado para permitir que o
SDK capture o encerramento. No Android, o emulador pode ser usado; também valide
em um aparelho físico antes de concluir o aceite das duas plataformas.

Os testes unitários verificam o bloqueio de envio fora de release, a classificação
fatal/não fatal, os handlers globais e a recuperação quando o registro falha.
Eles não substituem a confirmação do recebimento dos crashes no console.

## Validação realizada

- Análise estática sem problemas e 12 testes passando.
- Android release: erros tratado e Flutter e crash nativo recebidos pelo
  Crashlytics, confirmados pelo relatório `topIssues` da ferramenta oficial.
- Android debug: coleta nativa desabilitada e nenhum evento recebido no
  intervalo do teste, incluindo um crash nativo seguido de reabertura.
- Builds release Android e iOS sem assinatura concluídos; build debug para
  simulador iOS concluído.
- App de validação executado no simulador iOS com **Coleta nativa: false**.
- A validação de crash em release no iOS está pendente de um iPhone físico
  com assinatura configurada.

Referências: [configuração do Crashlytics no Flutter](https://firebase.google.com/docs/crashlytics/flutter/get-started),
[customização e coleta](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports),
[validação da integração](https://firebase.google.com/docs/crashlytics/flutter/test-implementation).
