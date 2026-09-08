import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final supabase = Supabase.instance.client;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'la_rivera_celdas.db');
    return await openDatabase(
      path,
      // ESTO LO MODIFIQUE: Versión 12 para sincronizar con el DDL real de Supabase
      version: 12,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < newVersion) {
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
          _onCreate(db, newVersion);
        }
      },
    );
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
  Future<void> guardarUsuario(Map<String, dynamic> user) async {
    final db = await database;
    await db.delete('usuario_local');
    await db.insert('usuario_local', user);
  }

  Future<Map<String, dynamic>?> obtenerUsuarioLocal() async {
    final db = await database;
    final res = await db.query('usuario_local');
    return res.isNotEmpty ? res.first : null;
  }

  // --- DESCARGA (PULL) DESDE SUPABASE ---
  Future<void> descargarTodoDesdeSupabase() async {
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

          // Normalización de claves que pudieran llegar con espacios
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
      print("Error descargando tabla $nombreTabla: $e");
      rethrow;
    }
  }

// ACA ES LO NUEVO: 1. Busca el último ciclo ACTIVO de un Big Bag físico
  Future<Map<String, dynamic>?> obtenerBolsonActivoPorQR(String qrCodigo) async {
    final db = await database;
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
    final db = await database;
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
    required DatabaseExecutor db,
    required String nombreTabla,
    required String columnaQR,
    required String codigoQR,
    required String nuevoRegLocal,
  }) async {
    await db.update(
      nombreTabla,
      {
        'estado': 'VOLCADO',
        'sincronizado': 0, // Notifica el cambio de estado a la nube
      },
      where: '$columnaQR = ? AND reg_local != ? AND (estado != \'VOLCADO\' AND estado != \'INACTIVO\' OR estado IS NULL)',
      whereArgs: [codigoQR, nuevoRegLocal],
    );
  }
  
  String generarIdCorto({int longitud = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(longitud, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}