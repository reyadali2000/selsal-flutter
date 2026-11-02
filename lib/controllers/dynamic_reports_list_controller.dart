import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/dynamic_report_models.dart';
import '../services/api/dynamic_reports_api_service.dart';

class DynamicReportsListController extends GetxController {
  var isLoading = false.obs;
  var reports = <DynamicReport>[].obs;
  var categories = <DynamicReportCategory>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;
    try {
      final apiService = DynamicReportsApiService.to;
      categories.value = await apiService.getCategories();
      reports.value = await apiService.getTemplates();
    } catch (e, stackTrace) {
      debugPrint('DynamicReportsList loadData error: $e\n$stackTrace');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل التقارير: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteReport(int reportId) async {
    isLoading.value = true;
    try {
      await DynamicReportsApiService.to.deleteReport(reportId);
      reports.removeWhere((r) => r.id == reportId);
      await loadData();
      Get.snackbar('نجاح', 'تم حذف التقرير وكافة سجلاته بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حذف التقرير: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleReportActive(DynamicReport report, bool isActive) async {
    try {
      final updatedReport = report.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      await DynamicReportsApiService.to.updateReport(updatedReport);
      await loadData();
      Get.snackbar('نجاح', isActive ? 'تم تفعيل التقرير' : 'تم تعطيل التقرير');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تعديل حالة التقرير: $e');
    }
  }
}
