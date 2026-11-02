import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/production_models.dart';
import '../services/database_helper.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';

class PackagesManagementController extends GetxController {
  final packages = <Product>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPackages();
    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.currentUser, (_) => loadPackages());
    }
  }

  Future<void> loadPackages() async {
    isLoading.value = true;
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        try {
          // شاشة الإدارة تحتاج عرض كل العبوات (النشطة وغير النشطة) للتمكّن من تعطيلها أو حذفها
          final apiProducts = await MasterDataApiService.to.getProducts(includeInactive: true);
          if (apiProducts.isNotEmpty) {
            packages.value = apiProducts.map((e) => Product.fromMap(e)).toList();
            isLoading.value = false;
            return;
          }
        } catch (e) {
          debugPrint('API load packages error: $e');
        }
      }
      packages.value = await DatabaseHelper.instance.getAllProducts();
    } catch (e) {
      debugPrint('loadPackages error: $e');
    }
    isLoading.value = false;
  }

  /// العبوات المرئية فقط لمستخدم مقيّد بفرع (يستخدمها الموظفون في شاشات الإدخال)
  Future<List<Product>> visibleProductsFor(int? branchId) {
    return DatabaseHelper.instance.getActiveProducts(branchId: branchId);
  }

  /// بناء الحمولة (payload) المرسلة للـ API بصيغة camelCase المطابقة لعقد العمالة اليومية
  Map<String, dynamic> _toApiPayload(Product product) {
    return {
      'id': product.id ?? 0,
      'branchId': product.branchId,
      'name': product.name,
      'volumeLiters': product.volumeLiters,
      'isActive': product.isActive,
    };
  }

  Future<void> addProduct({
    required String name,
    required double volumeLiters,
    required int branchId,
  }) async {
    final product = Product(
      branchId: branchId,
      name: name.trim(),
      volumeLiters: volumeLiters,
      isActive: true,
    );
    // المزامنة مع الـ API أولاً (المصدر الأساسي للبيانات)، ثم الحفظ المحلي
    if (Get.isRegistered<MasterDataApiService>()) {
      final apiOk = await MasterDataApiService.to.saveProduct(_toApiPayload(product));
      if (apiOk) {
        try {
          await DatabaseHelper.instance.insertProduct(product);
        } catch (_) {}
        await loadPackages();
        return;
      }
    }
    // مسار احتياطي: الاعتماد على قاعدة البيانات المحلية فقط
    await DatabaseHelper.instance.insertProduct(product);
    await loadPackages();
  }

  Future<void> editProduct(Product product) async {
    if (Get.isRegistered<MasterDataApiService>()) {
      final apiOk = await MasterDataApiService.to.saveProduct(_toApiPayload(product));
      if (apiOk) {
        try {
          await DatabaseHelper.instance.updateProduct(product);
        } catch (_) {}
        await loadPackages();
        return;
      }
    }
    await DatabaseHelper.instance.updateProduct(product);
    await loadPackages();
  }

  Future<void> toggleActive(Product product) async {
    if (product.id == null) return;
    final newState = !product.isActive;
    if (Get.isRegistered<MasterDataApiService>()) {
      final apiOk = await MasterDataApiService.to.toggleProductStatus(product.id!, newState);
      if (apiOk) {
        try {
          await DatabaseHelper.instance.setProductActive(product.id!, newState);
        } catch (_) {}
        await loadPackages();
        return;
      }
    }
    await DatabaseHelper.instance.setProductActive(product.id!, newState);
    await loadPackages();
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) return;
    if (Get.isRegistered<MasterDataApiService>()) {
      final apiOk = await MasterDataApiService.to.deleteProduct(product.id!);
      if (apiOk) {
        try {
          await DatabaseHelper.instance.deleteProduct(product.id!);
        } catch (_) {}
        await loadPackages();
        return;
      }
    }
    await DatabaseHelper.instance.deleteProduct(product.id!);
    await loadPackages();
  }
}
