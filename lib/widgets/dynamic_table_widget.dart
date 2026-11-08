import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/dynamic_report_models.dart';
import '../widgets/ds/ds.dart';

class DynamicTableWidget extends StatefulWidget {
  final DynamicReportField field;
  final dynamic initialValue;
  final Function(dynamic) onChanged;

  const DynamicTableWidget({
    super.key,
    required this.field,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<DynamicTableWidget> createState() => _DynamicTableWidgetState();
}

class _DynamicTableWidgetState extends State<DynamicTableWidget> {
  late DynamicTableConfig config;
  List<Map<String, dynamic>> tableRows = [];
  final ScrollController _horizontalScrollController = ScrollController();
  int _syncVersion = 0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DynamicTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newRaw = widget.initialValue?.toString() ?? '';
    final curRaw = jsonEncode(tableRows);
    if (newRaw.isNotEmpty && newRaw != curRaw) {
      try {
        final decoded = jsonDecode(newRaw);
        if (decoded is List) {
          setState(() {
            tableRows = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _syncVersion++;
          });
        }
      } catch (_) {}
    }
  }

  bool _isCorrectiveOrNotesCol(DynamicTableColumn col) {
    final k = col.key.toLowerCase();
    final t = col.title;
    return k.contains('corrective') ||
        k.contains('action') ||
        k.contains('note') ||
        t.contains('إجراء') ||
        t.contains('اجراء') ||
        t.contains('تصحيحي') ||
        t.contains('ملاحظات');
  }

  bool _isCellNonCompliant(DynamicTableColumn col, dynamic rawVal) {
    if (rawVal == null) return false;
    final val = rawVal.toString().trim();
    if (val.isEmpty) return false;

    final title = col.title;
    // الأعمدة التي يكون فيها "نعم" مؤشراً سلبياً (مثل وجود حشرات أو عيوب أو تسريب)
    final bool isDefectQuestion = title.contains('حشرات') ||
        title.contains('قوارض') ||
        title.contains('تسريب') ||
        title.contains('عيوب') ||
        title.contains('تلوث') ||
        title.contains('صدأ');

    if (isDefectQuestion) {
      return val == 'نعم' || val == 'يوجد' || val == 'غير مطابق' || val == 'مرفوض';
    }

    const negativeValues = {
      'لا',
      'غير مطابق',
      'مرفوض',
      'غير صالح',
      'غير نظيف',
      'غير ملتزم',
      'تالفة',
      'رديئة',
      'ملوثة',
    };
    return negativeValues.contains(val);
  }

  bool _isRowNonCompliant(Map<String, dynamic> rowData) {
    for (final col in config.columns) {
      if (_isCorrectiveOrNotesCol(col)) continue;
      if (_isCellNonCompliant(col, rowData[col.key])) {
        return true;
      }
    }
    return false;
  }

  bool _hasCorrectiveColumn() {
    return config.columns.any(_isCorrectiveOrNotesCol);
  }

  bool _isRowMissingCorrectiveAction(Map<String, dynamic> rowData) {
    if (!_isRowNonCompliant(rowData)) return false;
    final correctiveCols = config.columns.where(_isCorrectiveOrNotesCol).toList();
    if (correctiveCols.isEmpty) return false;
    for (final col in correctiveCols) {
      final v = rowData[col.key]?.toString().trim() ?? '';
      if (v.isNotEmpty && v != '-' && v != '—') {
        return false;
      }
    }
    return true;
  }

  void _scrollTable(double delta) {
    if (!_horizontalScrollController.hasClients) return;
    final target = (_horizontalScrollController.offset + delta)
        .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
    _horizontalScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    config = widget.field.tableConfig ?? DynamicTableConfig.inspectionChecklistTemplate();
    _initRows();
  }

  void _initRows() {
    if (widget.initialValue != null && widget.initialValue.toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.initialValue.toString());
        if (decoded is List) {
          tableRows = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return;
        }
      } catch (_) {}
    }

