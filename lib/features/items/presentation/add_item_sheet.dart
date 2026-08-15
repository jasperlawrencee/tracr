import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';
import 'package:tracr/core/presentation/widgets/suggesting_input.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';

import '../../sellers/data/seller_repository.dart';
import '../../sellers/domain/seller.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';

enum _CreateStage { wishlist, stashed }

List<String> _detailValueSuggestions(List<ItemAttribute> attributes, String label) {
  final wanted = label.trim().toLowerCase();
  if (wanted.isNotEmpty) {
    final scoped = attributes.where((a) => a.label.trim().toLowerCase() == wanted);
    if (scoped.isNotEmpty) return _distinct(scoped.map((a) => a.value));
  }
  return _distinct(attributes.map((a) => a.value));
}

List<String> _distinct(Iterable<String?> values) {
  final set = <String>{};
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) set.add(trimmed);
  }
  return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _marketValueController = TextEditingController();
  final _targetPriceController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _sellerPlatformController = TextEditingController();

  final List<_AttributeRow> _attributeRows = [];

  _CreateStage _createStage = _CreateStage.wishlist;
  Priority _priority = Priority.want;
  bool _isLoading = false;
  String? _error;

  Seller? _matchedSeller(List<Seller> sellers) {
    final typed = _sellerNameController.text.trim().toLowerCase();
    if (typed.isEmpty) return null;
    for (final seller in sellers) {
      if (seller.name.trim().toLowerCase() == typed) return seller;
    }
    return null;
  }

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
    _sellerNameController.dispose();
    _sellerPlatformController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Seller> sellers) async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }

    if (_createStage == _CreateStage.stashed) {
      final priceValid = double.tryParse(_priceController.text.trim()) != null;
      final sellerValid = _sellerNameController.text.trim().isNotEmpty;
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
        final items = await ref.read(itemRepositoryProvider).watchUserItems().first;
        final created = items.firstWhere(
          (i) => i.name == newItem.name && i.stage == ItemStage.wishlist,
          orElse: () => items.first,
        );

        final existingSeller = _matchedSeller(sellers);

        await repo.purchase(
          itemId: created.id,
          existingSeller: existingSeller,
          newSellerName: existingSeller == null ? _sellerNameController.text.trim() : null,
          newSellerPlatform: _sellerPlatformController.text.trim().isEmpty
              ? null
              : _sellerPlatformController.text.trim(),
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
    final items = ref.watch(userItemsStreamProvider).value ?? const <Item>[];

    final nameSuggestions = _distinct(items.map((i) => i.name));
    final categorySuggestions = _distinct(items.map((i) => i.category));
    final sourceUrlSuggestions = _distinct(items.map((i) => i.sourceUrl));
    final tagSuggestions = _distinct(items.expand((i) => i.tags));
    final sellerNameSuggestions = _distinct(sellers.map((s) => s.name));
    final platformSuggestions = _distinct(sellers.map((s) => s.platform));

    final allAttributes = items.expand((i) => i.attributes).toList();
    final detailLabelSuggestions = _distinct(allAttributes.map((a) => a.label));

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
                SuggestingInput(
                  controller: _nameController,
                  suggestions: nameSuggestions,
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
                          SuggestingInput(
                            controller: _categoryController,
                            suggestions: categorySuggestions,
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
                          child: SuggestingInput(
                            controller: _attributeRows[i].label,
                            suggestions: detailLabelSuggestions,
                            placeholder: const Text('Label, e.g. Card Number'),
                            onChanged: (_) => setState(() {}),
                            onSelected: (_) => setState(() {}),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: SuggestingInput(
                            controller: _attributeRows[i].value,
                            suggestions: _detailValueSuggestions(
                              allAttributes,
                              _attributeRows[i].label.text,
                            ),
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
                  SuggestingInput(
                    controller: _sourceUrlController,
                    suggestions: sourceUrlSuggestions,
                    placeholder: const Text('Where you spotted it'),
                  ),
                  const Gap(16),
                ],

                if (_createStage == _CreateStage.stashed) ...[
                  Text('Seller', style: textTheme.small),
                  const Gap(6),
                  SuggestingInput(
                    controller: _sellerNameController,
                    suggestions: sellerNameSuggestions,
                    placeholder: const Text('e.g., @CardKing on Whatnot'),
                    onChanged: (_) => setState(() {}),
                    onSelected: (name) {
                      final seller = _matchedSeller(sellers);
                      if (seller?.platform != null) {
                        _sellerPlatformController.text = seller!.platform!;
                      }
                      setState(() {});
                    },
                  ),
                  const Gap(6),
                  Text(
                    _matchedSeller(sellers) != null
                        ? 'Matches a saved seller — this purchase will be added to them.'
                        : 'Type a new name to create a seller.',
                    style: textTheme.muted.copyWith(fontSize: 11.5),
                  ),
                  const Gap(16),
                  Text('Platform (optional)', style: textTheme.small),
                  const Gap(6),
                  SuggestingInput(
                    controller: _sellerPlatformController,
                    suggestions: platformSuggestions,
                    placeholder: const Text('Facebook, Shopee, Carousell, IG...'),
                  ),
                  const Gap(16),
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
                SuggestingInput(
                  controller: _tagsController,
                  suggestions: tagSuggestions,
                  commaSeparated: true,
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
