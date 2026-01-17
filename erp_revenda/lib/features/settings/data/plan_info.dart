import '../../../shared/plan/app_plan.dart';

class PlanInfo {
  final AppPlan plan;
  final int clientes;
  final int produtos;
  final int vendas;

  const PlanInfo({
    required this.plan,
    required this.clientes,
    required this.produtos,
    required this.vendas,
  });

  bool get isPro => plan.isPro;

  int? get maxClientes => plan.maxClientes;
  int? get maxProdutos => plan.maxProdutos;
  int? get maxVendas => plan.maxVendas;

  double? progressClientes() => _progress(clientes, maxClientes);
  double? progressProdutos() => _progress(produtos, maxProdutos);
  double? progressVendas() => _progress(vendas, maxVendas);

  bool nearClientes([double threshold = 0.8]) =>
      _nearLimit(clientes, maxClientes, threshold);
  bool nearProdutos([double threshold = 0.8]) =>
      _nearLimit(produtos, maxProdutos, threshold);
  bool nearVendas([double threshold = 0.8]) =>
      _nearLimit(vendas, maxVendas, threshold);

  static double? _progress(int used, int? max) {
    if (max == null || max <= 0) return null;
    final pct = used / max;
    if (pct.isNaN) return 0;
    return pct.clamp(0.0, 1.0);
  }

  static bool _nearLimit(int used, int? max, double threshold) {
    if (max == null || max <= 0) return false;
    return used / max >= threshold;
  }
}
