import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';

final categoryDropdownOptionsProvider =
    StreamProvider.autoDispose.family<List<CategoryModel>, CategoryType>(
  (ref, type) {
    return ref.watch(categoryRepositoryProvider).watchByType(type);
  },
);

class TransactionCategoryDropdown extends ConsumerStatefulWidget {
  const TransactionCategoryDropdown({
    super.key,
    required this.type,
    required this.selected,
    required this.onSelect,
    this.preselectedId,
    this.autoSelectFirst = false,
    this.hintText = 'Search or choose a category',
  });

  final CategoryType type;
  final CategoryModel? selected;
  final int? preselectedId;
  final ValueChanged<CategoryModel> onSelect;
  final bool autoSelectFirst;
  final String hintText;

  @override
  ConsumerState<TransactionCategoryDropdown> createState() =>
      _TransactionCategoryDropdownState();
}

class _TransactionCategoryDropdownState
    extends ConsumerState<TransactionCategoryDropdown> {
  static const int _addCategoryValue = -1;

  final TextEditingController _controller = TextEditingController();
  CategoryType? _lastAutoSelectedType;
  bool _resolvedPreselection = false;

  @override
  void didUpdateWidget(covariant TransactionCategoryDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _resolvedPreselection = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync =
        ref.watch(categoryDropdownOptionsProvider(widget.type));
    final cs = Theme.of(context).colorScheme;
    final accentColor = _AddCategoryDialog._accentColorForType(widget.type);

    return categoriesAsync.when(
      data: (categories) {
        _resolvePreselection(categories);
        _autoSelectFirst(categories);
        // Syncing controller in post-frame to avoid side-effects during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncControllerText(_labelForSelection(categories));
        });

        final entries = <DropdownMenuEntry<int>>[
          for (final category in categories)
            DropdownMenuEntry<int>(
              value: category.id,
              label: category.name,
              leadingIcon:
                  _CategoryDot(color: Color(category.colorHex.toColorInt())),
            ),
          DropdownMenuEntry<int>(
            value: _addCategoryValue,
            label: 'Add New Category',
            leadingIcon: Icon(
              Icons.add_circle_outline_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<int>(
              key: ValueKey('category-${widget.type.name}'),
              width: constraints.maxWidth,
              controller: _controller,
              initialSelection: widget.selected?.id ?? widget.preselectedId,
              enableFilter: true,
              enableSearch: true,
              filterCallback: (entries, filter) {
                final normalized = filter.trim().toLowerCase();
                if (normalized.isEmpty) {
                  return entries;
                }

                return entries.where((entry) {
                  return entry.value == _addCategoryValue ||
                      entry.label.toLowerCase().contains(normalized);
                }).toList();
              },
              requestFocusOnTap: false,
              menuHeight: 320,
              hintText: widget.hintText,
              textStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor.withOpacity(0.7)),
                ),
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.45),
                ),
              ),
              onSelected: (value) => _handleSelection(
                context: context,
                value: value,
                categories: categories,
              ),
              dropdownMenuEntries: entries,
            );
          },
        );
      },
      loading: () => SizedBox(
        height: 56,
        child: Center(
          child: LinearProgressIndicator(
            minHeight: 3,
            color: accentColor,
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Unable to load categories right now.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onErrorContainer,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSelection({
    required BuildContext context,
    required int? value,
    required List<CategoryModel> categories,
  }) async {
    if (value == null) {
      return;
    }

    if (value == _addCategoryValue) {
      final previousLabel = _labelForSelection(categories);
      final createdCategory = await _showCreateCategoryDialog(
        context,
        initialType: widget.type,
      );

      if (!mounted) {
        return;
      }

      if (createdCategory != null) {
        _syncControllerText(createdCategory.name);
        widget.onSelect(createdCategory);
      } else {
        _syncControllerText(previousLabel);
      }
      return;
    }

    final category = _findCategoryById(categories, value);
    if (category == null) {
      return;
    }

    _syncControllerText(category.name);
    widget.onSelect(category);
  }

  void _resolvePreselection(List<CategoryModel> categories) {
    if (_resolvedPreselection ||
        widget.selected != null ||
        widget.preselectedId == null) {
      return;
    }

    final category = _findCategoryById(categories, widget.preselectedId!);
    if (category == null) {
      return;
    }

    _resolvedPreselection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSelect(category);
    });
  }

  void _autoSelectFirst(List<CategoryModel> categories) {
    if (!widget.autoSelectFirst ||
        widget.selected != null ||
        widget.preselectedId != null ||
        categories.isEmpty ||
        _lastAutoSelectedType == widget.type) {
      return;
    }

    _lastAutoSelectedType = widget.type;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSelect(categories.first);
    });
  }

  String _labelForSelection(List<CategoryModel> categories) {
    if (widget.selected != null) {
      return widget.selected!.name;
    }

    if (widget.preselectedId == null) {
      return '';
    }

    return _findCategoryById(categories, widget.preselectedId!)?.name ?? '';
  }

  CategoryModel? _findCategoryById(List<CategoryModel> categories, int id) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  void _syncControllerText(String label) {
    if (_controller.text == label) {
      return;
    }

    _controller.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
  }

  Future<CategoryModel?> _showCreateCategoryDialog(
    BuildContext context, {
    required CategoryType initialType,
  }) {
    return showDialog<CategoryModel>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal during save
      builder: (dialogContext) => _AddCategoryDialog(
        initialType: initialType,
        ref: ref,
      ),
    );
  }
}

