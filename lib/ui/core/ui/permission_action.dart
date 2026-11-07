import 'package:flutter/material.dart';

import '../../../domain/models/app_permission.dart';
import '../view_models/permission_viewmodel.dart';

/// Envolve o botão de uma feature sem acessar o recurso na montagem da tela.
/// O builder deve ligar [VoidCallback] ao onPressed do botão correspondente.
class PermissionAction extends StatefulWidget {
  const PermissionAction({
    required this.viewModel,
    required this.permission,
    required this.onAuthorized,
    required this.builder,
    super.key,
  });

  final PermissionViewModel viewModel;
  final AppPermission permission;

  /// Recebe o estado para que a feature respeite o acesso limitado à galeria.
  final Future<void> Function(PermissionAccess access) onAuthorized;
  final Widget Function(BuildContext context, VoidCallback? onPressed) builder;

  @override
  State<PermissionAction> createState() => _PermissionActionState();
}

class _PermissionActionState extends State<PermissionAction> {
  bool _busy = false;

  Future<void> _activate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var access = await widget.viewModel.check(widget.permission);
      if (!mounted) return;
      if (access == PermissionAccess.denied) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(widget.permission.title),
            content: Text(widget.permission.rationale),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Agora não'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        access = await widget.viewModel.request(widget.permission);
        if (!mounted) return;
      }
      if (access.isAuthorized) {
        await widget.onAuthorized(access);
      } else {
        await _showFeedback(access);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFeedback(PermissionAccess access) async {
    final permanentlyDenied = access == PermissionAccess.permanentlyDenied;
    final message = switch (access) {
      PermissionAccess.permanentlyDenied =>
        'O acesso foi bloqueado. Para usar este recurso, permita o acesso '
            'nas configurações do aplicativo.',
      PermissionAccess.restricted =>
        'O acesso está restrito pelo sistema. Verifique as restrições '
            'do dispositivo com a pessoa responsável.',
      PermissionAccess.unavailable =>
        'Não foi possível verificar a permissão. Tente novamente mais tarde.',
      _ =>
        'O acesso não foi permitido. Você pode continuar usando o app '
            'e tentar novamente quando precisar deste recurso.',
    };
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.permission.title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fechar'),
          ),
          if (permanentlyDenied)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir configurações'),
            ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return;
    final opened = await widget.viewModel.openSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir as configurações. '
            'Abra os ajustes do dispositivo e procure O Que Comer App.',
          ),
        ),
      );
    }
    // O próximo toque consulta o sistema novamente, inclusive após os ajustes.
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _busy ? null : _activate);
}

extension on AppPermission {
  String get title => switch (this) {
    AppPermission.camera => 'Acesso à câmera',
    AppPermission.locationWhenInUse => 'Acesso à localização',
    AppPermission.microphone => 'Acesso ao microfone',
    AppPermission.speechRecognition => 'Reconhecimento de fala',
    AppPermission.photos => 'Acesso às fotos',
    AppPermission.appStorage => 'Armazenamento do aplicativo',
  };

  String get rationale => switch (this) {
    AppPermission.camera =>
      'O Que Comer App precisa acessar a câmera para tirar fotos '
          'quando você usar esse recurso.',
    AppPermission.locationWhenInUse =>
      'O Que Comer App usa sua localização para encontrar opções de comida '
          'perto de você, somente enquanto o aplicativo está em uso.',
    AppPermission.microphone =>
      'O Que Comer App precisa acessar o microfone para captar sua voz '
          'quando você usar os recursos de áudio.',
    AppPermission.speechRecognition =>
      'O Que Comer App usa o reconhecimento de fala para entender seus '
          'comandos no modo mãos livres.',
    AppPermission.photos =>
      'O Que Comer App precisa acessar suas fotos para que você escolha '
          'imagens para usar no aplicativo.',
    AppPermission.appStorage =>
      'Os dados são salvos no espaço privado do aplicativo, '
          'sem precisar de permissão do dispositivo.',
  };
}
