import 'package:flutter_test/flutter_test.dart';
import 'package:sovicut/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SoViCutApp());
    expect(find.byType(SoViCutApp), findsOneWidget);
  });
}
