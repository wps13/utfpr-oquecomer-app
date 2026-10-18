import 'package:flutter/material.dart';

import 'ui/core/themes/theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
