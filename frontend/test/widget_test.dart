import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('CinezaApp has correct title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CinezaApp());
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'Cineza Cinemas - Premium Movie Ticketing');
  });
}
