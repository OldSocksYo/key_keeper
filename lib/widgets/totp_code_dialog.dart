import 'dart:async';

import 'package:flutter/material.dart';
import 'package:key_keeper/services/totp_service.dart';

class TotpCodeDialog extends StatefulWidget {
  const TotpCodeDialog({
    super.key,
    required this.username,
    required this.secret,
    required this.totpService,
  });

  final String username;
  final String secret;
  final TotpService totpService;

  @override
  State<TotpCodeDialog> createState() => _TotpCodeDialogState();
}

class _TotpCodeDialogState extends State<TotpCodeDialog> {
  Timer? _timer;
  late String _code;
  late int _remain;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    setState(() {
      _code = widget.totpService.generateCode(widget.secret);
      _remain = widget.totpService.getRemainingSeconds();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remain / 30;
    return AlertDialog(
      title: const Text('TOTP 验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.username),
          const SizedBox(height: 16),
          Text(
            _code,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 6),
          ),
          const SizedBox(height: 12),
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('剩余 ${_remain}s'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
      ],
    );
  }
}
