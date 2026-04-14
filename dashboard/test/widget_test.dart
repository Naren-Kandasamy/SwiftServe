import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/main.dart';

void main() {
  testWidgets('Dashboard UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CrisisNetDashboardApp());
    expect(find.text('CrisisNet Command Dashboard'), findsOneWidget);
  });
}
