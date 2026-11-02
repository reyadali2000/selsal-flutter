import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:wadialain/controllers/raw_water_entry_controller.dart';
import 'package:wadialain/models/standards_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RawWaterEntryController - Sensory Toggle Options', () {
    late RawWaterEntryController controller;

    setUp(() {
      controller = RawWaterEntryController();
    });

    test('setParamValue toggles compliant and non-compliant values and updates compliance', () {
      final stdColor = QualityStandard(
        id: 1,
        parameterId: 101,
        waterType: 'Raw Water',
        expectedText: 'طبيعي',
      );
      final paramColor = TestParameter(
        id: 101,
        category: 'Sensory',
        nameAr: 'اللون',
        unit: '',
        inputType: 'Text',
      );

      controller.standards.value = [stdColor];
      controller.testParameters.value = [paramColor];
      controller.sensoryStandards.value = [stdColor];

      final textCtrl = TextEditingController();
      controller.formControllers[101] = textCtrl;
      controller.formValidations[101] = Rx<bool?>(null);
      controller.formNoteControllers[101] = TextEditingController();
      controller.isNoteVisible[101] = false.obs;

      // Listen to text changes for validation
      textCtrl.addListener(() {
        final text = textCtrl.text.trim();
        if (text.isEmpty) {
          controller.formValidations[101]?.value = null;
        } else if (text == 'غير مطابق') {
          controller.formValidations[101]?.value = false;
        } else {
          controller.formValidations[101]?.value = (text.toLowerCase() == stdColor.expectedText!.toLowerCase());
        }
        controller.isAllCompliant.value = controller.formValidations[101]?.value == true;
      });

      // 1. Initial state
      expect(controller.formControllers[101]!.text, '');
      expect(controller.isAllCompliant.value, false);

      // 2. Select expected (Compliant)
      controller.setParamValue(101, 'طبيعي');
      expect(controller.formControllers[101]!.text, 'طبيعي');
      expect(controller.formValidations[101]!.value, true);
      expect(controller.isAllCompliant.value, true);

      // 3. Toggle back to empty
      controller.setParamValue(101, '');
      expect(controller.formControllers[101]!.text, '');
      expect(controller.formValidations[101]!.value, null);
      expect(controller.isAllCompliant.value, false);

      // 4. Select Non-compliant ('غير مطابق')
      controller.setParamValue(101, 'غير مطابق');
      expect(controller.formControllers[101]!.text, 'غير مطابق');
      expect(controller.formValidations[101]!.value, false);
      expect(controller.isAllCompliant.value, false);

      // 5. Toggle note visibility
      expect(controller.isNoteVisible[101]!.value, false);
      controller.toggleParamNote(101);
      expect(controller.isNoteVisible[101]!.value, true);
      controller.toggleParamNote(101);
      expect(controller.isNoteVisible[101]!.value, false);
    });
  });
}
