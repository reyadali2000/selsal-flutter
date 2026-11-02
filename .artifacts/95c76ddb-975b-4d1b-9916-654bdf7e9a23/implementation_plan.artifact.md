# خطة المرحلة الثانية: ترحيل قاعدة البيانات + إصلاح D.3 و D.4 و D.5

## الوصف

بعد اكتمال المرحلة الأولى (توحيد مصدر الحقيقة وحذف `AppPermission` + `fail-closed`)،
تبقى لدينا قاعدة بيانات قديمة مخزّنة بأكواد صلاحيات متقادمة (مثل `fill_dynamic_reports`
و `create_hygiene_reports` لأخصائي الجودة)، بالإضافة إلى هشاشة مطابقة الأدوار النصية
وسقوطها المفتوح (fail-open) عند غياب الدور.

المرحلة الثانية تُتم المهمة: ترحيل آمن للبيانات + إصلاح المسار النصي + إزالة المهاجر المكرر.

---

## User Review Required

> [!IMPORTANT]
> **D.5 (السقوط المفتوح):** حالياً أي دور غير معروف يرث صلاحيات أخصائي الجودة كاملة.
> الخطة تغيّر هذا إلى **fail-closed** (قائمة فارغة) — مما يعني: مستخدم دوره محذوف من
> `CustomRoles` سيخسر كل الصلاحيات ولن يستطيع استخدام التطبيق حتى يُربط بدور صحيح.
> هذا هو السلوك الآمن، لكنه **تغيير في تجربة المستخدم** يحتاج موافقتك.

> [!IMPORTANT]
> **D.4 (المطابقة النصية):** خطة إصلاحها تعتمد على رفض أي دور غير موجود في جدول
> `CustomRoles` — أي أن الاعتماد على أسماء الأدوار النصية المضمنة في الكود
> (`'admin'`, `'gm'`, `'qm'`...) كـ fallback سيُحصر في القاموس الدقيق فقط دون
> مطابقة جزئية (`contains`).

## Open Questions

1. هل توافق على **D.5 fail-closed**؟ (مستخدم الدور المحذوف يفقد الصلاحيات بدل أخذ أخصائي جودة)
2. هل نوافق على رفع `schemaVersion` من `8` إلى `9`؟

## Proposed Changes

### 1. ترحيل قاعدة البيانات — رفع schemaVersion إلى 9

#### [MODIFY] [role_model.dart](file:///C:/Users/REYADH/AndroidStudioProjects/newEdea3/lib/models/role_model.dart)

رفع `schemaVersion` من `8` إلى `9` لتشغيل الترحيل عند أول تشغيل:

```dart
static const int schemaVersion = 9;
```

إضافة مفتاح ترحيل للكتالوج الجديد في `legacyMigrationMap`:
```dart
// مفتاح ترحيل لرفع الإصدار 9: إزالة createHygieneReports من أخصائي الجودة
// وتفكيك fill_dynamic_reports لا يحتاج مفتاحاً (موجود مسبقاً)
```

تعديل `removeCrossDepartmentPermissionsForSystemRole` — إضافة تنظيف
`createHygieneReports` من `quality_manager` (موجود حالياً لأخصائي الجودة فقط):

```dart
case 'quality_specialist':
  cleaned.removeAll([
    createHygieneReports,      // ← موجود
    fillHealthReports,
    viewHealthReports,
    fillFoodSafetyDynamicReports,
  ]);
```

> [!NOTE]
> `quality_manager` حالياً لا يملك `createHygieneReports` في `defaultSystemRoles`
> الجديدة، لكن الأدوار المخزّنة في قاعدة البيانات القديمة قد تملكه — لذا التنظيف
> ضروري للترحيل.

### 2. توحيد المهاجرَين — إصلاح D.2 (جزئياً مُنجز)

#### [MODIFY] [database_helper.dart](file:///C:/Users/REYADH/AndroidStudioProjects/newEdea3/lib/services/database_helper.dart)

`_migrateDynamicReportPermissions` (السطر 402) أصبحت الآن **متطابقة** تماماً مع
`RolesDatabaseService._migrateRolesSchemaIfNeeded` (كلاهما يستدعي
`migratePermissions` + `removeCrossDepartmentPermissionsForSystemRole`).

> [!TIP]
> فحص الكود يؤكد أن D.2 **تم إصلاحها مسبقاً** — المهاجران يطبّقان نفس المنطق الآن.
> سأكتفي بالتحقق من ذلك بالاختبارات دون تعديل إضافي.

### 3. إصلاح D.5 — السقوط المفتوح في getPermissionsForRole

#### [MODIFY] [roles_database_service.dart](file:///C:/Users/REYADH/AndroidStudioProjects/newEdea3/lib/services/roles_database_service.dart)

استبدال الـ fallback النهائي المفتوح:

```dart
// قبل: أي دور غير معروف يرث أخصائي الجودة
final defInspector = RoleModel.defaultSystemRoles.firstWhere((e) => e.code == 'quality_specialist');
return defInspector.permissions;
```

بسلوك **fail-closed**:

