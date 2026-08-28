import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_rag/main.dart';

void main() {
  testWidgets('Norbu RAG App Navigation and Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title in the App Bar is "Norbu RAG" (HomeScreen active)
    expect(find.text('Norbu RAG'), findsOneWidget);

    // Verify we have the instruction welcome message
    expect(find.text('Identify Your Gemstone'), findsOneWidget);

    // Verify we have the Take Photo and Upload buttons
    expect(find.text('Take Photo (Camera)'), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);

    // Verify that BottomNavigationBar displays the Home, History, and Profile tabs
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);

    // Tap the History navigation tab
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    // Verify app bar title changes to "Scan History"
    expect(find.text('Scan History'), findsOneWidget);

    // Tap the Profile navigation tab
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    // Verify app bar title changes to "Sign In" since we are not logged in initially
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign In with Google'), findsOneWidget);
  });
}
