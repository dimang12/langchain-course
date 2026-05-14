import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final stack = details.stack?.toString() ?? '';
      final exception = details.exception.toString();
      if (stack.contains('mouse_tracker.dart') ||
          exception.contains('mouse_tracker.dart')) {
        return;
      }
      originalOnError?.call(details);
    };
  }

  runApp(
    const ProviderScope(
      child: RagAssistantApp(),
    ),
  );
}
