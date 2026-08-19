import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';
import 'package:tracr/core/presentation/widgets/card_container.dart';
import 'package:tracr/core/presentation/widgets/search_field.dart';

import '../../containers/data/container_repository.dart';
import '../../containers/domain/storage_container.dart';
import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/edit_item_sheet.dart';
import '../../shipments/data/shipment_repository.dart';
import '../../shipments/domain/shipment.dart';

// TODO: auto-refresh via AfterShip/EasyPost needs a Cloud Function — browser
// CORS blocks direct courier API calls from Flutter Web.

enum _ShipmentFilter {
  all('All'),
  inTransit('In Transit'),
  delivered('Delivered');

  const _ShipmentFilter(this.label);

  final String label;
}

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  final _searchController = TextEditingController();
  _ShipmentFilter _filter = _ShipmentFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Shipment shipment) {
    switch (_filter) {
      case _ShipmentFilter.all:
        return true;
      case _ShipmentFilter.inTransit:
        return !shipment.status.isDelivered;
      case _ShipmentFilter.delivered:
        return shipment.status.isDelivered;
    }
  }

  bool _matchesShipment(Shipment shipment, List<Item> allItems) {
    if (_query.isEmpty) return true;
    final q = _query.trim().toLowerCase();
    if (shipment.trackingNumber.toLowerCase().contains(q)) return true;
    if (shipment.courier.label.toLowerCase().contains(q)) return true;
    return allItems.any((i) => i.shipmentId == shipment.id && i.matchesQuery(_query));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final shipmentsAsync = ref.watch(userShipmentsStreamProvider);
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return AppShell(
      activeIndex: 3,
      child: shipmentsAsync.when(
        data: (shipments) {
          final allItems = itemsAsync.value ?? const <Item>[];
          final filtered = shipments
              .where((s) => _matchesFilter(s) && _matchesShipment(s, allItems))
              .toList()
            ..sort((a, b) {
              final byStatus = a.status.sortRank.compareTo(b.status.sortRank);
              if (byStatus != 0) return byStatus;
              return b.shippedAt.compareTo(a.shippedAt);
            });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tracking', style: textTheme.h3),
                const Gap(4),
                Text("Where's my package.", style: textTheme.muted),
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      child: SearchField(
                        controller: _searchController,
                        placeholder: 'Search tracking number or items...',
                        onChanged: (val) => setState(() => _query = val),
                      ),
                    ),
                    const Gap(8),
                    SizedBox(
                      width: 180,
                      child: ShadSelect<_ShipmentFilter>(
                        initialValue: _filter,
                        placeholder: const Text('Filter by status'),
                        options: [
                          for (final f in _ShipmentFilter.values)
                            ShadOption(value: f, child: Text(f.label)),
                        ],
                        selectedOptionBuilder: (context, val) => Text(val.label),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _filter = val);
                        },
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            shipments.isEmpty
                                ? 'No shipments yet.'
                                : _filter == _ShipmentFilter.all
                                    ? 'No shipments match your search.'
                                    : 'No ${_filter.label.toLowerCase()} shipments match your search.',
                            style: textTheme.muted,
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Gap(12),
                          itemBuilder: (context, index) => _ShipmentCard(shipment: filtered[index]),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading shipments: $err')),
      ),
    );
  }
}

class _ShipmentCard extends ConsumerStatefulWidget {
  final Shipment shipment;

  const _ShipmentCard({required this.shipment});

  @override
  ConsumerState<_ShipmentCard> createState() => _ShipmentCardState();
}

class _ShipmentCardState extends ConsumerState<_ShipmentCard> {
  bool _expanded = false;

