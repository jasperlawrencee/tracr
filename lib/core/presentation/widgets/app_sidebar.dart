import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/layout/sidebar_provider.dart';
import 'package:tracr/core/presentation/widgets/confimation_dialog.dart';
import 'package:tracr/core/presentation/widgets/user_avatar.dart';
import 'package:tracr/core/theme/theme_provider.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';
import 'package:tracr/features/profile/data/profile_repository.dart';

const _navLabels = ['Overview', 'Wishlist', 'Stash', 'Tracking', 'In Hand'];
const _navRoutes = ['/dashboard', '/wishlist', '/stash', '/tracking', '/in-hand'];
const _navIcons = [
  Icons.space_dashboard_outlined,
  Icons.favorite_border,
  Icons.inventory_2_outlined,
  Icons.local_shipping_outlined,
  Icons.shield_outlined,
];

const _expandedWidth = 240.0;
const _collapsedWidth = 64.0;

class AppSidebar extends ConsumerWidget {
  final int activeIndex;
  final bool isInDrawer;

  const AppSidebar({super.key, required this.activeIndex, this.isInDrawer = false});

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.settings_suggest_outlined,
      };

  void _cycleTheme(WidgetRef ref, ThemeMode current) {
    const order = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final next = order[(order.indexOf(current) + 1) % order.length];
    ref.read(themeModeProvider.notifier).setThemeMode(next);
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      description: 'Are you sure you want to log out of your account?',
      confirmLabel: 'Log Out',
      style: ConfirmActionStyle.destructive,
      onConfirm: () async {
        await ref.read(authRepositoryProvider).signOut();
      },
    );
  }

  void _onNavTap(BuildContext context, String route) {
    if (isInDrawer) Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final collapsed = !isInDrawer && ref.watch(sidebarCollapsedProvider);
    final width = collapsed ? _collapsedWidth : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _navLabels.length; i++)
              _NavItem(
                icon: _navIcons[i],
                label: _navLabels[i],
                collapsed: collapsed,
                active: i == activeIndex,
                onTap: () => _onNavTap(context, _navRoutes[i]),
              ),
            const Spacer(),
            const Divider(height: 1),
            _FooterButton(
              icon: Icon(_themeIcon(ref.watch(themeModeProvider))),
              label: 'Theme: ${ref.watch(themeModeProvider).name}',
              collapsed: collapsed,
              onTap: () => _cycleTheme(ref, ref.read(themeModeProvider)),
            ),
            Builder(builder: (context) {
              final profile = ref.watch(currentUserProfileProvider).value;
              if (profile == null) return const SizedBox.shrink();
              return _FooterButton(
                icon: UserAvatar(username: profile.username, photoUrl: profile.photoUrl, radius: 12),
                label: profile.username,
                collapsed: collapsed,
                onTap: null,
              );
            }),
            _FooterButton(
              icon: const Icon(Icons.logout),
              label: 'Log Out',
              collapsed: collapsed,
              onTap: () => _confirmLogout(context, ref),
            ),
            if (!isInDrawer)
              _FooterButton(
                icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
                label: 'Collapse',
                collapsed: collapsed,
                onTap: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
              ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = active ? theme.colorScheme.accentForeground : theme.colorScheme.mutedForeground;

    final row = Row(
      children: [
        Icon(icon, size: 20, color: color),
        if (!collapsed) ...[
          const Gap(12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.p.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? theme.colorScheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: collapsed ? Tooltip(message: label, child: row) : row,
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool collapsed;
  final VoidCallback? onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final row = Row(
      children: [
        icon,
        if (!collapsed) ...[
          const Gap(12),
          Expanded(
            child: Text(label, style: theme.textTheme.small, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: collapsed ? Tooltip(message: label, child: row) : row,
          ),
        ),
      ),
    );
  }
}
