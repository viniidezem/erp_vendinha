import 'package:flutter/material.dart';

Future<void> showErrorDialog(BuildContext context, String message) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Erro'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
