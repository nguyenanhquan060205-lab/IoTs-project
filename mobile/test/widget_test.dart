import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/main.dart';

void main() {
  testWidgets('SoilNutrientApp smoke test - renders dashboard, title and triggers simulated reading', (WidgetTester tester) async {
    // Set screen size for standard phone viewport
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SoilNutrientApp());
    await tester.pumpAndSettle();

    // Verify AppBar title is present
    expect(find.text('Dinh Dưỡng Đất Thông Minh'), findsOneWidget);

    // Verify key UI sections are rendered
    expect(find.byTooltip('Mô phỏng dữ liệu ngẫu nhiên (Demo)'), findsOneWidget);

    // Tap the simulation button
    await tester.tap(find.byTooltip('Mô phỏng dữ liệu ngẫu nhiên (Demo)'));
    await tester.pumpAndSettle();

    // Verify that the widget tree remains healthy and responsive
    expect(find.text('Dinh Dưỡng Đất Thông Minh'), findsOneWidget);
  });
}
