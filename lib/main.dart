import 'package:flutter/material.dart';

import 'config/error_handling.dart';
import 'config/firebase_bootstrap.dart';
import 'data/services/errors/error_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errorReporter = await initializeErrorReporting();
  installErrorHandlers(errorReporter: errorReporter);
  runApp(MainApp(errorReporter: errorReporter));
}

class MainApp extends StatelessWidget {
  const MainApp({
    this.errorReporter = const DisabledErrorReporter(),
    super.key,
  });

  final ErrorReporter errorReporter;

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
