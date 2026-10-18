import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/money.dart';
import '../../state/providers.dart';

/// Tampilkan nominal, atau ••• jika privacy mode aktif.
class MaskedAmount extends ConsumerWidget {
  const MaskedAmount(this.amount,
      {super.key, this.style, this.short = false, this.prefix = ''});

  final int amount;
  final TextStyle? style;
  final bool short;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyModeProvider);
    final text = privacy
        ? '••••••'
        : '$prefix${short ? formatIdrShort(amount) : formatIdr(amount)}';
    return Text(text, style: style);
  }
}
