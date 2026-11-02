import 'package:flutter_test/flutter_test.dart';
import 'package:bengkel_kim3_security_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SecurityMasterTruckApp());
    expect(find.byType(SecurityMasterTruckApp), findsOneWidget);
  });
}
