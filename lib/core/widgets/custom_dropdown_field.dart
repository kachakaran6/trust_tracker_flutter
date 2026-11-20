import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';

class CustomDropdownField<T> extends StatelessWidget {
  final T value;
  final String label;
  final IconData prefixIcon;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onChanged;
  final String Function(T) itemLabelBuilder;

  const CustomDropdownField({
    super.key,
    required this.value,
    required this.label,
    required this.prefixIcon,
    required this.items,
    required this.onChanged,
    required this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.rMd),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          elevation: 4,
        ),
      ),
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onChanged,
        offset: const Offset(0, 56),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
        position: PopupMenuPosition.over,
        clipBehavior: Clip.antiAlias,
        itemBuilder: (context) => items,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(prefixIcon, size: 20),
            suffixIcon: const Icon(LucideIcons.chevronsUpDown, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.rMd),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.rMd),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Text(
            itemLabelBuilder(value),
            style: tt.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class CustomDropdownItem<T> extends PopupMenuEntry<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CustomDropdownItem({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  @override
  double get height => 48.0;

  @override
  bool represents(T? value) => this.value == value;

  @override
  State<CustomDropdownItem<T>> createState() => _CustomDropdownItemState<T>();
}

class _CustomDropdownItemState<T> extends State<CustomDropdownItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isSelected = PopupMenuTheme.of(context).textStyle?.color == Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => Navigator.of(context).pop(widget.value),
      onHover: (hovered) => setState(() => _isHovered = hovered),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: Colors.white70),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                widget.label,
                style: tt.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
