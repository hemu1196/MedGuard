import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/app/app.dart';

void main() {
  testWidgets('MedGuardApp basic launch smoke test', (
    WidgetTester tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MedGuardApp());
    await tester.pumpAndSettle();
    expect(find.byType(MedGuardApp), findsOneWidget);
  });
}
