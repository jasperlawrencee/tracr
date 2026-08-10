import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A consistent search input used at the top of each module page
/// (Wishlist/Stash/Tracking/In Hand) to filter its own list in place.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;

  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return ShadInput(
      controller: controller,
      placeholder: Text(placeholder),
      onChanged: onChanged,
      leading: const Padding(
        padding: EdgeInsets.only(left: 4, right: 6),
        child: Icon(Icons.search, size: 16),
      ),
      trailing: controller.text.isEmpty
          ? null
          : ShadIconButton.ghost(
              icon: const Icon(Icons.close, size: 14),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
    );
  }
}
