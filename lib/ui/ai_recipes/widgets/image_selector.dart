import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/app_permission.dart';
import '../../core/ui/permission_action.dart';
import '../../core/view_models/permission_viewmodel.dart';
import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';

class ImageSelector extends StatelessWidget {
  const ImageSelector({
    required this.imageBytes,
    required this.permissionViewModel,
    required this.onPickImage,
    super.key,
  });

  final Uint8List? imageBytes;
  final PermissionViewModel? permissionViewModel;
  final ValueChanged<ImageSource> onPickImage;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Column(
        children: [
          if (imageBytes != null)
            ClipRRect(
              borderRadius: AppRadius.borderMd,
              child: Image.memory(
                imageBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.x5),
              child: Icon(Icons.photo_camera_outlined, size: 48),
            ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Expanded(
                child: _ImageSourceButton(
                  permissionViewModel: permissionViewModel,
                  permission: AppPermission.camera,
                  source: ImageSource.camera,
                  icon: Icons.camera_alt_outlined,
                  label: 'Tirar foto',
                  onPickImage: onPickImage,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: _ImageSourceButton(
                  permissionViewModel: permissionViewModel,
                  permission: AppPermission.photos,
                  source: ImageSource.gallery,
                  icon: Icons.photo_library_outlined,
                  label: 'Galeria',
                  onPickImage: onPickImage,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ImageSourceButton extends StatelessWidget {
  const _ImageSourceButton({
    required this.permissionViewModel,
    required this.permission,
    required this.source,
    required this.icon,
    required this.label,
    required this.onPickImage,
  });

  final PermissionViewModel? permissionViewModel;
  final AppPermission permission;
  final ImageSource source;
  final IconData icon;
  final String label;
  final ValueChanged<ImageSource> onPickImage;

  @override
  Widget build(BuildContext context) {
    Widget buttonBuilder(BuildContext context, VoidCallback? onPressed) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );

    if (permissionViewModel == null) {
      return buttonBuilder(context, null);
    }

    return PermissionAction(
      viewModel: permissionViewModel!,
      permission: permission,
      onAuthorized: (_) async => onPickImage(source),
      builder: buttonBuilder,
    );
  }
}
