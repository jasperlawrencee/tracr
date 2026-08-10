import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';

import '../data/item_repository.dart';
import '../domain/item.dart';

Future<void> showEditItemSheet(BuildContext context, Item item) {
  return showShadSheet(
    context: context,
    side: ShadSheetSide.right,
    builder: (context) => EditItemSheet(item: item),
  );
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

class EditItemSheet extends ConsumerStatefulWidget {
  final Item item;

  const EditItemSheet({super.key, required this.item});

  @override
  ConsumerState<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<EditItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _marketValueController;
  late final TextEditingController _targetPriceController;
  late final TextEditingController _pricePaidController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final TextEditingController _gradingCompanyController;
  late final TextEditingController _gradingGradeController;
  late final TextEditingController _gradingCertController;

  late Priority _priority;
  Condition? _condition;
  late bool _isForSale;
  final List<_AttributeRow> _attributeRows = [];

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.name);
    _categoryController = TextEditingController(text: item.category);
    _quantityController = TextEditingController(text: item.quantity.toString());
    _marketValueController = TextEditingController(text: item.marketValue?.toString() ?? '');
    _targetPriceController = TextEditingController(text: item.targetPrice?.toString() ?? '');
    _pricePaidController = TextEditingController(text: item.pricePaid?.toString() ?? '');
    _sourceUrlController = TextEditingController(text: item.sourceUrl ?? '');
    _tagsController = TextEditingController(text: item.tags.join(', '));
    _notesController = TextEditingController(text: item.notes ?? '');
    _gradingCompanyController = TextEditingController(text: item.grading?.company ?? '');
    _gradingGradeController =
        TextEditingController(text: item.grading == null ? '' : item.grading!.grade.toString());
    _gradingCertController = TextEditingController(text: item.grading?.certNo ?? '');
    _priority = item.priority;
    _condition = item.condition;
    _isForSale = item.isForSale;
    _attributeRows.addAll(item.attributes.map((a) => _AttributeRow(label: a.label, value: a.value)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _marketValueController.dispose();
    _targetPriceController.dispose();
    _pricePaidController.dispose();
    _sourceUrlController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _gradingCompanyController.dispose();
    _gradingGradeController.dispose();
    _gradingCertController.dispose();
    for (final row in _attributeRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final tags =
        _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final attributes = _attributeRows
        .where((row) => row.label.text.trim().isNotEmpty && row.value.text.trim().isNotEmpty)
        .map((row) => ItemAttribute(label: row.label.text.trim(), value: row.value.text.trim()))
        .toList();

    Grading? grading;
    final gradingCompany = _gradingCompanyController.text.trim();
    final grade = double.tryParse(_gradingGradeController.text.trim());
    if (gradingCompany.isNotEmpty && grade != null) {
      grading = Grading(
        company: gradingCompany,
        grade: grade,
        certNo: _gradingCertController.text.trim().isEmpty ? null : _gradingCertController.text.trim(),
      );
    }

    try {
      await ref.read(itemRepositoryProvider).editItem(
            widget.item,
            name: _nameController.text.trim(),
            category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
            quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
            marketValue: double.tryParse(_marketValueController.text.trim()),
            targetPrice: double.tryParse(_targetPriceController.text.trim()),
            pricePaid: double.tryParse(_pricePaidController.text.trim()),
            priority: _priority,
            sourceUrl: _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
            condition: _condition,
            grading: grading,
            isForSale: _isForSale,
            tags: tags,
            attributes: attributes,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save changes: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    return ShadSheet(
      title: Text('Edit Item', style: textTheme.h3),
      description: Text('Update any detail of "${widget.item.name}".'),
      actions: [
        ShadButton.outline(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        ),
      ],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item Name *', style: textTheme.small),
              const Gap(6),
              ShadInput(controller: _nameController),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category', style: textTheme.small),
                        const Gap(6),
                        ShadInput(controller: _categoryController),
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
                        ShadInput(controller: _quantityController, keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),

              Text('Market Value', style: textTheme.small),
              const Gap(6),
              ShadInput(
                controller: _marketValueController,
                placeholder: const Text('0.00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const Gap(16),

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
                        Text('Price Paid', style: textTheme.small),
                        const Gap(6),
                        ShadInput(
                          controller: _pricePaidController,
                          placeholder: const Text('0.00'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),

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
              const Gap(16),

              Text('Source Link', style: textTheme.small),
              const Gap(6),
              ShadInput(controller: _sourceUrlController, placeholder: const Text('Where you spotted it')),
              const Gap(16),

              Text('Condition', style: textTheme.small),
              const Gap(6),
              ShadSelect<Condition?>(
                initialValue: _condition,
                placeholder: const Text('Not set'),
                options: const [
                  ShadOption(value: null, child: Text('Not set')),
                  ShadOption(value: Condition.nm, child: Text('NM')),
                  ShadOption(value: Condition.lp, child: Text('LP')),
                  ShadOption(value: Condition.mp, child: Text('MP')),
                  ShadOption(value: Condition.hp, child: Text('HP')),
                  ShadOption(value: Condition.dmg, child: Text('DMG')),
                ],
                selectedOptionBuilder: (context, value) => Text(value?.name.toUpperCase() ?? 'Not set'),
                onChanged: (val) => setState(() => _condition = val),
              ),
              const Gap(16),

              Text('Grading company (PSA, BGS, CGC)', style: textTheme.small),
              const Gap(6),
              ShadInput(controller: _gradingCompanyController),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grade', style: textTheme.small),
                        const Gap(6),
                        ShadInput(
                          controller: _gradingGradeController,
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
                        Text('Cert number', style: textTheme.small),
                        const Gap(6),
                        ShadInput(controller: _gradingCertController),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: Text('Listed for sale', style: textTheme.small),
                  ),
                  ShadSwitch(
                    value: _isForSale,
                    onChanged: (val) => setState(() => _isForSale = val),
                  ),
                ],
              ),
              const Gap(16),

              Text('Tags (comma separated)', style: textTheme.small),
              const Gap(6),
              ShadInput(controller: _tagsController, placeholder: const Text('vintage, grail, holo')),
              const Gap(16),

              Row(
                children: [
                  Expanded(child: Text('Custom Details', style: textTheme.small)),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _attributeRows.add(_AttributeRow())),
                    child: const Text('+ Add Detail'),
                  ),
                ],
              ),
              for (var i = 0; i < _attributeRows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShadInput(
                          controller: _attributeRows[i].label,
                          placeholder: const Text('Label, e.g. Set Name'),
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
              const Gap(16),

              Text('Notes', style: textTheme.small),
              const Gap(6),
              ShadInput(controller: _notesController, maxLines: 3),

              if (_error != null) ...[
                const Gap(16),
                Text(_error!, style: textTheme.small.copyWith(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
