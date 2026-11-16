import 'package:flutter_test/flutter_test.dart';

import 'package:reeltalk/catalog.dart';
import 'package:reeltalk/main.dart';

void main() {
  testWidgets('Shows the login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const ReelTalkApp());
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Username'), findsOneWidget);
  });

  test('normalizeTitle matches the web client rules', () {
    expect(normalizeTitle('The Lord of the Rings & Me!'), 'lord of the rings and me');
  });
}
