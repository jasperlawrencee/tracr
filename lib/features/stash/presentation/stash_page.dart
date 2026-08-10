import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';
import 'package:tracr/core/presentation/widgets/card_container.dart';
import 'package:tracr/core/presentation/widgets/confimation_dialog.dart';
import 'package:tracr/core/presentation/widgets/search_field.dart';

import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/edit_item_sheet.dart';
import '../../sellers/data/seller_repository.dart';
import '../../sellers/domain/seller.dart';
import '../../shipments/domain/shipment.dart';

Color stashHeatColor(DateTime? oldest) {
  if (oldest == null) return Colors.grey;
  final days = DateTime.now().difference(oldest).inDays;
  if (days < 14) return Colors.green.shade600;
  if (days < 60) return Colors.amber.shade700;
  return Colors.red.shade600;
}

class StashPage extends ConsumerStatefulWidget {
  const StashPage({super.key});

  @override
  ConsumerState<StashPage> createState() => _StashPageState();
}

class _StashPageState extends ConsumerState<StashPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);
    final sellersAsync = ref.watch(userSellersStreamProvider);

    return AppShell(
      activeIndex: 2,
      child: itemsAsync.when(
        data: (items) {
          final sellers = sellersAsync.value ?? const <Seller>[];
          var stashed = items.where((i) => i.stage == ItemStage.stashed).toList();
          if (_query.isNotEmpty) {
            stashed = stashed.where((i) => i.matchesQuery(_query)).toList();
          }

          final bySeller = <String, List<Item>>{};
          for (final item in stashed) {
            if (item.sellerId == null) continue;
            bySeller.putIfAbsent(item.sellerId!, () => []).add(item);
          }

          final moneyParked = stashed.fold<double>(0, (sum, i) => sum + (i.pricePaid ?? 0));
          final sellerIds = bySeller.keys.toList()
            ..sort((a, b) {
              final sa = sellers.where((s) => s.id == a).firstOrNull;
              final sb = sellers.where((s) => s.id == b).firstOrNull;
              return (sa?.name ?? '').compareTo(sb?.name ?? '');
            });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stash', style: textTheme.h3),
                const Gap(4),
                Text('Manage what sellers are holding.', style: textTheme.muted),
                const Gap(16),
                SearchField(
                  controller: _searchController,
                  placeholder: 'Search stash...',
                  onChanged: (val) => setState(() => _query = val),
                ),
                const Gap(16),
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('Money parked', style: textTheme.muted.copyWith(fontSize: 12)),
                      const Gap(8),
                      Text('₱${moneyParked.toStringAsFixed(2)}', style: textTheme.h4),
                      const Gap(16),
                      Text('across ${sellerIds.length} seller${sellerIds.length == 1 ? '' : 's'}',
                          style: textTheme.muted.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: sellerIds.isEmpty
                      ? Center(child: Text('Nothing stashed with a seller yet.', style: textTheme.muted))
                      : ListView.separated(
                          itemCount: sellerIds.length,
                          separatorBuilder: (context, index) => const Gap(12),
                          itemBuilder: (context, index) {
                            final sellerId = sellerIds[index];
                            final seller = sellers.where((s) => s.id == sellerId).firstOrNull ??
                                Seller(id: sellerId, name: 'Unknown seller');
                            return _SellerGroupCard(seller: seller, items: bySeller[sellerId]!);
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading stash: $err')),
      ),
    );
  }
}

class _SellerGroupCard extends ConsumerStatefulWidget {
  final Seller seller;
  final List<Item> items;

  const _SellerGroupCard({required this.seller, required this.items});

  @override
  ConsumerState<_SellerGroupCard> createState() => _SellerGroupCardState();
}

class _SellerGroupCardState extends ConsumerState<_SellerGroupCard> {
  final Set<String> _selectedIds = {};

  double get _stashedValue => widget.items.fold<double>(0, (sum, i) => sum + (i.pricePaid ?? 0));

  DateTime? get _oldest {
    final dates = widget.items.map((i) => i.purchasedAt).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  void _editSeller(BuildContext context) {
    final nameController = TextEditingController(text: widget.seller.name);
    final contactController = TextEditingController(text: widget.seller.contactUrl ?? '');
    double rating = widget.seller.trustRating ?? 3;

    showShadDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => ShadDialog(
          title: const Text('Seller Details'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(sellerRepositoryProvider).updateSeller(
                      widget.seller.id,
                      name: nameController.text.trim(),
                      contactUrl:
                          contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                      trustRating: rating,
                    );
              },
              child: const Text('Save'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Name'),
                const Gap(6),
                ShadInput(controller: nameController),
                const Gap(12),
                const Text('Contact link'),
                const Gap(6),
                ShadInput(controller: contactController, placeholder: const Text('Chat / profile URL')),
                const Gap(12),
                Text('Trust rating: ${rating.toStringAsFixed(1)}'),
                ShadSlider(
                  initialValue: rating,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  onChanged: (v) => setState(() => rating = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shipSelected(BuildContext context) {
    final selectedItems = widget.items.where((i) => _selectedIds.contains(i.id)).toList();
    if (selectedItems.isEmpty) return;

    final trackingController = TextEditingController();
    final costController = TextEditingController();
    Courier courier = Courier.lbc;

    showShadDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => ShadDialog(
          title: const Text('Ship Selected Items'),
          description: Text('Consolidate ${selectedItems.length} item(s) from ${widget.seller.name} '
              'into one shipment.'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () async {
                final tracking = trackingController.text.trim();
                if (tracking.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await ref.read(itemRepositoryProvider).consolidate(
                      sellerId: widget.seller.id,
                      items: selectedItems,
                      courier: courier,
                      trackingNumber: tracking,
                      shippingCost: double.tryParse(costController.text.trim()),
                    );
                if (mounted) setState(() => _selectedIds.clear());
              },
              child: const Text('Ship'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Courier'),
                const Gap(6),
                ShadSelect<Courier>(
                  initialValue: courier,
                  options: [
                    for (final c in Courier.values) ShadOption(value: c, child: Text(c.label)),
                  ],
                  selectedOptionBuilder: (context, value) => Text(value.label),
                  onChanged: (val) {
                    if (val != null) setState(() => courier = val);
                  },
                ),
                const Gap(12),
                const Text('Tracking Number'),
                const Gap(6),
                ShadInput(controller: trackingController),
                const Gap(12),
                const Text('Shipping Cost (optional)'),
                const Gap(6),
                ShadInput(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final heat = stashHeatColor(_oldest);
    final ageDays = _oldest == null ? null : DateTime.now().difference(_oldest!).inDays;

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: heat, shape: BoxShape.circle)),
              const Gap(8),
              Expanded(
                child: Text(widget.seller.name, style: textTheme.p.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (widget.seller.trustRating != null)
                ShadBadge.secondary(child: Text('★ ${widget.seller.trustRating!.toStringAsFixed(1)}')),
              const Gap(8),
              ShadIconButton.ghost(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _editSeller(context),
              ),
            ],
          ),
          const Gap(4),
          Text(
            '${widget.items.length} item${widget.items.length == 1 ? '' : 's'} · '
            '₱${_stashedValue.toStringAsFixed(2)}'
            '${ageDays == null ? '' : ' · oldest $ageDays day${ageDays == 1 ? '' : 's'}'}',
            style: textTheme.muted.copyWith(fontSize: 12, color: heat),
          ),
          const Gap(12),
          const Divider(height: 1),
          const Gap(8),
          ...widget.items.map(
            (item) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selectedIds.contains(item.id),
              onChanged: (checked) {
                setState(() {
                  if (checked ?? false) {
                    _selectedIds.add(item.id);
                  } else {
                    _selectedIds.remove(item.id);
                  }
                });
              },
              title: Text(item.name, style: textTheme.small),
              subtitle: Text(
                '₱${(item.pricePaid ?? 0).toStringAsFixed(2)}',
                style: textTheme.muted.copyWith(fontSize: 11),
              ),
              secondary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => showEditItemSheet(context, item),
                    child: const Icon(Icons.edit_outlined, size: 16),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => ConfirmationDialog.show(
                      context: context,
                      title: 'Delete Item',
                      description: 'Delete "${item.name}"? This cannot be undone.',
                      confirmLabel: 'Delete',
                      style: ConfirmActionStyle.destructive,
                      onConfirm: () => ref.read(itemRepositoryProvider).deleteItem(item),
                    ),
                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
              enabled: _selectedIds.isNotEmpty,
              size: ShadButtonSize.sm,
              onPressed: _selectedIds.isEmpty ? null : () => _shipSelected(context),
              child: Text('Ship Selected (${_selectedIds.length})'),
            ),
          ),
        ],
      ),
    );
  }
}