    // Initialize with default rows from config
    if (config.defaultRows.isNotEmpty) {
      tableRows = config.defaultRows.map((r) => Map<String, dynamic>.from(r)).toList();
    } else if (config.rowCount > 0) {
      tableRows = List.generate(config.rowCount, (_) => <String, dynamic>{});
    } else {
      tableRows = [{}];
    }
    // Notify initial state if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(jsonEncode(tableRows));
    });
  }

  void _notifyChange() {
    widget.onChanged(jsonEncode(tableRows));
  }

  void _addRow() {
    setState(() {
      tableRows.add({});
    });
    _notifyChange();
  }

  void _removeRow(int index) {
    setState(() {
      tableRows.removeAt(index);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final columns = config.columns;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppCard(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart_rounded,
                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.field.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                ),
                // أزرار سهمية للتمرير السريع للأعمدة يميناً ويساراً
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        tooltip: 'تمرير لليمين',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _scrollTable(-250),
                      ),
                      Container(width: 1, height: 16, color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        tooltip: 'تمرير لليسار',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _scrollTable(250),
                      ),
                    ],
                  ),
                ),
                if (config.allowAddRows)
                  AppButton.text(
                    label: 'إضافة بند',
                    icon: Icons.add_circle_outline,
                    onPressed: _addRow,
                  ),
              ],
            ),
            if (widget.field.hint != null && widget.field.hint!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.field.hint!,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: RawScrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 10,
                radius: const Radius.circular(5),
                thumbColor: isDark
                    ? AppColors.primaryLight.withValues(alpha: 0.65)
                    : AppColors.primaryDark.withValues(alpha: 0.75),
                trackColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                trackRadius: const Radius.circular(5),
                padding: const EdgeInsets.only(bottom: 2, top: 4),
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: columns.length > 5 ? 1250 : 650),
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 12,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 68,
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? AppColors.primaryMedium.withValues(alpha: 0.15)
                        : AppColors.primaryLightest.withValues(alpha: 0.45),
                  ),
                  border: TableBorder.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 0.8,
                  ),
                  columns: [
                    const DataColumn(
                      label: Text('#', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold)),
                    ),
                    ...columns.map((col) {
                      return DataColumn(
                        label: Text(
                          col.title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                          ),
                        ),
                      );
                    }),
                    if (config.allowAddRows)
                      const DataColumn(
                        label: Text('إجراء', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold)),
                      ),
                  ],
                  rows: List.generate(tableRows.length, (rowIndex) {
                    final rowData = tableRows[rowIndex];
                    final isColored = (rowIndex % 2 == 0);
                    final isNonCompliant = _isRowNonCompliant(rowData);
                    final isMissingCorrective = _isRowMissingCorrectiveAction(rowData);
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isMissingCorrective) {
                          return isDark
                              ? Colors.red.shade900.withValues(alpha: 0.25)
                              : const Color(0xFFFFEBEE);
                        }
                        if (isNonCompliant) {
                          return isDark
                              ? Colors.amber.shade900.withValues(alpha: 0.20)
                              : const Color(0xFFFFF8E1);
                        }
                        if (isColored) {
                          return isDark
                              ? const Color(0xFFD9E1F3).withValues(alpha: 0.22)
                              : const Color(0xFFD9E1F3);
                        }
                        return isDark ? Colors.transparent : Colors.white;
                      }),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${rowIndex + 1}', style: const TextStyle(fontFamily: AppTheme.fontFamily)),
                              if (isNonCompliant) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: isMissingCorrective
                                      ? 'يوجد عدم مطابقة في هذا الصف — يرجى توثيق الإجراء التصحيحي'
                                      : 'تم رصد عدم مطابقة وتوثيق الملاحظة/الإجراء التصحيحي',
                                  child: Icon(
                                    isMissingCorrective ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                    size: 15,
                                    color: isMissingCorrective ? Colors.red.shade700 : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ...columns.map((col) {
                          return DataCell(
                            _buildCell(col, rowData, rowIndex, isDark),
                          );
                        }),
                        if (config.allowAddRows)
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppButton.dangerColor, size: 20),
                              tooltip: 'حذف البند',
                              onPressed: () => _removeRow(rowIndex),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        _buildNonComplianceSummaryBanner(isDark),
        if (columns.length > 4) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_outlined, size: 14, color: isDark ? AppColors.darkMuted : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                'اسحب الشريط الأفقي بالماوس أو استخدم أزرار الأسهم بالأعلى للتنقل بين أعمدة الفحص',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  ),
);
  }

  Widget _buildCell(DynamicTableColumn col, Map<String, dynamic> rowData, int rowIndex, bool isDark) {
    final currentValue = rowData[col.key];

    // Check if column is inspector / المسؤول عن المراقبة (غير قابلة للإدخال اليدوي - تُملأ تلقائياً عند التوقيع)
    final bool isInspectorCol = col.type != 'signature' && (
      col.type == 'inspector' ||
      col.key == 'inspector' ||
      col.key.toLowerCase().contains('inspector') ||
      col.title.contains('المسؤول عن المراقبة')
    );

    if (isInspectorCol) {
      final String inspectorName = currentValue?.toString().trim() ?? '';
      final bool hasInspector = inspectorName.isNotEmpty &&
          inspectorName != '-' &&
          inspectorName != '—' &&
          inspectorName != 'null';

      return Tooltip(
        message: hasInspector
            ? 'المسؤول عن المراقبة: $inspectorName'
            : 'يتم تسجيل اسم المسؤول تلقائياً عند التوقيع',
        child: Container(
          width: 135,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasInspector
                ? (isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : Colors.grey.shade100)
                : (isDark ? Colors.black12 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasInspector
                  ? (isDark ? AppColors.darkBorder : Colors.grey.shade400)
                  : (isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : Colors.grey.shade300),
              width: 0.8,
            ),
          ),
          child: Text(
            hasInspector ? inspectorName : '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: hasInspector ? FontWeight.bold : FontWeight.normal,
              color: hasInspector
                  ? (isDark ? AppColors.darkInk : AppColors.ink)
                  : (isDark ? AppColors.darkMuted : Colors.grey.shade400),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      );
    }

    switch (col.type) {
      case 'dropdown':
      case 'select':
        final options = col.options;
        String? currentVal = currentValue?.toString();
        if (currentVal != null && !options.contains(currentVal)) {
          currentVal = null;
        }
        return Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<String>(
            isDense: true,
            isExpanded: true,
            initialValue: currentVal,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              hintText: 'اختر...',
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: isDark ? AppColors.darkMuted : Colors.grey,
              ),
            ),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
            items: options.map((opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(
                  opt,
                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                rowData[col.key] = val;
              });
              _notifyChange();
            },
          ),
        );

      case 'label':
        return Container(
          constraints: const BoxConstraints(maxWidth: 160),
          alignment: Alignment.centerRight,
          child: Text(
            currentValue?.toString() ?? '',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );

      case 'radio':
      case 'yes_no':
      case 'match':
        final List<String> options;
        if (col.type == 'yes_no') {
          options = col.options.isNotEmpty ? col.options : ['نعم', 'لا'];
        } else if (col.type == 'match') {
          options = col.options.isNotEmpty ? col.options : ['مطابق', 'غير مطابق'];
        } else {
          options = col.options.isNotEmpty ? col.options : ['نعم', 'لا'];
        }

        return Container(
          constraints: BoxConstraints(maxWidth: options.length == 2 ? 140 : 200),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.map((option) {
                final isSelected = currentValue?.toString() == option;
                final isPositive = option == 'مطابق' || option == 'نعم';
                final activeColor = isPositive ? AppColors.success : AppButton.dangerColor;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        rowData[col.key] = isSelected ? null : option;
                      });
                      _notifyChange();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor
                            : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : (isDark ? AppColors.darkBorder : Colors.grey.shade400),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? (isPositive ? Icons.check_circle : Icons.cancel)
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkMuted : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            option,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.darkInk : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );

      case 'checkbox':
        final isChecked = currentValue == true || currentValue == 'true';
        return Checkbox(
          value: isChecked,
          onChanged: (val) {
            setState(() {
              rowData[col.key] = val;
            });
            _notifyChange();
          },
        );

      case 'date':
        final dateValue = currentValue?.toString() ?? '';
        return Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () async {
              DateTime? initialDate;
              if (dateValue.isNotEmpty) {
                try {
                  initialDate = DateFormat('dd/MM/yyyy').parse(dateValue);
                } catch (_) {
                  initialDate = null;
                }
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (picked != null) {
                setState(() {
                  rowData[col.key] = DateFormat('dd/MM/yyyy').format(picked);
                });
                _notifyChange();
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: 'يوم/شهر/سنة',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                ),
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                ),
              ),
              child: Text(
                dateValue,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: dateValue.isNotEmpty
                      ? (isDark ? AppColors.darkInk : Colors.black87)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        );

      case 'time':
        final timeValue = currentValue?.toString() ?? '';
        return Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () async {
              TimeOfDay? initialTime;
              if (timeValue.isNotEmpty) {
                try {
                  final parsed = DateFormat('HH:mm').parse(timeValue);
                  initialTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
                } catch (_) {
                  initialTime = null;
                }
              }
              final picked = await showTimePicker(
                context: context,
                initialTime: initialTime ?? TimeOfDay.now(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null) {
                final now = DateTime.now();
                final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                setState(() {
                  rowData[col.key] = DateFormat('HH:mm').format(dt);
                });
                _notifyChange();
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: 'ساعة:دقيقة',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                ),
                suffixIcon: Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                ),
              ),
              child: Text(
                timeValue,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: timeValue.isNotEmpty
                      ? (isDark ? AppColors.darkInk : Colors.black87)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        );

      case 'signature':
        final sigValue = currentValue?.toString() ?? '';
        final bool isSigned = sigValue.isNotEmpty && (sigValue.contains('معتمد') || sigValue.contains('✓'));

        return Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () {
              final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
              String currentUserName = session?.currentUser.value?.fullName.trim() ?? '';
              if (currentUserName.isEmpty || currentUserName.toLowerCase().contains('current_user')) {
                currentUserName = session?.currentUserName.value.trim() ?? 'المراقب';
              }
              if (currentUserName.isEmpty || currentUserName.toLowerCase().contains('current_user')) {
                currentUserName = 'المراقب';
              }

              // تحديد مفتاح عمود المسؤول عن المراقبة في الجدول لربطه آلياً بالتوقيع
              final inspectorCol = config.columns.cast<DynamicTableColumn?>().firstWhere(
                (c) => c != null && (c.key == 'inspector' || c.key.toLowerCase().contains('inspector') || c.title.contains('المسؤول عن المراقبة')),
                orElse: () => null,
              );
              final inspectorKey = inspectorCol?.key ?? 'inspector';

              setState(() {
                if (isSigned) {
                  rowData[col.key] = null;
                  rowData[inspectorKey] = null;
                } else {
                  rowData[col.key] = 'معتمد ($currentUserName)';
                  rowData[inspectorKey] = currentUserName;
                }
              });
              _notifyChange();
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isSigned
                    ? (isDark ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade50)
                    : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSigned
                      ? Colors.green.shade600
                      : (isDark ? AppColors.darkBorder : Colors.grey.shade400),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSigned ? Icons.verified : Icons.draw,
                    size: 14,
                    color: isSigned ? Colors.green.shade700 : (isDark ? AppColors.darkMuted : Colors.grey.shade700),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isSigned ? 'تم التوقيع ✓' : 'توقيع ✍️',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: isSigned ? FontWeight.bold : FontWeight.normal,
                        color: isSigned ? Colors.green.shade800 : (isDark ? AppColors.darkInk : Colors.black87),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case 'number':
      case 'decimal':
      case 'text':
      default:
        final bool isLongText = col.key == 'corrective_action' || col.key == 'notes' || _isCorrectiveOrNotesCol(col);
        final double fieldWidth = isLongText ? 220 : (col.key == 'employee' ? 140 : 100);
        final bool isCorrectiveNeeded = _isCorrectiveOrNotesCol(col) && _isRowMissingCorrectiveAction(rowData);
        return Container(
          width: fieldWidth,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            key: ValueKey('cell_${_syncVersion}_${rowIndex}_${col.key}'),
            initialValue: currentValue?.toString() ?? '',
            keyboardType: col.type == 'decimal'
                ? const TextInputType.numberWithOptions(decimal: true)
                : (col.type == 'number' ? TextInputType.number : TextInputType.text),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: isCorrectiveNeeded,
              fillColor: isCorrectiveNeeded
                  ? (isDark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50)
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              hintText: isCorrectiveNeeded ? '⚠️ وثّق الإجراء التصحيحي...' : col.title,
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: isCorrectiveNeeded ? FontWeight.bold : FontWeight.normal,
                color: isCorrectiveNeeded
                    ? Colors.red.shade700
                    : (isDark ? AppColors.darkMuted : Colors.grey),
              ),
              enabledBorder: isCorrectiveNeeded
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
                    )
                  : null,
            ),
            onChanged: (val) {
              final wasMissing = _isRowMissingCorrectiveAction(rowData);
              rowData[col.key] = val;
              final nowMissing = _isRowMissingCorrectiveAction(rowData);
              if (wasMissing != nowMissing) {
                setState(() {});
              }
              _notifyChange();
            },
          ),
        );
    }
  }

  Widget _buildNonComplianceSummaryBanner(bool isDark) {
    int nonCompliantCount = 0;
    int missingCorrectiveCount = 0;
    for (final row in tableRows) {
      if (_isRowNonCompliant(row)) {
        nonCompliantCount++;
        if (_isRowMissingCorrectiveAction(row)) {
          missingCorrectiveCount++;
        }
      }
    }

    if (nonCompliantCount == 0) return const SizedBox.shrink();

    final bool hasMissing = missingCorrectiveCount > 0 && _hasCorrectiveColumn();
    final Color bannerColor = hasMissing ? Colors.red.shade700 : Colors.amber.shade800;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            hasMissing ? Icons.warning_amber_rounded : Icons.fact_check_rounded,
            size: 18,
            color: bannerColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasMissing
                  ? 'تنبيه رقابة الجودة: تم رصد ($nonCompliantCount) بند غير مطابق، منها ($missingCorrectiveCount) بند بدون توثيق إجراء تصحيحي أو ملاحظة.'
                  : 'مؤشر رقابة الجودة: تم رصد ($nonCompliantCount) بند غير مطابق وتم توثيق الإجراءات التصحيحية/الملاحظات المرتبطة بها.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : bannerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
