import 'package:flutter/painting.dart';

/// Paleta "Sabor em Foco" (protótipo do Stitch). Única fonte das cores do
/// app: para mudar uma cor, altere aqui; o tema propaga para os componentes.
abstract final class AppColors {
  // Primary (Burnt Orange)
  static const primary = Color(0xFF994700);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFF7A00);
  static const onPrimaryContainer = Color(0xFF5C2800);
  static const inversePrimary = Color(0xFFFFB68B);
  static const primaryFixed = Color(0xFFFFDBC8);
  static const primaryFixedDim = Color(0xFFFFB68B);
  static const onPrimaryFixed = Color(0xFF321200);
  static const onPrimaryFixedVariant = Color(0xFF753400);

  // Secondary (Sun Yellow)
  static const secondary = Color(0xFF705D00);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFDD400);
  static const onSecondaryContainer = Color(0xFF6F5C00);
  static const secondaryFixed = Color(0xFFFFE170);
  static const secondaryFixedDim = Color(0xFFE9C400);
  static const onSecondaryFixed = Color(0xFF221B00);
  static const onSecondaryFixedVariant = Color(0xFF544600);

  // Tertiary (Fresh Green)
  static const tertiary = Color(0xFF006E1C);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF51B454);
  static const onTertiaryContainer = Color(0xFF00410D);
  static const tertiaryFixed = Color(0xFF94F990);
  static const tertiaryFixedDim = Color(0xFF78DC77);
  static const onTertiaryFixed = Color(0xFF002204);
  static const onTertiaryFixedVariant = Color(0xFF005313);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Neutral (Soft Gray/White)
  static const surface = Color(0xFFF8F9FA);
  static const surfaceDim = Color(0xFFD9DADB);
  static const surfaceBright = Color(0xFFF8F9FA);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);
  static const surfaceTint = Color(0xFF994700);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF584235);
  static const inverseSurface = Color(0xFF2E3132);
  static const onInverseSurface = Color(0xFFF0F1F2);
  static const outline = Color(0xFF8C7263);
  static const outlineVariant = Color(0xFFE0C0AF);
}
