import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/packages_management_controller.dart';
import '../models/production_models.dart';
import '../widgets/ds/ds.dart';

class PackagesManagementView extends StatelessWidget {
  const PackagesManagementView({super.key});

  static const Map<int, ({String title, Color color, IconData icon})> _branches = {
    1: (title: 'مصنع أرتل', color: Color(0xFF007791), icon: Icons.factory_rounded),
    2: (title: 'مصنع سنحان', color: Color(0xFF8E24AA), icon: Icons.domain_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PackagesManagementController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('إدارة العبوات والمصانع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              tooltip: 'إضافة عبوة جديدة',
              onPressed: () => _showProductDialog(context, controller),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل قائمة العبوات...');
          }
          final items = controller.packages;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'لا توجد عبوات بعد',
                      message: 'أضف عبوة جديدة واربطها بأحد المصانع لبدء الفحوصات',
                    ),
                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: 'إضافة أول عبوة',
                      icon: Icons.add_rounded,
                      onPressed: () => _showProductDialog(context, controller),
                    ),
                  ],
                ),
              ),
            );
          }

          // تجميع العبوات حسب المصنع
          final grouped = <int, List<Product>>{};
          for (final p in items) {
            grouped.putIfAbsent(p.branchId, () => []).add(p);
          }
          final branchIds = grouped.keys.toList()..sort();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: branchIds.length,
                itemBuilder: (ctx, i) {
                  final bId = branchIds[i];
                  final branch = _branches[bId];
                  final branchItems = grouped[bId]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i > 0) const SizedBox(height: 24),
                      AppCard(
                        padding: EdgeInsets.zero,
                        borderColor: (branch?.color ?? Colors.blue).withValues(alpha: 0.25),
                        borderWidth: 1.2,
                        child: Column(
                          children: [
                            // رأس بطاقة المصنع الأنيق
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: (branch?.color ?? Colors.blue).withValues(alpha: 0.08),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                border: Border(
                                  bottom: BorderSide(
                                    color: (branch?.color ?? Colors.blue).withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (branch?.color ?? Colors.blue),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      branch?.icon ?? Icons.factory_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branch?.title ?? 'فرع $bId',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: isDark ? Colors.white : (branch?.color ?? AppColors.ink),
                                          ),
                                        ),
                                        Text(
                                          '${branchItems.where((p) => p.isActive).length} نشطة من أصل ${branchItems.length} عبوة',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showProductDialog(context, controller, branchId: bId),
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text(
                                      'إضافة عبوة',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (branch?.color ?? Colors.blue),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // قائمة العبوات التابعة للمصنع
                            for (int j = 0; j < branchItems.length; j++) ...[
                              if (j > 0)
                                Divider(
                                  height: 1,
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                  indent: 12,
                                  endIndent: 12,
                                ),
                              _buildProductTile(context, controller, branchItems[j], branch?.color ?? Colors.blue),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showProductDialog(context, controller),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('عبوة جديدة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildProductTile(
    BuildContext context,
    PackagesManagementController controller,
    Product product,
    Color branchColor,
  ) {
    return Obx(() {
      final current = controller.packages.firstWhereOrNull((p) => p.id == product.id) ?? product;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < mobileWidth;

          if (isMobile) {
            // تصميم متجاوب مريح للهواتف الذكية يمنع تزاحم النصوص
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصف الأول: الأيقونة + الاسم والحجم + زر التفعيل
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: current.isActive
                              ? branchColor.withValues(alpha: 0.12)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.water_drop_rounded,
                          color: current.isActive ? branchColor : Colors.grey.shade500,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    current.name,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: current.isActive
                                          ? (isDark ? Colors.white : AppColors.ink)
                                          : Colors.grey.shade500,
                                      decoration: current.isActive
                                          ? TextDecoration.none
                                          : TextDecoration.lineThrough,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: current.volumeLiters >= 1
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.teal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: current.volumeLiters >= 1
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.teal.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    current.volumeLabel,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: current.volumeLiters >= 1
                                          ? Colors.blue.shade700
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: current.isActive ? Colors.green.shade600 : Colors.grey.shade500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  current.isActive ? 'مرتبطة بـ ${current.branchName} • نشطة' : 'مرتبطة بـ ${current.branchName} • معطّلة',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.82,
                        child: Switch.adaptive(
                          value: current.isActive,
                          activeThumbColor: branchColor,
                          onChanged: (_) => controller.toggleActive(current),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // الصف الثاني: أزرار التعديل والحذف بشكل جانبي نظيف
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _showProductDialog(context, controller, product: current),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.blue.shade300 : const Color(0xFF007791)),
                              const SizedBox(width: 4),
                              Text(
                                'تعديل',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.blue.shade300 : const Color(0xFF007791),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _confirmDelete(context, controller, current),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'حذف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          // تصميم الأجهزة اللوحية والآيباد والشاشات العريضة
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: current.isActive
                        ? branchColor.withValues(alpha: 0.12)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: current.isActive ? branchColor : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              current.name,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: current.isActive
                                    ? (isDark ? Colors.white : AppColors.ink)
                                    : Colors.grey.shade500,
                                decoration: current.isActive
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: current.volumeLiters >= 1
                                  ? Colors.blue.withValues(alpha: 0.12)
                                  : Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: current.volumeLiters >= 1
                                    ? Colors.blue.withValues(alpha: 0.3)
                                    : Colors.teal.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              current.volumeLabel,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: current.volumeLiters >= 1
                                    ? Colors.blue.shade700
                                    : Colors.teal.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: current.isActive ? Colors.green.shade600 : Colors.grey.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            current.isActive
                                ? 'مرتبطة بـ ${current.branchName} • نشطة ومتاحة للفحوصات'
                                : 'مرتبطة بـ ${current.branchName} • معطّلة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: current.isActive,
                      activeThumbColor: branchColor,
                      onChanged: (_) => controller.toggleActive(current),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: isDark ? Colors.blue.shade300 : const Color(0xFF007791),
                      tooltip: 'تعديل العبوة',
                      onPressed: () => _showProductDialog(context, controller, product: current),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: Colors.redAccent,
                      tooltip: 'حذف العبوة',
                      onPressed: () => _confirmDelete(context, controller, current),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showProductDialog(
    BuildContext context,
    PackagesManagementController controller, {
    Product? product,
    int? branchId,
  }) {
    final isEditing = product != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final volumeCtrl = TextEditingController(
      text: product != null ? _formatVolumeInput(product.volumeLiters) : '',
    );
    final selectedBranch = Rx<int>(product?.branchId ?? branchId ?? 1);

    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isEditing ? Icons.edit_rounded : Icons.add_rounded, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Text(
                isEditing ? 'تعديل العبوة' : 'إضافة عبوة جديدة',
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسم العبوة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'مثال: عبوة 600 مل',
                    hintStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                    prefixIcon: const Icon(Icons.water_drop_outlined, color: AppColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('الحجم (باللتر):', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: volumeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'مثال: 0.6',
                    hintStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                    prefixIcon: const Icon(Icons.straighten_rounded, color: AppColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('المصنع المرتبط:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Obx(() => Row(
                      children: _branches.entries.map((e) {
                        final selected = selectedBranch.value == e.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              onPressed: () => selectedBranch.value = e.key,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selected ? e.value.color : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                foregroundColor: selected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                e.value.title,
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                const SizedBox(height: 4),
                Text(
                  'ستظهر هذه العبوة فقط للمستخدمين العاملين في المصنع المختار.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final volume = double.tryParse(volumeCtrl.text.trim());
                if (name.isEmpty) {
                  Get.snackbar('تنبيه', 'يرجى إدخال اسم العبوة', backgroundColor: Colors.orange, colorText: Colors.white);
                  return;
                }
                if (volume == null || volume <= 0) {
                  Get.snackbar('تنبيه', 'يرجى إدخال حجم صحيح باللتر', backgroundColor: Colors.orange, colorText: Colors.white);
                  return;
                }
                Get.back();
                if (isEditing) {
                  await controller.editProduct(product.copyWith(
                    name: name,
                    volumeLiters: volume,
                    branchId: selectedBranch.value,
                  ));
                } else {
                  await controller.addProduct(
                    name: name,
                    volumeLiters: volume,
                    branchId: selectedBranch.value,
                  );
                }
                Get.snackbar(
                  'تم الحفظ',
                  isEditing ? 'تم تحديث العبوة بنجاح' : 'تمت إضافة العبوة وربطها بالمصنع',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatVolumeInput(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toString();
  }

  void _confirmDelete(BuildContext context, PackagesManagementController controller, Product product) {
    Get.defaultDialog(
      title: 'حذف العبوة',
      titleStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.redAccent),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل أنت متأكد من حذف "${product.name}" المرتبطة بـ ${product.branchName}؟',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم حذف المواصفات القياسية الخاصة بهذه العبوة أيضاً. تقارير الفحص المحفوظة سابقاً تبقى كما هي.',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.orange.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'حذف',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        Get.back();
        await controller.deleteProduct(product);
      },
    );
  }
}
