import 'package:flutter/material.dart';
import 'package:key_keeper/services/key_service.dart';

class PrivateKeyDialog extends StatefulWidget {
  const PrivateKeyDialog({super.key, required this.keyService});

  final KeyService keyService;

  @override
  State<PrivateKeyDialog> createState() => _PrivateKeyDialogState();
}

class _PrivateKeyDialogState extends State<PrivateKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _alreadySet = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final set = await widget.keyService.isUserKeySet();
    if (!mounted) return;
    setState(() => _alreadySet = set);
    if (set) {
      final key = await widget.keyService.getUserKey();
      if (!mounted) return;
      _controller.text = key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('个人密钥设置'),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        enabled: !_alreadySet,
        decoration: InputDecoration(
          labelText: '个人密钥',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        if (!_alreadySet)
          FilledButton(
            onPressed: () async {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              await widget.keyService.saveUserKey(text);
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('确定'),
          ),
      ],
    );
  }
}
