import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_datos.dart';
import 'package:intl/intl.dart';

// TOKENS DE DISEÑO AGROSOFT
const Color kColorBg = Color(0xFFF3F5F1);
const Color kColorSurface = Color(0xFFFFFFFF);
const Color kColorText = Color(0xFF1B231D);
const Color kColorTextSecondary = Color(0xFF5F6B62);
const Color kColorAccent = Color(0xFF1E6B4C);
const Color kColorAccentDark = Color(0xFF123F2C);
const Color kColorAccentSoft = Color(0x1A1E6B4C);
const Color kColorDanger = Color(0xFFC0483C);
const Color kColorDangerSoft = Color(0x1FC0483C);
const Color kColorBorder = Color(0x1F1B231D);

class PaginaSincronizar extends StatefulWidget {
  const PaginaSincronizar({super.key});

  @override
  State<PaginaSincronizar> createState() => _PaginaSincronizarState();

  // =======================================================================
  // ACA ES LO NUEVO: 1. SUBIDA PUNTUAL DE CELDAS Y CALIDAD
  // =======================================================================
  static Future<int> sincronizarCeldas({String? usuario}) async {
    final db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    // A. celdas_recepcion
    final celdas = await db.query('celdas_recepcion', where: 'sincronizado = 0 OR sincronizado IS NULL');
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

    // B. control_calidad
    final calidad = await db.query('control_calidad', where: 'sincronizado = 0 OR sincronizado IS NULL');
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

    // C. celdas_control_calidad_calibre
    final calibres = await db.query('celdas_control_calidad_calibre', where: 'sincronizado = 0 OR sincronizado IS NULL');
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
  // ACA ES LO NUEVO: 2. SUBIDA PUNTUAL DE EMBOLSADO DE BIG BAGS
  // =======================================================================
  static Future<int> sincronizarBag() async {
    final db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;

    final embolsado = await db.query('embolsado_bag', where: 'sincronizado = 0 OR sincronizado IS NULL');
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
  // ACA ES LO NUEVO: SUBIDA PUNTUAL EXCLUSIVA DE CELDAS RECEPCIÓN
  // =======================================================================
  static Future<int> sincronizarRecepcion() async {
    final db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;

    final celdas = await db.query(
      'celdas_recepcion',
      where: 'sincronizado = 0 OR sincronizado IS NULL',
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

      await supabase.from('celdas_recepcion').upsert(
        payload,
        onConflict: 'reg_local',
      );

      await db.update(
        'celdas_recepcion',
        {'sincronizado': 1},
        where: 'sincronizado = 0 OR sincronizado IS NULL',
      );

      return celdas.length;
    }
    return 0;
  }
  
  // =======================================================================
  // ACA ES LO NUEVO: 3. SUBIDA PUNTUAL DE VOLCADO DE BIG BAGS
  // =======================================================================
  static Future<int> sincronizarVolcadoBag() async {
    final db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    // Subir cambio de estado a VOLCADO en embolsado_bag si lo hubiera
    subidos += await sincronizarBag();

    // Subir nuevo registro a volcado_bag
    final volcados = await db.query('volcado_bag', where: 'sincronizado = 0 OR sincronizado IS NULL');
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
  // ACA ES LO NUEVO: 4. SUBIDA PUNTUAL DE BINS Y VOLCADO DE BINS
  // =======================================================================
  static Future<int> sincronizarBins() async {
    final db = await DatabaseHelper().database;
    final supabase = Supabase.instance.client;
    int subidos = 0;

    // A. empaque_armado_bins
    final empaque = await db.query('empaque_armado_bins', where: 'sincronizado = 0 OR sincronizado IS NULL');
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

    // B. volcado_bins
    final volcadosBins = await db.query('volcado_bins', where: 'sincronizado = 0 OR sincronizado IS NULL');
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
  // MOTOR UNIFICADO: PUSH COMPLETO + PULL DE CATÁLOGOS
  // =======================================================================
  static Future<String> sincronizarTodo({String? usuario}) async {
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

  String _ultimaSinc = "Nunca";
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
    _log("Módulo inicializado. Pendientes actuales: $_totalPendientes");
  }

  Future<void> _actualizarContadorPendientes() async {
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
    final db = await DatabaseHelper().database;
    final res = await db.query('usuario_local', limit: 1);
    if (res.isNotEmpty && mounted) {
      setState(() {
        usuario = res.first['operario']?.toString() ?? 'Operador';
        rolUsuario = res.first['rol']?.toString() ?? 'GENERAL';
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

    _log("--- DESCARGANDO CATÁLOGOS DESDE SUPABASE ---");
    try {
      await DatabaseHelper().descargarTodoDesdeSupabase();
      _log("Catálogos y estructuras descargadas correctamente", esExito: true);

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
            border: Border(bottom: BorderSide(color: kColorBorder, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kColorSurface,
                        border: Border.all(color: kColorBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: kColorTextSecondary),
                          SizedBox(width: 4),
                          Text("VOLVER", style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
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
                        Text("CENTRO DE DATOS Y LOGS", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText)),
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
                    color: const Color(0xFF007AFF),
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
                const Text("TERMINAL DE EVENTOS Y DIAGNÓSTICO", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11.5, color: kColorTextSecondary, letterSpacing: 0.5)),
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
                  border: Border.all(color: kColorBorder),
                ),
                child: Text("Operador Activo: ${usuario.isEmpty ? '...' : usuario} ($rolUsuario)", style: const TextStyle(color: kColorTextSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kColorAccentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storage_rounded, size: 24, color: kColorAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$_totalPendientes Registros por Subir", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kColorText)),
                const SizedBox(height: 2),
                Text("Última sinc: $_ultimaSinc", style: const TextStyle(color: kColorTextSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
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
          border: Border.all(color: tienePendientes ? kColorAccent.withOpacity(0.4) : kColorBorder),
        ),
        child: Column(
          children: [
            Text("$cantidad", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tienePendientes ? kColorAccentDark : kColorTextSecondary)),
            const SizedBox(height: 1),
            Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: kColorTextSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAccionCompacto({required String titulo, required IconData icono, required Color color, required bool enProgreso, required VoidCallback onTap}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: enProgreso ? null : onTap,
        icon: enProgreso ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icono, size: 18),
        label: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black),
      ),
      child: _logs.isEmpty
          ? const Center(child: Text("Presiona 'SUBIR DATOS' para sincronizar...", style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')))
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
                  child: Text(log, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: colorTexto, height: 1.3)),
                );
              },
            ),
    );
  }
}