import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/main.dart';
import 'package:soil_nutrient_app/widgets/app_bottom_nav.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // Set screen size for standard phone viewport
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SoilNutrientApp());
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  testWidgets('Overview shows the summary, the sample in use and the to-do list, with a badge on its tab', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Trạm đo đất'), findsOneWidget);
    expect(find.textContaining('ESP32 Soil Station 01'), findsOneWidget);
    expect(find.textContaining('Chỉ độ ẩm là số đo'), findsOneWidget);
    expect(find.text('Đất vườn (đất thịt)'), findsOneWidget);
    expect(find.text('Chỉ số chính'), findsOneWidget);

    // The demo reading lacks nitrogen and phosphorus, so the Overview tab carries a to-do badge
    await tester.scrollUntilVisible(find.text('Việc nên làm'), 300);
    expect(find.bySemanticsLabel(RegExp(r'^Tổng quan, \d+ việc cần làm$')), findsOneWidget);

    // Tap the simulation button
    await tester.tap(find.byTooltip('Mô phỏng dữ liệu ngẫu nhiên (Demo)'));
    await tester.pumpAndSettle();
    expect(find.text('Trạm đo đất'), findsOneWidget);
  });

  testWidgets('Overview shows pump and valve switches that stay disabled until the station is connected', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.text('Van dinh dưỡng'), 300);
    expect(find.text('Điều khiển trạm'), findsOneWidget);
    expect(find.text('Máy bơm tưới'), findsOneWidget);
    expect(find.text('Chưa rõ trạng thái'), findsNWidgets(2));
    expect(find.text('Cần kết nối với trạm để bật hoặc tắt.'), findsOneWidget);

    // No broker in widget tests: the switches are off and cannot be toggled
    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches.length, 2);
    for (final tile in switches) {
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
    }
  });

  testWidgets('Bottom navigation opens every function on its own page', (WidgetTester tester) async {
    await pumpApp(tester);

    await openTab(tester, 'Chỉ số');
    expect(find.text('Chỉ số đất'), findsOneWidget);
    expect(find.text('Chuẩn 50 - 100'), findsOneWidget);
    expect(find.text('Chuẩn 30 - 70'), findsOneWidget);
    expect(find.text('Chuẩn 80 - 150'), findsOneWidget);
    expect(find.text('So với mức chuẩn'), findsOneWidget);

    await openTab(tester, 'Mẫu đất');
    expect(find.text('Chọn mẫu đất'), findsOneWidget);
    expect(find.text('Cao'), findsOneWidget);
    expect(find.text('Thấp'), findsOneWidget);

    // History: no sqflite plugin in widget tests, so the page shows its empty state instead of crashing
    await openTab(tester, 'Lịch sử');
    expect(find.text('Lịch sử đo'), findsOneWidget);
    expect(find.text('Chưa có số đo nào trong khoảng này'), findsOneWidget);
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo nào trong khoảng này'), findsOneWidget);

    await openTab(tester, 'Hiệu chuẩn');
    expect(find.text('Hiệu chuẩn cảm biến'), findsOneWidget);
    expect(find.text('Để đầu dò khô'), findsOneWidget);

    await openTab(tester, 'Tổng quan');
    expect(find.text('Trạm đo đất'), findsOneWidget);
  });

  testWidgets('Picking a soil sample updates the description and the overview card', (WidgetTester tester) async {
    await pumpApp(tester);

    // The overview card jumps straight to the soil page
    await tester.tap(find.text('Đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mẫu đất'), findsOneWidget);
    expect(find.text('Đất vườn (đất thịt)'), findsOneWidget);

    await tester.tap(find.text('Đóng bao'));
    await tester.pumpAndSettle();

    expect(find.text('Đất dinh dưỡng đóng bao'), findsOneWidget);
    expect(find.text('Phối trộn sẵn phân hữu cơ, tro trấu, xơ dừa'), findsOneWidget);
    // No broker in widget tests, so the choice waits for a connection instead of showing as confirmed
    expect(find.text('Chờ có mạng để gửi'), findsOneWidget);
    expect(find.text('Trạm đã nhận'), findsNothing);

    await openTab(tester, 'Tổng quan');
    expect(find.text('Đất dinh dưỡng đóng bao'), findsOneWidget);
  });

  testWidgets('Calibration wizard needs a connection to save and can skip ahead', (WidgetTester tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Hiệu chuẩn');

    // The demo reading carries no ADC block yet
    expect(find.text('Trạm chưa gửi tín hiệu đầu dò'), findsOneWidget);

    await tester.tap(find.text('Lưu mốc khô'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa kết nối được với trạm, hãy thử lại.'), findsOneWidget);
    expect(find.text('Để đầu dò khô'), findsOneWidget);

    await tester.tap(find.text('Bỏ qua bước này'));
    await tester.pumpAndSettle();
    expect(find.text('Nhúng đầu dò vào nước'), findsOneWidget);
    expect(find.text('Lưu mốc ướt'), findsOneWidget);

    // Leaving the tab and coming back keeps the step
    await openTab(tester, 'Chỉ số');
    await openTab(tester, 'Hiệu chuẩn');
    expect(find.text('Nhúng đầu dò vào nước'), findsOneWidget);
  });
}
