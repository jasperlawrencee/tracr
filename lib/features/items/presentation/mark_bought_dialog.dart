import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import '../../sellers/data/seller_repository.dart';
import '../../sellers/domain/seller.dart';
import '../data/item_repository.dart';

/// Shared "wishlist -> stashed" dialog: pick an existing seller or add a new
/// one, enter what was paid. Used from both the kanban card's "Mark Bought"
/// button and the Wishlist module.
Future<void> showMarkBoughtDialog({
  required BuildContext context,
  required String itemId,
  required String itemName,
}) {
  return showShadDialog(
    context: context,
    builder: (dialogContext) => _MarkBoughtDialog(itemId: itemId, itemName: itemName),
  );
}

class _MarkBoughtDialog extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;

  const _MarkBoughtDialog({required this.itemId, required this.itemName});

  @override
  ConsumerState<_MarkBoughtDialog> createState() => _MarkBoughtDialogState();
}

class _MarkBoughtDialogState extends ConsumerState<_MarkBoughtDialog> {
  static const _newSellerSentinel = '__new__';

  String _selectedSellerId = _newSellerSentinel;
  final _newSellerNameController = TextEditingController();
  final _newSellerPlatformController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _newSellerNameController.dispose();
    _newSellerPlatformController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Seller> sellers) async {
    final pricePaid = double.tryParse(_priceController.text.trim());
    if (pricePaid == null) {
      setState(() => _error = 'Enter a valid price paid.');
      return;
    }

    Seller? existingSeller;
    String? newSellerName;
    if (_selectedSellerId == _newSellerSentinel) {
      newSellerName = _newSellerNameController.text.trim();
      if (newSellerName.isEmpty) {
        setState(() => _error = 'Enter the seller\'s name, or pick an existing one.');
        return;
      }
    } else {
      existingSeller = sellers.firstWhere((s) => s.id == _selectedSellerId);
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(itemRepositoryProvider).purchase(
            itemId: widget.itemId,
            existingSeller: existingSeller,
            newSellerName: newSellerName,
            newSellerPlatform: _newSellerPlatformController.text.trim().isEmpty
                ? null
                : _newSellerPlatformController.text.trim(),
            pricePaid: pricePaid,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not mark as bought: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final sellersAsync = ref.watch(userSellersStreamProvider);
    final sellers = sellersAsync.value ?? const <Seller>[];

    if (_selectedSellerId != _newSellerSentinel && sellers.every((s) => s.id != _selectedSellerId)) {
      _selectedSellerId = _newSellerSentinel;
    }

    return ShadDialog(
      title: const Text('Mark as Bought'),
      description: Text('Who did you buy "${widget.itemName}" from, and for how much?'),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: _isSaving ? null : () => _submit(sellers),
          child: Text(_isSaving ? 'Saving...' : 'Confirm'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seller', style: textTheme.small),
            const Gap(6),
            ShadSelect<String>(
              initialValue: _selectedSellerId,
              options: [
                const ShadOption(value: _newSellerSentinel, child: Text('+ New seller')),
                for (final seller in sellers) ShadOption(value: seller.id, child: Text(seller.name)),
              ],
              selectedOptionBuilder: (context, value) => Text(
                value == _newSellerSentinel
                    ? '+ New seller'
                    : sellers.firstWhere((s) => s.id == value, orElse: () => sellers.first).name,
              ),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSellerId = val);
              },
            ),
            const Gap(16),
            if (_selectedSellerId == _newSellerSentinel) ...[
              Text('New seller name', style: textTheme.small),
              const Gap(6),
              ShadInput(
                controller: _newSellerNameController,
                placeholder: const Text('e.g., CardShopPH'),
              ),
              const Gap(16),
              Text('Platform (optional)', style: textTheme.small),
              const Gap(6),
              ShadInput(
                controller: _newSellerPlatformController,
                placeholder: const Text('Facebook, Shopee, Carousell, IG...'),
              ),
              const Gap(16),
            ],
            Text('Price paid', style: textTheme.small),
            const Gap(6),
            ShadInput(
              controller: _priceController,
              placeholder: const Text('0.00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_error != null) ...[
              const Gap(12),
              Text(_error!, style: textTheme.small.copyWith(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
