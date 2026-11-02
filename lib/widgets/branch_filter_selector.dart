import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';

/// Widget اختيار المصنع — يظهر فقط للأدوار العليا (Admin / GM / QM غير المقيد)
/// يُضاف في AppBar أو في أعلى أي شاشة تحتاج فلترة بالمصنع
class BranchFilterSelector extends StatelessWidget {
  /// callback اختياري يُستدعى عند تغيير المصنع المختار
  final VoidCallback? onChanged;
  final bool compact;

  const BranchFilterSelector({super.key, this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionService.to;
    if (!session.canFilterByBranch) return const SizedBox.shrink();

    return Obx(() {
      final selected = session.activeBranchFilter.value;
      if (compact) return _buildCompact(context, session, selected);
      return _buildFull(context, session, selected);
    });
  }

  Widget _buildFull(BuildContext context, UserSessionService session, int? selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.factory_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'المصنع:',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Tajawal',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _buildDropdown(context, session, selected, isCompact: false),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, UserSessionService session, int? selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: _buildDropdown(context, session, selected, isCompact: true),
    );
  }

  Widget _buildDropdown(BuildContext context, UserSessionService session, int? selected, {required bool isCompact}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: selected,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 18,
          color: isCompact ? Colors.white : Theme.of(context).colorScheme.primary,
        ),
        selectedItemBuilder: isCompact
            ? (BuildContext context) {
                return [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.all_inclusive, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'الكل',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  ...UserSessionService.availableBranches.map((b) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.factory_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            b['name'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )),
                ];
              }
            : null,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w600,
          color: isCompact ? Colors.white : Theme.of(context).colorScheme.primary,
        ),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.all_inclusive, size: 14,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'كل المصانع',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...UserSessionService.availableBranches.map((b) => DropdownMenuItem<int?>(
            value: b['id'] as int,
            child: Row(
              children: [
                Icon(Icons.factory_rounded, size: 14,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  b['name'] as String,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          )),
        ],
        onChanged: (val) {
          session.setActiveBranchFilter(val);
          onChanged?.call();
        },
      ),
    );
  }
}
