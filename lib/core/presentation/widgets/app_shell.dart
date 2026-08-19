import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/responsive.dart';
import 'package:tracr/core/presentation/widgets/app_sidebar.dart';
import 'package:tracr/features/items/presentation/add_item_sheet.dart';

class AppShell extends ConsumerWidget {
  final int activeIndex;
  final Widget child;

  const AppShell({super.key, required this.activeIndex, required this.child});

  void _openAddItemSheet(BuildContext context) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.right,
      builder: (context) => const AddItemSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = ShadTheme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < kSidebarBreakpoint;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: isMobile ? 0 : null,
            title: Text(
              'tracr 📦',
              style: isMobile ? textTheme.large : textTheme.h4,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isMobile)
                ShadButton(
                  onPressed: () => _openAddItemSheet(context),
                  size: ShadButtonSize.sm,
                  child: const Icon(Icons.add, size: 18),
                )
              else
                ShadButton(
                  onPressed: () => _openAddItemSheet(context),
                  child: const Text('Add Item'),
                ),
              Gap(isMobile ? 8 : 16),
            ],
          ),
          drawer: isMobile
              ? Drawer(child: AppSidebar(activeIndex: activeIndex, isInDrawer: true))
              : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile) AppSidebar(activeIndex: activeIndex),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
