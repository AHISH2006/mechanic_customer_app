import 'package:flutter_test/flutter_test.dart';
import 'package:mechanic_customer_app/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MechanicCustomerApp());
    expect(find.text('Mechanic Help'), findsOneWidget);
  });
}
