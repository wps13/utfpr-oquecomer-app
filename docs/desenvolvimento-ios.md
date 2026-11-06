# Preparar o desenvolvimento iOS

## Ferramentas do Mac

Instale o [Xcode pela App Store](https://apps.apple.com/app/xcode/id497799835).
Use uma versão estável compatível com o macOS instalado e, no mínimo, Xcode
26.1.1, requisito da versão de `device_info_plus` usada neste projeto.
Somente instalar Command Line Tools não fornece o SDK iOS nem o simulador.

Abra o Xcode, revise e aceite os termos, conclua a instalação dos componentes
iniciais e selecione o suporte à plataforma iOS. No terminal:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
xcodebuild -version
flutter doctor -v
```

Se o Xcode solicitar a aceitação de licença pelo terminal, execute
`sudo xcodebuild -license` e revise os termos. Se estiver instalado com outro
nome ou caminho, ajuste o caminho passado ao `xcode-select`.

## Configuração do projeto

Execute os comandos a partir da raiz do repositório:

```sh
flutter pub get
flutter build ios --config-only
open ios/Runner.xcworkspace
```

O deployment target atual é iOS 15.0. Os plugins compatíveis usam Swift Package
Manager. O leitor `flutter_tts` 4.2.5, integrado na APP-48 a partir da APP-42,
ainda usa CocoaPods; por isso o projeto também versiona `ios/Podfile`, seu lock
e a integração de Pods no workspace. Instale essa ferramenta antes do build:

```sh
brew install cocoapods
pod --version
```

`flutter build ios` e `flutter run` instalam os Pods necessários. Ao executar pelo
Xcode em um checkout novo, execute primeiro o build de configuração acima e
`(cd ios && pod install)`, depois abra `ios/Runner.xcworkspace`.
O aviso de plugin sem SwiftPM refere-se ao leitor; a integração atual usa os
dois gerenciadores sem duplicar o Firebase. A compilação release sem assinatura
da APP-48 foi validada com Xcode 27.1 e CocoaPods 1.17.0.

As permissões de câmera, localização em uso, microfone e fotos estão declaradas
no `ios/Runner/Info.plist`, com justificativas em português. O plugin detecta
essas chaves e habilita as estratégias correspondentes. Para builds iniciados
diretamente na interface do Xcode, execute antes de abrir o aplicativo:

```sh
launchctl setenv PERMISSION_HANDLER_INFO_PLIST "$PWD/ios/Runner/Info.plist"
```

Reabra o Xcode após definir a variável. Ela é específica para este checkout;
ajuste-a se mudar a pasta do projeto. Pelo terminal, iniciando o build na raiz,
o plugin detecta o `Info.plist` automaticamente.

## Simulador e release

No Xcode, selecione um simulador iPhone instalado e execute o target Runner.
Também é possível iniciar o simulador pelo menu do Xcode e usar:

```sh
flutter devices
flutter run -d <id-do-simulador> \
  --dart-define-from-file=config/firebase.local.json
```

O simulador serve para validar a interface e parte do comportamento de
permissões. Câmera, microfone e localização também precisam ser validados em
um dispositivo físico, de acordo com a disponibilidade desses recursos.

Para verificar a compilação release sem configurar assinatura:

```sh
flutter build ios --release --no-codesign \
  --dart-define-from-file=config/firebase.local.json
```

Esse comando produz um build para dispositivo sem assinatura; ele não instala
nem executa o app no iPhone. Flutter não executa release no simulador iOS.

Para rodar em um iPhone físico, adicione sua Apple Account nas configurações do
Xcode e, em **Runner > Signing & Capabilities**, selecione seu **Team** e habilite
**Automatically manage signing**. O Bundle Identifier é
`br.edu.utfpr.oquecomer`, correspondente ao app registrado no Firebase.
Dados pessoais de assinatura não devem ser
versionados como configuração obrigatória de todos os desenvolvedores.

Conecte o iPhone, confirme a confiança no Mac e habilite o Developer Mode quando
solicitado. Então execute:

```sh
flutter run --release -d <id-do-iphone> \
  --dart-define-from-file=config/firebase.local.json
```

Configure os mesmos defines ao usar o Xcode. Para habilitar
a integração Gemini, acrescente seu arquivo local conforme o
[guia do Gemini](gemini.md). Consulte a [configuração Firebase](firebase-crashlytics.md)
para preencher os campos obrigatórios.

A assinatura e as credenciais da equipe serão necessárias para validar a
execução release no dispositivo. O build sem assinatura e os testes no simulador
podem ser preparados antes dessa configuração.

Referências: [configuração iOS do Flutter](https://docs.flutter.dev/platform-integration/ios/setup),
[Swift Package Manager no Flutter](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers),
[integração do permission_handler](https://pub.dev/packages/permission_handler).
