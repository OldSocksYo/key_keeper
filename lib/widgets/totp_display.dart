import 'package:flutter/material.dart';
import 'package:key_keeper/services/totp_service.dart';
import 'package:key_keeper/services/totp_ticker.dart';

/// 列表项右侧 TOTP 展示（共享全局倒计时）。
class TotpListTrailing extends StatefulWidget {
  const TotpListTrailing({
    super.key,
    required this.secret,
    required this.totpService,
  });

  final String secret;
  final TotpService totpService;

  @override
  State<TotpListTrailing> createState() => _TotpListTrailingState();
}

class _TotpListTrailingState extends State<TotpListTrailing> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    TotpTicker.instance.addListener(_onTick);
  }

  @override
  void dispose() {
    TotpTicker.instance.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.secret.trim().toUpperCase();
    if (raw.isEmpty || !widget.totpService.isValidBase32(raw)) {
      return const SizedBox.shrink();
    }
    final code = widget.totpService.generateCode(raw);
    final remain = widget.totpService.getRemainingSeconds();
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 20,
          tooltip: _revealed ? '隐藏验证码' : '显示验证码',
          onPressed: () => setState(() => _revealed = !_revealed),
          icon: Icon(
            _revealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _revealed = !_revealed),
          child: Text(
            _revealed ? code : '••••••',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: _revealed ? 2 : 1,
              color: _revealed ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: remain / 30,
            strokeWidth: 2.5,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// 详情页 TOTP 预览卡片（共享全局倒计时）。
class TotpPreviewCard extends StatefulWidget {
  const TotpPreviewCard({
    super.key,
    required this.secret,
    required this.totpService,
  });

  final String secret;
  final TotpService totpService;

  @override
  State<TotpPreviewCard> createState() => _TotpPreviewCardState();
}

class _TotpPreviewCardState extends State<TotpPreviewCard> {
  @override
  void initState() {
    super.initState();
    TotpTicker.instance.addListener(_onTick);
  }

  @override
  void dispose() {
    TotpTicker.instance.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.secret.trim().toUpperCase();
    final valid = raw.isNotEmpty && widget.totpService.isValidBase32(raw);
    final code = valid ? widget.totpService.generateCode(raw) : '------';
    final remain = widget.totpService.getRemainingSeconds();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            Column(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    value: remain / 30,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${remain}s'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
