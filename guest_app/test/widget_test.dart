import 'package:flutter_test/flutter_test.dart';
import 'package:guest_app/main.dart';

void main() {
  testWidgets('App starts with CrisisNet title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CrisisNetApp());

    // Verify that our title is present.
    expect(find.text('CrisisNet SOS'), findsOneWidget);
  });
}
