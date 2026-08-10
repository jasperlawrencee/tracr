import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';

import '../../sellers/data/seller_repository.dart';
import '../../sellers/domain/seller.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';

enum _CreateStage { wishlist, stashed }

class _AttributeRow {
  final TextEditingController label;
  final TextEditingController value;

  _AttributeRow({String label = '', String value = ''})
      : label = TextEditingController(text: label),
        value = TextEditingController(text: value);

  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key});

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  static const _newSellerSentinel = '__new__';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _marketValueController = TextEditingController();
  final _targetPriceController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController();
  final _newSellerNameController = TextEditingController();
  final _newSellerPlatformController = TextEditingController();

  final List<_AttributeRow> _attributeRows = [];

  _CreateStage _createStage = _CreateStage.wishlist;
  Priority _priority = Priority.want;
  String _selectedSellerId = _newSellerSentinel;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    for (final row in _attributeRows) {
      row.dispose();
    }
    _quantityController.dispose();
    _marketValueController.dispose();
    _targetPriceController.dispose();
    _sourceUrlController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _newSellerNameController.dispose();
    _newSellerPlatformController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Seller> sellers) async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }

    if (_createStage == _CreateStage.stashed) {
      final priceValid = double.tryParse(_priceController.text.trim()) != null;
      final sellerValid = _selectedSellerId != _newSellerSentinel ||
          _newSellerNameController.text.trim().isNotEmpty;
      if (!priceValid || !sellerValid) {
        setState(() => _error = 'Enter a seller and a valid price paid.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authUser = ref.read(firebaseAuthProvider).currentUser;
    if (authUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final attributes = _attributeRows
        .where((row) => row.label.text.trim().isNotEmpty && row.value.text.trim().isNotEmpty)
        .map((row) => ItemAttribute(label: row.label.text.trim(), value: row.value.text.trim()))
        .toList();

    final newItem = Item(
      id: '',
      userId: authUser.uid,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
      attributes: attributes,
      quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
      stage: ItemStage.wishlist,
      marketValue: double.tryParse(_marketValueController.text.trim()),
      targetPrice: double.tryParse(_targetPriceController.text.trim()),
      priority: _priority,
      sourceUrl: _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );

    try {
      final repo = ref.read(itemRepositoryProvider);
      await repo.addItem(newItem);

      if (_createStage == _CreateStage.stashed) {
        // Fetch the id of the doc we just created via the freshest stream
        // snapshot isn't available synchronously, so re-query by matching
        // name+createdAt is fragile — instead, addItem is split so the
        // stashed path creates then immediately purchases using the same
        // rollup logic as the Wishlist module's "Mark Bought" action.
        final items = await ref.read(itemRepositoryProvider).watchUserItems().first;
        final created = items.firstWhere(
          (i) => i.name == newItem.name && i.stage == ItemStage.wishlist,
          orElse: () => items.first,
        );

        Seller? existingSeller;
        String? newSellerName;
        if (_selectedSellerId == _newSellerSentinel) {
          newSellerName = _newSellerNameController.text.trim();
        } else {
          existingSeller = sellers.firstWhere((s) => s.id == _selectedSellerId);
        }

        await repo.purchase(
          itemId: created.id,
          existingSeller: existingSeller,
          newSellerName: newSellerName,
          newSellerPlatform: _newSellerPlatformController.text.trim().isEmpty
              ? null
              : _newSellerPlatformController.text.trim(),
          pricePaid: double.parse(_priceController.text.trim()),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Error adding item: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final sellersAsync = ref.watch(userSellersStreamProvider);
    final sellers = sellersAsync.value ?? const <Seller>[];

    return ShadSheet(
      title: Text('Add New Item', style: textTheme.h3),
      description: const Text('Log a wishlist item, or something you already bought from a seller.'),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: _isLoading ? null : () => _submit(sellers),
          child: Text(_isLoading ? 'Saving...' : 'Save Item'),
        ),
      ],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item Name *', style: textTheme.small),
                const Gap(6),
                ShadInput(
                  controller: _nameController,
                  placeholder: const Text('e.g., Charizard VMAX #074'),
                ),
                const Gap(16),

                Text('Starting Stage *', style: textTheme.small),
                const Gap(6),
                ShadSelect<_CreateStage>(
                  initialValue: _createStage,
                  options: const [
                    ShadOption(value: _CreateStage.wishlist, child: Text('💭 Wishlist')),
                    ShadOption(value: _CreateStage.stashed, child: Text('⏳ Already bought (Stashed)')),
                  ],
                  selectedOptionBuilder: (context, value) =>
                      Text(value == _CreateStage.wishlist ? '💭 Wishlist' : '⏳ Already bought (Stashed)'),
                  onChanged: (val) {
                    if (val != null) setState(() => _createStage = val);
                  },
                ),
                const Gap(16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category', style: textTheme.small),
                          const Gap(6),
                          ShadInput(
                            controller: _categoryController,
                            placeholder: const Text('Card, Sealed, Figure...'),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity', style: textTheme.small),
                          const Gap(6),
                          ShadInput(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(16),

                Row(
                  children: [
                    Expanded(
                      child: Text('Custom Details', style: textTheme.small),
                    ),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () => setState(() => _attributeRows.add(_AttributeRow())),
                      child: const Text('+ Add Detail'),
                    ),
                  ],
                ),
                if (_attributeRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Set Name, Card Number, Pop Number, Edition — whatever fits this collectible.',
                      style: textTheme.muted.copyWith(fontSize: 11.5),
                    ),
                  ),
                for (var i = 0; i < _attributeRows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ShadInput(
                            controller: _attributeRows[i].label,
                            placeholder: const Text('Label, e.g. Card Number'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: ShadInput(
                            controller: _attributeRows[i].value,
                            placeholder: const Text('Value, e.g. 025/165'),
                          ),
                        ),
                        ShadIconButton.ghost(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _attributeRows[i].dispose();
                            _attributeRows.removeAt(i);
                          }),
                        ),
                      ],
                    ),
                  ),
                const Gap(8),

                Text('Market Value', style: textTheme.small),
                const Gap(6),
                ShadInput(
                  controller: _marketValueController,
                  placeholder: const Text('0.00'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const Gap(16),

                if (_createStage == _CreateStage.wishlist) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Price', style: textTheme.small),
                            const Gap(6),
                            ShadInput(
                              controller: _targetPriceController,
                              placeholder: const Text('0.00'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Priority', style: textTheme.small),
                            const Gap(6),
                            ShadSelect<Priority>(
                              initialValue: _priority,
                              options: const [
                                ShadOption(value: Priority.mustHave, child: Text('Must Have')),
                                ShadOption(value: Priority.want, child: Text('Want')),
                                ShadOption(value: Priority.someday, child: Text('Someday')),
                              ],
                              selectedOptionBuilder: (context, value) => Text(value.name),
                              onChanged: (val) {
                                if (val != null) setState(() => _priority = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Text('Source Link', style: textTheme.small),
                  const Gap(6),
                  ShadInput(
                    controller: _sourceUrlController,
                    placeholder: const Text('Where you spotted it'),
                  ),
                  const Gap(16),
                ],

                if (_createStage == _CreateStage.stashed) ...[
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
                    Text('New Seller Name', style: textTheme.small),
                    const Gap(6),
                    ShadInput(
                      controller: _newSellerNameController,
                      placeholder: const Text('e.g., @CardKing on Whatnot'),
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
                  Text('Price Paid', style: textTheme.small),
                  const Gap(6),
                  ShadInput(
                    controller: _priceController,
                    placeholder: const Text('0.00'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const Gap(16),
                ],

                Text('Tags (comma separated)', style: textTheme.small),
                const Gap(6),
                ShadInput(
                  controller: _tagsController,
                  placeholder: const Text('vintage, grail, holo'),
                ),

                if (_error != null) ...[
                  const Gap(16),
                  Text(_error!, style: textTheme.small.copyWith(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
