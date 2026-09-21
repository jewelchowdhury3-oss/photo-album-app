import 'package:flutter_test/flutter_test.dart';
import 'package:photo_album_app/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZayanMediaApp());
    expect(find.text('Zayan\'s Media Album ❤️'), findsOneWidget);
  });

  testWidgets('Media action controls are available', (WidgetTester tester) async {
    await tester.pumpWidget(const ZayanMediaApp());

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}