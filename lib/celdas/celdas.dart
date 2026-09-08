import 'package:flutter/material.dart';
import '../base_datos.dart';
import 'package:intl/intl.dart';

// =========================================================================
// TOKENS DE DISEÑO AGROSOFT INDUSTRIAL (CSS DESIGN SYSTEM)
// =========================================================================
const Color kColorBg = Color(0xFFF3F5F1);
const Color kColorSurface = Color(0xFFFFFFFF);
const Color kColorText = Color(0xFF1B231D);
const Color kColorTextSecondary = Color(0xFF5F6B62);
const Color kColorAccent = Color(0xFF1E6B4C);
const Color kColorAccentDark = Color(0xFF123F2C);
const Color kColorAccentSoft = Color(0x1A1E6B4C); // 10%
const Color kColorWa = Color(0xFF25D366);
const Color kColorWaSoft = Color(0x1F25D366); // 12%
const Color kColorDanger = Color(0xFFC0483C);
const Color kColorDangerSoft = Color(0x1FC0483C);
const Color kColorBorder = Color(0x1F1B231D); // 12%

// TONOS PASTEL PARA ESTADOS DE CELDA
// 1. ACTIVA: Amarillo Pastel
const Color kColorActivaBg = Color(0xFFFFFBEB);
const Color kColorActivaBorder = Color(0xFFFDE68A);
const Color kColorActivaText = Color(0xFF92400E);
const Color kColorActivaIconBg = Color(0xFFFEF3C7);

// 2. PASIVA: Violeta / Púrpura Pastel
const Color kColorPasivaBg = Color(0xFFF5F3FF);
const Color kColorPasivaBorder = Color(0xFFDDD6FE);
const Color kColorPasivaText = Color(0xFF5B21B6);
const Color kColorPasivaIconBg = Color(0xFFEDE9FE);

class PaginaCeldas extends StatefulWidget {
  const PaginaCeldas({super.key});

  @override
  State<PaginaCeldas> createState() => _PaginaCeldasState();
}

