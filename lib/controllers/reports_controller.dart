import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/water_quality_models.dart';
import '../services/database_helper.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';

class ReportsController extends GetxController {
  var readings = <WaterQualityLog>[].obs;
  var isLoading = true.obs;

  final TextEditingController searchController = TextEditingController();
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadReadings();

    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.currentUser, (_) => loadReadings());
      ever(UserSessionService.to.currentRole, (_) => loadReadings());
      ever(UserSessionService.to.activeBranchFilter, (_) => loadReadings());
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  List<WaterQualityLog> get filteredReadings {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return readings;
    return readings.where((r) {
      final batch = (r.batchNumber ?? '').toLowerCase();
      final product = (r.productName ?? '').toLowerCase();
      final notes = (r.generalNotes ?? '').toLowerCase();
      final shift = r.shiftId.toString();
      return batch.contains(q) || product.contains(q) || notes.contains(q) || shift.contains(q);
    }).toList();
  }

  Future<void> loadReadings() async {
    isLoading.value = true;
    try {
      final branchId = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.effectiveBranchFilter
          : null;

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiLogs = await WaterQualityApiService.to.getLogs(branchId: branchId);
          readings.value = apiLogs.map((e) => WaterQualityLog.fromMap(e)).toList();
          isLoading.value = false;
          return;
        } catch (e) {
          debugPrint('API loadReadings error: $e');
        }
      }

      final data = await DatabaseHelper.instance.getAllWaterQualityLogs(branchId: branchId);
      readings.assignAll(data);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحميل التقارير: $e', snackPosition: SnackPosition.TOP);
    } finally {
      isLoading.value = false;
    }
  }
}
