import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/responsive.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';

import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/item_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  ItemStage? _selectedStage;

  String _getStageLabel(ItemStage? stage) {
    if (stage == null) return '✨ All Pipeline Stages';
    switch (stage) {
      case ItemStage.wishlist:
        return '💭 Wishlist';
      case ItemStage.stashed:
        return '⏳ Stashed';
      case ItemStage.inTransit:
        return '🚚 In Transit';
      case ItemStage.inHand:
        return '🛡️ In Hand';
      case ItemStage.archived:
        return '📦 Archived';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return AppShell(
      activeIndex: 0,
      child: itemsAsync.when(
        data: (items) {
          final wishlistItems = items.where((i) => i.stage == ItemStage.wishlist).toList();
          final stashedItems = items.where((i) => i.stage == ItemStage.stashed).toList();
          final inTransitItems = items.where((i) => i.stage == ItemStage.inTransit).toList();
          final inHandItems = items.where((i) => i.stage == ItemStage.inHand).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < kSidebarBreakpoint;
              final activeMobileStage = _selectedStage ?? ItemStage.stashed;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: isMobile
                          ? _buildMobileView(
                              activeMobileStage,
                              wishlistItems,
                              stashedItems,
                              inTransitItems,
                              inHandItems,
                            )
                          : _buildDesktopView(
                              context,
                              _selectedStage,
                              wishlistItems,
                              stashedItems,
                              inTransitItems,
                              inHandItems,
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading inventory: $err', style: textTheme.small),
        ),
      ),
    );
  }

  List<Item> _itemsForStage(
    ItemStage stage,
    List<Item> wishlistItems,
    List<Item> stashedItems,
    List<Item> inTransitItems,
    List<Item> inHandItems,
  ) {
    switch (stage) {
      case ItemStage.wishlist:
        return wishlistItems;
      case ItemStage.stashed:
        return stashedItems;
      case ItemStage.inTransit:
        return inTransitItems;
      case ItemStage.inHand:
        return inHandItems;
      case ItemStage.archived:
        return const [];
    }
  }

  Widget _buildMobileView(
    ItemStage selectedStage,
    List<Item> wishlistItems,
    List<Item> stashedItems,
    List<Item> inTransitItems,
    List<Item> inHandItems,
  ) {
    final activeItems =
        _itemsForStage(selectedStage, wishlistItems, stashedItems, inTransitItems, inHandItems);

    return SingleChildScrollView(
      child: _buildPipelineColumn(context, _getStageLabel(selectedStage), activeItems),
    );
  }

  Widget _buildDesktopView(
    BuildContext context,
    ItemStage? selectedStage,
    List<Item> wishlistItems,
    List<Item> stashedItems,
    List<Item> inTransitItems,
    List<Item> inHandItems,
  ) {
    if (selectedStage != null) {
      final items =
          _itemsForStage(selectedStage, wishlistItems, stashedItems, inTransitItems, inHandItems);

      return Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: _buildPipelineColumn(context, _getStageLabel(selectedStage), items),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildPipelineColumn(context, _getStageLabel(ItemStage.wishlist), wishlistItems),
        ),
        const Gap(16),
        Expanded(
          child: _buildPipelineColumn(context, _getStageLabel(ItemStage.stashed), stashedItems),
        ),
        const Gap(16),
        Expanded(
          child: _buildPipelineColumn(context, _getStageLabel(ItemStage.inTransit), inTransitItems),
        ),
        const Gap(16),
        Expanded(
          child: _buildPipelineColumn(context, _getStageLabel(ItemStage.inHand), inHandItems),
        ),
      ],
    );
  }

  Widget _buildPipelineColumn(BuildContext context, String title, List<Item> items) {
    final textTheme = ShadTheme.of(context).textTheme;

    return ShadCard(
      padding: const EdgeInsets.all(12),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: textTheme.p.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ShadBadge.secondary(child: Text('${items.length}')),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Gap(12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No items here yet',
                  style: textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) => ItemCard(item: items[index]),
              ),
            ),
        ],
      ),
    );
  }
}
