import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoc/main.dart';

void main() {
  testWidgets('renders the Flutter shell', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('emoc/native'),
          (call) async => null,
        );

    await tester.pumpWidget(const EmoCApp());
    await tester.pump();

    expect(find.text('登录网易云音乐'), findsOneWidget);
  });
}
