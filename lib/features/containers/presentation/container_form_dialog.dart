import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:gap/gap.dart';

import '../data/container_repository.dart';
import '../domain/storage_container.dart';

const containerColorPalette = <String>[
  '#EF4444', // red
  '#F97316', // orange
  '#F59E0B', // amber
  '#22C55E', // green
  '#14B8A6', // teal
  '#3B82F6', // blue
  '#6366F1', // indigo
  '#A855F7', // purple
  '#EC4899', // pink
  '#6B7280', // grey
];

Future<void> showContainerFormDialog(
  BuildContext context,
  WidgetRef ref, {
  StorageContainer? existing,
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final capacityController = TextEditingController(text: (existing?.capacity ?? 360).toString());
  final locationController = TextEditingController(text: existing?.location ?? '');
  ContainerType type = existing?.type ?? ContainerType.binder;
  String? colorHex = existing?.colorHex;
  bool isSaving = false;
  String? error;

  return showShadDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => ShadDialog(
        title: Text(existing == null ? 'New Container' : 'Edit Container'),
        actions: [
          ShadButton.outline(
            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: isSaving
                ? null
                : () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setState(() => error = 'Container name is required.');
                      return;
                    }
                    setState(() {
                      isSaving = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(containerRepositoryProvider);
                      final capacity = int.tryParse(capacityController.text.trim());
                      final location =
                          locationController.text.trim().isEmpty ? null : locationController.text.trim();
                      if (existing == null) {
                        await repo.addContainer(
                          name: name,
                          type: type,
                          capacity: capacity,
                          colorHex: colorHex,
                          location: location,
                        );
                      } else {
                        await repo.updateContainer(
                          existing.id,
                          name: name,
                          type: type,
                          capacity: capacity,
                          colorHex: colorHex,
                          location: location,
                        );
                      }
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    } catch (e) {
                      setState(() {
                        isSaving = false;
                        error = 'Could not save container: $e';
                      });
                    }
                  },
            child: Text(isSaving ? 'Saving...' : (existing == null ? 'Create' : 'Save')),
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
              ShadInput(controller: nameController, placeholder: const Text('Binder 1 — Vintage')),
              const Gap(12),
              const Text('Type'),
              const Gap(6),
              ShadSelect<ContainerType>(
                initialValue: type,
                options: [
                  for (final t in ContainerType.values) ShadOption(value: t, child: Text(t.label)),
                ],
                selectedOptionBuilder: (context, value) => Text(value.label),
                onChanged: (val) {
                  if (val != null) setState(() => type = val);
                },
              ),
              const Gap(12),
              const Text('Capacity (slots)'),
              const Gap(6),
              ShadInput(controller: capacityController, keyboardType: TextInputType.number),
              const Gap(12),
              const Text('Location'),
              const Gap(6),
              ShadInput(controller: locationController, placeholder: const Text('Bedroom shelf')),
              const Gap(12),
              const Text('Color'),
              const Gap(8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in containerColorPalette)
                    GestureDetector(
                      onTap: () => setState(() => colorHex = hex),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(int.parse(hex.replaceFirst('#', '0xff'))),
                          shape: BoxShape.circle,
                          border: colorHex == hex
                              ? Border.all(color: ShadTheme.of(context).colorScheme.foreground, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              if (error != null) ...[
                const Gap(12),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
