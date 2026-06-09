import 'package:flutter/material.dart';

Future<bool?> showConfirmDeleteDialog(
  BuildContext context, {
  String title = '是否删除此账户？',
  String confirmLabel = '删除',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
