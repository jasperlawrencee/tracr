import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/confimation_dialog.dart';

import '../../containers/data/container_repository.dart';
import '../../containers/domain/storage_container.dart';
import '../../shipments/domain/shipment.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';
import 'edit_item_sheet.dart';
import 'mark_bought_dialog.dart';

class ItemCard extends ConsumerWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    ConfirmationDialog.show(
      context: context,
      title: 'Delete Item',
      description: 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
      confirmLabel: 'Delete Item',
      style: ConfirmActionStyle.destructive,
      onConfirm: () async {
        await ref.read(itemRepositoryProvider).deleteItem(item);
      },
    );
  }

  void _showShipDialog(BuildContext context, WidgetRef ref) {
    final trackingController = TextEditingController();
    final costController = TextEditingController();
    Courier courier = Courier.lbc;

    showShadDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => ShadDialog(
          title: const Text('Mark Shipped'),
          description: const Text('Enter the courier and tracking number for this package.'),
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
                await ref.read(itemRepositoryProvider).shipOne(
                      item,
                      courier,
                      tracking,
                      shippingCost: double.tryParse(costController.text.trim()),
                    );
              },
              child: const Text('Confirm'),
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
                ShadInput(
                  controller: trackingController,
                  placeholder: const Text('e.g., 940011122233'),
                ),
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

  void _showReceiveDialog(BuildContext context, WidgetRef ref) {
    showShadDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final containersAsync = ref.watch(userContainersStreamProvider);
          final containers = containersAsync.value ?? const <StorageContainer>[];
          StorageContainer? selected = containers.isEmpty ? null : containers.first;

          return StatefulBuilder(
            builder: (context, setState) => ShadDialog(
              title: const Text('Mark Received'),
              description: const Text('Which container does this item go in?'),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ShadButton(
                  onPressed: selected == null || item.shipmentId == null
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          await ref
                              .read(itemRepositoryProvider)
                              .receiveOne(item.shipmentId!, item, selected!);
                        },
                  child: const Text('Confirm'),
                ),
              ],
              child: containers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No containers yet — add one from the In Hand tab first.'),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: ShadSelect<String>(
                        initialValue: selected!.id,
                        options: [
                          for (final c in containers) ShadOption(value: c.id, child: Text(c.name)),
                        ],
                        selectedOptionBuilder: (context, value) =>
                            Text(containers.firstWhere((c) => c.id == value).name),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => selected = containers.firstWhere((c) => c.id == val));
                        },
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = ShadTheme.of(context).textTheme;

    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShadBadge.secondary(child: Text(item.category)),
              if ((item.marketValue ?? 0) > 0)
                ShadBadge(child: Text('₱${item.marketValue!.toStringAsFixed(2)}')),
            ],
          ),
          const Gap(8),
          Text(item.name, style: textTheme.p.copyWith(fontWeight: FontWeight.bold)),
          const Gap(4),

          if (item.sellerName != null && item.sellerName!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    'Seller: ${item.sellerName}',
                    style: textTheme.muted.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(4),
          ],

          if (item.containerName != null && item.containerName!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    item.containerName!,
                    style: textTheme.muted.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(4),
          ],

          if (item.attributes.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final attr in item.attributes)
                  ShadBadge.outline(child: Text('${attr.label}: ${attr.value}')),
              ],
            ),
            const Gap(4),
          ],

          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const Gap(4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.notes!,
                style: textTheme.small.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],

          const Gap(12),
          const Divider(height: 1),
          const Gap(8),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              switch (item.stage) {
                ItemStage.wishlist => ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => showMarkBoughtDialog(
                      context: context,
                      itemId: item.id,
                      itemName: item.name,
                    ),
                    child: const Text('Mark Bought'),
                  ),
                ItemStage.stashed => ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => _showShipDialog(context, ref),
                    child: const Text('Mark Shipped'),
                  ),
                ItemStage.inTransit => ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => _showReceiveDialog(context, ref),
                    child: const Text('Mark Received'),
                  ),
                ItemStage.inHand => const SizedBox.shrink(),
                ItemStage.archived => const SizedBox.shrink(),
              },
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => showEditItemSheet(context, item),
                    child: const Icon(Icons.edit_outlined, size: 16),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => _confirmDelete(context, ref),
                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
