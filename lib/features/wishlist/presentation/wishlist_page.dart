import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';
import 'package:tracr/core/presentation/widgets/card_container.dart';
import 'package:tracr/core/presentation/widgets/search_field.dart';

import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/edit_item_sheet.dart';
import '../../items/presentation/mark_bought_dialog.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  final _searchController = TextEditingController();
  Priority? _priorityFilter;
  String _query = '';

  bool _isDeal(Item item) =>
      item.marketValue != null && item.targetPrice != null && item.marketValue! <= item.targetPrice!;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return AppShell(
      activeIndex: 1,
      child: itemsAsync.when(
        data: (items) {
          var wishlist = items.where((i) => i.stage == ItemStage.wishlist).toList();
          if (_priorityFilter != null) {
            wishlist = wishlist.where((i) => i.priority == _priorityFilter).toList();
          }
          if (_query.isNotEmpty) {
            wishlist = wishlist.where((i) => i.matchesQuery(_query)).toList();
          }
          wishlist.sort((a, b) => b.priority.sortRank.compareTo(a.priority.sortRank));

          final costToComplete = wishlist.fold<double>(0, (sum, i) => sum + (i.marketValue ?? 0));
          final dealCount = wishlist.where(_isDeal).length;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wishlist', style: textTheme.h3),
                const Gap(4),
                Text('Decide what to buy next.', style: textTheme.muted),
                const Gap(16),
                SearchField(
                  controller: _searchController,
                  placeholder: 'Search wishlist...',
                  onChanged: (val) => setState(() => _query = val),
                ),
                const Gap(16),
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cost to complete', style: textTheme.muted.copyWith(fontSize: 12)),
                          Text(
                            '₱${costToComplete.toStringAsFixed(2)}',
                            style: textTheme.h4,
                          ),
                        ],
                      ),
                      if (dealCount > 0)
                        ShadBadge(
                          backgroundColor: Colors.green.shade700,
                          child: Text('$dealCount deal${dealCount == 1 ? '' : 's'} available'),
                        ),
                      SizedBox(
                        width: 200,
                        child: ShadSelect<Priority?>(
                          initialValue: _priorityFilter,
                          placeholder: const Text('Filter by priority'),
                          options: const [
                            ShadOption(value: null, child: Text('All priorities')),
                            ShadOption(value: Priority.mustHave, child: Text('Must Have')),
                            ShadOption(value: Priority.want, child: Text('Want')),
                            ShadOption(value: Priority.someday, child: Text('Someday')),
                          ],
                          selectedOptionBuilder: (context, val) =>
                              Text(val == null ? 'All priorities' : val.name),
                          onChanged: (val) => setState(() => _priorityFilter = val),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: wishlist.isEmpty
                      ? Center(child: Text('Nothing on the wishlist yet.', style: textTheme.muted))
                      : ListView.separated(
                          itemCount: wishlist.length,
                          separatorBuilder: (context, index) => const Gap(10),
                          itemBuilder: (context, index) => _WishlistRow(
                            item: wishlist[index],
                            isDeal: _isDeal(wishlist[index]),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading wishlist: $err')),
      ),
    );
  }
}

class _WishlistRow extends StatelessWidget {
  final Item item;
  final bool isDeal;

  const _WishlistRow({required this.item, required this.isDeal});

  String get _priorityLabel {
    switch (item.priority) {
      case Priority.mustHave:
        return 'Must Have';
      case Priority.want:
        return 'Want';
      case Priority.someday:
        return 'Someday';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    return CardContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.name, style: textTheme.p.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(8),
                    ShadBadge.secondary(child: Text(_priorityLabel)),
                    if (isDeal) ...[
                      const Gap(8),
                      ShadBadge(backgroundColor: Colors.green.shade700, child: const Text('Deal!')),
                    ],
                  ],
                ),
                const Gap(4),
                Text(
                  [
                    if (item.targetPrice != null) 'Target ₱${item.targetPrice!.toStringAsFixed(2)}',
                    if (item.marketValue != null) 'Market ₱${item.marketValue!.toStringAsFixed(2)}',
                  ].join(' · '),
                  style: textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty)
            ShadIconButton.ghost(
              icon: const Icon(Icons.open_in_new, size: 16),
              onPressed: () async {
                final uri = Uri.tryParse(item.sourceUrl!);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          const Gap(4),
          ShadIconButton.ghost(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => showEditItemSheet(context, item),
          ),
          const Gap(4),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () =>
                showMarkBoughtDialog(context: context, itemId: item.id, itemName: item.name),
            child: const Text('Mark Bought'),
          ),
        ],
      ),
    );
  }
}
