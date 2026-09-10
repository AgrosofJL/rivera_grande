import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_datos.dart';
import 'package:intl/intl.dart';

// TOKENS DE DISEÑO AGROSOFT - ESTILO APPLE SOFT CAMPO.JS
const Color kColorBg = Color(0xFFF5F4F1);
const Color kColorSurface = Color(0xFFFFFFFF);
const Color kColorText = Color(0xFF211C16);
const Color kColorTextSecondary = Color(0xFF6B6255);
const Color kColorAccent = Color(0xFF1E6B4C);
const Color kColorAccentDark = Color(0xFF123F2C);
const Color kColorAccentSoft = Color(0x1A1E6B4C); // 10%
const Color kColorDanger = Color(0xFFC0483C);
const Color kColorDangerSoft = Color(0x1FC0483C);
const Color kColorBorder = Color(0xFFE0DCD4);

class PaginaSincronizar extends StatefulWidget {
  const PaginaSincronizar({super.key});

  @override
  State<PaginaSincronizar> createState() => _PaginaSincronizarState();

  // =======================================================================
  // 1. SUBIDA PUNTUAL DE CELDAS Y CALIDAD
  // =======================================================================
  static Future<int> sincronizarCeldas({String? usuario}) async {
    if (kIsWeb) return 0;

    final dynamic db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    // ESTO LO MODIFIQUE: Tipado explicito para evitar error con subidos += length
    final List<Map<String, dynamic>> celdas = List<Map<String, dynamic>>.from(
      await db.query('celdas_recepcion', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (celdas.isNotEmpty) {
      final payload = celdas.map((e) => {
        'reg_local': e['reg_local'],
        'fecha_reg': e['fecha_reg'],
        'hora': e['hora'],
        'cod_celda': e['cod_celda'],
        'cuadro': e['cuadro'],
        'celda_numero': e['celda_numero'] ?? e['cod_celda'],
        'productor': e['productor'],
        'cultivo': e['cultivo'],
        'variedad': e['variedad'],
        'lote_proceso': e['lote_proceso'],
        'estado': e['estado'] ?? 'ACTIVO',
      }).toList();

      await supabase.from('celdas_recepcion').upsert(payload, onConflict: 'reg_local');
      await db.update('celdas_recepcion', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += celdas.length;
    }

    final List<Map<String, dynamic>> calidad = List<Map<String, dynamic>>.from(
      await db.query('control_calidad', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (calidad.isNotEmpty) {
      final payload = calidad.map((e) => {
        'reg_local': e['reg_local'],
        'reg_celda': e['reg_celda'],
        'cod_celda': e['cod_celda'],
        'celda_nro': e['celda_nro'] ?? e['cod_celda'],
        'lote_proceso': e['lote_proceso'],
        'fecha': e['fecha'],
        'hora': e['hora'],
        'usuario': e['usuario'] ?? (usuario ?? 'Operador'),
        'establecimiento': e['establecimiento'],
        'cuadro': e['cuadro'],
        'cultivo': e['cultivo'],
        'variedad': e['variedad'],
        'remito': e['remito']?.toString() ?? "0",
        'estado_celda': e['estado_celda'] ?? 'ACTIVO',
      }).toList();

      await supabase.from('control_calidad').upsert(payload, onConflict: 'reg_local');
      await db.update('control_calidad', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += calidad.length;
    }

    final List<Map<String, dynamic>> calibres = List<Map<String, dynamic>>.from(
      await db.query('celdas_control_calidad_calibre', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (calibres.isNotEmpty) {
      final payload = calibres.map((e) => {
        'reg_local': e['reg_local'],
        'cod_historial': e['cod_historial'],
        'fecha': e['fecha'],
        'cod_celda': e['cod_celda'],
        'celda_numero': e['celda_numero'] ?? e['cod_celda'],
        'productor': e['productor'],
        'lote': e['lote'],
        'cultivo': e['cultivo'],
        'variedad': e['variedad'],
        'lote_proceso': e['lote_proceso'],
        'calidad_final': e['calidad_final'],
        'cal1': e['cal1'],
        'nro_1': e['nro_1'],
        'cal2': e['cal2'],
        'nro_2': e['nro_2'],
        'cal3': e['cal3'],
        'nro_3': e['nro_3'],
        'cal4': e['cal4'],
        'nro_4': e['nro_4'],
        'estado_celda': e['estado_celda'] ?? 'ACTIVO',
      }).toList();

      await supabase.from('celdas_control_calidad_calibre').upsert(payload, onConflict: 'reg_local');
      await db.update('celdas_control_calidad_calibre', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += calibres.length;
    }

    return subidos;
  }

  // =======================================================================
  // 2. SUBIDA PUNTUAL DE EMBOLSADO DE BIG BAGS
  // =======================================================================
  static Future<int> sincronizarBag() async {
    if (kIsWeb) return 0;

    final dynamic db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;

    final List<Map<String, dynamic>> embolsado = List<Map<String, dynamic>>.from(
      await db.query('embolsado_bag', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (embolsado.isNotEmpty) {
      final payload = embolsado.map((e) => {
        'reg_local': e['reg_local'],
        'registro_emb': e['registro_emb'] ?? e['reg_local'],
        'fecha': e['fecha'],
        'hora': e['hora'],
        'cod_bigbag': e['cod_bigbag'],
        'celda': e['celda'],
        'productor': e['productor'],
        'especie': e['especie'],
        'lote': e['lote'],
        'variedad': e['variedad'],
        'kg': e['kg']?.toString(),
        'lote_proceso': e['lote_proceso'],
        'calibre': e['calibre'] ?? '',
        'fumigado': e['fumigado'] ?? 'NO',
        'estado': e['estado'],
        'tipo_envase': e['tipo_envase'] ?? 'BIG BAG',
        'deposito': e['deposito'] ?? 'PLANTA CENTRAL',
      }).toList();

      await supabase.from('embolsado_bag').upsert(payload, onConflict: 'reg_local');
      await db.update('embolsado_bag', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      return embolsado.length;
    }
    return 0;
  }

  // =======================================================================
  // 3. SUBIDA PUNTUAL DE RECEPCIÓN EXCLUSIVA
  // =======================================================================
  static Future<int> sincronizarRecepcion() async {
    if (kIsWeb) return 0;

    final dynamic db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;

    final List<Map<String, dynamic>> celdas = List<Map<String, dynamic>>.from(
      await db.query('celdas_recepcion', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );

    if (celdas.isNotEmpty) {
      final payload = celdas.map((e) => {
        'reg_local': e['reg_local'],
        'fecha_reg': e['fecha_reg'],
        'hora': e['hora'],
        'cod_celda': e['cod_celda'],
        'cuadro': e['cuadro'],
        'celda_numero': e['celda_numero'] ?? e['cod_celda'],
        'productor': e['productor'],
        'cultivo': e['cultivo'],
        'variedad': e['variedad'],
        'lote_proceso': e['lote_proceso'],
        'estado': e['estado'] ?? 'ACTIVO',
      }).toList();

      await supabase.from('celdas_recepcion').upsert(payload, onConflict: 'reg_local');
      await db.update('celdas_recepcion', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      return celdas.length;
    }
    return 0;
  }

  // =======================================================================
  // 4. SUBIDA PUNTUAL DE VOLCADO DE BIG BAGS
  // =======================================================================
  static Future<int> sincronizarVolcadoBag() async {
    if (kIsWeb) return 0;

    final dynamic db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    subidos += await sincronizarBag();

    final List<Map<String, dynamic>> volcados = List<Map<String, dynamic>>.from(
      await db.query('volcado_bag', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (volcados.isNotEmpty) {
      final payload = volcados.map((e) => {
        'reg_local': e['reg_local'],
        'fecha': e['fecha'],
        'hora': e['hora'],
        'registro_emb': e['registro_emb'],
        'cod_bigbag': e['cod_bigbag'],
        'fecha_emb': e['fecha_emb'],
        'hora_emb': e['hora_emb'],
        'productor': e['productor'],
        'especie': e['especie'],
        'variedad': e['variedad'],
        'lote': e['lote'],
        'tipo_envase': e['tipo_envase'],
        'fumigado': e['fumigado'] ?? 'NO',
        'calidad': e['calidad'],
        'lote_proceso': e['lote_proceso'],
      }).toList();

      await supabase.from('volcado_bag').upsert(payload, onConflict: 'reg_local');
      await db.update('volcado_bag', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += volcados.length;
    }
    return subidos;
  }

  // =======================================================================
  // 5. SUBIDA PUNTUAL DE BINS Y VOLCADO DE BINS
  // =======================================================================
  static Future<int> sincronizarBins() async {
    if (kIsWeb) return 0;

    final dynamic db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    final List<Map<String, dynamic>> empaque = List<Map<String, dynamic>>.from(
      await db.query('empaque_armado_bins', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (empaque.isNotEmpty) {
      final payload = empaque.map((e) => {
        'reg_local': e['reg_local'],
        'cod_bin': e['cod_bin'],
        'fecha': e['fecha'],
        'hora': e['hora'],
        'fecha_emb': e['fecha_emb'],
        'hora_emb': e['hora_emb'],
        'registro_mov': e['registro_mov']?.toString(),
        'cod_bigbag': e['cod_bigbag'],
        'productor': e['productor'],
        'lote': e['lote'],
        'lote_proceso': e['lote_proceso'],
        'especie': e['especie'],
        'variedad': e['variedad'],
        'cliente': e['cliente'],
        'calibre': e['calibre'],
        'estado': e['estado'],
        'calidad': e['calidad'],
        'fumigado': e['fumigado'],
        'deposito': e['deposito'],
      }).toList();

      await supabase.from('empaque_armado_bins').upsert(payload, onConflict: 'reg_local');
      await db.update('empaque_armado_bins', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += empaque.length;
    }

    final List<Map<String, dynamic>> volcadosBins = List<Map<String, dynamic>>.from(
      await db.query('volcado_bins', where: 'sincronizado = 0 OR sincronizado IS NULL')
    );
    if (volcadosBins.isNotEmpty) {
      final payload = volcadosBins.map((e) => {
        'reg_local': e['reg_local'],
        'id': e['id'] ?? e['reg_local'],
        'fecha': e['fecha'],
        'hora': e['hora'],
        'reg_bin': e['reg_bin'],
        'cod_bin': e['cod_bin'],
        'cliente': e['cliente'],
        'productor': e['productor'],
        'lote': e['lote'],
        'lote_proceso': e['lote_proceso'],
        'kilos': e['kilos']?.toString(),
      }).toList();

      await supabase.from('volcado_bins').upsert(payload, onConflict: 'reg_local');
      await db.update('volcado_bins', {'sincronizado': 1}, where: 'sincronizado = 0 OR sincronizado IS NULL');
      subidos += volcadosBins.length;
    }

    return subidos;
  }


  // =======================================================================
  // MOTOR UNIFICADO: PUSH + PULL DE PARÁMETROS
  // =======================================================================
  static Future<String> sincronizarTodo({String? usuario}) async {
    if (kIsWeb) {
      return "Modo Web: Conexión activa y datos sincronizados en tiempo real con Supabase.";
    }

    int totalSubidos = 0;
    List<String> errores = [];

    try {
      totalSubidos += await sincronizarCeldas(usuario: usuario);
    } catch (e) {
      errores.add("Celdas: $e");
    }

    try {
      totalSubidos += await sincronizarBag();
    } catch (e) {
      errores.add("Embolsado: $e");
    }

    try {
      totalSubidos += await sincronizarVolcadoBag();
    } catch (e) {
      errores.add("Volcado Bag: $e");
    }

    try {
      totalSubidos += await sincronizarBins();
    } catch (e) {
      errores.add("Bins: $e");
    }

    try {
      await DatabaseHelper().descargarTodoDesdeSupabase();
    } catch (e) {
      errores.add("Descarga catálogos: $e");
    }

    if (errores.isNotEmpty) {
      throw errores.join(" | ");
    }

    return totalSubidos > 0
        ? "Sincronización completa: $totalSubidos registros subidos y catálogos al día."
        : "Catálogos actualizados. No hay registros pendientes de subida.";
  }
}

class _PaginaSincronizarState extends State<PaginaSincronizar> {
  bool _isSyncing = false;
  int _pendRecepcion = 0;
  int _pendCalidad = 0;
  int _pendCalibres = 0;
  int _pendEmbolsado = 0;
  int _pendVolcado = 0;
  int _pendBins = 0;
  int get _totalPendientes => _pendRecepcion + _pendCalidad + _pendCalibres + _pendEmbolsado + _pendVolcado + _pendBins;

  String _ultimaSinc = "En tiempo real";
  String usuario = "";
  String rolUsuario = "";

  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _log(String mensaje, {bool esError = false, bool esExito = false}) {
    final String hora = DateFormat('HH:mm:ss').format(DateTime.now());
    final String prefijo = esError ? "❌ [ERROR]" : (esExito ? "✅ [OK]" : "ℹ️ [INFO]");
    final String logCompleto = "$hora $prefijo $mensaje";

    debugPrint(logCompleto);
    setState(() {
      _logs.add(logCompleto);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _cargarDatosIniciales() async {
    await _actualizarContadorPendientes();
    await _buscarUsuario();
    if (kIsWeb) {
      _log("Módulo inicializado en modo Web. Conectado directamente a Supabase.", esExito: true);
    } else {
      _log("Módulo inicializado. Pendientes actuales: $_totalPendientes");
    }
  }

  Future<void> _actualizarContadorPendientes() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _pendRecepcion = 0;
          _pendCalidad = 0;
          _pendCalibres = 0;
          _pendEmbolsado = 0;
          _pendVolcado = 0;
          _pendBins = 0;
        });
      }
      return;
    }

    final db = await DatabaseHelper().database;

    final rRec = await db.rawQuery('SELECT COUNT(*) as t FROM celdas_recepcion WHERE sincronizado = 0 OR sincronizado IS NULL');
    final rCal = await db.rawQuery('SELECT COUNT(*) as t FROM control_calidad WHERE sincronizado = 0 OR sincronizado IS NULL');
    final rCalib = await db.rawQuery('SELECT COUNT(*) as t FROM celdas_control_calidad_calibre WHERE sincronizado = 0 OR sincronizado IS NULL');
    final rEmb = await db.rawQuery('SELECT COUNT(*) as t FROM embolsado_bag WHERE sincronizado = 0 OR sincronizado IS NULL');
    final rVolc = await db.rawQuery('SELECT COUNT(*) as t FROM volcado_bag WHERE sincronizado = 0 OR sincronizado IS NULL');
    final rBins = await db.rawQuery('SELECT COUNT(*) as t FROM empaque_armado_bins WHERE sincronizado = 0 OR sincronizado IS NULL');

    if (mounted) {
      setState(() {
        _pendRecepcion = (rRec.first['t'] as int?) ?? 0;
        _pendCalidad = (rCal.first['t'] as int?) ?? 0;
        _pendCalibres = (rCalib.first['t'] as int?) ?? 0;
        _pendEmbolsado = (rEmb.first['t'] as int?) ?? 0;
        _pendVolcado = (rVolc.first['t'] as int?) ?? 0;
        _pendBins = (rBins.first['t'] as int?) ?? 0;
      });
    }
  }

  Future<void> _buscarUsuario() async {
    final user = await DatabaseHelper().obtenerUsuarioLocal();
    if (user != null && mounted) {
      setState(() {
        usuario = user['operario']?.toString() ?? 'Operador';
        rolUsuario = user['rol']?.toString() ?? 'GENERAL';
      });
    }
  }

  Future<void> _ejecutarSincronizacionUI() async {
    setState(() {
      _isSyncing = true;
      _logs.clear();
    });

    _log("--- INICIANDO PROCESO CENTRAL DE SINCRONIZACIÓN ---");
    try {
      final resultado = await PaginaSincronizar.sincronizarTodo(usuario: usuario);
      _log(resultado, esExito: true);

      setState(() => _ultimaSinc = DateFormat('HH:mm').format(DateTime.now()));
      await _actualizarContadorPendientes();
    } catch (e) {
      _log("Error general: $e", esError: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _ejecutarDescargaParametros() async {
    setState(() {
      _isSyncing = true;
      _logs.clear();
    });

    _log("--- ACTUALIZANDO CATÁLOGOS DESDE SUPABASE ---");
    try {
      if (kIsWeb) {
        _log("En Web los catálogos se leen en tiempo real de Supabase.", esExito: true);
      } else {
        await DatabaseHelper().descargarTodoDesdeSupabase();
        _log("Catálogos y estructuras descargadas correctamente", esExito: true);
      }

      setState(() => _ultimaSinc = DateFormat('HH:mm').format(DateTime.now()));
      await _actualizarContadorPendientes();
    } catch (e) {
      _log("Error al descargar: $e", esError: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: kColorSurface,
            border: Border(bottom: BorderSide(color: kColorBorder, width: 1.5)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kColorSurface,
                        border: Border.all(color: kColorBorder, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: kColorTextSecondary),
                          SizedBox(width: 4),
                          Text("VOLVER", style: TextStyle(fontFamily: 'Roboto', fontSize: 11, fontWeight: FontWeight.w800, color: kColorTextSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("CENTRO DE DATOS Y SINCRONIZACIÓN", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 14, color: kColorText)),
                        Text("Sincronizador Bidireccional SQLite - Supabase", style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeaderCard(),
            const SizedBox(height: 12),
            _buildDesglosePendientes(),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildBotonAccionCompacto(
                    titulo: "SUBIR DATOS (PUSH)",
                    icono: Icons.cloud_upload_rounded,
                    color: kColorAccent,
                    enProgreso: _isSyncing,
                    onTap: _ejecutarSincronizacionUI,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBotonAccionCompacto(
                    titulo: "DESCARGAR (PULL)",
                    icono: Icons.cloud_download_rounded,
                    color: const Color(0xFF1E6B4C),
                    enProgreso: _isSyncing,
                    onTap: _ejecutarDescargaParametros,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TERMINAL DE EVENTOS Y DIAGNÓSTICO", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 11, color: kColorTextSecondary, letterSpacing: 0.4)),
                if (_logs.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _logs.clear()),
                    child: const Text("Limpiar", style: TextStyle(fontSize: 11, color: kColorDanger, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTerminalLogs(),
            const SizedBox(height: 20),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kColorSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorBorder, width: 1.2),
                ),
                child: Text("Operador Activo: ${usuario.isEmpty ? '...' : usuario} ($rolUsuario)", style: const TextStyle(fontFamily: 'Roboto', color: kColorTextSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kColorAccentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorAccent.withOpacity(0.25)),
            ),
            child: const Icon(Icons.storage_rounded, size: 22, color: kColorAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kIsWeb ? "Modo Web Online" : "$_totalPendientes Registros por Subir",
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800, color: kColorText),
                ),
                const SizedBox(height: 2),
                Text(
                  kIsWeb ? "Sincronización automática con Supabase" : "Última sinc: $_ultimaSinc",
                  style: const TextStyle(fontFamily: 'Roboto', color: kColorTextSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesglosePendientes() {
    return Row(
      children: [
        _buildMiniContador("Recep.", _pendRecepcion),
        const SizedBox(width: 4),
        _buildMiniContador("Calidad", _pendCalidad),
        const SizedBox(width: 4),
        _buildMiniContador("Calib.", _pendCalibres),
        const SizedBox(width: 4),
        _buildMiniContador("Bag", _pendEmbolsado),
        const SizedBox(width: 4),
        _buildMiniContador("Volc.Bag", _pendVolcado),
        const SizedBox(width: 4),
        _buildMiniContador("Bins", _pendBins),
      ],
    );
  }

  Widget _buildMiniContador(String titulo, int cantidad) {
    final bool tienePendientes = cantidad > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tienePendientes ? kColorAccent.withOpacity(0.5) : kColorBorder, width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              "$cantidad",
              style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 13, color: tienePendientes ? kColorAccentDark : kColorTextSecondary),
            ),
            const SizedBox(height: 1),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 9, color: kColorTextSecondary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAccionCompacto({required String titulo, required IconData icono, required Color color, required bool enProgreso, required VoidCallback onTap}) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: enProgreso ? null : onTap,
        icon: enProgreso
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icono, size: 17),
        label: Text(
          titulo,
          style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildTerminalLogs() {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141916),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
      ),
      child: _logs.isEmpty
          ? const Center(child: Text("Presiona 'SUBIR DATOS' para sincronizar...", style: TextStyle(color: Colors.white38, fontSize: 11.5, fontFamily: 'monospace')))
          : ListView.builder(
              controller: _logScrollController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color colorTexto = const Color(0xFFD1D5DB);
                if (log.contains("[ERROR]")) colorTexto = const Color(0xFFFF6B6B);
                if (log.contains("[OK]")) colorTexto = const Color(0xFF51CF66);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(log, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: colorTexto, height: 1.3)),
                );
              },
            ),
    );
  }
}