import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';
import 'package:tracr/core/presentation/widgets/card_container.dart';
import 'package:tracr/core/presentation/widgets/search_field.dart';

import '../../containers/data/container_repository.dart';
import '../../containers/domain/storage_container.dart';
import '../../containers/presentation/container_form_dialog.dart';
import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';

class InHandPage extends ConsumerStatefulWidget {
  const InHandPage({super.key});

  @override
  ConsumerState<InHandPage> createState() => _InHandPageState();
}

class _InHandPageState extends ConsumerState<InHandPage> {
  // Which containers are expanded to show their item preview inline —
  // lets users browse "what's inside" right on this page instead of always
  // having to open the full container detail route.
  final Set<String> _expandedIds = {};
  final _searchController = TextEditingController();
  String _query = '';

  void _toggleExpanded(String containerId) {
    setState(() {
      if (_expandedIds.contains(containerId)) {
        _expandedIds.remove(containerId);
      } else {
        _expandedIds.add(containerId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesContainer(StorageContainer container, List<Item> inHandItems) {
    if (_query.isEmpty) return true;
    final q = _query.trim().toLowerCase();
    if (container.name.toLowerCase().contains(q)) return true;
    if (container.location != null && container.location!.toLowerCase().contains(q)) return true;
    return inHandItems.any((i) => i.containerId == container.id && i.matchesQuery(_query));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final containersAsync = ref.watch(userContainersStreamProvider);
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return AppShell(
      activeIndex: 4,
      child: containersAsync.when(
        data: (containers) {
          final allInHandItems =
              (itemsAsync.value ?? const <Item>[]).where((i) => i.stage == ItemStage.inHand).toList();
          final filteredContainers = containers.where((c) => _matchesContainer(c, allInHandItems)).toList();
          final filteredContainerIds = filteredContainers.map((c) => c.id).toSet();
          final inHandItems =
              allInHandItems.where((i) => filteredContainerIds.contains(i.containerId)).toList();
          final totalMarketValue = inHandItems.fold<double>(0, (sum, i) => sum + (i.marketValue ?? 0));
          final totalPricePaid = inHandItems.fold<double>(0, (sum, i) => sum + (i.pricePaid ?? 0));
          final pnl = totalMarketValue - totalPricePaid;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('In Hand', style: textTheme.h3),
                          const Gap(4),
                          Text('What do I own, and where is it.', style: textTheme.muted),
                        ],
                      ),
                    ),
                    ShadButton(
                      onPressed: () => showContainerFormDialog(context, ref),
                      child: const Text('New Container'),
                    ),
                  ],
                ),
                const Gap(16),
                SearchField(
                  controller: _searchController,
                  placeholder: 'Search containers or items...',
                  onChanged: (val) => setState(() => _query = val),
                ),
                const Gap(16),
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _statTile(textTheme, 'Containers', '${filteredContainers.length}'),
                      const Gap(24),
                      _statTile(textTheme, 'Market value', '₱${totalMarketValue.toStringAsFixed(2)}'),
                      const Gap(24),
                      _statTile(textTheme, 'Paid', '₱${totalPricePaid.toStringAsFixed(2)}'),
                      const Gap(24),
                      _statTile(
                        textTheme,
                        'P&L',
                        '${pnl >= 0 ? '+' : ''}₱${pnl.toStringAsFixed(2)}',
                        color: pnl >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: containers.isEmpty
                      ? _EmptyState(onCreate: () => showContainerFormDialog(context, ref))
                      : filteredContainers.isEmpty
                          ? Center(
                              child: Text('No containers match your search.', style: textTheme.muted),
                            )
                          : ListView.separated(
                              itemCount: filteredContainers.length,
                              separatorBuilder: (context, index) => const Gap(12),
                              itemBuilder: (context, index) {
                                final container = filteredContainers[index];
                                return _ContainerListCard(
                                  key: ValueKey(container.id),
                                  container: container,
                                  expanded: _expandedIds.contains(container.id),
                                  onToggleExpand: () => _toggleExpanded(container.id),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading containers: $err')),
      ),
    );
  }

  Widget _statTile(ShadTextTheme textTheme, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.muted.copyWith(fontSize: 12)),
        Text(value, style: textTheme.h4.copyWith(color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: textTheme.muted.color?.withValues(alpha: 0.6)),
          const Gap(14),
          Text('No containers yet', style: textTheme.p.copyWith(fontWeight: FontWeight.bold)),
          const Gap(6),
          SizedBox(
            width: 320,
            child: Text(
              'A container is a binder, box, or shelf — anywhere you physically keep items. '
              'Create one to start assigning items you have in hand.',
              style: textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(18),
          ShadButton(onPressed: onCreate, child: const Text('Create your first container')),
        ],
      ),
    );
  }
}

class _ContainerListCard extends ConsumerWidget {
  final StorageContainer container;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const _ContainerListCard({
    super.key,
    required this.container,
    required this.expanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final textTheme = theme.textTheme;
    final capacity = container.capacity;
    final fraction = capacity != null && capacity > 0
        ? (container.itemCount / capacity).clamp(0.0, 1.0)
        : null;
    final parsedColor = container.colorHex == null
        ? null
        : int.tryParse(container.colorHex!.replaceFirst('#', '0xff'));
    final color = parsedColor != null ? Color(parsedColor) : theme.colorScheme.primary;

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                container.name,
                                style: textTheme.p.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Gap(8),
                            ShadBadge.secondary(child: Text(container.type.label)),
                            if (container.itemCount == 0) ...[
                              const Gap(6),
                              ShadBadge.outline(child: const Text('Empty')),
                            ],
                            if (container.location != null && container.location!.isNotEmpty) ...[
                              const Gap(6),
                              Icon(Icons.place_outlined, size: 12, color: textTheme.muted.color),
                              const Gap(2),
                              Flexible(
                                child: Text(
                                  container.location!,
                                  style: textTheme.muted.copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Gap(6),
                        if (fraction != null)
                          Row(
                            children: [
                              SizedBox(width: 140, child: ShadProgress(value: fraction)),
                              const Gap(8),
                              Text(
                                '${container.itemCount} / $capacity slots',
                                style: textTheme.muted.copyWith(fontSize: 11),
                              ),
                            ],
                          )
                        else
                          Text(
                            '${container.itemCount} item${container.itemCount == 1 ? '' : 's'}',
                            style: textTheme.muted.copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  Text(
                    '₱${container.totalValue.toStringAsFixed(2)}',
                    style: textTheme.p.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Gap(12),
                  ShadIconButton.ghost(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    onPressed: () => showContainerFormDialog(context, ref, existing: container),
                  ),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => context.go('/in-hand/${container.id}'),
                    child: const Text('Open'),
                  ),
                  const Gap(4),
                  ShadIconButton.ghost(
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                    onPressed: onToggleExpand,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Gap(12),
            const Divider(height: 1),
            const Gap(12),
            _ItemsPreview(containerId: container.id),
          ],
        ],
      ),
    );
  }
}

class _ItemsPreview extends ConsumerWidget {
  final String containerId;

  const _ItemsPreview({required this.containerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(itemsInContainerProvider(containerId));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Text('Nothing placed here yet.', style: textTheme.muted.copyWith(fontSize: 12.5));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.go('/in-hand/$containerId'),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: ShadTheme.of(context).colorScheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.small.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Text(
                        '₱${(item.marketValue ?? 0).toStringAsFixed(2)}',
                        style: textTheme.muted.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (err, stack) => Text(
        'Could not load items: $err',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
