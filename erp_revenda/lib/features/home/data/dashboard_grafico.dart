class DashboardGraficoItem {
  final String label;
  final double valor;

  const DashboardGraficoItem({
    required this.label,
    required this.valor,
  });
}

class DashboardGrafico {
  final List<DashboardGraficoItem> itens;
  final double total;

  const DashboardGrafico({
    required this.itens,
    required this.total,
  });
}
