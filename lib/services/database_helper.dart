import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/client_model.dart';
import '../models/budget_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budget_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // 👈 Subimos la versión a 2
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // 👈 Si la versión anterior es menor a 2, agregamos la columna title a la tabla existente
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE budgets ADD COLUMN title TEXT DEFAULT 'Cotización'");
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Tabla de Clientes
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT
      )
    ''');

    // 2. Tabla de Presupuestos (Cabecera)
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    // 3. Tabla de Ítems del Presupuesto (Detalle)
    await db.execute('''
      CREATE TABLE budget_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- MÉTODOS PARA CLIENTES ---
  
  Future<int> insertClient(Client client) async {
    final db = await instance.database;
    return await db.insert('clients', client.toMap());
  }

  Future<List<Client>> getClients() async {
    final db = await instance.database;
    final result = await db.query('clients', orderBy: 'name ASC');
    return result.map((map) => Client.fromMap(map)).toList();
  }

  // Actualizar un cliente existente
  Future<int> updateClient(Client client) async {
    final db = await database;
    return await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  // Eliminar un cliente por su ID
  Future<int> deleteClient(int id) async {
    final db = await database;
    return await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  // --- MÉTODOS PARA PRESUPUESTOS (BUDGETS) ---

  // Guardar un presupuesto completo con sus ítems en transacción segura
  Future<int> insertBudget(Budget budget) async {
    final db = await instance.database;
    
    return await db.transaction((txn) async {
      // 1. Insertar la cabecera
      final budgetId = await txn.insert('budgets', {
        'client_id': budget.clientId,
        'title': budget.title, 
        'date': budget.date,
        'total_amount': budget.totalAmount,
        'status': budget.status,
      });

      // 2. Insertar los ítems asociados
      for (var item in budget.items) {
        await txn.insert('budget_items', {
          'budget_id': budgetId,
          'description': item.description,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
        });
      }

      return budgetId;
    });
  }


// Método para actualizar un presupuesto existente
  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    
    // 1. Actualizamos los datos principales de la tabla 'budgets'
    int result = await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );

    // 2. Para los ítems, lo más limpio y seguro es borrar los ítems anteriores de este presupuesto e insertar los nuevos actualizados
    await db.delete(
      'budget_items',
      where: 'budget_id = ?',
      whereArgs: [budget.id],
    );

    for (var item in budget.items) {
      final itemMap = item.toMap();
      itemMap['budget_id'] = budget.id; // Aseguramos que pertenezca a este presupuesto
      await db.insert('budget_items', itemMap);
    }

    return result;
  }
  
  // Obtener un presupuesto por su ID
  Future<Budget?> getBudgetById(int id) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final budgetMap = maps.first;
      // Consultar también sus ítems asociados
      final itemMaps = await db.query(
        'budget_items',
        where: 'budget_id = ?',
        whereArgs: [id],
      );

      List<BudgetItem> items = itemMaps.map((item) => BudgetItem.fromMap(item)).toList();

      return Budget(
        id: budgetMap['id'] as int,
        clientId: budgetMap['client_id'] as int,
        title: budgetMap['title'] as String,
        date: budgetMap['date'] as String,
        totalAmount: budgetMap['total_amount'] as double,
        status: budgetMap['status'] as String,
        items: items,
      );
    }
    return null;
  }

  // Obtener un cliente por su ID
  Future<Client?> getClientById(int id) async {
    final db = await database;
    final maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Client.fromMap(maps.first);
    }
    return null;
  }
  
  // Obtener todos los presupuestos con sus respectivos ítems
  Future<List<Budget>> getBudgets() async {
    final db = await instance.database;
    
    final budgetMaps = await db.query('budgets', orderBy: 'date DESC');
    List<Budget> budgets = [];

    for (var bMap in budgetMaps) {
      final budgetId = bMap['id'] as int;

      final itemMaps = await db.query(
        'budget_items',
        where: 'budget_id = ?',
        whereArgs: [budgetId],
      );

      List<BudgetItem> items = itemMaps.map((iMap) => BudgetItem.fromMap(iMap)).toList();

      budgets.add(Budget.fromMap(bMap, items));
    }

    return budgets;
  }

  // Eliminar presupuesto (los ítems se eliminan automáticamente por CASCADE)
  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Cerrar base de datos
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}