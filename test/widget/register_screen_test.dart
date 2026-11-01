import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bobp/features/auth/presentation/register_screen.dart';

void main() {
  testWidgets('requires an account type and name before submitting', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    final button = find.widgetWithText(FilledButton, 'Register');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Please choose one'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('choosing an account type clears the error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    final button = find.widgetWithText(FilledButton, 'Register');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Please choose one'), findsOneWidget);

    await tester.tap(find.text('I provide a service'));
    await tester.pump();
    expect(find.text('Please choose one'), findsNothing);
  });
}
