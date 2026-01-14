import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import '../../clientes/data/cliente_model.dart';
import '../../categorias/data/categoria_model.dart';
import 'cadastros_resumo.dart';

class CadastrosResumoRepository {
  final AppDatabase _db;
  CadastrosResumoRepository(this._db);

  Future<CadastrosResumo> carregar() async {
    final Database db = await _db.database;

    Future<int> count(String sql, [List<Object?> args = const []]) async {
      try {
        final res = await db.rawQuery(sql, args);
        if (res.isEmpty) return 0;
        final v = res.first.values.first;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      } catch (_) {
        // Se uma tabela ainda não existir (migração antiga), não quebra a tela.
        return 0;
      }
    }

    final clientesTotal =
        await count('SELECT COUNT(*) as c FROM clientes');
    final clientesAtivos = await count(
      'SELECT COUNT(*) as c FROM clientes WHERE status = ?',
      [ClienteStatus.ativo.dbValue],
    );

    final produtosAtivos =
        await count('SELECT COUNT(*) as c FROM produtos WHERE ativo = 1');
    final produtosComSaldo = await count(
      'SELECT COUNT(*) as c FROM produtos WHERE ativo = 1 AND estoque > 0',
    );

    final fornecedores =
        await count('SELECT COUNT(*) as c FROM fornecedores');
    final fabricantes =
        await count('SELECT COUNT(*) as c FROM fabricantes');

    final categoriasTipoProduto = await count(
      'SELECT COUNT(*) as c FROM categorias WHERE tipo = ?',
      [CategoriaTipo.tipoProduto.db],
    );

    final categoriasOcasiao = await count(
      'SELECT COUNT(*) as c FROM categorias WHERE tipo = ?',
      [CategoriaTipo.ocasiao.db],
    );
    final categoriasFamilia = await count(
      'SELECT COUNT(*) as c FROM categorias WHERE tipo = ?',
      [CategoriaTipo.familia.db],
    );
    final categoriasPropriedade = await count(
      'SELECT COUNT(*) as c FROM categorias WHERE tipo = ?',
      [CategoriaTipo.propriedade.db],
    );

    return CadastrosResumo(
      clientesTotal: clientesTotal,
      clientesAtivos: clientesAtivos,
      produtosAtivos: produtosAtivos,
      produtosComSaldo: produtosComSaldo,
      fornecedores: fornecedores,
      fabricantes: fabricantes,
      categoriasTipoProduto: categoriasTipoProduto,
      categoriasOcasiao: categoriasOcasiao,
      categoriasFamilia: categoriasFamilia,
      categoriasPropriedade: categoriasPropriedade,
    );
  }
}
