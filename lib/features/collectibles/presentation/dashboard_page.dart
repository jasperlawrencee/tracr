import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/app_shell.dart';

import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/item_card.dart';

const _kStackBreakpoint = 600.0;
const _kBoardBreakpoint = 1180.0;
const _kColumnMinWidth = 280.0;

const _pipelineStages = [
  ItemStage.wishlist,
  ItemStage.stashed,
  ItemStage.inTransit,
  ItemStage.inHand,
];

String _stageEmoji(ItemStage stage) => switch (stage) {
      ItemStage.wishlist => '💭',
      ItemStage.stashed => '⏳',
      ItemStage.inTransit => '🚚',
      ItemStage.inHand => '🛡️',
      ItemStage.archived => '📦',
    };

String _stageLabel(ItemStage stage) => switch (stage) {
      ItemStage.wishlist => 'Wishlist',
      ItemStage.stashed => 'Stashed',
      ItemStage.inTransit => 'In Transit',
      ItemStage.inHand => 'In Hand',
      ItemStage.archived => 'Archived',
    };

Color _stageColor(ItemStage stage) => switch (stage) {
      ItemStage.wishlist => const Color(0xFFEC4899),
      ItemStage.stashed => const Color(0xFFF59E0B),
      ItemStage.inTransit => const Color(0xFF3B82F6),
      ItemStage.inHand => const Color(0xFF10B981),
      ItemStage.archived => const Color(0xFF6B7280),
    };

String _stageHint(ItemStage stage) => switch (stage) {
      ItemStage.wishlist => 'Nothing on the wishlist yet.',
      ItemStage.stashed => 'No items waiting to ship.',
      ItemStage.inTransit => 'Nothing in transit right now.',
      ItemStage.inHand => 'No items received yet.',
      ItemStage.archived => 'Nothing archived.',
    };

String _peso(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₱$buffer.${parts[1]}';
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  ItemStage _selectedStage = ItemStage.stashed;

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final itemsAsync = ref.watch(userItemsStreamProvider);

    return AppShell(
      activeIndex: 0,
      child: itemsAsync.when(
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < _kStackBreakpoint;
            final byStage = {
              for (final stage in _pipelineStages)
                stage: items.where((i) => i.stage == stage).toList(),
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, isMobile ? 12 : 16),
                  child: _Overview(items: items, byStage: byStage, isMobile: isMobile),
                ),
                if (isMobile)
                  _StageTabs(
                    byStage: byStage,
                    selected: _selectedStage,
                    onSelected: (stage) => setState(() => _selectedStage = stage),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, isMobile ? 12 : 0, 16, 16),
                    child: isMobile
                        ? _PipelineColumn(
                            stage: _selectedStage,
                            items: byStage[_selectedStage]!,
                          )
                        : _PipelineBoard(byStage: byStage, maxWidth: constraints.maxWidth),
                  ),
                ),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading inventory: $err',
              style: textTheme.small,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final List<Item> items;
  final Map<ItemStage, List<Item>> byStage;
  final bool isMobile;

  const _Overview({required this.items, required this.byStage, required this.isMobile});

  double _valueOf(ItemStage stage) =>
      byStage[stage]!.fold<double>(0, (sum, i) => sum + (i.marketValue ?? 0));

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final tracked = items.where((i) => i.stage != ItemStage.archived).length;

    final stats = [
      _Stat(
        label: 'Tracked Items',
        value: '$tracked',
        icon: Icons.inventory_2_outlined,
        color: _stageColor(ItemStage.stashed),
      ),
      _Stat(
        label: 'In Hand Value',
        value: _peso(_valueOf(ItemStage.inHand)),
        icon: Icons.shield_outlined,
        color: _stageColor(ItemStage.inHand),
      ),
      _Stat(
        label: 'In Transit',
        value: '${byStage[ItemStage.inTransit]!.length}',
        icon: Icons.local_shipping_outlined,
        color: _stageColor(ItemStage.inTransit),
      ),
      _Stat(
        label: 'Wishlist Cost',
        value: _peso(_valueOf(ItemStage.wishlist)),
        icon: Icons.favorite_border,
        color: _stageColor(ItemStage.wishlist),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: isMobile ? textTheme.h4 : textTheme.h3),
        const Gap(2),
        Text(
          'Every item you are chasing, waiting on, or already own.',
          style: textTheme.muted,
        ),
        Gap(isMobile ? 12 : 16),
        if (isMobile)
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stats.length,
              separatorBuilder: (context, index) => const Gap(10),
              itemBuilder: (context, index) => SizedBox(width: 156, child: stats[index]),
            ),
          )
        else
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const Gap(12),
                Expanded(child: stats[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTabs extends StatelessWidget {
  final Map<ItemStage, List<Item>> byStage;
  final ItemStage selected;
  final ValueChanged<ItemStage> onSelected;

  const _StageTabs({required this.byStage, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pipelineStages.length,
        separatorBuilder: (context, index) => const Gap(8),
        itemBuilder: (context, index) {
          final stage = _pipelineStages[index];
          return _StageTab(
            stage: stage,
            count: byStage[stage]!.length,
            active: stage == selected,
            onTap: () => onSelected(stage),
          );
        },
      ),
    );
  }
}

class _StageTab extends StatelessWidget {
  final ItemStage stage;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _StageTab({
    required this.stage,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = _stageColor(stage);

    return Material(
      color: active ? color.withValues(alpha: 0.14) : theme.colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color : theme.colorScheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_stageEmoji(stage)} ${_stageLabel(stage)}'),
              const Gap(6),
              Text(
                '$count',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.bold,
                  color: active ? color : theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineBoard extends StatelessWidget {
  final Map<ItemStage, List<Item>> byStage;
  final double maxWidth;

  const _PipelineBoard({required this.byStage, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final scrolls = maxWidth < _kBoardBreakpoint;

    final columns = [
      for (var i = 0; i < _pipelineStages.length; i++) ...[
        if (i > 0) const Gap(16),
        Builder(builder: (context) {
          final stage = _pipelineStages[i];
          final column = _PipelineColumn(stage: stage, items: byStage[stage]!);
          return scrolls ? SizedBox(width: _kColumnMinWidth, child: column) : Expanded(child: column);
        }),
      ],
    ];

    if (!scrolls) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _kColumnMinWidth * _pipelineStages.length + 16 * (_pipelineStages.length - 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns),
      ),
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  final ItemStage stage;
  final List<Item> items;

  const _PipelineColumn({required this.stage, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = _stageColor(stage);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    '${_stageEmoji(stage)} ${_stageLabel(stage)}',
                    style: theme.textTheme.p.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _EmptyStage(stage: stage)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
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

class _EmptyStage extends StatelessWidget {
  final ItemStage stage;

  const _EmptyStage({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: 0.35, child: Text(_stageEmoji(stage), style: const TextStyle(fontSize: 28))),
            const Gap(8),
            Text(
              _stageHint(stage),
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
