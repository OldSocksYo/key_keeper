import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_keeper/widgets/confirm_delete_dialog.dart';

void main() {
  testWidgets('删除确认对话框可正常展示', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showConfirmDeleteDialog(context),
              child: const Text('删除'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('是否删除此账户？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
