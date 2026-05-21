import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sikulak/main.dart';
import 'package:sikulak/welcome_page.dart';

void main() {
  testWidgets('app launches with WelcomePage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Let async initialization complete
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 2));
    }

    // Verify welcome page is shown
    expect(find.byType(WelcomePage), findsWidgets);
  });
}



