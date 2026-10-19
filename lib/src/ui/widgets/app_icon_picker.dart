import 'package:flutter/material.dart';

import '../../services/app_icon_service.dart';

/// Tile "Ikon aplikasi" di Pengaturan: tampilkan ikon aktif,
/// ketuk untuk buka pemilih 3 varian logo feminim.
class AppIconTile extends StatefulWidget {
  const AppIconTile({super.key});

  @override
  State<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends State<AppIconTile> {
  String _current = 'a';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final id = await AppIconService.instance.getCurrentIcon();
    if (mounted) {
      setState(() {
        _current = id;
        _loading = false;
      });
    }
  }

  AppIconOption get _active => AppIconService.options.firstWhere(
        (o) => o.id == _current,
        orElse: () => AppIconService.options.first,
      );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _loading
          ? const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : _IconBadge(option: _active),
      title: const Text('Ikon aplikasi'),
      subtitle: Text(_loading ? 'Memuat…' : _active.name),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showPicker(context),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _IconPickerSheet(currentId: _current),
    );
    if (picked == null || picked == _current) return;
    if (!context.mounted) return;
    // Kasih tau user aplikasinya restart sebentar (Android rebuild activity).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ikon diganti! Aplikasi restart sebentar ya…'),
        duration: Duration(seconds: 2),
      ),
    );
    final ok = await AppIconService.instance.setIcon(picked);
    if (ok) {
      await _refresh();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal ganti ikon di perangkat ini.')),
      );
    }
  }
}

/// Bottom sheet pemilih ikon: 3 kartu thumbnail.
class _IconPickerSheet extends StatelessWidget {
  const _IconPickerSheet({required this.currentId});
  final String currentId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih ikon kesukaanmu',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ikon di layar utama HP langsung keganti, nggak perlu install ulang.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final opt in AppIconService.options)
                  Expanded(
                    child: _IconCard(
                      option: opt,
                      selected: opt.id == currentId,
                      onTap: () => Navigator.of(context).pop(opt.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Catatan: di beberapa HP, ikon baru muncul setelah beberapa detik.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge ikon tanpa file gambar: lingkaran warna + inisial.
/// (Thumbnail PNG via asset korup saat push, jadi digambar manual.)
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.option, this.size = 40});
  final AppIconOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = {
      'a': [const Color(0xFFE8A0B4), const Color(0xFF4A2C3A)],
      'b': [const Color(0xFFC49A5F), const Color(0xFF4A2C3A)],
      'c': [const Color(0xFFB76E8A), const Color(0xFFFFF7F1)],
    };
    final c = colors[option.id] ?? colors['a']!;
    final label = {'a': 'S', 'b': '☽', 'c': 'A'}[option.id] ?? 'S';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c[0], c[0].withValues(alpha: 0.7)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: c[1],
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final AppIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              _IconBadge(option: option, size: 64),
              const SizedBox(height: 8),
              Text(
                option.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: scheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
