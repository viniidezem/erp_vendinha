import 'package:flutter/material.dart';

import '../../../app/ui/app_colors.dart';

String fmtMoney(double v) {
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $s';
}

String fmtDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}

class RelatorioPeriodoRapido {
  static const hoje = 'HOJE';
  static const ultimos7Dias = 'ULTIMOS_7_DIAS';
  static const ultimos30Dias = 'ULTIMOS_30_DIAS';

  static const List<String> values = [hoje, ultimos7Dias, ultimos30Dias];

  static String label(String value) {
    switch (value) {
      case hoje:
        return 'Hoje';
      case ultimos7Dias:
        return 'Últimos 7 dias';
      case ultimos30Dias:
        return 'Últimos 30 dias';
      default:
        return value;
    }
  }
}

class RelatorioQuickPeriodChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const RelatorioQuickPeriodChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: RelatorioPeriodoRapido.values.map((p) {
        final selected = p == value;
        return ChoiceChip(
          label: Text(RelatorioPeriodoRapido.label(p)),
          selected: selected,
          onSelected: (_) => onChanged(p),
        );
      }).toList(),
    );
  }
}

class RelatorioKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const RelatorioKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RelatorioSectionTitle extends StatelessWidget {
  final String label;

  const RelatorioSectionTitle(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}

class RelatorioDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const RelatorioDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ).copyWith(labelText: label),
        child: Text(fmtDate(value)),
      ),
    );
  }
}
