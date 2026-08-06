import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquila/theme/aquila_theme.dart';

void main() {
  testWidgets('Aquila theme builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AquilaTheme.dark(),
        home: const Scaffold(body: Text('ok')),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}