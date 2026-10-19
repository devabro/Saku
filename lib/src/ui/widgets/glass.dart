import 'dart:ui';

import 'package:flutter/material.dart';

/// Primitif "Liquid Glass" ala iOS 26, diadaptasi untuk Saku:
/// kaca = translusensi + border 1px terang + radius besar.
/// BackdropFilter (blur) hanya dipakai di: top bar, dock navigasi,
/// dan SATU hero card — sisanya kaca palsu (warna semi-transparan)
/// agar tetap ringan.

/// Isi kaca: putih 55% (terang) / putih 12% (gelap) — dinaikkan biar berasa.
Color sakuGlassFill(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.55);
}

/// Border kaca: garis terang pemberi definisi — dipertegas di dark mode.
Color sakuGlassBorder(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? Colors.white.withValues(alpha: 0.28)
      : Colors.white.withValues(alpha: 0.7);
}

/// Background gradien statis + dua glow lembut (sekali gambar, murah).
class SakuBackdrop extends StatelessWidget {
  const SakuBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF3A2530), // plum gelap
                  Color(0xFF2A1E24), // dasar
                  Color(0xFF40304A), // ungu-mawar gelap
                ]
              : const [
                  Color(0xFFFFF8F3),
                  Color(0xFFFBEAEA),
                  Color(0xFFFFF8F3),
                ],
        ),
      ),
      child: Stack(
        children: [
          // Glow rose kanan-atas — diperkuat biar blur ada yang dibiaskan.
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (dark
                            ? const Color(0xFFE8A0B4)
                            : const Color(0xFFF3B8C6))
                        .withValues(alpha: dark ? 0.35 : 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Glow gold kiri-bawah.
          Positioned(
            left: -80,
            bottom: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (dark
                            ? const Color(0xFFC49A5F)
                            : const Color(0xFFE8C98F))
                        .withValues(alpha: dark ? 0.28 : 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Glow rose tambahan tengah-kiri biar gradien hidup.
          Positioned(
            left: -100,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB76E8A)
                        .withValues(alpha: dark ? 0.22 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu kaca TANPA blur (murah). Pengganti Card di layar yang dirombak.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Gradien vertikal: terang di atas (kilau kaca), gelap di bawah.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.10 : 0.25),
            sakuGlassFill(context),
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: sakuGlassBorder(context), width: 1),
      ),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }
    return Padding(padding: margin, child: content);
  }
}

/// Panel kaca DENGAN blur — hanya untuk hero card.
class GlassHeroPanel extends StatelessWidget {
  const GlassHeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: sakuGlassFill(context),
              borderRadius: radius,
              border:
                  Border.all(color: sakuGlassBorder(context), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Top bar kaca melayang DENGAN blur.
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: sakuGlassFill(context),
            border: Border(
              bottom:
                  BorderSide(color: sakuGlassBorder(context), width: 1),
            ),
          ),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                  ),
                ),
                ...actions,
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item untuk dock navigasi.
class DockItem {
  const DockItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Dock navigasi pil melayang DENGAN blur — gaya iOS.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final List<DockItem> items;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: sakuGlassFill(context),
            borderRadius: BorderRadius.circular(32),
            border:
                Border.all(color: sakuGlassBorder(context), width: 1),
          ),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _DockButton(
                    item: items[i],
                    selected: i == selected,
                    onTap: () => onTap(i),
                    activeColor: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  final DockItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected
                  ? activeColor
                  : scheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? activeColor
                    : scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
