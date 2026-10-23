import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('CinezaApp launches and displays branding', (WidgetTester tester) async {
    await tester.pumpWidget(const CinezaApp());
    expect(find.text('CINEZA'), findsOneWidget);
  });
}
