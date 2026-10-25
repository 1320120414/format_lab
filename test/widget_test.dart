import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:format_lab/app.dart';

void main() {
  testWidgets('首页展示图片与视频两个入口', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FormatLabApp()));
    await tester.pump();

    expect(find.text('格式坊'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
  });
}
