import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static const int _databaseVersion = 12;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla pending_photos
    await db.execute('''
      CREATE TABLE pending_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL,
        image_path TEXT NOT NULL,
        tipo TEXT, 
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT
      )
    ''');

    // Tabla orders
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        numero_orden TEXT NOT NULL UNIQUE,
        nombre_cliente TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        valor_servicio REAL,
        celular TEXT,
        direccion TEXT,
        observaciones TEXT,
        fecha_programada TEXT,
        status TEXT NOT NULL,
        synced_at INTEGER,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        fecha_llegada TEXT,
        solucion_tecnico TEXT,
        mac_router TEXT,
        mac_bridge TEXT,
        mac_ont TEXT,
        otros_equipos TEXT,
        firma_tecnico TEXT,
        firma_suscriptor TEXT,
        articulos TEXT,
        technician_id INTEGER,
        cliente_id INTEGER,
        cedula TEXT,
        precinto TEXT,
        tipo_orden TEXT,
        tipo_funcion TEXT,
        fecha_trn TEXT,
        fecha_vencimiento TEXT,
        estado_orden TEXT,
        tipo TEXT,
        estado_interno TEXT,
        direccion_asociado TEXT,
        telefono TEXT,
        otro_telefono TEXT,
        telefono_facturacion TEXT,
        saldo_cliente TEXT,
        solicitado_por TEXT,
        estado_tv TEXT,
        tecnico_auxiliar_id INTEGER,
        solicitud_suscriptor TEXT,
        fecha_inicio_atencion TEXT,
        fecha_fin_atencion TEXT,
        fecha_cierre TEXT,
        plan_internet TEXT,
        novedades_noc TEXT,
        codigo_contrato TEXT,
        barrio TEXT,
        coordenadas TEXT,
        prioridad INTEGER DEFAULT 0,
        clasificacion TEXT,
        tipo_servicio TEXT
      )
    ''');

    // Tabla pending_operations
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        order_number TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Tabla sync_metadata
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Inicializar sync_metadata
    await db.insert('sync_metadata', {
      'key': 'last_sync_orders',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'last_sync_profile',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'pending_operations_count',
      'value': '0',
    });
    await db.insert('sync_metadata', {
      'key': 'sync_status',
      'value': 'idle',
    });

    // Índices para velocidad extrema de búsquedas y listas
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_estado ON orders(estado_orden)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_technician ON orders(technician_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_numero ON orders(numero_orden)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_photos_status ON pending_photos(sync_status)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrar pending_photos
      await db.execute('''
        ALTER TABLE pending_photos 
        ADD COLUMN created_at INTEGER DEFAULT (strftime('%s', 'now'))
      ''');
      await db.execute('''
        ALTER TABLE pending_photos 
        ADD COLUMN sync_status TEXT DEFAULT 'pending'
      ''');

      // Crear nuevas tablas
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY,
          numero_orden TEXT NOT NULL UNIQUE,
          nombre_cliente TEXT NOT NULL,
          fecha_hora TEXT NOT NULL,
          valor_servicio REAL,
          celular TEXT,
          direccion TEXT,
          observaciones TEXT,
          fecha_programada TEXT,
          status TEXT NOT NULL,
          synced_at INTEGER,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      await db.execute('''
        CREATE TABLE pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_type TEXT NOT NULL,
          order_number TEXT NOT NULL,
          operation_data TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');

      // Inicializar sync_metadata
      await db.insert('sync_metadata', {
        'key': 'last_sync_orders',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'last_sync_profile',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'pending_operations_count',
        'value': '0',
      });
      await db.insert('sync_metadata', {
        'key': 'sync_status',
        'value': 'idle',
      });
    }

    if (oldVersion < 5) {
      // Legacy cleanup/migration handled in previous versions or table recreation
    }

    if (oldVersion < 6) {
       try { await db.execute('ALTER TABLE orders ADD COLUMN direccion TEXT'); } catch (_) {}
       try { await db.execute('ALTER TABLE orders ADD COLUMN observaciones TEXT'); } catch (_) {}
    }

    if (oldVersion < 7) {
      // Ensure all other new columns exist
      final columns = [
        'fecha_llegada', 'solucion_tecnico', 'mac_router', 'mac_bridge', 
        'mac_ont', 'otros_equipos', 'firma_tecnico', 'firma_suscriptor', 'articulos'
      ];
      for (var col in columns) {
        try { await db.execute('ALTER TABLE orders ADD COLUMN $col TEXT'); } catch (_) {}
      }
    }

    if (oldVersion < 8) {
      final newColumns = [
        'technician_id INTEGER',
        'cliente_id INTEGER',
        'cedula TEXT',
        'precinto TEXT',
        'tipo_orden TEXT',
        'tipo_funcion TEXT',
        'fecha_trn TEXT',
        'fecha_vencimiento TEXT',
        'estado_orden TEXT',
        'tipo TEXT',
        'estado_interno TEXT',
        'direccion_asociado TEXT',
        'telefono TEXT',
        'otro_telefono TEXT',
        'saldo_cliente TEXT',
        'solicitado_por TEXT',
        'estado_tv TEXT',
        'tecnico_auxiliar_id INTEGER',
        'solicitud_suscriptor TEXT',
        'fecha_inicio_atencion TEXT',
        'fecha_fin_atencion TEXT',
        'fecha_cierre TEXT'
      ];
      
      for (var colDef in newColumns) {
        try { await db.execute('ALTER TABLE orders ADD COLUMN $colDef'); } catch (_) {}
      }
    }

    if (oldVersion < 9) {
       try { await db.execute('ALTER TABLE pending_photos ADD COLUMN tipo TEXT'); } catch (_) {}
    }
    
    // Fallback block if table existed before we added these three
    try { await db.execute('ALTER TABLE orders ADD COLUMN plan_internet TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN novedades_noc TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN codigo_contrato TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN barrio TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN telefono_facturacion TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN coordenadas TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN prioridad INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN clasificacion TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE orders ADD COLUMN tipo_servicio TEXT'); } catch (_) {}

    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_estado ON orders(estado_orden)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_technician ON orders(technician_id)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_numero ON orders(numero_orden)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_barrio ON orders(barrio)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_photos_status ON pending_photos(sync_status)'); } catch (_) {}
  }

  // ========== PENDING PHOTOS ==========
  Future<int> addPendingPhoto(String orderNumber, String imagePath, {String? tipo}) async {
    final db = await database;
    return await db.insert('pending_photos', {
      'order_number': orderNumber,
      'image_path': imagePath,
      'tipo': tipo,
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    final db = await database;
    return await db.query('pending_photos', orderBy: 'id');
  }

  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(String orderNumber) async {
    final db = await database;
    return await db.query(
      'pending_photos',
      where: 'order_number = ?',
      whereArgs: [orderNumber],
    );
  }

  Future<void> deletePendingPhoto(int id) async {
    final db = await database;
    await db.delete('pending_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingPhotoError(int id, String error) async {
    final db = await database;
    await db.update(
      'pending_photos',
      {'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== ORDERS ==========
  Future<void> saveOrder(Map<String, dynamic> orderData) async {
    final db = await database;
    await db.insert(
      'orders',
      orderData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    if (orders.isEmpty) return;
    final db = await database;

    final numbers = orders
        .map((o) => o['numero_orden']?.toString())
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (numbers.isEmpty) return;

    // Obtener todas las órdenes existentes en una sola consulta ultra rápida
    final placeholders = List.filled(numbers.length, '?').join(',');
    final existingRows = await db.query(
      'orders',
      where: 'numero_orden IN ($placeholders)',
      whereArgs: numbers,
    );

    final existingMap = {
      for (var row in existingRows) row['numero_orden'].toString(): Map<String, dynamic>.from(row)
    };

    final batch = db.batch();
    for (var order in orders) {
      final number = order['numero_orden']?.toString();
      if (number == null) continue;

      final existing = existingMap[number];
      if (existing != null) {
        final newMap = Map<String, dynamic>.from(order);
        newMap.forEach((key, value) {
          if (value == null && existing[key] != null) {
            newMap[key] = existing[key];
          }
        });

        batch.update(
          'orders',
          newMap,
          where: 'numero_orden = ?',
          whereArgs: [number],
        );
      } else {
        batch.insert(
          'orders',
          order,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Reconcilia las órdenes de un estado específico con la lista devuelta por el servidor.
  /// Cualquier orden local en este estado que NO esté en [serverOrderNumbers]
  /// y NO tenga operaciones pendientes offline será eliminada de SQLite.
  Future<void> reconcileOrdersForStatus({
    required String status,
    required List<String> serverOrderNumbers,
    int? technicianId,
  }) async {
    final db = await database;

    // Proteger órdenes con operaciones o fotos pendientes de subir
    final pendingOps = await db.query('pending_operations', columns: ['order_number']);
    final pendingPhotos = await db.query('pending_photos', columns: ['order_number']);

    final protectedNumbers = <String>{
      ...pendingOps.map((r) => r['order_number'].toString()),
      ...pendingPhotos.map((r) => r['order_number'].toString()),
    };

    final serverSet = serverOrderNumbers.toSet();

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    final s = status.toLowerCase().trim();
    if (s == 'especiales') {
      whereClauses.add("(LOWER(status) IN ('reasignar', 'reprogramada') OR LOWER(estado_orden) IN ('reasignar', 'reprogramada'))");
    } else if (s != 'todas' && s.isNotEmpty) {
      whereClauses.add("(LOWER(status) = ? OR LOWER(estado_orden) = ?)");
      whereArgs.addAll([s, s]);
    }

    if (technicianId != null) {
      whereClauses.add("(technician_id = ? OR technician_id IS NULL)");
      whereArgs.add(technicianId);
    }

    final localRows = await db.query(
      'orders',
      columns: ['numero_orden'],
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    final toRemove = <String>[];
    for (var row in localRows) {
      final num = row['numero_orden']?.toString();
      if (num != null && !serverSet.contains(num) && !protectedNumbers.contains(num)) {
        toRemove.add(num);
      }
    }

    if (toRemove.isNotEmpty) {
      final batch = db.batch();
      for (var num in toRemove) {
        batch.delete('orders', where: 'numero_orden = ?', whereArgs: [num]);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Elimina órdenes ejecutadas o cerradas locales que ya no tienen operaciones pendientes
  Future<void> purgeSyncedExecutedOrders() async {
    final db = await database;

    final pendingOps = await db.query('pending_operations', columns: ['order_number']);
    final pendingPhotos = await db.query('pending_photos', columns: ['order_number']);

    final protectedNumbers = <String>{
      ...pendingOps.map((r) => r['order_number'].toString()),
      ...pendingPhotos.map((r) => r['order_number'].toString()),
    };

    final executedRows = await db.query(
      'orders',
      columns: ['numero_orden'],
      where: "LOWER(status) IN ('ejecutada', 'cerrada', 'anulada') OR LOWER(estado_orden) IN ('ejecutada', 'cerrada', 'anulada')",
    );

    final toDelete = <String>[];
    for (var row in executedRows) {
      final num = row['numero_orden']?.toString();
      if (num != null && !protectedNumbers.contains(num)) {
        toDelete.add(num);
      }
    }

    if (toDelete.isNotEmpty) {
      final batch = db.batch();
      for (var num in toDelete) {
        batch.delete('orders', where: 'numero_orden = ?', whereArgs: [num]);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? search,
    String? barrio,
    int? technicianId,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // 1. Filtro de Estado
    if (status != null && status != 'todas' && status.isNotEmpty) {
      final s = status.toLowerCase().trim();
      if (s == 'especiales') {
        whereClauses.add("(LOWER(status) IN ('reasignar', 'reprogramada') OR LOWER(estado_orden) IN ('reasignar', 'reprogramada'))");
      } else {
        whereClauses.add("(LOWER(status) = ? OR LOWER(estado_orden) = ?)");
        whereArgs.addAll([s, s]);
      }
    }

    // 2. Filtro de Búsqueda Offline
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      whereClauses.add(
        "(numero_orden LIKE ? OR nombre_cliente LIKE ? OR direccion LIKE ? OR cedula LIKE ? OR telefono LIKE ? OR codigo_contrato LIKE ?)"
      );
      whereArgs.addAll([term, term, term, term, term, term]);
    }

    // 3. Filtro de Barrio Offline
    if (barrio != null && barrio.trim().isNotEmpty) {
      whereClauses.add("barrio LIKE ?");
      whereArgs.add('%${barrio.trim()}%');
    }

    // 4. Técnico asignado
    if (technicianId != null) {
      whereClauses.add("(technician_id = ? OR technician_id IS NULL)");
      whereArgs.add(technicianId);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    return await db.query(
      'orders',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'prioridad DESC, fecha_hora DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersInProcess({int? technicianId}) async {
    final db = await database;
    final whereClauses = <String>[
      "(LOWER(status) IN ('en_proceso', 'en_sitio', 'en proceso', 'en sitio') OR LOWER(estado_orden) IN ('en_proceso', 'en_sitio', 'en proceso', 'en sitio'))"
    ];
    final whereArgs = <dynamic>[];

    if (technicianId != null) {
      whereClauses.add("(technician_id = ? OR technician_id IS NULL)");
      whereArgs.add(technicianId);
    }

    return await db.query(
      'orders',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'prioridad DESC, fecha_hora DESC',
    );
  }

  Future<Map<String, dynamic>?> getOrderByNumber(String numeroOrden) async {
    final db = await database;
    final results = await db.query(
      'orders',
      where: 'numero_orden = ?',
      whereArgs: [numeroOrden],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateOrder(String numeroOrden, Map<String, dynamic> updates) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'orders',
      updates,
      where: 'numero_orden = ?',
      whereArgs: [numeroOrden],
    );
  }

  Future<void> deleteOrder(String numeroOrden) async {
    final db = await database;
    await db.delete('orders', where: 'numero_orden = ?', whereArgs: [numeroOrden]);
  }

  // ========== PENDING OPERATIONS ==========
  Future<int> addPendingOperation({
    required String operationType,
    required String orderNumber,
    required Map<String, dynamic> operationData,
  }) async {
    final db = await database;
    final id = await db.insert('pending_operations', {
      'operation_type': operationType,
      'order_number': orderNumber,
      'operation_data': jsonEncode(operationData),
    });
    await _updatePendingOperationsCount();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getPendingOperationsForOrder(String orderNumber) async {
    final db = await database;
    return await db.query(
      'pending_operations',
      where: 'order_number = ?',
      whereArgs: [orderNumber],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deletePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
    await _updatePendingOperationsCount();
  }

  Future<void> incrementRetryCount(int id, String? error) async {
    final db = await database;
    final result = await db.query(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
      columns: ['retry_count'],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final currentCount = result.first['retry_count'] as int;
      await db.update(
        'pending_operations',
        {
          'retry_count': currentCount + 1,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }



  // ========== SYNC METADATA ==========
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<int> getLastSyncOrders() async {
    final value = await getSyncMetadata('last_sync_orders');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> setLastSyncOrders(int timestamp) async {
    await setSyncMetadata('last_sync_orders', timestamp.toString());
  }

  Future<int> getLastSyncProfile() async {
    final value = await getSyncMetadata('last_sync_profile');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> setLastSyncProfile(int timestamp) async {
    await setSyncMetadata('last_sync_profile', timestamp.toString());
  }

  Future<String> getSyncStatus() async {
    return await getSyncMetadata('sync_status') ?? 'idle';
  }

  Future<void> setSyncStatus(String status) async {
    await setSyncMetadata('sync_status', status);
  }

  Future<int> getPendingOperationsCount() async {
    final value = await getSyncMetadata('pending_operations_count');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<void> _updatePendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_operations');
    final count = result.first['count'] as int;
    await setSyncMetadata('pending_operations_count', count.toString());
  }
}