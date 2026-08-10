import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A `ShadCard`-styled box built from a plain [Container] instead of
/// [ShadCard] itself.
///
/// [ShadCard] silently wraps whatever you pass as `child` inside its own
/// `Row(mainAxisSize: min) > Flexible > Column(mainAxisSize: min) >
/// Flexible` chain. That collides with any content that has its own `Row`
/// containing an `Expanded`/`Flexible`, throwing "RenderFlex received
/// unbounded constraints" — first hit on the In Hand container list. Use
/// this instead for any card whose content has that shape; same background,
/// border, and radius as a themed [ShadCard], without the internal
/// flex-in-flex conflict.
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
