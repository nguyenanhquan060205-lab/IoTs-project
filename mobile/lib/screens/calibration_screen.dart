import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_telemetry.dart';
import '../providers/soil_data_provider.dart';
import '../widgets/inline_alert.dart';
import '../widgets/step_indicator.dart';

class _CalibrationStep {
  final String label;
  final String title;
  final String instruction;
  final IconData icon;
  final String action;
  final CalibrationPoint? point; // null: bước cuối, chỉ hướng dẫn đo

  const _CalibrationStep({
    required this.label,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.action,
    this.point,
  });
}

const _steps = [
  _CalibrationStep(
    label: 'Mốc khô',
    title: 'Để đầu dò khô',
    instruction: 'Rút đầu dò khỏi đất, lau sạch rồi để ngoài không khí khoảng 10 giây, '
        'chờ số tín hiệu ở trên đứng yên.',
    icon: Icons.wb_sunny_outlined,
    action: 'Lưu mốc khô',
    point: CalibrationPoint.dry,
  ),
  _CalibrationStep(
    label: 'Mốc ướt',
    title: 'Nhúng đầu dò vào nước',
    instruction: 'Nhúng vào cốc nước tới vạch giới hạn, không để nước chạm phần mạch điện, '
        'chờ số tín hiệu đứng yên.',
    icon: Icons.water_drop_outlined,
    action: 'Lưu mốc ướt',
    point: CalibrationPoint.wet,
  ),
  _CalibrationStep(
    label: 'Đo đất',
    title: 'Cắm vào đất để đo',
    instruction: 'Chọn đúng loại đất ở màn hình chính, cắm đầu dò ngập vào đất và chờ khoảng 1 phút. '
        'Mỗi mẫu đất nên đo ở 3 chỗ khác nhau.',
    icon: Icons.grass_rounded,
    action: 'Xong',
  ),
];

class CalibrationScreen extends StatefulWidget {
  final VoidCallback? onFinished; // Bấm "Xong" ở bước cuối; không truyền thì đóng trang

  const CalibrationScreen({super.key, this.onFinished});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _step = 0;
  int _direction = 1;

  void _goTo(int step) {
    if (step < 0 || step >= _steps.length || step == _step) return;
    setState(() {
      _direction = step > _step ? 1 : -1;
      _step = step;
    });
  }

  void _primaryAction(SoilDataProvider provider) {
    final point = _steps[_step].point;
    if (point == null) {
      final onFinished = widget.onFinished;
      if (onFinished == null) {
        Navigator.of(context).pop();
      } else {
        // Về lại bước đầu cho lần hiệu chuẩn sau
        setState(() => _step = 0);
        onFinished();
      }
      return;
    }
    final sent = provider.calibrate(point);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? 'Đã gửi. Mốc mới sẽ hiện ở thẻ tín hiệu khi trạm nhận được.'
          : 'Chưa kết nối được với trạm, hãy thử lại.'),
    ));
    if (sent) _goTo(_step + 1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final telemetry = provider.currentTelemetry;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Hiệu chuẩn cảm biến', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const InlineAlert(
            color: AppColors.accent,
            icon: Icons.info_outline_rounded,
            title: 'Vì sao cần hiệu chuẩn?',
            message: 'Mỗi cảm biến cho tín hiệu hơi khác nhau. Làm 1 lần khi mới lắp hoặc khi thay đầu dò '
                'để độ ẩm đo được chính xác. Đạm, lân, kali, độ chua và độ phì được ước lượng từ độ ẩm.',
          ),
          const SizedBox(height: 16),
          _SignalCard(adc: telemetry.adc, moisture: telemetry.moisture),
          const SizedBox(height: 16),
          _buildWizard(provider),
        ],
      ),
    );
  }

  Widget _buildWizard(SoilDataProvider provider) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepIndicator(
            labels: [for (final s in _steps) s.label],
            current: _step,
            onDoneStepTap: _goTo,
          ),
          const SizedBox(height: 18),
          ClipRect(
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 550),
              switchInCurve: AppMotion.ease,
              switchOutCurve: AppMotion.ease,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                // Bước mới trượt vào từ phía đang đi tới, bước cũ trượt ra phía ngược lại
                final incoming = child.key == ValueKey(_step);
                final begin = Offset((incoming ? 0.4 : -0.4) * _direction, 0);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: begin, end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _StepPane(key: ValueKey(_step), step: step, isLast: isLast),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: Opacity(
                  opacity: _step == 0 ? 0.35 : 1,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.ink,
                      disabledBackgroundColor: AppColors.surface2,
                      disabledForegroundColor: AppColors.ink,
                    ),
                    onPressed: _step == 0 ? null : () => _goTo(_step - 1),
                    child: const Text('Quay lại'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isLast ? AppColors.ok : AppColors.ink,
                    foregroundColor: isLast ? AppColors.accentInk : AppColors.page,
                  ),
                  onPressed: () => _primaryAction(provider),
                  child: Text(step.action),
                ),
              ),
            ],
          ),
          if (!isLast)
            TextButton(
              onPressed: () => _goTo(_step + 1),
              style: TextButton.styleFrom(foregroundColor: AppColors.ink2, minimumSize: const Size.fromHeight(44)),
              child: const Text('Bỏ qua bước này', style: TextStyle(fontSize: 15)),
            ),
        ],
      ),
    );
  }
}

class _StepPane extends StatelessWidget {
  final _CalibrationStep step;
  final bool isLast;

  const _StepPane({super.key, required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isLast ? AppColors.ok : AppColors.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(step.icon, size: 26, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                step.instruction,
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ tín hiệu đầu dò: số ADC đang đọc, độ ẩm tính ra, mức nhiễu và 2 mốc đang lưu
class _SignalCard extends StatelessWidget {
  final AdcInfo? adc;
  final double moisture;

  const _SignalCard({required this.adc, required this.moisture});

  @override
  Widget build(BuildContext context) {
    final adc = this.adc;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      child: adc == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CalmState(
                icon: Icons.hourglass_empty_rounded,
                color: AppColors.ink3,
                title: 'Trạm chưa gửi tín hiệu đầu dò',
                message: 'Hãy bật trạm và nạp phần mềm mới cho ESP32 để hiệu chuẩn từ điện thoại.',
              ),
            )
          : _buildSignal(adc),
    );
  }

  Widget _buildSignal(AdcInfo adc) {
    // Nhiễu là độ lệch chuẩn của 21 mẫu ADC 12-bit (0 - 4095)
    final (noiseLabel, noiseColor) = adc.noise < 15
        ? ('Tín hiệu ổn định', AppColors.ok)
        : adc.noise < 50
            ? ('Tín hiệu hơi nhiễu', AppColors.warn)
            : ('Nhiễu nhiều, kiểm tra dây cắm và nguồn', AppColors.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tín hiệu đầu dò',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink2),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${adc.raw}',
              style: const TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${moisture.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent),
                ),
                const Text('độ ẩm', style: TextStyle(fontSize: 13, color: AppColors.ink3)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.circle, size: 9, color: noiseColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$noiseLabel (±${adc.noise.toStringAsFixed(1)})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: noiseColor),
              ),
            ),
          ],
        ),
        const Divider(height: 28, color: AppColors.line),
        Row(
          children: [
            Expanded(child: _pointValue('Mốc khô đang lưu', adc.dry)),
            Expanded(child: _pointValue('Mốc ướt đang lưu', adc.wet)),
          ],
        ),
      ],
    );
  }

  Widget _pointValue(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ],
    );
  }
}
