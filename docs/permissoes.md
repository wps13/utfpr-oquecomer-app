# Permissões do dispositivo — APP-23 / TT14

O serviço `PermissionService` pode ser injetado por construtor em qualquer
ViewModel. Sua implementação é `PermissionHandlerService`. Criar a instância
não consulta nem solicita permissões; compartilhe uma instância entre as features
para serializar os diálogos nativos.

`check` consulta o estado atual, `request` solicita acesso e `openSettings` abre
os ajustes do aplicativo. Nenhum desses métodos deve ser chamado na abertura do
app. No Android, `check` retorna `denied` tanto antes da primeira solicitação
quanto após uma recusa permanente; somente `request` distingue esses casos.

## Uso em uma funcionalidade

Crie o serviço na composição das dependências e injete-o na ViewModel:

```dart
final permissionService = PermissionHandlerService();
final permissionViewModel = PermissionViewModel(
  permissionService: permissionService,
);
```

O componente compartilhado `PermissionAction` associa a solicitação ao botão da
feature. Exemplo para a futura funcionalidade de câmera:

```dart
PermissionAction(
  viewModel: permissionViewModel,
  permission: AppPermission.camera,
  onAuthorized: (access) async {
    await cameraViewModel.takePhoto(); // Implementado no card da feature.
  },
  builder: (context, onPressed) => FilledButton(
    onPressed: onPressed,
    child: const Text('Tirar foto'),
  ),
)
```

Ao tocar no botão, o componente consulta a permissão, apresenta uma justificativa
em português quando há necessidade de solicitá-la e só então abre o diálogo do
sistema após a confirmação. Uma recusa mantém o restante do app utilizável.
Recusas permanentes mostram o botão **Abrir configurações**; se a abertura
falhar, uma mensagem orienta como encontrar os ajustes manualmente. Um novo
toque no recurso consulta o estado novamente, inclusive após voltar dos ajustes.

Os textos do diálogo nativo do Android são definidos pelo sistema e seguem o
idioma do dispositivo. As justificativas personalizadas em português são
apresentadas pelo componente Flutter. No iOS, os quatro textos do diálogo nativo
estão no `Info.plist`.

## Recursos e versões

| Recurso | Android | iOS |
| --- | --- | --- |
| Câmera | `CAMERA` | `NSCameraUsageDescription` |
| Localização em uso | `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` | `NSLocationWhenInUseUsageDescription` |
| Microfone | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` |
| Fotos até Android 12L | `READ_EXTERNAL_STORAGE`, limitado à API 32 | `NSPhotoLibraryUsageDescription` |
| Fotos no Android 13+ | `READ_MEDIA_IMAGES` | `NSPhotoLibraryUsageDescription` |
| Fotos selecionadas no Android 14+ | `READ_MEDIA_VISUAL_USER_SELECTED` | Acesso limitado disponível desde iOS 14 |
| Arquivos privados do app | Sem permissão | Sem permissão |

`limited` é um estado autorizado separado: a feature recebe esse estado e deve
operar apenas sobre as fotos selecionadas. Não se deve interpretar isso como
acesso à galeria inteira nem persistir permissões em cache. `restricted` indica
restrições do sistema, como controles parentais; `unavailable` indica erro de
integração ou plataforma sem suporte. Ambos impedem o uso do recurso com uma
mensagem explicativa, sem repetir solicitações.

`AppPermission.appStorage` representa a escrita no diretório privado do app e
retorna `granted` sem abrir diálogos. Não declaramos `WRITE_EXTERNAL_STORAGE` nem
`MANAGE_EXTERNAL_STORAGE`: não há funcionalidade de escrita em armazenamento
compartilhado legado neste card. Salvar fotos na galeria pública, caso seja
necessário futuramente, exige uma política própria; `appStorage` não autoriza
esse uso. Também não declaramos permissões de vídeo, leitura de áudio,
notificações ou localização em segundo plano.

Para seleção pontual de imagens, a futura feature pode usar o Photo Picker do
sistema, dispensando acesso amplo à galeria. O serviço cobre o acesso direto à
biblioteca quando esse for o fluxo escolhido.

## Configuração e validação

O Android usa `compileSdk = 37`, exigido por `permission_handler_android` 14.1.0.
O `minSdk` e o `targetSdk` seguem os valores do Flutter do projeto.

O projeto iOS usa Swift Package Manager. `permission_handler_apple` 9.6.2 habilita
as estratégias pela presença das chaves no `Info.plist`; somente localização
durante o uso está configurada. Não é necessário criar um `Podfile`. Para builds
iniciados pela interface do Xcode, o plugin exige indicar o arquivo explicitamente
antes de abrir o Xcode:

```sh
launchctl setenv PERMISSION_HANDLER_INFO_PLIST "$PWD/ios/Runner/Info.plist"
```

O comando deve ser executado na raiz deste projeto. Reabra o Xcode depois de
definir a variável. Builds pelo terminal, iniciados na raiz do projeto,
detectam o arquivo automaticamente. Consulte a documentação do plugin caso o
cache do Swift Package Manager tenha sido resolvido antes de alterar as chaves.

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub --fatal-infos --fatal-warnings
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

Antes de concluir o aceite em dispositivos, validar Android 12L, 13 e 14+
e iOS: permitir, negar, bloquear, selecionar algumas fotos e alterar o acesso nos
ajustes. Confirmar que cancelar não executa a feature, que a abertura do app não
solicita permissões e que a escrita privada não exibe diálogo. A execução iOS
requer Xcode completo e, em um dispositivo físico, assinatura provisionada.
As funcionalidades que usam câmera, localização, microfone e galeria continuam
nos seus próprios cards; o componente deve ser conectado a elas nesses cards.

Referências: [permission_handler](https://pub.dev/packages/permission_handler),
[armazenamento privado no Android](https://developer.android.com/training/data-storage/app-specific),
[acesso parcial a fotos no Android 14+](https://developer.android.com/about/versions/14/changes/partial-photo-video-access).
