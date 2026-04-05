import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rag_assistant/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RagAssistantApp(),
      ),
    );

    expect(find.text('RAG Assistant'), findsOneWidget);
  });
}