```dart
// بعد: دور غير معروف = لا صلاحيات
debugPrint('⚠️ الدور "$roleCodeOrTitle" غير موجود في CustomRoles — تم رفض كل الصلاحيات (fail-closed)');
return <String>[];
```

> [!CAUTION]
> هذا التغيير يعني: أي مستخدم دوره غير مسجل في `CustomRoles` (مثلاً دور محذوف)
> سيحصل على قائمة صلاحيات فارغة → كل شاشاته ستعرض "لا تملك صلاحية".
> هذه هي النتيجة المقصودة (الأمان على حساب الراحة).

### 4. إصلاح D.4 — مطابقة الأدوار النصية الجزئية

#### [MODIFY] [roles_database_service.dart](file:///C:/Users/REYADH/AndroidStudioProjects/newEdea3/lib/services/roles_database_service.dart)

استبدال سلسلة `normalized.contains(...)` الهشّة بمطابقة **دقيقة فقط** على
قائمة الأسماء النظامية المعروفة:

```dart
// قبل: normalized.contains('admin') → 'sysadmin' يأخذ كل الصلاحيات!
if (normalized.contains('admin') || normalized.contains('مديرالنظام')) { ... }
```

```dart
// بعد: مطابقة دقيقة لمفاتيح النظام المعروفة فقط
const systemRoleAliases = <String, String>{
  'admin': 'admin',
  'administrator': 'admin',
  'مديرالنظام': 'admin',
  'generalmanager': 'general_manager',
  'gmanager': 'general_manager',
  'مديرعام': 'general_manager',
  'المديرالعام': 'general_manager',
  'qualitymanager': 'quality_manager',
  'qm': 'quality_manager',
  'مديرالجودة': 'quality_manager',
  'factorymanager': 'factory_manager',
  'gm': 'factory_manager',
  'مديرالمصنع': 'factory_manager',
  'foodsafetyengineer': 'food_safety_engineer',
  'foodsafety': 'food_safety_engineer',
  'سلامةالغذاء': 'food_safety_engineer',
  'مهندسسلامة': 'food_safety_engineer',
};

final code = systemRoleAliases[normalized];
if (code != null) {
  return RoleModel.defaultSystemRoles
      .firstWhere((e) => e.code == code, orElse: () => ...)
      .permissions;
}
return <String>[];  // fail-closed
```

> [!IMPORTANT]
> المطابقة الدقيقة تعني: `'agm'` لن يطابق `'gm'`، و`'sqm'` لن يطابق `'qm'`،
> و`'sysadmin'` لن يطابق `'admin'` — تم إغلاق ثغرات التصعيد الصامت.

### 5. اختبارات المرحلة الثانية

#### [MODIFY] [permissions_matrix_test.dart](file:///C:/Users/REYADH/AndroidStudioProjects/newEdea3/test/permissions_matrix_test.dart)

تحديث اختبارات D.4/D.5 لتعكس السلوك الجديد:
- `simulateFallback('sysadmin')` → **قائمة فارغة** (بدل كل الصلاحيات)
- `simulateFallback('agm')` → **قائمة فارغة** (بدل صلاحيات factory_manager)
- `simulateFallback('sqm')` → **قائمة فارغة** (بدل صلاحيات quality_manager)
- `simulateFallback('محاسب')` → **قائمة فارغة** (بدل صلاحيات quality_specialist)
- المطابقة الدقيقة لا تزال تنجح للأسماء الصحيحة

#### [NEW] اختبارات الترحيل (داخل permissions_matrix_test.dart)

- `migratePermissions` على دور مخزن قديم لأخصائي الجودة يزيل `createHygieneReports`
- `removeCrossDepartmentPermissionsForSystemRole` على `quality_manager` يزيل `createHygieneReports`
- رفع `schemaVersion` إلى 9

---

## Verification Plan

### Automated Tests
```bash
flutter test test/permissions_matrix_test.dart test/food_safety_role_test.dart test/dynamic_permissions_split_test.dart
```

النتيجة المتوقعة:
- جميع اختبارات المصفوفة (38+) نجاح
- اختبارات D.4/D.5 الجديدة تعكس fail-closed
- اختبارات الترحيل تنجح

### Static Analysis
```bash
flutter analyze lib/models/role_model.dart lib/services/roles_database_service.dart lib/services/database_helper.dart lib/models/user_model.dart lib/services/user_session_service.dart
```

النتيجة المتوقعة: `No issues found!`

### Manual Verification
- تطبيق الترحيل على قاعدة البيانات الحالية يتطلب تشغيل التطبيق على جهاز
- بعد التشغيل: فحص جدول `CustomRoles` للتأكد من:
  - `quality_specialist` لا يحوي `create_hygiene_reports`
  - أي دور يملك `fill_dynamic_reports` تم تفكيكه
  - `schemaVersion` = 9 في SharedPreferences

### Regression Risk
> [!WARNING]
> التغييران D.4 + D.5 يُغيّران سلوك fallback الجذري. أي مستخدم حالي دوره
> مُسجَّل في `CustomRoles` (الحالة الطبيعية) **لن يتأثر إطلاقاً** — التغيير
> يطال فقط المستخدمين الذين أدوارهم غير مسجّلة (حالة شاذة).
