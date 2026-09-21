import 'package:flutter_test/flutter_test.dart';
import 'package:photo_album_app/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZayanMediaApp());
    expect(find.text('Zayan\'s Media Album ❤️'), findsOneWidget);
  });

  testWidgets('Folder controls are available', (WidgetTester tester) async {
    await tester.pumpWidget(const ZayanMediaApp());

    expect(find.byTooltip('Create folder'), findsOneWidget);
  });
}