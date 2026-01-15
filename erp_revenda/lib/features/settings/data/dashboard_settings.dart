class DashboardGraficoPeriodo {
  static const mesAtual = 'MES_ATUAL';
  static const semanaAtual = 'SEMANA_ATUAL';
  static const diaAtual = 'DIA_ATUAL';

  static const List<String> values = [mesAtual, semanaAtual, diaAtual];

  static String label(String value) {
    switch (value) {
      case mesAtual:
        return 'Mes atual';
      case semanaAtual:
        return 'Semana atual';
      case diaAtual:
        return 'Dia atual';
      default:
        return value;
    }
  }
}

class DashboardSettings {
  final bool mostrarGraficos;
  final double metaFaturamentoMensal;
  final String periodoGrafico;

  const DashboardSettings({
    required this.mostrarGraficos,
    required this.metaFaturamentoMensal,
    required this.periodoGrafico,
  });

  DashboardSettings copyWith({
    bool? mostrarGraficos,
    double? metaFaturamentoMensal,
    String? periodoGrafico,
  }) {
    return DashboardSettings(
      mostrarGraficos: mostrarGraficos ?? this.mostrarGraficos,
      metaFaturamentoMensal:
          metaFaturamentoMensal ?? this.metaFaturamentoMensal,
      periodoGrafico: periodoGrafico ?? this.periodoGrafico,
    );
  }

  static DashboardSettings defaults() {
    return const DashboardSettings(
      mostrarGraficos: false,
      metaFaturamentoMensal: 0,
      periodoGrafico: DashboardGraficoPeriodo.mesAtual,
    );
  }
}
