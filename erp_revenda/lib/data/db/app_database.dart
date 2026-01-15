import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'erp_revenda.db';
  // v9: garante colunas de checkout em bases já "inconsistentes" (ex.: DB marcado como v7/v8
  // mas tabela vendas ainda sem entrega_tipo/forma_pagamento_id/etc.).
  static const _dbVersion = 18;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    final db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onOpen: (db) async {
        // Defesa extra: mesmo que a versão do DB já esteja alta, pode existir base "inconsistente"
        // (ex.: criada em builds anteriores sem todas as colunas). Garantimos o schema mínimo.
        await _ensureCheckoutSchema(db);
        await _ensureStatusLogData(db);
        await _ensureFinanceiroSchema(db);
        await _ensureProdutosSchema(db);
        await _ensureEntradasSchema(db);
        await _ensureFornecedoresSchema(db);
        await _ensureKitsSchema(db);
        await _ensureSettingsSchema(db);
      },
      onCreate: (db, version) async {
        // CLIENTES
        await db.execute('''
          CREATE TABLE clientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            apelido TEXT,
            telefone TEXT,
            telefone_whatsapp INTEGER NOT NULL DEFAULT 0,
            cpf TEXT,
            email TEXT,
            status TEXT NOT NULL DEFAULT 'ATIVO',
            created_at INTEGER NOT NULL,
            ultima_compra_at INTEGER
          );
        ''');

        await db.execute('''
          CREATE TABLE cliente_enderecos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cliente_id INTEGER NOT NULL,
            rotulo TEXT,
            cep TEXT,
            logradouro TEXT,
            numero TEXT,
            complemento TEXT,
            bairro TEXT,
            cidade TEXT,
            uf TEXT,
            principal INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');

        // FORNECEDORES
        await db.execute('''
          CREATE TABLE fornecedores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            telefone TEXT,
            email TEXT,
            contato_nome TEXT,
            contato_telefone TEXT,
            created_at INTEGER NOT NULL
          );
        ''');

        // CATEGORIAS DINÂMICAS
        await db.execute('''
          CREATE TABLE categorias (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,        -- 'OCASIAO' | 'FAMILIA' | 'PROPRIEDADE'
            nome TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');

        // PRODUTOS (novo schema)
        await db.execute('''
          CREATE TABLE produtos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            ref_codigo TEXT,
            fabricante_id INTEGER,
            fornecedor_id INTEGER,
            tipo_id INTEGER,
            preco_custo REAL NOT NULL DEFAULT 0,
            preco_venda REAL NOT NULL DEFAULT 0,
            tamanho_valor REAL,
            tamanho_unidade TEXT,      -- 'ML' | 'G' | 'UN'
            ocasiao_id INTEGER,
            familia_id INTEGER,
            estoque REAL NOT NULL DEFAULT 0,
            ativo INTEGER NOT NULL DEFAULT 1,
            is_kit INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');

        // PRODUTO x PROPRIEDADES (N:N)
        await db.execute('''
          CREATE TABLE produto_propriedades (
            produto_id INTEGER NOT NULL,
            categoria_id INTEGER NOT NULL,
            PRIMARY KEY (produto_id, categoria_id)
          );
        ''');

        await db.execute('''
          CREATE TABLE kit_itens (
            kit_id INTEGER NOT NULL,
            produto_id INTEGER NOT NULL,
            qtd REAL NOT NULL,
            PRIMARY KEY (kit_id, produto_id)
          );
        ''');

        // VENDAS
        await db.execute('''
          CREATE TABLE vendas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cliente_id INTEGER,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            desconto_valor REAL NOT NULL DEFAULT 0,
            desconto_percentual REAL,
            entrega_tipo TEXT NOT NULL DEFAULT 'ENTREGA', -- 'ENTREGA' | 'RETIRADA'
            endereco_entrega_id INTEGER,
            forma_pagamento_id INTEGER,
            parcelas INTEGER,
            observacao TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE venda_itens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            venda_id INTEGER NOT NULL,
            produto_id INTEGER NOT NULL,
            qtd REAL NOT NULL,
            preco_unit REAL NOT NULL,
            subtotal REAL NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE venda_status_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            venda_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            obs TEXT,
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE contas_receber (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            venda_id INTEGER NOT NULL,
            parcela_numero INTEGER NOT NULL,
            parcelas_total INTEGER NOT NULL,
            valor REAL NOT NULL,
            valor_recebido REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'ABERTA',
            vencimento_at INTEGER,
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE contas_pagar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entrada_id INTEGER,
            fornecedor_id INTEGER NOT NULL,
            descricao TEXT,
            total REAL NOT NULL,
            parcela_numero INTEGER NOT NULL,
            parcelas_total INTEGER NOT NULL,
            valor REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'ABERTA',
            vencimento_at INTEGER,
            pago_at INTEGER,
            created_at INTEGER NOT NULL
          );
        ''');

        // FORMAS DE PAGAMENTO
        await db.execute('''
          CREATE TABLE formas_pagamento (
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

        await _seedFormasPagamento(db);

        await db.execute('''
          CREATE TABLE fabricantes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE entradas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fornecedor_id INTEGER NOT NULL,
            data_nota INTEGER,
            data_entrada INTEGER NOT NULL,
            numero_nota TEXT,
            observacao TEXT,
            total_nota REAL NOT NULL DEFAULT 0,
            frete_total REAL NOT NULL DEFAULT 0,
            desconto_total REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'RASCUNHO',
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE entrada_itens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entrada_id INTEGER NOT NULL,
            produto_id INTEGER NOT NULL,
            qtd REAL NOT NULL,
            custo_unit REAL NOT NULL,
            subtotal REAL NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v3: vendas
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS vendas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER,
              total REAL NOT NULL,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS venda_itens (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              venda_id INTEGER NOT NULL,
              produto_id INTEGER NOT NULL,
              qtd REAL NOT NULL,
              preco_unit REAL NOT NULL,
              subtotal REAL NOT NULL
            );
          ''');
        }

        // v4: clientes evoluções + endereços
        if (oldVersion < 4) {
          await _addColumnIfMissing(db, 'clientes', 'apelido', 'TEXT');
          await _addColumnIfMissing(
            db,
            'clientes',
            'telefone_whatsapp',
            "INTEGER NOT NULL DEFAULT 0",
          );
          await _addColumnIfMissing(db, 'clientes', 'cpf', 'TEXT');
          await _addColumnIfMissing(
            db,
            'clientes',
            'status',
            "TEXT NOT NULL DEFAULT 'ATIVO'",
          );
          await _addColumnIfMissing(
            db,
            'clientes',
            'ultima_compra_at',
            'INTEGER',
          );

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cliente_enderecos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER NOT NULL,
              rotulo TEXT,
              cep TEXT,
              logradouro TEXT,
              numero TEXT,
              complemento TEXT,
              bairro TEXT,
              cidade TEXT,
              uf TEXT,
              principal INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            );
          ''');
        }

        // v5: fornecedores + categorias + produtos schema novo + produto_propriedades
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS fornecedores (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL,
              telefone TEXT,
              email TEXT,
              created_at INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS categorias (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              tipo TEXT NOT NULL,
              nome TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS produto_propriedades (
              produto_id INTEGER NOT NULL,
              categoria_id INTEGER NOT NULL,
              PRIMARY KEY (produto_id, categoria_id)
            );
          ''');

          // Evolução do schema de produtos (mantém o que já existe)
          await _addColumnIfMissing(db, 'produtos', 'ref_codigo', 'TEXT');
          await _addColumnIfMissing(db, 'produtos', 'fabricante', 'TEXT');
          await _addColumnIfMissing(db, 'produtos', 'fornecedor_id', 'INTEGER');
          await _addColumnIfMissing(
            db,
            'produtos',
            'preco_custo',
            'REAL NOT NULL DEFAULT 0',
          );
          // preco_venda já existia (mas garantimos)
          await _addColumnIfMissing(db, 'produtos', 'tamanho_valor', 'REAL');
          await _addColumnIfMissing(db, 'produtos', 'tamanho_unidade', 'TEXT');
          await _addColumnIfMissing(db, 'produtos', 'ocasiao_id', 'INTEGER');
          await _addColumnIfMissing(db, 'produtos', 'familia_id', 'INTEGER');
        }

        if (oldVersion < 6) {
          await db.execute('''
      CREATE TABLE IF NOT EXISTS fabricantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

          await _addColumnIfMissing(db, 'produtos', 'fabricante_id', 'INTEGER');
          // Se você ainda tem a coluna antiga "fabricante" (texto), pode manter por enquanto.
        }
        if (oldVersion < 7) {
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

          await _addColumnIfMissing(
            db,
            'vendas',
            'entrega_tipo',
            "TEXT NOT NULL DEFAULT 'ENTREGA'",
          );
          await _addColumnIfMissing(
            db,
            'vendas',
            'endereco_entrega_id',
            'INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'vendas',
            'forma_pagamento_id',
            'INTEGER',
          );
          await _addColumnIfMissing(db, 'vendas', 'parcelas', 'INTEGER');
          await _addColumnIfMissing(db, 'vendas', 'observacao', 'TEXT');

          await _seedFormasPagamento(db);
        }

        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS venda_status_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              venda_id INTEGER NOT NULL,
              status TEXT NOT NULL,
              obs TEXT,
              created_at INTEGER NOT NULL
            );
          ''');
        }

        // v9: reforço para bases que por algum motivo chegaram em v7/v8 sem as colunas de checkout
        // na tabela vendas (ou sem as tabelas auxiliares).
        if (oldVersion < 9) {
          await _ensureCheckoutSchema(db);
        }

        if (oldVersion < 11) {
          await _ensureFinanceiroSchema(db);
        }
        if (oldVersion < 12) {
          await _ensureProdutosSchema(db);
        }
        if (oldVersion < 13) {
          await _ensureFinanceiroSchema(db);
        }
        if (oldVersion < 14) {
          await _ensureEntradasSchema(db);
        }
        if (oldVersion < 15) {
          await _ensureFinanceiroSchema(db);
        }
        if (oldVersion < 16) {
          await _ensureFornecedoresSchema(db);
        }
        if (oldVersion < 17) {
          await _ensureKitsSchema(db);
        }
        if (oldVersion < 18) {
          await _ensureSettingsSchema(db);
        }
      },
    );

    _db = db;
    return db;
  }

  Future<String> dbPath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbName);
  }

  Future<void> close() async {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _db = null;
  }

  static Future<void> _ensureCheckoutSchema(Database db) async {
    // Garante tabela base (caso o app tenha sido instalado em alguma versão antiga)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        total REAL NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    // Colunas de checkout/pagamento/entrega
    await _addColumnIfMissing(
      db,
      'vendas',
      'entrega_tipo',
      "TEXT NOT NULL DEFAULT 'ENTREGA'",
    );
    await _addColumnIfMissing(db, 'vendas', 'endereco_entrega_id', 'INTEGER');
    await _addColumnIfMissing(db, 'vendas', 'forma_pagamento_id', 'INTEGER');
    await _addColumnIfMissing(db, 'vendas', 'parcelas', 'INTEGER');
    await _addColumnIfMissing(db, 'vendas', 'observacao', 'TEXT');

    // Tabelas auxiliares do checkout
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS venda_status_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        obs TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    await _seedFormasPagamento(db);
  }

  static Future<void> _ensureStatusLogData(Database db) async {
    final rows = await db.rawQuery('''
      SELECT v.id, v.status, v.created_at
      FROM vendas v
      LEFT JOIN venda_status_log l ON l.venda_id = v.id
      WHERE l.id IS NULL
        AND v.status IS NOT NULL
        AND v.status <> 'ABERTA'
    ''');

    if (rows.isEmpty) return;

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;

      final status = (row['status'] as String?) ?? 'PEDIDO';
      final createdAt = (row['created_at'] as int?) ?? now;

      batch.insert('venda_status_log', {
        'venda_id': id,
        'status': status,
        'obs': null,
        'created_at': createdAt,
      });
    }

    await batch.commit(noResult: true);
  }

  static Future<void> _ensureFinanceiroSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contas_receber (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL,
        parcela_numero INTEGER NOT NULL,
        parcelas_total INTEGER NOT NULL,
        valor REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'ABERTA',
        vencimento_at INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    await _addColumnIfMissing(
      db,
      'contas_receber',
      'vencimento_at',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'contas_receber',
      'valor_recebido',
      'REAL NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS contas_pagar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entrada_id INTEGER,
        fornecedor_id INTEGER NOT NULL,
        descricao TEXT,
        total REAL NOT NULL,
        parcela_numero INTEGER NOT NULL,
        parcelas_total INTEGER NOT NULL,
        valor REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'ABERTA',
        vencimento_at INTEGER,
        pago_at INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'entrada_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'descricao',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'total',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'parcela_numero',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'parcelas_total',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'valor',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'status',
      "TEXT NOT NULL DEFAULT 'ABERTA'",
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'vencimento_at',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'contas_pagar',
      'pago_at',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'formas_pagamento',
      'permite_vencimento',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _addColumnIfMissing(
      db,
      'vendas',
      'desconto_valor',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'vendas', 'desconto_percentual', 'REAL');
  }

  static Future<void> _ensureProdutosSchema(Database db) async {
    await _addColumnIfMissing(db, 'produtos', 'tipo_id', 'INTEGER');
  }

  static Future<void> _ensureEntradasSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entradas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fornecedor_id INTEGER NOT NULL,
        data_nota INTEGER,
        data_entrada INTEGER NOT NULL,
        numero_nota TEXT,
        observacao TEXT,
        total_nota REAL NOT NULL DEFAULT 0,
        frete_total REAL NOT NULL DEFAULT 0,
        desconto_total REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'RASCUNHO',
        created_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entrada_itens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entrada_id INTEGER NOT NULL,
        produto_id INTEGER NOT NULL,
        qtd REAL NOT NULL,
        custo_unit REAL NOT NULL,
        subtotal REAL NOT NULL
      );
    ''');

    await _addColumnIfMissing(db, 'entradas', 'data_nota', 'INTEGER');
    await _addColumnIfMissing(db, 'entradas', 'data_entrada', 'INTEGER');
    await _addColumnIfMissing(db, 'entradas', 'numero_nota', 'TEXT');
    await _addColumnIfMissing(db, 'entradas', 'observacao', 'TEXT');
    await _addColumnIfMissing(
      db,
      'entradas',
      'total_nota',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'entradas',
      'frete_total',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'entradas',
      'desconto_total',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'entradas',
      'status',
      "TEXT NOT NULL DEFAULT 'RASCUNHO'",
    );
  }

  static Future<void> _ensureFornecedoresSchema(Database db) async {
    await _addColumnIfMissing(db, 'fornecedores', 'contato_nome', 'TEXT');
    await _addColumnIfMissing(db, 'fornecedores', 'contato_telefone', 'TEXT');
  }

  static Future<void> _ensureKitsSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      'produtos',
      'is_kit',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kit_itens (
        kit_id INTEGER NOT NULL,
        produto_id INTEGER NOT NULL,
        qtd REAL NOT NULL,
        PRIMARY KEY (kit_id, produto_id)
      );
    ''');
  }

  static Future<void> _ensureSettingsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
  }

  static Future<void> _seedFormasPagamento(Database db) async {
    // Insere formas padrão apenas se a tabela estiver vazia
    final rows = await db.rawQuery(
      'SELECT COUNT(1) AS c FROM formas_pagamento;',
    );
    final count = (rows.first['c'] as int?) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    Future<void> ins({
      required String nome,
      required bool permiteDesconto,
      required bool permiteParcelamento,
      required int maxParcelas,
    }) async {
      await db.insert('formas_pagamento', {
        'nome': nome,
        'permite_desconto': permiteDesconto ? 1 : 0,
        'permite_parcelamento': permiteParcelamento ? 1 : 0,
        'max_parcelas': maxParcelas,
        'ativo': 1,
        'created_at': now,
      });
    }

    await ins(
      nome: 'Pix',
      permiteDesconto: true,
      permiteParcelamento: false,
      maxParcelas: 1,
    );
    await ins(
      nome: 'Pix Parcelado',
      permiteDesconto: true,
      permiteParcelamento: true,
      maxParcelas: 6,
    );
    await ins(
      nome: 'Cartão de débito',
      permiteDesconto: true,
      permiteParcelamento: false,
      maxParcelas: 1,
    );
    await ins(
      nome: 'Cartão de crédito à vista',
      permiteDesconto: true,
      permiteParcelamento: false,
      maxParcelas: 1,
    );
    await ins(
      nome: 'Cartão de crédito parcelado',
      permiteDesconto: true,
      permiteParcelamento: true,
      maxParcelas: 12,
    );
  }


  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table);');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
  }
}
