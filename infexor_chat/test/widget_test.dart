import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infexor_chat/main.dart';

void main() {
  testWidgets('App launches with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: InfexorChatApp()),
    );
    expect(find.text('Infexor Chat'), findsOneWidget);
  });
}
