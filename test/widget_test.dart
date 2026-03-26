import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/constants/app_constants.dart';
import 'package:notes_app/main.dart';

void main() {
  testWidgets('renders splash screen shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NotesApp(),
      ),
    );

    expect(find.text(appName), findsOneWidget);
  });
}
