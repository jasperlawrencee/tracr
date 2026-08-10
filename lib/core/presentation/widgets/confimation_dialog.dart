import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ConfirmActionStyle { primary, destructive }

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final ConfirmActionStyle style;
  final Future<void> Function() onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.style = ConfirmActionStyle.primary,
  });

  /// Helper static method to show the dialog with clean syntax
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required Future<void> Function() onConfirm,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    ConfirmActionStyle style = ConfirmActionStyle.primary,
  }) {
    return showShadDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        style: style,
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          await onConfirm();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: Text(title),
      description: Text(description),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
        if (style == ConfirmActionStyle.destructive)
          ShadButton.destructive(
            onPressed: onConfirm,
            child: Text(confirmLabel),
          )
        else
          ShadButton(
            onPressed: onConfirm,
            child: Text(confirmLabel),
          ),
      ],
    );
  }
}