// ── Add Category Dialog ──────────────────────────────────────────────────────

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({
    required this.initialType,
    required this.ref,
  });

  final CategoryType initialType;
  final WidgetRef ref;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();

  static Color _accentColorForType(CategoryType type) {
    return type == CategoryType.income
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
  }

  static String _typeLabel(CategoryType type) {
    return type == CategoryType.income ? 'Income' : 'Expense';
  }

  static String _nextColorForType(CategoryType type, int seed) {
    const incomePalette = [
      '#10B981',
      '#3B82F6',
      '#14B8A6',
      '#8B5CF6',
    ];
    const expensePalette = [
      '#F97316',
      '#EF4444',
      '#EC4899',
      '#06B6D4',
      '#F59E0B',
      '#6366F1',
    ];

    final palette =
        type == CategoryType.income ? incomePalette : expensePalette;
    if (seed < 0) {
      return AppConstants.categoryColors.first;
    }
    return palette[seed % palette.length];
  }
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  late CategoryType _selectedType;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorText = 'Enter a category name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final repo = widget.ref.read(categoryRepositoryProvider);
      final existingCategories = await repo.getByType(_selectedType);
      
      final duplicateExists = existingCategories.any(
        (category) =>
            category.name.trim().toLowerCase() == trimmedName.toLowerCase(),
      );

      if (duplicateExists) {
        setState(() {
          _isSaving = false;
          _errorText =
              'A ${_AddCategoryDialog._typeLabel(_selectedType).toLowerCase()} category with this name already exists.';
        });
        return;
      }

      final createdCategory = CategoryModel.create(
        name: trimmedName,
        colorHex: _AddCategoryDialog._nextColorForType(
          _selectedType,
          existingCategories.length,
        ),
        iconName: 'category',
        type: _selectedType,
      );

      final id = await repo.add(createdCategory);
      createdCategory.id = id;

      if (!mounted) return;
      Navigator.of(context).pop(createdCategory);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'An error occurred while saving.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Add New Category',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _isSaving ? null : _saveCategory(),
              decoration: InputDecoration(
                hintText: 'Category name',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Type',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: CategoryType.values.map((type) {
                final isSelected = _selectedType == type;
                final typeAccent = _AddCategoryDialog._accentColorForType(type);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: type == CategoryType.income ? 8 : 0,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          _errorText = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? typeAccent
                              : cs.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? typeAccent
                                : cs.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _AddCategoryDialog._typeLabel(type),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _CategoryDot(
                    color: Color(
                      _AddCategoryDialog._nextColorForType(
                        _selectedType,
                        0,
                      ).toColorInt(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A matching color will be assigned automatically. You can refine it later from Categories.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withOpacity(0.68),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveCategory,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Category'),
        ),
      ],
    );
  }

  }

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