class _PaginaCeldasState extends State<PaginaCeldas> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Estados de datos
  List<Map<String, dynamic>> todosLosRegistros = [];
  List<Map<String, dynamic>> registrosFiltrados = [];
  List<Map<String, dynamic>> celdasFisicas = [];
  List<String> calibresMaestros = [];
  bool cargando = false;

  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _inicializarPanel();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _inicializarPanel() async {
    await _cargarCalibresMaestros();
    await _cargarDatosCompletos();
  }

  Future<void> _cargarCalibresMaestros() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> res = await db.query('parametros_calibre');
      setState(() {
        calibresMaestros = res.map((c) => c['calibre'].toString()).toList();
      });
    } catch (e) {
      debugPrint("Error cargando parámetros: $e");
    }
  }

  // ESTO LO MODIFIQUE: Consulta completa con orden de prioridad ACTIVO -> PASIVO -> INACTIVO y fechas
  Future<void> _cargarDatosCompletos() async {
    setState(() => cargando = true);
    final db = await dbHelper.database;

    // 1. Catálogo físico de celdas
    final List<Map<String, dynamic>> celdasRes = await db.query('parametros_celdas', orderBy: 'celda_nombre ASC');

    // 2. Registros con ordenamiento de prioridad por estado (ACTIVO primero, PASIVO segundo, resto al final)
    final List<Map<String, dynamic>> historialRes = await db.rawQuery('''
      SELECT 
        r.reg_local, r.fecha_reg, r.hora, r.cod_celda, r.cuadro, r.productor, r.cultivo, r.variedad, r.lote_proceso,
        r.estado,
        c.calidad_final, c.cal1, c.nro_1, c.cal2, c.nro_2, c.cal3, c.nro_3, c.cal4, c.nro_4,
        cc.establecimiento
      FROM celdas_recepcion r
      LEFT JOIN celdas_control_calidad_calibre c ON r.lote_proceso = c.lote_proceso
      LEFT JOIN control_calidad cc ON r.lote_proceso = cc.lote_proceso
      ORDER BY 
        CASE 
          WHEN UPPER(r.estado) = 'ACTIVO' THEN 1 
          WHEN UPPER(r.estado) = 'PASIVO' THEN 2 
          ELSE 3 
        END ASC,
        r.fecha_reg DESC, r.hora DESC
    ''');

    setState(() {
      celdasFisicas = celdasRes;
      todosLosRegistros = historialRes;
      _aplicarFiltro(queryBusqueda);
      cargando = false;
    });
  }

  void _aplicarFiltro(String query) {
    setState(() {
      queryBusqueda = query.toLowerCase().trim();
      if (queryBusqueda.isEmpty) {
        registrosFiltrados = List.from(todosLosRegistros);
      } else {
        registrosFiltrados = todosLosRegistros.where((c) {
          final celda = (c['cod_celda'] ?? '').toString().toLowerCase();
          final lote = (c['lote_proceso'] ?? '').toString().toLowerCase();
          final prod = (c['productor'] ?? '').toString().toLowerCase();
          final variedad = (c['variedad'] ?? '').toString().toLowerCase();
          final fecha = (c['fecha_reg'] ?? '').toString().toLowerCase();
          return celda.contains(queryBusqueda) ||
              lote.contains(queryBusqueda) ||
              prod.contains(queryBusqueda) ||
              variedad.contains(queryBusqueda) ||
              fecha.contains(queryBusqueda);
        }).toList();
      }
    });
  }

  // Helpers para obtener registros por celda
  List<Map<String, dynamic>> _obtenerHistorialDeCelda(String codCelda) {
    return todosLosRegistros.where((r) {
      final c = (r['cod_celda'] ?? '').toString().trim().toUpperCase();
      return c == codCelda.trim().toUpperCase();
    }).toList();
  }

  Map<String, dynamic>? _obtenerRegistroActualCelda(String codCelda) {
    // 1. Primero busca si tiene un lote ACTIVO
    try {
      return todosLosRegistros.firstWhere((r) {
        final c = (r['cod_celda'] ?? '').toString().trim().toUpperCase();
        final estado = (r['estado'] ?? '').toString().toUpperCase();
        return c == codCelda.trim().toUpperCase() && estado == 'ACTIVO';
      });
    } catch (_) {
      // 2. Si no tiene activo, busca si está en PASIVO
      try {
        return todosLosRegistros.firstWhere((r) {
          final c = (r['cod_celda'] ?? '').toString().trim().toUpperCase();
          final estado = (r['estado'] ?? '').toString().toUpperCase();
          return c == codCelda.trim().toUpperCase() && estado == 'PASIVO';
        });
      } catch (_) {
        return null;
      }
    }
  }

  // =========================================================================
  // ACCIONES OPERATIVAS: VOLCAR (ACTIVO -> PASIVO) E INACTIVAR (PASIVO -> INACTIVO)
  // =========================================================================
  Future<void> _volcarCeldaActiva(Map<String, dynamic> celda) async {
    final codCelda = celda['cod_celda'];
    final lote = celda['lote_proceso'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kColorPasivaIconBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.layers_clear_rounded, color: kColorPasivaText, size: 22),
            ),
            const SizedBox(width: 10),
            const Text("¿VOLCAR CELDA?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          "La Celda $codCelda (Lote $lote) pasará a estado PASIVO para quedar lista para el llenado de Big Bags.",
          style: const TextStyle(fontSize: 13, color: kColorTextSecondary, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR", style: TextStyle(color: kColorTextSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kColorAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRMAR VOLCADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final db = await dbHelper.database;
      await db.update(
        'celdas_recepcion',
        {'estado': 'PASIVO', 'sincronizado': 0},
        where: 'reg_local = ?',
        whereArgs: [celda['reg_local']],
      );
      _mostrarToast("Celda $codCelda pasada a PASIVO (lista para embolsar)", tipo: 'info');
      _cargarDatosCompletos();
    }
  }

  Future<void> _inactivarCeldaPasiva(Map<String, dynamic> celda) async {
    final codCelda = celda['cod_celda'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kColorDangerSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_open_rounded, color: kColorDanger, size: 22),
            ),
            const SizedBox(width: 10),
            const Text("¿LIBERAR CELDA?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          "La Celda $codCelda se marcará como INACTIVA, liberando el espacio para nuevas descargas.",
          style: const TextStyle(fontSize: 13, color: kColorTextSecondary, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR", style: TextStyle(color: kColorTextSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kColorDanger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("LIBERAR / INACTIVAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final db = await dbHelper.database;
      await db.update(
        'celdas_recepcion',
        {'estado': 'INACTIVO', 'sincronizado': 0},
        where: 'reg_local = ?',
        whereArgs: [celda['reg_local']],
      );
      _mostrarToast("Celda $codCelda liberada con éxito", tipo: 'exito');
      _cargarDatosCompletos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalActivas = todosLosRegistros.where((r) => (r['estado'] ?? '').toString().toUpperCase() == 'ACTIVO').length;
    final int totalPasivas = todosLosRegistros.where((r) => (r['estado'] ?? '').toString().toUpperCase() == 'PASIVO').length;

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
                        Text("MONITOR CELDAS", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 14.5, color: kColorText)),
                        Text("", style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _cargarDatosCompletos,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kColorAccentSoft,
                        border: Border.all(color: kColorAccent.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 15, color: kColorAccentDark),
                          SizedBox(width: 4),
                          Text("ACTUALIZAR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorAccentDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // PANEL DE MÉTRICAS + BUSCADOR + SOLAPAS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kColorSurface,
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Chip Activas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: kColorActivaBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kColorActivaBorder)),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: kColorActivaText, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text("$totalActivas ACTIVAS", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorActivaText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chip Pasivas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: kColorPasivaBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kColorPasivaBorder)),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: kColorPasivaText, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text("$totalPasivas PASIVAS", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorPasivaText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kColorBorder)),
                      child: Text("${todosLosRegistros.length} REGISTROS", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Buscador
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: kColorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kColorBorder),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _aplicarFiltro,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kColorText),
                    decoration: InputDecoration(
                      hintText: "Buscar por celda, lote, productor, variedad o fecha...",
                      hintStyle: const TextStyle(fontSize: 12, color: kColorTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kColorTextSecondary),
                      suffixIcon: queryBusqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: kColorTextSecondary),
                              onPressed: () {
                                _searchController.clear();
                                _aplicarFiltro("");
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Solapas
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kColorBorder)),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: kColorSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kColorBorder),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    labelColor: kColorAccentDark,
                    unselectedLabelColor: kColorTextSecondary,
                    labelStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11.5),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, fontSize: 11.5),
                    tabs: const [
                      Tab(text: "PANELES POR CELDA"),
                      Tab(text: "HISTORIAL POR FECHA"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSolapaPanelesPorCelda(),
                      _buildSolapaHistorialPorFecha(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SOLAPA 1: PANELES POR CELDA (ORDENADAS: ACTIVAS -> PASIVAS -> LIBRES)
  // =========================================================================
  Widget _buildSolapaPanelesPorCelda() {
    final Set<String> nombresCeldas = {};
    for (var c in celdasFisicas) {
      final nom = (c['celda_nombre'] ?? c['celda_numero'] ?? '').toString().trim();
      if (nom.isNotEmpty) nombresCeldas.add(nom);
    }
    for (var r in todosLosRegistros) {
      final nom = (r['cod_celda'] ?? '').toString().trim();
      if (nom.isNotEmpty) nombresCeldas.add(nom);
    }

    final listaCeldas = nombresCeldas.toList();

    // ACA ES LO NUEVO: Ordenamiento estricto: ACTIVAS (1) -> PASIVAS (2) -> LIBRES (3)
    listaCeldas.sort((a, b) {
      final regA = _obtenerRegistroActualCelda(a);
      final regB = _obtenerRegistroActualCelda(b);

      final pesoA = (regA?['estado'] == 'ACTIVO') ? 1 : ((regA?['estado'] == 'PASIVO') ? 2 : 3);
      final pesoB = (regB?['estado'] == 'ACTIVO') ? 1 : ((regB?['estado'] == 'PASIVO') ? 2 : 3);

      if (pesoA != pesoB) return pesoA.compareTo(pesoB);
      return a.compareTo(b);
    });

    final listaFiltrada = listaCeldas.where((celda) {
      if (queryBusqueda.isEmpty) return true;
      final hist = _obtenerHistorialDeCelda(celda);
      final coincideCelda = celda.toLowerCase().contains(queryBusqueda);
      final coincideHist = hist.any((h) =>
          (h['lote_proceso'] ?? '').toString().toLowerCase().contains(queryBusqueda) ||
          (h['productor'] ?? '').toString().toLowerCase().contains(queryBusqueda) ||
          (h['variedad'] ?? '').toString().toLowerCase().contains(queryBusqueda));
      return coincideCelda || coincideHist;
    }).toList();

    if (listaFiltrada.isEmpty) {
      return _buildVacioMensaje("No se encontraron celdas para la búsqueda");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatosCompletos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: listaFiltrada.length,
        itemBuilder: (context, index) {
          final codCelda = listaFiltrada[index];
          final registroActual = _obtenerRegistroActualCelda(codCelda);
          final historial = _obtenerHistorialDeCelda(codCelda);
          return _buildCardArchiveroCelda(codCelda, registroActual, historial);
        },
      ),
    );
  }

  // ACA ES LO NUEVO: Tarjeta con color pastel según estado + Botón para Volcar o Inactivar
  Widget _buildCardArchiveroCelda(String codCelda, Map<String, dynamic>? regActual, List<Map<String, dynamic>> historial) {
    final String estado = (regActual?['estado'] ?? 'LIBRE').toString().toUpperCase();
    final bool esActiva = estado == 'ACTIVO';
    final bool esPasiva = estado == 'PASIVO';

    // Colorimetría pastel adaptativa
    Color cardBg = kColorSurface;
    Color borderCol = kColorBorder;
    Color iconBg = kColorBg;
    Color iconCol = kColorTextSecondary;
    Color badgeBg = kColorBg;
    Color badgeTxt = kColorTextSecondary;

    if (esActiva) {
      cardBg = kColorActivaBg;
      borderCol = kColorActivaBorder;
      iconBg = kColorActivaIconBg;
      iconCol = kColorActivaText;
      badgeBg = kColorActivaIconBg;
      badgeTxt = kColorActivaText;
    } else if (esPasiva) {
      cardBg = kColorPasivaBg;
      borderCol = kColorPasivaBorder;
      iconBg = kColorPasivaIconBg;
      iconCol = kColorPasivaText;
      badgeBg = kColorPasivaIconBg;
      badgeTxt = kColorPasivaText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: (esActiva || esPasiva) ? 1.5 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarModalArchiveroCompletoDeCelda(codCelda, historial),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Celda + Estado + Cantidad de rotaciones
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Icon(Icons.warehouse_rounded, color: iconCol, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "CELDA $codCelda".toUpperCase(),
                                style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 15.5, color: kColorText),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderCol)),
                                child: Text(
                                  estado,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeTxt),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text("${historial.length} rotaciones en historial archivado", style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kColorTextSecondary),
                  ],
                ),

                // Lote en curso (ACTIVO o PASIVO)
                if (regActual != null && (esActiva || esPasiva)) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: kColorBorder),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kColorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "LOTE: ${regActual['lote_proceso'] ?? 'S/L'}",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: esActiva ? kColorActivaText : kColorPasivaText),
                            ),
                            Text(
                              "${regActual['fecha_reg'] ?? ''}",
                              style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${regActual['productor'] ?? 'S/P'} • Cuadro ${regActual['cuadro'] ?? 'S/C'} • ${regActual['variedad'] ?? 'Nuez'}",
                          style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BOTONES DE ACCIÓN DIRECTOS EN LA TARJETA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (esActiva)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.layers_clear_rounded, size: 15),
                          label: const Text("VOLCAR A PASIVO", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          onPressed: () => _volcarCeldaActiva(regActual),
                        ),
                      if (esPasiva)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorDanger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 15),
                          label: const Text("LIBERAR / INACTIVAR", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          onPressed: () => _inactivarCeldaPasiva(regActual),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SOLAPA 2: HISTORIAL POR FECHA (EVENTOS SUELTOS CRONOLÓGICOS)
  // =========================================================================
  Widget _buildSolapaHistorialPorFecha() {
    if (registrosFiltrados.isEmpty) {
      return _buildVacioMensaje("No hay registros en el historial");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatosCompletos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: registrosFiltrados.length,
        itemBuilder: (context, index) {
          final item = registrosFiltrados[index];
          return _buildCardItemHistorialFecha(item);
        },
      ),
    );
  }

  Widget _buildCardItemHistorialFecha(Map<String, dynamic> item) {
    final String estado = (item['estado'] ?? '').toString().toUpperCase();
    final bool esActivo = estado == 'ACTIVO';
    final bool esPasivo = estado == 'PASIVO';

    String label1 = (item['cal1'] != null && item['cal1'].toString().isNotEmpty) ? item['cal1'].toString() : (calibresMaestros.isNotEmpty ? calibresMaestros[0] : "C1");
    String label2 = (item['cal2'] != null && item['cal2'].toString().isNotEmpty) ? item['cal2'].toString() : (calibresMaestros.length > 1 ? calibresMaestros[1] : "C2");
    String label3 = (item['cal3'] != null && item['cal3'].toString().isNotEmpty) ? item['cal3'].toString() : (calibresMaestros.length > 2 ? calibresMaestros[2] : "C3");
    String label4 = (item['cal4'] != null && item['cal4'].toString().isNotEmpty) ? item['cal4'].toString() : (calibresMaestros.length > 3 ? calibresMaestros[3] : "C4");

    Color badgeBg = kColorBg;
    Color badgeTxt = kColorTextSecondary;
    if (esActivo) {
      badgeBg = kColorActivaIconBg;
      badgeTxt = kColorActivaText;
    } else if (esPasivo) {
      badgeBg = kColorPasivaIconBg;
      badgeTxt = kColorPasivaText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: esActivo ? kColorActivaBorder : (esPasivo ? kColorPasivaBorder : kColorBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _mostrarModalDetalleLote(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.layers_outlined, color: badgeTxt, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("CELDA ${item['cod_celda']}".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kColorText)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(6)),
                                child: Text("LOTE ${item['lote_proceso'] ?? 'S/L'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${item['productor'] ?? 'S/P'} • Cuadro ${item['cuadro'] ?? 'S/C'} • ${item['variedad'] ?? 'Nuez'}",
                            style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(estado, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeTxt)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: kColorBorder),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMiniChipCalibre(label1, item['nro_1']),
                    const SizedBox(width: 6),
                    _buildMiniChipCalibre(label2, item['nro_2']),
                    const SizedBox(width: 6),
                    _buildMiniChipCalibre(label3, item['nro_3']),
                    const SizedBox(width: 6),
                    _buildMiniChipCalibre(label4, item['nro_4']),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: kColorTextSecondary),
                        const SizedBox(width: 4),
                        Text("${item['fecha_reg'] ?? ''}", style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MODAL 1: ARCHIVERO HISTÓRICO COMPLETO DE UNA CELDA ESPECÍFICA
  // =========================================================================
  void _mostrarModalArchiveroCompletoDeCelda(String codCelda, List<Map<String, dynamic>> historial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ARCHIVERO HISTÓRICO DE CELDA", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5)),
                      Text("CELDA $codCelda".toUpperCase(), style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 20, color: kColorText)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kColorTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: historial.isEmpty
                  ? const Center(child: Text("No hay registros archivados para esta celda.", style: TextStyle(color: kColorTextSecondary, fontSize: 13)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      itemCount: historial.length,
                      itemBuilder: (context, index) {
                        final item = historial[index];
                        final String estadoItem = (item['estado'] ?? '').toString().toUpperCase();
                        final bool esActivo = estadoItem == 'ACTIVO';
                        final bool esPasivo = estadoItem == 'PASIVO';

                        Color badgeBg = kColorBg;
                        Color badgeTxt = kColorTextSecondary;
                        if (esActivo) {
                          badgeBg = kColorActivaIconBg;
                          badgeTxt = kColorActivaText;
                        } else if (esPasivo) {
                          badgeBg = kColorPasivaIconBg;
                          badgeTxt = kColorPasivaText;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kColorBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: esActivo ? kColorActivaBorder : (esPasivo ? kColorPasivaBorder : kColorBorder)),
                          ),
                          child: InkWell(
                            onTap: () => _mostrarModalDetalleLote(item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("LOTE: ${item['lote_proceso'] ?? 'S/L'}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kColorText)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                      child: Text(estadoItem, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeTxt)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("Productor: ${item['productor'] ?? 'S/P'} • Cuadro: ${item['cuadro'] ?? 'S/C'}", style: const TextStyle(fontSize: 12, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                                Text("Variedad: ${item['variedad'] ?? 'Nuez'} (${item['cultivo'] ?? 'Frutos'})", style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: kColorTextSecondary),
                                    const SizedBox(width: 4),
                                    Text("Fecha: ${item['fecha_reg']} • Hora: ${item['hora'] ?? ''}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kColorTextSecondary)),
                                    const Spacer(),
                                    const Text("Ver detalles >", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorAccent)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MODAL 2: FICHA DE DETALLES Y DISTRIBUCIÓN DE CALIBRES DEL LOTE
  // =========================================================================
  void _mostrarModalDetalleLote(Map<String, dynamic> item) {
    String label1 = (item['cal1'] != null && item['cal1'].toString().isNotEmpty) ? item['cal1'].toString() : (calibresMaestros.isNotEmpty ? calibresMaestros[0] : "CALIBRE 1");
    String label2 = (item['cal2'] != null && item['cal2'].toString().isNotEmpty) ? item['cal2'].toString() : (calibresMaestros.length > 1 ? calibresMaestros[1] : "CALIBRE 2");
    String label3 = (item['cal3'] != null && item['cal3'].toString().isNotEmpty) ? item['cal3'].toString() : (calibresMaestros.length > 2 ? calibresMaestros[2] : "CALIBRE 3");
    String label4 = (item['cal4'] != null && item['cal4'].toString().isNotEmpty) ? item['cal4'].toString() : (calibresMaestros.length > 3 ? calibresMaestros[3] : "CALIBRE 4");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TRAZABILIDAD DE ALMACENAJE", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5)),
                      Text("CELDA ${item['cod_celda']}".toUpperCase(), style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 20, color: kColorText)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kColorTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  _buildEtiquetaSeccion("FICHA TÉCNICA Y ORIGEN"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRenglonDato("Lote Proceso", item['lote_proceso'], esDestacado: true),
                        const Divider(height: 14, color: kColorBorder),
                        _buildRenglonDato("Establecimiento", item['establecimiento']),
                        _buildRenglonDato("Cuadro de Origen", item['cuadro']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Variedad / Cultivo", "${item['variedad'] ?? 'Nuez'} (${item['cultivo'] ?? 'Frutos'})"),
                        _buildRenglonDato("Fecha de Carga", item['fecha_reg']),
                        _buildRenglonDato("Hora de Registro", item['hora']),
                        _buildRenglonDato("Estado de Celda", item['estado']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildEtiquetaSeccion("DISTRIBUCIÓN DE CALIBRES EN CELDA"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildBarraModal(label1, item['nro_1']),
                        _buildBarraModal(label2, item['nro_2']),
                        _buildBarraModal(label3, item['nro_3']),
                        _buildBarraModal(label4, item['nro_4']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ELEMENTOS AUXILIARES ---
  Widget _buildMiniChipCalibre(String nombre, String? porcentaje) {
    final String val = (porcentaje == null || porcentaje.isEmpty) ? '0' : porcentaje.replaceAll('%', '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$nombre: ", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: kColorTextSecondary)),
          Text("$val%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorAccentDark)),
        ],
      ),
    );
  }

  Widget _buildEtiquetaSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorTextSecondary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildRenglonDato(String etiqueta, String? valor, {bool esDestacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
          Text(
            (valor == null || valor.isEmpty) ? "S/D" : valor,
            style: TextStyle(fontSize: esDestacado ? 13.5 : 12.5, fontWeight: FontWeight.w700, color: esDestacado ? kColorAccentDark : kColorText),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraModal(String nombre, String? porcentaje) {
    double valorProgreso = (double.tryParse(porcentaje?.replaceAll('%', '').trim() ?? '0') ?? 0) / 100;
    double valorDisplay = (double.tryParse(porcentaje?.replaceAll('%', '').trim() ?? '0') ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: kColorText)),
              Text("${valorDisplay.toStringAsFixed(1)} %", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: kColorAccentDark)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: valorProgreso.clamp(0.0, 1.0),
              backgroundColor: kColorSurface,
              color: kColorAccent,
              minHeight: 7,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVacioMensaje(String texto) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: kColorSurface, shape: BoxShape.circle, border: Border.all(color: kColorBorder)),
                child: const Icon(Icons.grid_off_rounded, size: 36, color: kColorTextSecondary),
              ),
              const SizedBox(height: 14),
              Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText)),
              const SizedBox(height: 4),
              const Text("Verifica los términos o actualiza los datos desde la nube.", style: TextStyle(fontSize: 12, color: kColorTextSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarToast(String mensaje, {String tipo = 'exito'}) {
    Color bg = kColorAccentSoft;
    Color colorTxt = kColorAccentDark;
    IconData icon = Icons.check_circle_rounded;

    if (tipo == 'error') {
      bg = kColorDangerSoft;
      colorTxt = kColorDanger;
      icon = Icons.error_rounded;
    } else if (tipo == 'info') {
      bg = kColorPasivaIconBg;
      colorTxt = kColorPasivaText;
      icon = Icons.info_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colorTxt, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje, style: TextStyle(color: colorTxt, fontWeight: FontWeight.w700, fontSize: 12.5))),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorTxt.withOpacity(0.2))),
        elevation: 4,
      ),
    );
  }
}