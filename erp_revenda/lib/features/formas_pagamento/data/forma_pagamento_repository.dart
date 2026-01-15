import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'forma_pagamento_model.dart';

class FormaPagamentoRepository {
  final AppDatabase _db;
  FormaPagamentoRepository(this._db);

  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS formas_pagamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        permite_desconto INTEGER NOT NULL DEFAULT 0,
        permite_parcelamento INTEGER NOT NULL DEFAULT 0,
        permite_vencimento INTEGER NOT NULL DEFAULT 0,
        max_parcelas INTEGER NOT NULL DEFAULT 1,
        ativo INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      );
    ''');
  }

  Future<void> _ensureSeed(Database db) async {
    // evita duplicar seeds
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM formas_pagamento');
    final count = (rows.first['c'] as int?) ?? 0;
    if (count > 0) return;

    final now = DateTime.now();
    final seeds = <FormaPagamento>[
      FormaPagamento(
        nome: 'Pix',
        permiteDesconto: true,
        permiteParcelamento: false,
        permiteInformarVencimento: false,
        maxParcelas: 1,
        ativo: true,
        createdAt: now,
      ),
      FormaPagamento(
        nome: 'Pix Parcelado',
        permiteDesconto: true,
        permiteParcelamento: true,
        permiteInformarVencimento: false,
        maxParcelas: 6,
        ativo: true,
        createdAt: now,
      ),
      FormaPagamento(
        nome: 'Cartão de débito',
        permiteDesconto: false,
        permiteParcelamento: false,
        permiteInformarVencimento: false,
        maxParcelas: 1,
        ativo: true,
        createdAt: now,
      ),
      FormaPagamento(
        nome: 'Cartão de crédito à vista',
        permiteDesconto: false,
        permiteParcelamento: false,
        permiteInformarVencimento: false,
        maxParcelas: 1,
        ativo: true,
        createdAt: now,
      ),
      FormaPagamento(
        nome: 'Cartão de crédito parcelado',
        permiteDesconto: false,
        permiteParcelamento: true,
        permiteInformarVencimento: false,
        maxParcelas: 12,
        ativo: true,
        createdAt: now,
      ),
    ];

    final batch = db.batch();
    for (final fp in seeds) {
      batch.insert('formas_pagamento', fp.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureReady(Database db) async {
    await _ensureTable(db);
    await _ensureSeed(db);
  }

  Future<List<FormaPagamento>> listar({
    String search = '',
    bool onlyActive = true,
  }) async {
    final Database db = await _db.database;
    await _ensureReady(db);

    final where = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      where.add('ativo = 1');
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      where.add('nome LIKE ?');
      args.add('%$q%');
    }

    final rows = await db.query(
      'formas_pagamento',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => FormaPagamento.fromMap(e)).toList();
  }

  Future<int> inserir(FormaPagamento fp) async {
    final db = await _db.database;
    await _ensureReady(db);
    return db.insert('formas_pagamento', fp.toMap());
  }

  Future<int> atualizar(FormaPagamento fp) async {
    final db = await _db.database;
    await _ensureReady(db);

    final id = fp.id;
    if (id == null) {
      throw ArgumentError('FormaPagamento.id não pode ser nulo no update');
    }
    return db.update(
      'formas_pagamento',
      fp.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> salvar(FormaPagamento fp) async {
    if (fp.id == null) {
      await inserir(fp);
    } else {
      await atualizar(fp);
    }
  }

  Future<void> setAtivo(int id, bool ativo) async {
    final db = await _db.database;
    await _ensureReady(db);
    await db.update(
      'formas_pagamento',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
