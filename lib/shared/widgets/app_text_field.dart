import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import 'pressable.dart';

/// Labelled text field: the label sits above the box (always visible, never a floating placeholder), inputs are 16 px so
/// iOS never zooms, errors appear below in text (not colour alone), and passwords get a show/hide toggle with a 44 px target.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.obscure = false,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.optional = false,
    this.readOnly = false,
    this.onTap,
    this.showCounter = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// A server-side error (e.g. a field error from the API). Client-side [validator] errors are shown too.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool obscure;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final bool optional;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool showCounter;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final isPassword = widget.obscure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              text: widget.label,
              style: t.labelMedium?.copyWith(color: c.foreground),
              children: [if (widget.optional) TextSpan(text: '  Optional', style: t.bodySmall)],
            ),
          ),
        ),
        Semantics(
          label: widget.label,
          textField: true,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            autofocus: widget.autofocus,
            obscureText: _hidden,
            enableSuggestions: !isPassword,
            autocorrect: !isPassword && widget.keyboardType != TextInputType.emailAddress,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLines: isPassword ? 1 : widget.maxLines,
            minLines: widget.minLines,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: t.bodyLarge, // 16 px: iOS does not zoom the field on focus
            cursorColor: c.primary,
            buildCounter: widget.showCounter
                ? null
                : (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              helperMaxLines: 3,
              errorText: widget.errorText,
              errorMaxLines: 3,
              prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20, color: c.mutedForeground),
              prefixText: widget.prefixText,
              prefixStyle: t.bodyLarge,
              suffixIcon: isPassword
                  ? Pressable(
                      onTap: () => setState(() => _hidden = !_hidden),
                      semanticLabel: _hidden ? 'Show password' : 'Hide password',
                      minSize: const Size(kMinTap, kMinTap),
                      scale: 0.9,
                      child: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: c.mutedForeground),
                    )
                  : widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}
