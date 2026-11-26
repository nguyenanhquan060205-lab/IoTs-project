import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/app_colors.dart';
import 'providers/soil_data_provider.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _useDesktopDatabase();
  runApp(const SoilNutrientApp());
}

/// sqflite chỉ chạy trên Android, iOS, macOS. Trên Windows/Linux phải dùng SQLite qua FFI,
/// nếu không thì CSDL lịch sử không mở được và App không lưu được số đo nào.
Future<void> _useDesktopDatabase() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) return;
  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Mặc định FFI lưu vào thư mục đang chạy lệnh; chuyển về thư mục dữ liệu của App để mở lại vẫn còn lịch sử
    final dir = await getApplicationSupportDirectory();
    await databaseFactory.setDatabasesPath(dir.path);
  } catch (e) {
    debugPrint('[HISTORY] Không chuẩn bị được SQLite cho máy tính: $e');
  }
}

class SoilNutrientApp extends StatelessWidget {
  const SoilNutrientApp({super.key});

  // Giao diện sáng để đọc rõ ngoài trời, dùng phông mặc định của máy (có đủ dấu tiếng Việt)
  static ThemeData buildTheme() {
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));
    // Lấy kiểu chữ gốc của Material để mọi style dưới đây giữ phông hệ thống của từng máy
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light).textTheme;
    final buttonText = base.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        onPrimary: AppColors.accentInk,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.titleLarge!.copyWith(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: buttonShape,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line2),
          textStyle: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        labelStyle: base.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
        secondaryLabelStyle: base.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.page),
        side: const BorderSide(color: AppColors.line2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: base.bodyMedium!.copyWith(fontSize: 15, color: AppColors.page),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SoilDataProvider()),
      ],
      child: MaterialApp(
        title: 'Trạm đo đất',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
