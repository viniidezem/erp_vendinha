import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/plan/app_plan.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/plan_controller.dart';
import '../data/plan_info.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  static const String _productId = 'erp_revenda_pro';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _storeAvailable = false;
  bool _loadingStore = true;
  bool _purchasePending = false;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => _showSnack('Erro na compra: $e'),
    );
    _initStore();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initStore() async {
    final available = await _iap.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _storeAvailable = false;
        _loadingStore = false;
      });
      return;
    }

    final response = await _iap.queryProductDetails({_productId});
    if (!mounted) return;

    if (response.error != null) {
      setState(() {
        _storeAvailable = true;
        _loadingStore = false;
        _storeError = response.error?.message;
      });
      return;
    }

    setState(() {
      _storeAvailable = true;
      _loadingStore = false;
      _product = response.productDetails.isNotEmpty
          ? response.productDetails.first
          : null;
    });
  }

  Future<void> _buy() async {
    if (_product == null) {
      _showSnack('Produto nao encontrado na loja.');
      return;
    }
    final param = PurchaseParam(productDetails: _product!);
    setState(() => _purchasePending = true);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _restore() async {
    setState(() => _purchasePending = true);
    await _iap.restorePurchases();
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    await ref.read(planInfoProvider.notifier).definirPlano(AppPlan.pro);
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
    if (!mounted) return;
    setState(() => _purchasePending = false);
    _showSnack('Plano Pro ativado!');
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        setState(() => _purchasePending = true);
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        setState(() => _purchasePending = false);
        _showSnack('Compra nao concluida.');
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _deliver(purchase);
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planInfoProvider);

    return AppPage(
      title: 'Plano',
      child: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar plano: $e')),
        data: (info) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _PlanHeader(info: info),
            const SizedBox(height: 12),
            _UsageCard(info: info),
            const SizedBox(height: 12),
            if (!info.isPro) _WarningCard(info: info),
            const SizedBox(height: 12),
            _PurchaseCard(
              info: info,
              storeAvailable: _storeAvailable,
              loadingStore: _loadingStore,
              purchasePending: _purchasePending,
              storeError: _storeError,
              priceLabel: _product?.price,
              onBuy: _buy,
              onRestore: _restore,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final PlanInfo info;

  const _PlanHeader({required this.info});

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: info.isPro ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                info.isPro ? 'Plano Pro ativo' : 'Plano gratuito',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Chip(
              label: Text(info.isPro ? 'Pro' : 'Free'),
              backgroundColor:
                  info.isPro ? AppColors.success.withValues(alpha: 0.12) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final PlanInfo info;

  const _UsageCard({required this.info});

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uso atual',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _UsageRow(
              label: 'Clientes',
              used: info.clientes,
              max: info.maxClientes,
              isNear: info.nearClientes(),
            ),
            const SizedBox(height: 10),
            _UsageRow(
              label: 'Produtos',
              used: info.produtos,
              max: info.maxProdutos,
              isNear: info.nearProdutos(),
            ),
            const SizedBox(height: 10),
            _UsageRow(
              label: 'Vendas',
              used: info.vendas,
              max: info.maxVendas,
              isNear: info.nearVendas(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int used;
  final int? max;
  final bool isNear;

  const _UsageRow({
    required this.label,
    required this.used,
    required this.max,
    required this.isNear,
  });

  @override
  Widget build(BuildContext context) {
    final maxText = max?.toString() ?? '∞';
    final pct = max == null ? 1.0 : (used / max!).clamp(0.0, 1.0);
    final color = isNear ? AppColors.danger : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$used/$maxText'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: AppColors.surfaceAlt,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final PlanInfo info;

  const _WarningCard({required this.info});

  List<String> _warnings() {
    final items = <String>[];
    if (info.nearClientes()) {
      items.add('Clientes: ${info.clientes}/${info.maxClientes}');
    }
    if (info.nearProdutos()) {
      items.add('Produtos: ${info.produtos}/${info.maxProdutos}');
    }
    if (info.nearVendas()) {
      items.add('Vendas: ${info.vendas}/${info.maxVendas}');
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _warnings();
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perto do limite',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
            const SizedBox(height: 6),
            Text(
              warnings.join(' • '),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PlanInfo info;
  final bool storeAvailable;
  final bool loadingStore;
  final bool purchasePending;
  final String? storeError;
  final String? priceLabel;
  final VoidCallback onBuy;
  final VoidCallback onRestore;

  const _PurchaseCard({
    required this.info,
    required this.storeAvailable,
    required this.loadingStore,
    required this.purchasePending,
    required this.storeError,
    required this.priceLabel,
    required this.onBuy,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final price = priceLabel ?? '';

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plano Pro',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Desbloqueia limites ilimitados e recursos avancados.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (loadingStore)
              const Center(child: CircularProgressIndicator())
            else if (!storeAvailable)
              const Text(
                'Loja indisponivel no momento.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else if (storeError != null)
              Text(
                'Erro ao carregar produto: $storeError',
                style: const TextStyle(color: AppColors.textMuted),
              )
            else ...[
              if (price.isNotEmpty)
                Text(
                  'Preco: $price',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: info.isPro || purchasePending ? null : onBuy,
                  child: purchasePending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(info.isPro ? 'Plano Pro ativo' : 'Ativar Plano Pro'),
                ),
              ),
              TextButton(
                onPressed: storeAvailable ? onRestore : null,
                child: const Text('Restaurar compras'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
