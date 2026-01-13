import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'erp_revenda.db';
  static const _dbVersion = 4; // era 3

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    final db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        // CLIENTES (novo schema)
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

        // PRODUTOS
        await db.execute('''
          CREATE TABLE produtos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            preco_venda REAL NOT NULL,
            estoque REAL NOT NULL DEFAULT 0,
            ativo INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL
          );
        ''');

        // VENDAS
        await db.execute('''
          CREATE TABLE vendas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cliente_id INTEGER,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL
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

        // ENDEREÇOS DO CLIENTE
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Se vier de versões bem antigas, garante as tabelas
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS produtos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL,
              preco_venda REAL NOT NULL,
              estoque REAL NOT NULL DEFAULT 0,
              ativo INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
          ''');
        }

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

        if (oldVersion < 4) {
          // Evolui tabela clientes sem perder dados
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

          // Endereços
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
      },
    );

    _db = db;
    return db;
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