  void _copyTracking(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.shipment.trackingNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking number copied'), duration: Duration(seconds: 1)),
    );
  }

  void _openArrivalSheet(BuildContext context) {
    showShadSheet(
      context: context,
      side: ShadSheetSide.right,
      builder: (context) => _ArrivalSheet(shipment: widget.shipment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shipment = widget.shipment;
    final textTheme = ShadTheme.of(context).textTheme;
    final trackingUrl = shipment.courier.trackingUrl(shipment.trackingNumber);
    final landedCostLabel = shipment.shippingCost != null && shipment.itemCount > 0
        ? '₱${(shipment.shippingCost! / shipment.itemCount).toStringAsFixed(2)} / item landed cost'
        : null;

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                ShadBadge.secondary(child: Text(shipment.courier.label)),
                const Gap(8),
                Expanded(
                  child: Text(
                    shipment.trackingNumber,
                    style: textTheme.p.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => _copyTracking(context),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  onPressed: trackingUrl == null
                      ? null
                      : () => launchUrl(Uri.parse(trackingUrl), mode: LaunchMode.externalApplication),
                ),
                if (shipment.isStale) ...[
                  const Gap(4),
                  ShadBadge(backgroundColor: Colors.red.shade700, child: const Text('Stale')),
                ],
                ShadIconButton.ghost(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          const Gap(6),
          Text(
            [
              '${shipment.itemCount} item${shipment.itemCount == 1 ? '' : 's'}',
              if (shipment.shippingCost != null) '₱${shipment.shippingCost!.toStringAsFixed(2)} shipping',
              ?landedCostLabel,
              if (shipment.estimatedArrival != null)
                'ETA ${shipment.estimatedArrival!.toLocal().toString().split(' ').first}',
            ].join(' · '),
            style: textTheme.muted.copyWith(fontSize: 12),
          ),
          if (_expanded) ...[
            const Gap(12),
            const Divider(height: 1),
            const Gap(8),
            _ShipmentItemsList(shipmentId: shipment.id),
          ],
          const Gap(12),
          Align(
            alignment: Alignment.centerRight,
            child: shipment.status == ShipmentStatus.delivered
                ? ShadBadge(backgroundColor: Colors.green.shade700, child: const Text('Delivered'))
                : ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: () => _openArrivalSheet(context),
                    child: const Text('Mark Delivered'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentItemsList extends ConsumerWidget {
  final String shipmentId;

  const _ShipmentItemsList({required this.shipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return itemsAsync.when(
      data: (allItems) {
        final items = allItems.where((i) => i.shipmentId == shipmentId).toList();
        if (items.isEmpty) {
          return Text('No items on this shipment.', style: textTheme.muted.copyWith(fontSize: 12.5));
        }
        return Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: textTheme.small,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₱${(item.marketValue ?? 0).toStringAsFixed(2)}',
                      style: textTheme.muted.copyWith(fontSize: 11),
                    ),
                    const Gap(4),
                    ShadIconButton.ghost(
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      onPressed: () => showEditItemSheet(context, item),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Text(
        'Could not load items: $err',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}

class _ArrivalSheet extends ConsumerStatefulWidget {
  final Shipment shipment;

  const _ArrivalSheet({required this.shipment});

  @override
  ConsumerState<_ArrivalSheet> createState() => _ArrivalSheetState();
}

class _ArrivalSheetState extends ConsumerState<_ArrivalSheet> {
  final Map<String, StorageContainer> _placements = {};
  bool _isSaving = false;

  void _applyToAll(StorageContainer container, List<Item> items) {
    setState(() {
      for (final item in items) {
        _placements[item.id] = container;
      }
    });
  }

  Future<void> _confirm(List<Item> items) async {
    if (_placements.length != items.length) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(itemRepositoryProvider).receive(
            widget.shipment.id,
            items: items,
            placements: _placements,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);
    final containersAsync = ref.watch(userContainersStreamProvider);
    final containers = containersAsync.value ?? const <StorageContainer>[];

    return ShadSheet(
      title: const Text('Assign to Containers'),
      description: const Text('Where does each item in this shipment go?'),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
      child: itemsAsync.when(
        data: (allItems) {
          final items = allItems.where((i) => i.shipmentId == widget.shipment.id).toList();

          if (containers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No containers yet — add one from the In Hand tab first.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Assign all to:', style: textTheme.small)),
                    ShadSelect<String>(
                      placeholder: const Text('Pick a container'),
                      options: [for (final c in containers) ShadOption(value: c.id, child: Text(c.name))],
                      selectedOptionBuilder: (context, value) =>
                          Text(containers.firstWhere((c) => c.id == value).name),
                      onChanged: (val) {
                        if (val == null) return;
                        _applyToAll(containers.firstWhere((c) => c.id == val), items);
                      },
                    ),
                  ],
                ),
                const Gap(12),
                const Divider(),
                const Gap(8),
                ...items.map((item) {
                  final current = _placements[item.id];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: textTheme.small)),
                        SizedBox(
                          width: 180,
                          child: ShadSelect<String>(
                            initialValue: current?.id,
                            placeholder: const Text('Choose container'),
                            options: [
                              for (final c in containers) ShadOption(value: c.id, child: Text(c.name)),
                            ],
                            selectedOptionBuilder: (context, value) =>
                                Text(containers.firstWhere((c) => c.id == value).name),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _placements[item.id] = containers.firstWhere((c) => c.id == val));
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Gap(16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ShadButton(
                    enabled: !_isSaving && _placements.length == items.length && items.isNotEmpty,
                    onPressed: _isSaving || _placements.length != items.length || items.isEmpty
                        ? null
                        : () => _confirm(items),
                    child: Text(_isSaving ? 'Saving...' : 'Confirm Delivery'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Text('Error: $err'),
      ),
    );
  }
}
