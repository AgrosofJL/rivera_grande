import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as inMemoryDatabaseFactory show openDatabase;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

// ESTO LO MODIFIQUE: Para Web usamos inMemoryDatabaseFactory sin WASM ni Workers raros
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final supabase = Supabase.instance.client;

  // Retorna Database normal (NO nulo) -> Desaparecen los 170 errores de compilación
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

 Future<Database> _initDatabase() async {
    // ACA ES LO NUEVO: En Web se usa la fábrica en memoria de sqflite sin getDatabasesPath
    if (kIsWeb) {
      return await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: _onCreate,
        ),
      );
    }

    // Para Celulares (Android / iOS)
    String path = join(await getDatabasesPath(), 'la_rivera_celdas.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < newVersion) {
          await _onUpgradeDropTables(db);
          _onCreate(db, newVersion);
        }
      },
    );
  }

  Future<void> _onUpgradeDropTables(Database db) async {
    await db.execute("DROP TABLE IF EXISTS usuario_local");
    await db.execute("DROP TABLE IF EXISTS celdas_control_calidad_calibre");
    await db.execute("DROP TABLE IF EXISTS celdas_historial");
    await db.execute("DROP TABLE IF EXISTS celdas_recepcion");
    await db.execute("DROP TABLE IF EXISTS control_calidad");
    await db.execute("DROP TABLE IF EXISTS detalle_despacho");
    await db.execute("DROP TABLE IF EXISTS embolsado_bag");
    await db.execute("DROP TABLE IF EXISTS empaque_armado_bins");
    await db.execute("DROP TABLE IF EXISTS volcado_bag");
    await db.execute("DROP TABLE IF EXISTS volcado_bins");
    await db.execute("DROP TABLE IF EXISTS inventario");
    await db.execute("DROP TABLE IF EXISTS parametros_calibre");
    await db.execute("DROP TABLE IF EXISTS parametros_calidad");
    await db.execute("DROP TABLE IF EXISTS parametros_celdas");
    await db.execute("DROP TABLE IF EXISTS parametros_depositos");
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Sesión Local
    await db.execute('''CREATE TABLE usuario_local (
      id INTEGER PRIMARY KEY, correo TEXT, operario TEXT, 
      establecimiento TEXT, clave TEXT, device_id TEXT, rol TEXT,
      sincronizado INTEGER DEFAULT 0
    )''');

    // 2. Tablas Operativas y Registros
    await db.execute('''CREATE TABLE celdas_control_calidad_calibre (
      reg_local TEXT PRIMARY KEY, id INTEGER, cod_historial TEXT, fecha TEXT, 
      cod_celda TEXT, celda_numero TEXT, productor TEXT, lote TEXT, cultivo TEXT, 
      variedad TEXT, lote_proceso TEXT, calidad_final TEXT, cal1 TEXT, nro_1 TEXT, 
      cal2 TEXT, nro_2 TEXT, cal3 TEXT, nro_3 TEXT, cal4 TEXT, nro_4 TEXT, 
      estado_celda TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE celdas_historial (
      registro INTEGER PRIMARY KEY AUTOINCREMENT, reg_local TEXT UNIQUE, 
      fecha TEXT, hora TEXT, cod_celda TEXT, celda_numero TEXT, productor TEXT, 
      cuadro TEXT, cultivo TEXT, variedad TEXT, calidad TEXT, lote_proceso TEXT, 
      usuario TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE celdas_recepcion (
      reg_local TEXT PRIMARY KEY, id INTEGER, fecha_reg TEXT, hora TEXT, 
      cod_celda TEXT, cuadro TEXT, celda_numero TEXT, productor TEXT, cultivo TEXT, 
      variedad TEXT, lote_proceso TEXT, estado TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE control_calidad (
      reg_local TEXT PRIMARY KEY, id INTEGER, reg_celda TEXT, cod_celda TEXT, 
      celda_nro TEXT, lote_proceso TEXT, fecha TEXT, hora TEXT, usuario TEXT, 
      establecimiento TEXT, cuadro TEXT, cultivo TEXT, variedad TEXT, remito TEXT, 
      estado_celda TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE detalle_despacho (
      registro INTEGER PRIMARY KEY, cab_desp TEXT, fecha TEXT, remito TEXT, 
      cliente TEXT, destino TEXT, reg_embolsado TEXT, cod_bigbag TEXT, cod_traza TEXT, 
      productor TEXT, especie TEXT, lote TEXT, variedad TEXT, kg REAL, calidad TEXT, 
      lote_proceso TEXT, calibre TEXT, fumigado TEXT, tipo_envase TEXT,
      sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE embolsado_bag (
      reg_local TEXT PRIMARY KEY, id INTEGER, registro_emb TEXT, fecha TEXT, hora TEXT, 
      cod_bigbag TEXT, celda TEXT, productor TEXT, especie TEXT, lote TEXT, variedad TEXT, 
      kg TEXT, lote_proceso TEXT, calibre TEXT, fumigado TEXT, estado TEXT, 
      tipo_envase TEXT, deposito TEXT, calidad TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE empaque_armado_bins (
      reg_local TEXT PRIMARY KEY, id INTEGER, cod_bin TEXT, fecha TEXT, hora TEXT, 
      registro_mov TEXT, cod_bigbag TEXT, fecha_emb TEXT, hora_emb TEXT, productor TEXT, 
      lote TEXT, especie TEXT, variedad TEXT, cliente TEXT, calibre TEXT, estado TEXT, 
      calidad TEXT, fumigado TEXT, lote_proceso TEXT, deposito TEXT,
      sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE volcado_bag (
      reg_local TEXT PRIMARY KEY, id INTEGER, fecha TEXT, hora TEXT, 
      registro_emb TEXT, cod_bigbag TEXT, fecha_emb TEXT, hora_emb TEXT, productor TEXT, 
      especie TEXT, variedad TEXT, lote TEXT, tipo_envase TEXT, fumigado TEXT, 
      calidad TEXT, lote_proceso TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE volcado_bins (
      reg_local TEXT PRIMARY KEY, id TEXT, fecha TEXT, hora TEXT, reg_bin TEXT, 
      cod_bin TEXT, cliente TEXT, productor TEXT, lote TEXT, lote_proceso TEXT, 
      kilos TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    // 3. Tablas Maestras y Parámetros
    await db.execute('''CREATE TABLE inventario (
      id INTEGER PRIMARY KEY, establecimiento TEXT, cuadro TEXT, cultivo TEXT, 
      sup REAL DEFAULT 0, variedad TEXT, plantacion TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE parametros_calibre (
      id INTEGER PRIMARY KEY, calibre TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE parametros_calidad (
      id INTEGER, calidad TEXT, sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE parametros_celdas (
      id INTEGER PRIMARY KEY, qr_celda TEXT, celda_numero TEXT, celda_nombre TEXT,
      sincronizado INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE parametros_depositos (
      id INTEGER PRIMARY KEY, deposito TEXT, sincronizado INTEGER DEFAULT 0
    )''');
  }

  // --- MÉTODOS DE SESIÓN ---
  // ESTO LO MODIFIQUE: Soporte multiplataforma con SharedPreferences y SQLite
  Future<void> guardarUsuario(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sesion_activa', jsonEncode(user));

    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        await db.delete('usuario_local');
        await db.insert('usuario_local', user);
      }
    }
  }

  Future<Map<String, dynamic>?> obtenerUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final sesionStr = prefs.getString('sesion_activa');
    if (sesionStr != null) {
      return jsonDecode(sesionStr) as Map<String, dynamic>;
    }

    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        final res = await db.query('usuario_local');
        return res.isNotEmpty ? res.first : null;
      }
    }
    return null;
  }

  // --- DESCARGA (PULL) DESDE SUPABASE ---
  // ESTO LO MODIFIQUE: En Web se omite porque la app trabaja online en tiempo real
  Future<void> descargarTodoDesdeSupabase() async {
    if (kIsWeb) return;

    // 1. Catálogos
    await _descargarTablaServidor('inventario', esParametroPuro: true);
    await _descargarTablaServidor('parametros_calibre', esParametroPuro: true);
    await _descargarTablaServidor('parametros_calidad', esParametroPuro: true);
    await _descargarTablaServidor('parametros_celdas', esParametroPuro: true);
    await _descargarTablaServidor('parametros_depositos', esParametroPuro: true);

    // 2. Operativas
    await _descargarTablaServidor('celdas_control_calidad_calibre', esParametroPuro: false);
    await _descargarTablaServidor('celdas_historial', esParametroPuro: false);
    await _descargarTablaServidor('celdas_recepcion', esParametroPuro: false);
    await _descargarTablaServidor('control_calidad', esParametroPuro: false);
    await _descargarTablaServidor('detalle_despacho', esParametroPuro: false);
    await _descargarTablaServidor('embolsado_bag', esParametroPuro: false);
    await _descargarTablaServidor('empaque_armado_bins', esParametroPuro: false);
    await _descargarTablaServidor('volcado_bag', esParametroPuro: false);
    await _descargarTablaServidor('volcado_bins', esParametroPuro: false);
  }

  Future<void> _descargarTablaServidor(String nombreTabla, {required bool esParametroPuro}) async {
    final db = await database;
    if (db == null) return;

    try {
      final datos = await supabase.from(nombreTabla).select();
      if (datos.isNotEmpty) {
        Batch batch = db.batch();

        if (esParametroPuro) {
          batch.delete(nombreTabla);
        } else {
          batch.delete(nombreTabla, where: 'sincronizado = 1');
        }

        for (var row in datos) {
          Map<String, dynamic> fila = Map<String, dynamic>.from(row);

          if (fila.containsKey('celda nro')) {
            fila['celda_nro'] = fila['celda nro'];
            fila.remove('celda nro');
          }
          if (fila.containsKey('lote proceso')) {
            fila['lote_proceso'] = fila['lote proceso'];
            fila.remove('lote proceso');
          }
          if (fila.containsKey('tipo envase')) {
            fila['tipo_envase'] = fila['tipo envase'];
            fila.remove('tipo envase');
          }

          fila['sincronizado'] = 1;

          batch.insert(
            nombreTabla,
            fila,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint("Error descargando tabla $nombreTabla: $e");
    }
  }

  // ACA ES LO NUEVO: 1. Busca el último ciclo ACTIVO de un Big Bag físico
  Future<Map<String, dynamic>?> obtenerBolsonActivoPorQR(String qrCodigo) async {
    if (kIsWeb) {
      final res = await supabase
          .from('embolsado_bag')
          .select()
          .eq('cod_bigbag', qrCodigo)
          .neq('estado', 'VOLCADO')
          .neq('estado', 'INACTIVO')
          .order('fecha', ascending: false)
          .limit(1);
      return res.isNotEmpty ? res.first : null;
    }

    final db = await database;
    if (db == null) return null;
    final List<Map<String, dynamic>> res = await db.query(
      'embolsado_bag',
      where: 'cod_bigbag = ? AND (estado != \'VOLCADO\' AND estado != \'INACTIVO\' OR estado IS NULL)',
      orderBy: 'fecha DESC, hora DESC, id DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  // ACA ES LO NUEVO: 2. Busca el último ciclo ACTIVO de un Bin físico
  Future<Map<String, dynamic>?> obtenerBinActivoPorQR(String qrCodigo) async {
    if (kIsWeb) {
      final res = await supabase
          .from('empaque_armado_bins')
          .select()
          .eq('cod_bin', qrCodigo)
          .neq('estado', 'VOLCADO')
          .neq('estado', 'INACTIVO')
          .order('fecha_emb', ascending: false)
          .limit(1);
      return res.isNotEmpty ? res.first : null;
    }

    final db = await database;
    if (db == null) return null;
    final List<Map<String, dynamic>> res = await db.query(
      'empaque_armado_bins',
      where: 'cod_bin = ? AND (estado != \'VOLCADO\' AND estado != \'INACTIVO\' OR estado IS NULL)',
      orderBy: 'fecha_emb DESC, hora_emb DESC, id DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  // ACA ES LO NUEVO: 3. Libera ciclos viejos si se reutiliza el QR para un nuevo llenado consecutivo
  Future<void> cerrarCicloPrevioQR({
    required dynamic db,
    required String nombreTabla,
    required String columnaQR,
    required String codigoQR,
    required String nuevoRegLocal,
  }) async {
    if (kIsWeb) {
      await supabase.from(nombreTabla).update({
        'estado': 'VOLCADO',
      }).eq(columnaQR, codigoQR).neq('reg_local', nuevoRegLocal);
      return;
    }

    if (db is DatabaseExecutor) {
      await db.update(
        nombreTabla,
        {
          'estado': 'VOLCADO',
          'sincronizado': 0,
        },
        where: '$columnaQR = ? AND reg_local != ? AND (estado != \'VOLCADO\' AND estado != \'INACTIVO\' OR estado IS NULL)',
        whereArgs: [codigoQR, nuevoRegLocal],
      );
    }
  }

  String generarIdCorto({int longitud = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(longitud, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}

// --- SESIÓN ---
  Future<void> guardarUsuario(Map<String, dynamic> user, dynamic instance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sesion_activa', jsonEncode(user));

    if (!kIsWeb) {
  final db = await instance.database;
  if (db is Database) {
    await db.delete('usuarios');
    await db.insert('usuarios', user);
  }
}
  }


  Future<Map<String, dynamic>?> obtenerUsuarioLocal(Future<Object?> database) async {
    final prefs = await SharedPreferences.getInstance();
    final sesionStr = prefs.getString('sesion_activa');
    if (sesionStr != null) {
      return jsonDecode(sesionStr) as Map<String, dynamic>;
    }
    if (!kIsWeb) {
      final db = await database;
      if (db is Database) {
        final res = await db.query('usuario_local');
        return res.isNotEmpty ? res.first : null;
      }
    }
    return null;
  }

  Future<void> descargarTodoDesdeSupabase() async {
    if (kIsWeb) return;
  }

  String generarIdCorto({int longitud = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(longitud, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }


// ============================================================================
// ACA ES LO NUEVO: Adaptador Web que emula métodos de SQLite consultando Supabase
// ============================================================================
class _WebDatabaseAdapter {
  final SupabaseClient supabase;
  _WebDatabaseAdapter(this.supabase);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic builder = supabase.from(table).select();

      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        final columna = where.split('=').first.trim();
        builder = builder.eq(columna, whereArgs.first);
      }

      if (orderBy != null) {
        final partes = orderBy.split(' ');
        final columna = partes[0].trim();
        final ascendente = partes.length > 1 ? partes[1].toUpperCase() == 'ASC' : true;
        builder = builder.order(columna, ascending: ascendente);
      }

      if (limit != null) {
        builder = builder.limit(limit);
      }

      final res = await builder;
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error query Web en $table: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    try {
      // Caso 1: Lectura principal de celdas con cruce de calidad y calibres
      if (sql.contains('celdas_recepcion') && sql.contains('celdas_control_calidad_calibre')) {
        final recepcion = await supabase.from('celdas_recepcion').select();
        final calibres = await supabase.from('celdas_control_calidad_calibre').select();
        final calidades = await supabase.from('control_calidad').select();

        final List<Map<String, dynamic>> listaCombinada = [];

        for (var r in recepcion) {
          final lote = r['lote_proceso'];
          final c = calibres.firstWhere((item) => item['lote_proceso'] == lote, orElse: () => {});
          final cc = calidades.firstWhere((item) => item['lote_proceso'] == lote, orElse: () => {});

          listaCombinada.add({
            'reg_local': r['reg_local'],
            'fecha_reg': r['fecha_reg'],
            'hora': r['hora'],
            'cod_celda': r['cod_celda'],
            'cuadro': r['cuadro'],
            'productor': r['productor'],
            'cultivo': r['cultivo'],
            'variedad': r['variedad'],
            'lote_proceso': r['lote_proceso'],
            'estado': r['estado'] ?? 'ACTIVO',
            'calidad_final': c['calidad_final'],
            'cal1': c['cal1'],
            'nro_1': c['nro_1'],
            'cal2': c['cal2'],
            'nro_2': c['nro_2'],
            'cal3': c['cal3'],
            'nro_3': c['nro_3'],
            'cal4': c['cal4'],
            'nro_4': c['nro_4'],
            'establecimiento': cc['establecimiento'],
          });
        }

        // Orden de prioridad: ACTIVO -> PASIVO -> OTROS
        listaCombinada.sort((a, b) {
          int getPrioridad(String? est) {
            final e = (est ?? '').toUpperCase();
            if (e == 'ACTIVO') return 1;
            if (e == 'PASIVO') return 2;
            return 3;
          }

          int comp = getPrioridad(a['estado']).compareTo(getPrioridad(b['estado']));
          if (comp != 0) return comp;
          return (b['fecha_reg'] ?? '').toString().compareTo((a['fecha_reg'] ?? '').toString());
        });

        return listaCombinada;
      }

      // Caso 2: Conteo de pendientes
      if (sql.toUpperCase().contains('COUNT(*)')) {
        return [{'t': 0}];
      }

      return [];
    } catch (e) {
      debugPrint("Error rawQuery Web: $e");
      return [];
    }
  }

  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      final payload = Map<String, dynamic>.from(values);
      payload.remove('sincronizado');
      await supabase.from(table).upsert(payload);
      return 1;
    } catch (e) {
      debugPrint("Error insert Web en $table: $e");
      return 0;
    }
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      final payload = Map<String, dynamic>.from(values);
      payload.remove('sincronizado');
      
      dynamic builder = supabase.from(table).update(payload);
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        final columna = where.split('=').first.trim();
        builder = builder.eq(columna, whereArgs.first);
      }
      await builder;
      return 1;
    } catch (e) {
      debugPrint("Error update Web en $table: $e");
      return 0;
    }
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    try {
      dynamic builder = supabase.from(table).delete();
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        final columna = where.split('=').first.trim();
        builder = builder.eq(columna, whereArgs.first);
      }
      await builder;
      return 1;
    } catch (e) {
      debugPrint("Error delete Web en $table: $e");
      return 0;
    }
  }
}