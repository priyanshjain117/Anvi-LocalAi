import 'package:flutter_test/flutter_test.dart';

import 'package:anvi/main.dart';

void main() {
  testWidgets('Anvi renders the launch experience', (tester) async {
    await tester.pumpWidget(const AnviApp(lockSplash: true));

    expect(find.text('Anvi'), findsOneWidget);
    expect(find.text('Offline intelligence, alive on-device'), findsOneWidget);
  });
}
