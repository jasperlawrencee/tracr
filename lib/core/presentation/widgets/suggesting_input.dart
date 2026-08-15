import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SuggestingInput extends StatefulWidget {
  final TextEditingController controller;

  final List<String> suggestions;

  final Widget? placeholder;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  final bool commaSeparated;

  final int maxSuggestions;

  final ValueChanged<String>? onSelected;

  final ValueChanged<String>? onChanged;

  const SuggestingInput({
    super.key,
    required this.controller,
    required this.suggestions,
    this.placeholder,
    this.keyboardType,
    this.inputFormatters,
    this.commaSeparated = false,
    this.maxSuggestions = 6,
    this.onSelected,
    this.onChanged,
  });

  @override
  State<SuggestingInput> createState() => _SuggestingInputState();
}

class _SuggestingInputState extends State<SuggestingInput> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  final _focusNode = FocusNode();

  final Object _tapGroupId = Object();

  bool _pressingPanel = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Focusing an empty field offers the full list, like a dropdown of values
    // used before.
    if (_focusNode.hasFocus) {
      _sync();
    } else if (!_pressingPanel) {
      _overlay.hide();
    }
  }

  List<String> _committedTokens() {
    final parts = widget.controller.text.split(',');
    return parts
        .take(parts.length - 1)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _query() {
    final text = widget.controller.text;
    if (!widget.commaSeparated) return text.trim();
    final comma = text.lastIndexOf(',');
    return (comma == -1 ? text : text.substring(comma + 1)).trim();
  }

  List<String> _matches() {
    final query = _query().toLowerCase();
    final taken = widget.commaSeparated
        ? _committedTokens().map((t) => t.toLowerCase()).toSet()
        : const <String>{};

    final seen = <String>{};
    final prefix = <String>[];
    final substring = <String>[];

    for (final suggestion in widget.suggestions) {
      final lower = suggestion.toLowerCase();
      if (taken.contains(lower)) continue;
      if (!seen.add(lower)) continue;
      if (query.isEmpty) {
        prefix.add(suggestion);
      } else if (lower == query) {
        continue; // Already typed in full; nothing left to complete.
      } else if (lower.startsWith(query)) {
        prefix.add(suggestion);
      } else if (lower.contains(query)) {
        substring.add(suggestion);
      }
    }

    return [...prefix, ...substring].take(widget.maxSuggestions).toList();
  }

  void _sync() {
    setState(() {});
    if (_matches().isEmpty || !_focusNode.hasFocus) {
      _overlay.hide();
    } else {
      _overlay.show();
    }
  }

  void _select(String value) {
    if (widget.commaSeparated) {
      final tokens = [..._committedTokens(), value];
      widget.controller.text = '${tokens.join(', ')}, ';
    } else {
      widget.controller.text = value;
    }
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onSelected?.call(value);

    // Put the caret back in case the press moved focus, so typing can carry on
    // straight after picking a value.
    _focusNode.requestFocus();

    // A tags field usually takes several values in a row, so it stays open.
    if (widget.commaSeparated) {
      _sync();
    } else {
      setState(() {});
      _overlay.hide();
    }
  }

  Widget _panel(BuildContext context, double? width) {
    final theme = ShadTheme.of(context);

    return TapRegion(
      groupId: _tapGroupId,
      child: Listener(
        onPointerDown: (_) => _pressingPanel = true,
        onPointerUp: (_) => _pressingPanel = false,
        onPointerCancel: (_) => _pressingPanel = false,
        // Rows must not take focus: a focusable row would blur the field on
        // press, which used to close the panel before the click landed.
        child: Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          descendantsAreTraversable: false,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.popover,
                  borderRadius: theme.radius,
                  border: Border.all(color: theme.colorScheme.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final match in _matches())
                          ShadButton.ghost(
                            width: double.infinity,
                            size: ShadButtonSize.sm,
                            canRequestFocus: false,
                            mainAxisAlignment: MainAxisAlignment.start,
                            onPressed: () => _select(match),
                            child: Text(match, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : null;

        return TapRegion(
          groupId: _tapGroupId,
          onTapOutside: (_) => _overlay.hide(),
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _overlay,
              overlayChildBuilder: (context) => CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 4),
                child: _panel(context, width),
              ),
              child: ShadInput(
                controller: widget.controller,
                focusNode: _focusNode,
                placeholder: widget.placeholder,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                onChanged: (value) {
                  _sync();
                  widget.onChanged?.call(value);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
