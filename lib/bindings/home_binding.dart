import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/reports_controller.dart';

/// حقن التبعيات للصفحة الرئيسية
/// يتم تسجيل الـ Controllers بشكل كسول (lazyPut) لتحسين الأداء
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(() => DashboardController());
    Get.lazyPut<ReportsController>(() => ReportsController());
  }
}
