import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shala_saathi/unified_login.dart';

Widget _app({bool ready = true}) => MaterialApp(
      home: UnifiedLoginScreen(
        firebaseReady: ready,
        onRole: (_) {},
        onLocalDemo: () {},
      ),
    );

void main() {
  test('normaliseMobile accepts valid Indian numbers only', () {
    expect(normaliseMobile('9876543210'), '+919876543210');
    expect(normaliseMobile('+91 98765 43210'), '+919876543210');
    expect(normaliseMobile('09876543210'), '+919876543210');
    expect(normaliseMobile('1234567890'), isNull);
    expect(normaliseMobile('98765'), isNull);
  });

  testWidgets('shows validation errors for empty and invalid input',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    expect(find.text('Mobile number / Email'), findsNothing);
    expect(find.textContaining('Mobile number / Email'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
        find.textContaining('मोबाईल क्रमांक किंवा ईमेल टाका'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'abc@');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Invalid email address'), findsOneWidget);
  });

  testWidgets('sign up mode asks for a name and a confirmed password',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    expect(find.textContaining('Full name'), findsNothing);

    await tester.tap(find.textContaining('Sign Up'));
    await tester.pump();
    expect(find.textContaining('Full name'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Enter your name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Anjali Shelake');
    await tester.enterText(find.byType(TextFormField).last, 'a@b.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Confirm password'), findsOneWidget);
    expect(find.textContaining('Forgot password?'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('at least 6 characters'), findsWidgets);
  });

  testWidgets('email moves to the password step; language can switch',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextFormField), 'a@b.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('a@b.com'), findsOneWidget);
    expect(find.text('Forgot password? / पासवर्ड विसरलात?'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}
