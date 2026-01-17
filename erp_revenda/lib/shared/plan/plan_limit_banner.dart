import 'package:flutter/material.dart';

import '../../app/ui/app_colors.dart';

class PlanLimitBanner extends StatelessWidget {
  final String label;
  final int used;
  final int max;
  final VoidCallback onTap;

  const PlanLimitBanner({
    super.key,
    required this.label,
    required this.used,
    required this.max,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final isNear = max > 0 && used / max >= 0.8;
    if (!isNear) return const SizedBox.shrink();

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Limite de $label quase atingido',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uso atual: $used/$max. Ative o plano Pro para liberar ilimitado.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
