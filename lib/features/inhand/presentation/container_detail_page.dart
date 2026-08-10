import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';
import 'package:tracr/core/presentation/widgets/card_container.dart';
import 'package:tracr/core/presentation/widgets/confimation_dialog.dart';

import '../../containers/data/container_repository.dart';
import '../../containers/domain/storage_container.dart';
import '../../containers/presentation/container_form_dialog.dart';
import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/edit_item_sheet.dart';

const _pocketsPerPage = 9;

class ContainerDetailPage extends ConsumerStatefulWidget {
  final String containerId;

  const ContainerDetailPage({super.key, required this.containerId});

  @override
  ConsumerState<ContainerDetailPage> createState() => _ContainerDetailPageState();
}

class _ContainerDetailPageState extends ConsumerState<ContainerDetailPage> {
  final Set<String> _selectedIds = {};

  @override
  void didUpdateWidget(covariant ContainerDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jumping between containers (prev/next/dropdown) reuses this State —
    // clear any item selection made in the previous container so "Move
    // Selected" can't fire against the wrong container's items.
    if (oldWidget.containerId != widget.containerId) {
      _selectedIds.clear();
    }
  }

  void _openMoveDialog(List<Item> selectedItems, String fromContainerId, List<StorageContainer> containers) {
    StorageContainer? target = containers.where((c) => c.id != fromContainerId).firstOrNull;

    showShadDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => ShadDialog(
          title: Text('Move ${selectedItems.length} item(s)'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: target == null
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await ref.read(containerRepositoryProvider).moveItems(
                            items: selectedItems,
                            fromContainerId: fromContainerId,
                            toContainer: target!,
                          );
                      if (mounted) setState(() => _selectedIds.clear());
                    },
              child: const Text('Move'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ShadSelect<String>(
              initialValue: target?.id,
              placeholder: const Text('Choose destination'),
              options: [
                for (final c in containers.where((c) => c.id != fromContainerId))
                  ShadOption(value: c.id, child: Text(c.name)),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(containers.firstWhere((c) => c.id == value).name),
              onChanged: (val) {
                if (val == null) return;
                setState(() => target = containers.firstWhere((c) => c.id == val));
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final containerAsync = ref.watch(userContainersStreamProvider);
    return AppShell(
      activeIndex: 4,
      child: containerAsync.when(
        data: (containers) {
          final container = containers.where((c) => c.id == widget.containerId).firstOrNull;
          if (container == null) {
            return Center(child: Text('Container not found.', style: textTheme.muted));
          }

          return Consumer(
            builder: (context, ref, _) {
              final itemsInContainerAsync =
                  ref.watch(itemsInContainerProvider(widget.containerId));

              return itemsInContainerAsync.when(
                data: (items) {
                  final rows = container.capacity != null
                      ? (container.capacity! / _pocketsPerPage).ceil()
                      : (items.length / _pocketsPerPage).ceil().clamp(1, 1000);
                  final slotCount = rows * _pocketsPerPage;
                  final selectedItems = items.where((i) => _selectedIds.contains(i.id)).toList();

                  final currentIndex = containers.indexWhere((c) => c.id == container.id);
                  final previousContainer =
                      currentIndex > 0 ? containers[currentIndex - 1] : null;
                  final nextContainer = currentIndex >= 0 && currentIndex < containers.length - 1
                      ? containers[currentIndex + 1]
                      : null;

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShadIconButton.ghost(
                              icon: const Icon(Icons.arrow_back, size: 18),
                              onPressed: () => context.go('/in-hand'),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                container.name,
                                style: textTheme.h3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ShadIconButton.ghost(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showContainerFormDialog(context, ref, existing: container),
                            ),
                            const Gap(8),
                            if (selectedItems.isNotEmpty) ...[
                              ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: () =>
                                    _openMoveDialog(selectedItems, container.id, containers),
                                child: Text('Move Selected (${selectedItems.length})'),
                              ),
                              const Gap(8),
                            ],
                          ],
                        ),
                        const Gap(10),
                        // Container navigator: step through with arrows or
                        // jump straight to any container from the dropdown,
                        // without going back to the grid overview each time.
                        Row(
                          children: [
                            ShadIconButton.outline(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: previousContainer == null
                                  ? null
                                  : () => context.go('/in-hand/${previousContainer.id}'),
                            ),
                            const Gap(6),
                            ShadIconButton.outline(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: nextContainer == null
                                  ? null
                                  : () => context.go('/in-hand/${nextContainer.id}'),
                            ),
                            const Gap(12),
                            SizedBox(
                              width: 220,
                              child: ShadSelect<String>(
                                key: ValueKey('container-switcher-${container.id}'),
                                initialValue: container.id,
                                options: [
                                  for (final c in containers)
                                    ShadOption(value: c.id, child: Text(c.name)),
                                ],
                                selectedOptionBuilder: (context, value) =>
                                    Text(containers.firstWhere((c) => c.id == value).name),
                                onChanged: (val) {
                                  if (val != null && val != container.id) {
                                    context.go('/in-hand/$val');
                                  }
                                },
                              ),
                            ),
                            const Gap(8),
                            Text(
                              '${currentIndex + 1} / ${containers.length}',
                              style: textTheme.muted.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const Gap(8),
                        Text(
                          [
                            '${container.itemCount} item${container.itemCount == 1 ? '' : 's'}',
                            '₱${container.totalValue.toStringAsFixed(2)}',
                            if (container.location != null && container.location!.isNotEmpty)
                              container.location!,
                          ].join(' · '),
                          style: textTheme.muted,
                        ),
                        const Gap(16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 140,
                              mainAxisExtent: 150,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: slotCount,
                            itemBuilder: (context, index) {
                              if (index >= items.length) {
                                return _EmptySlot(
                                  key: ValueKey('empty-slot-$index'),
                                  page: (index ~/ _pocketsPerPage) + 1,
                                );
                              }
                              final item = items[index];
                              return _ItemSlot(
                                key: ValueKey(item.id),
                                item: item,
                                selected: _selectedIds.contains(item.id),
                                onToggleSelect: () {
                                  setState(() {
                                    if (_selectedIds.contains(item.id)) {
                                      _selectedIds.remove(item.id);
                                    } else {
                                      _selectedIds.add(item.id);
                                    }
                                  });
                                },
                                onEdit: () => showEditItemSheet(context, item),
                                onToggleForSale: (val) => ref
                                    .read(itemRepositoryProvider)
                                    .updateItem(item.id, {'isForSale': val}),
                                onDelete: () => ConfirmationDialog.show(
                                  context: context,
                                  title: 'Delete Item',
                                  description: 'Delete "${item.name}"? This cannot be undone.',
                                  confirmLabel: 'Delete',
                                  style: ConfirmActionStyle.destructive,
                                  onConfirm: () => ref.read(itemRepositoryProvider).deleteItem(item),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final int page;

  const _EmptySlot({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return DottedSlot(page: page);
  }
}

class DottedSlot extends StatelessWidget {
  final int page;

  const DottedSlot({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text('P$page', style: textTheme.muted.copyWith(fontSize: 11)),
    );
  }
}

class _ItemSlot extends StatelessWidget {
  final Item item;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleForSale;
  final VoidCallback onDelete;

  const _ItemSlot({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onToggleForSale,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    return CardContainer(
      padding: const EdgeInsets.all(8),
      backgroundColor: selected ? ShadTheme.of(context).colorScheme.accent : null,
      child: InkWell(
        onTap: onToggleSelect,
        onLongPress: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: textTheme.small.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  onPressed: onEdit,
                ),
              ],
            ),
            if (item.condition != null)
              Text(item.condition!.name.toUpperCase(), style: textTheme.muted.copyWith(fontSize: 10)),
            if (item.grading != null)
              Text(
                '${item.grading!.company} ${item.grading!.grade}',
                style: textTheme.muted.copyWith(fontSize: 10),
              ),
            const Spacer(),
            Text('₱${(item.marketValue ?? 0).toStringAsFixed(2)}', style: textTheme.small),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Sale', style: textTheme.muted.copyWith(fontSize: 10)),
                    Transform.scale(
                      scale: 0.7,
                      child: ShadSwitch(value: item.isForSale, onChanged: onToggleForSale),
                    ),
                  ],
                ),
                ShadIconButton.ghost(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
