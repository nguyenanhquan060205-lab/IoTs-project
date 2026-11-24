import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/soil_data_provider.dart';
import '../widgets/app_bottom_nav.dart';
import 'calibration_screen.dart';
import 'history_screen.dart';
import 'metrics_screen.dart';
import 'overview_screen.dart';
import 'soil_type_screen.dart';

/// Khung chính: 5 trang chức năng, chuyển bằng thanh điều hướng dưới đáy.
/// Các trang giữ nguyên trạng thái khi chuyển qua lại (vị trí cuộn, bước hiệu chuẩn đang làm).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const int overviewTab = 0;
  static const int metricsTab = 1;
  static const int soilTab = 2;
  static const int historyTab = 3;
  static const int calibrationTab = 4;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = HomeShell.overviewTab;

  void _open(int index) {
    if (index != _index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final issueCount = provider.currentDiagnosis.issues.length;

    // Nút Back của Android: đang ở trang khác thì về Tổng quan trước, không thoát app ngay
    return PopScope(
      canPop: _index == HomeShell.overviewTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(HomeShell.overviewTab);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            OverviewScreen(
              onOpenSoil: () => _open(HomeShell.soilTab),
              onOpenMetrics: () => _open(HomeShell.metricsTab),
            ),
            const MetricsScreen(),
            const SoilTypeScreen(),
            HistoryScreen(repository: provider.historyRepository, active: _index == HomeShell.historyTab),
            CalibrationScreen(onFinished: () => _open(HomeShell.overviewTab)),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _index,
          onTap: _open,
          items: [
            BottomNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Tổng quan',
              badge: issueCount,
            ),
            const BottomNavItem(icon: Icons.eco_outlined, selectedIcon: Icons.eco_rounded, label: 'Chỉ số'),
            const BottomNavItem(icon: Icons.layers_outlined, selectedIcon: Icons.layers_rounded, label: 'Mẫu đất'),
            const BottomNavItem(icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded, label: 'Lịch sử'),
            const BottomNavItem(icon: Icons.tune_outlined, selectedIcon: Icons.tune_rounded, label: 'Hiệu chuẩn'),
          ],
        ),
      ),
    );
  }
}
