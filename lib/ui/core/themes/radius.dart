import 'package:flutter/painting.dart';

/// Raios de borda dos componentes (protótipo do Stitch).
abstract final class AppRadius {
  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;

  static const borderSm = BorderRadius.all(Radius.circular(sm));
  static const borderBase = BorderRadius.all(Radius.circular(base));
  static const borderMd = BorderRadius.all(Radius.circular(md));
  static const borderLg = BorderRadius.all(Radius.circular(lg));
  static const borderXl = BorderRadius.all(Radius.circular(xl));
  static const borderFull = BorderRadius.all(Radius.circular(full));
}
