import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const CardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.card,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: child,
    );
  }
}
