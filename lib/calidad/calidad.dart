import 'package:flutter/material.dart';
import 'package:la_rivera_celdas/sincronizar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../base_datos.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// =========================================================================
// PALETA DE DISEÑO AGROSOFT INDUSTRIAL (SISTEMA DE TOKENS CSS)
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

// TONOS PASTEL PARA ESTADOS DE CALIDAD
const Color kColorActivaBg = Color(0xFFFFFBEB);
const Color kColorActivaBorder = Color(0xFFFDE68A);
const Color kColorActivaText = Color(0xFF92400E);
const Color kColorActivaIconBg = Color(0xFFFEF3C7);

const Color kColorPasivaBg = Color(0xFFF5F3FF);
const Color kColorPasivaBorder = Color(0xFFDDD6FE);
const Color kColorPasivaText = Color(0xFF5B21B6);
const Color kColorPasivaIconBg = Color(0xFFEDE9FE);

class PaginaCalidad extends StatefulWidget {
  const PaginaCalidad({super.key});

  @override
  State<PaginaCalidad> createState() => _PaginaCalidadState();
}

class _PaginaCalidadState extends State<PaginaCalidad> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Estados del flujo
  String? qrEscaneado;
  String? nombreCeldaActiva;
  String? establecimientoSel;
  String? cuadroSel;
  String? calidadSel;
  DateTime fechaSel = DateTime.now();
  String? regLocalEditando;

  // Listados de datos
  List<Map<String, dynamic>> registrosHistorial = [];
  List<Map<String, dynamic>> registrosHistorialFiltrados = [];
  List<Map<String, dynamic>> registrosRanking = [];
  List<Map<String, dynamic>> registrosRankingFiltrados = [];
  List<Map<String, dynamic>> registrosPasivos = [];
  List<Map<String, dynamic>> registrosPasivosFiltrados = [];
  bool cargandoHistorial = false;
  bool cargandoPasivos = false;
  String usuarioActivo = "Operador";

  // Filtros
  List<String> productoresDisponibles = [];
  String? productorFiltro;
  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  // Catálogos
  List<String> establecimientos = [];
  List<Map<String, dynamic>> cuadros = [];
  List<String> calibres = [];
  List<String> calidades = [];
  final Map<String, TextEditingController> controladoresCalibre = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 2) {
          _cargarArchiveroPasivos();
        } else {
          _cargarHistorial();
        }
      }
    });
    _cargarUsuarioEnSesion();
    _cargarEstablecimientos();
    _cargarCalibres();
    _cargarCalidades();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (var c in controladoresCalibre.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarUsuarioEnSesion() async {
    final user = await dbHelper.obtenerUsuarioLocal();
    if (user != null && mounted) {
      setState(() {
        usuarioActivo = user['operario']?.toString() ?? user['correo']?.toString() ?? 'Operador';
      });
    }
  }

  // Carga de celdas activas y cálculo del ranking en vivo
  Future<void> _cargarHistorial() async {
    setState(() => cargandoHistorial = true);
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT r.*, c.cal1, c.nro_1, c.cal2, c.nro_2, c.cal3, c.nro_3, c.cal4, c.nro_4, c.calidad_final,
             cc.establecimiento
      FROM celdas_recepcion r
      LEFT JOIN celdas_control_calidad_calibre c ON r.lote_proceso = c.lote_proceso
      LEFT JOIN control_calidad cc ON r.reg_local = cc.reg_celda
      WHERE r.estado = 'ACTIVO'
      ORDER BY r.fecha_reg DESC, r.hora DESC
    ''');

    final List<Map<String, dynamic>> ranking = List.from(res);
    ranking.sort((a, b) {
      final double cal1A = double.tryParse((a['nro_1'] ?? '0').toString().replaceAll('%', '').trim()) ?? 0;
      final double cal1B = double.tryParse((b['nro_1'] ?? '0').toString().replaceAll('%', '').trim()) ?? 0;
      final String calidadA = (a['calidad_final'] ?? 'ESTANDAR').toString().toUpperCase();
      final String calidadB = (b['calidad_final'] ?? 'ESTANDAR').toString().toUpperCase();

      final int pesoA = (calidadA == 'PRIMERA') ? 3 : ((calidadA == 'ESTANDAR') ? 2 : 1);
      final int pesoB = (calidadB == 'PRIMERA') ? 3 : ((calidadB == 'ESTANDAR') ? 2 : 1);

      if (pesoA != pesoB) return pesoB.compareTo(pesoA);
      return cal1B.compareTo(cal1A);
    });

    setState(() {
      registrosHistorial = res;
      registrosRanking = ranking;
      _actualizarListaProductores();
      _aplicarFiltros();
      cargandoHistorial = false;
    });
  }

  Future<void> _cargarArchiveroPasivos() async {
    setState(() => cargandoPasivos = true);
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT r.*, c.cal1, c.nro_1, c.cal2, c.nro_2, c.cal3, c.nro_3, c.cal4, c.nro_4, c.calidad_final,
             cc.establecimiento
      FROM celdas_recepcion r
      LEFT JOIN celdas_control_calidad_calibre c ON r.lote_proceso = c.lote_proceso
      LEFT JOIN control_calidad cc ON r.reg_local = cc.reg_celda
      WHERE r.estado = 'PASIVO' OR c.estado_celda = 'PASIVO'
      ORDER BY r.fecha_reg DESC, r.hora DESC
    ''');
    setState(() {
      registrosPasivos = res;
      _actualizarListaProductores();
      _aplicarFiltros();
      cargandoPasivos = false;
    });
  }

  void _actualizarListaProductores() {
    final Set<String> prods = {};
    for (var r in registrosHistorial) {
      final p = (r['productor'] ?? '').toString().trim();
      if (p.isNotEmpty && p != 'S/P') prods.add(p.toUpperCase());
    }
    for (var r in registrosPasivos) {
      final p = (r['productor'] ?? '').toString().trim();
      if (p.isNotEmpty && p != 'S/P') prods.add(p.toUpperCase());
    }
    setState(() {
      productoresDisponibles = prods.toList()..sort();
    });
  }

  void _aplicarFiltros() {
    final query = queryBusqueda.toLowerCase().trim();

    bool cumpleFiltros(Map<String, dynamic> item) {
      final cod = (item['cod_celda'] ?? '').toString().toLowerCase();
      final lote = (item['lote_proceso'] ?? '').toString().toLowerCase();
      final prod = (item['productor'] ?? '').toString().toUpperCase();
      final variedad = (item['variedad'] ?? '').toString().toLowerCase();
      final cuadro = (item['cuadro'] ?? '').toString().toLowerCase();

      final coincideQuery = query.isEmpty ||
          cod.contains(query) ||
          lote.contains(query) ||
          prod.toLowerCase().contains(query) ||
          variedad.contains(query) ||
          cuadro.contains(query);

      final coincideProd = productorFiltro == null || prod == productorFiltro;

      return coincideQuery && coincideProd;
    }

    setState(() {
      registrosHistorialFiltrados = registrosHistorial.where(cumpleFiltros).toList();
      registrosRankingFiltrados = registrosRanking.where(cumpleFiltros).toList();
      registrosPasivosFiltrados = registrosPasivos.where(cumpleFiltros).toList();
    });
  }

  Future<void> _cargarEstablecimientos() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res =
        await db.rawQuery('SELECT establecimiento FROM inventario GROUP BY establecimiento');
    setState(() {
      establecimientos = res.map((e) => e['establecimiento'] as String).toList();
    });
  }

  Future<void> _cargarCuadros(String est) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res =
        await db.query('inventario', where: 'establecimiento = ?', whereArgs: [est]);
    setState(() {
      cuadros = res;
      cuadroSel = null;
      calidadSel = null;
    });
  }

  Future<void> _cargarCalibres() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query('parametros_calibre');
    setState(() {
      calibres = res.map((c) => c['calibre'].toString()).toList();
      for (var cal in calibres) {
        controladoresCalibre[cal] = TextEditingController();
      }
    });
  }

  Future<void> _cargarCalidades() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query('parametros_calidad');
    setState(() {
      calidades = res.map((c) => c['calidad'].toString()).toList();
      if (calidades.isEmpty) {
        calidades = ['ESTANDAR', 'PRIMERA', 'COMERCIAL', 'DESCARTE'];
      }
    });
  }

  // ESTO LO MODIFIQUE: Volcado atómico en SQLite y sincronización de celdas en background
  Future<void> _volcarCelda(String regLocal, String lote) async {
    final db = await dbHelper.database;
    try {
      await db.transaction((txn) async {
        await txn.update(
          'celdas_recepcion',
          {'estado': 'PASIVO', 'sincronizado': 0},
          where: 'reg_local = ?',
          whereArgs: [regLocal],
        );
        await txn.update(
          'celdas_control_calidad_calibre',
          {'estado_celda': 'PASIVO', 'sincronizado': 0},
          where: 'lote_proceso = ?',
          whereArgs: [lote],
        );
      });

      _mostrarToast("Celda volcada a PASIVO (lista para embolsar)", tipo: 'info');
      _cargarHistorial();
      _cargarArchiveroPasivos();

      // ACA ES LO NUEVO: Subida en segundo plano pasando el usuario activo
      PaginaSincronizar.sincronizarCeldas(usuario: usuarioActivo).catchError((e) {
        debugPrint("Sincronización de Celdas diferida: $e");
        return 0;
      });
    } catch (e) {
      _mostrarToast("Error al archivar: $e", tipo: 'error');
    }
  }

  void _prepararEdicion(Map<String, dynamic> item) async {
    setState(() {
      regLocalEditando = item['reg_local'];
      qrEscaneado = item['cod_celda'];
      nombreCeldaActiva = item['cod_celda'];
      establecimientoSel = item['establecimiento'];
      calidadSel = item['calidad_final'];
      fechaSel = DateTime.tryParse(item['fecha_reg'] ?? '') ?? DateTime.now();

      if (calibres.isNotEmpty) controladoresCalibre[calibres[0]]?.text = item['nro_1'] ?? '0';
      if (calibres.length > 1) controladoresCalibre[calibres[1]]?.text = item['nro_2'] ?? '0';
      if (calibres.length > 2) controladoresCalibre[calibres[2]]?.text = item['nro_3'] ?? '0';
      if (calibres.length > 3) controladoresCalibre[calibres[3]]?.text = item['nro_4'] ?? '0';
    });

    if (establecimientoSel != null) {
      await _cargarCuadros(establecimientoSel!);
      setState(() => cuadroSel = item['cuadro']);
    }

    _abrirModalFormulario();
  }

  // --- ESCÁNER Y FORMULARIO ---
  void _abrirEscanerModal(StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                "APUNTE AL CÓDIGO QR DE LA CELDA",
                style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 13, color: kColorTextSecondary),
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ClipRRect(
                child: MobileScanner(
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final codigo = barcodes.first.displayValue ?? "";
                      Navigator.pop(ctx);
                      final db = await dbHelper.database;
                      final res = await db.query('parametros_celdas', where: 'qr_celda = ?', whereArgs: [codigo]);
                      if (res.isNotEmpty) {
                        setState(() {
                          qrEscaneado = codigo;
                          nombreCeldaActiva = res.first['celda_nombre'].toString();
                        });
                        setModalState(() {});
                      } else {
                        _mostrarToast("QR no reconocido en catálogo", tipo: 'error');
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
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
                          Text(
                            regLocalEditando != null ? "MODIFICACIÓN DE LOTE" : "NUEVA LECTURA DE PLANTA",
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: kColorAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            nombreCeldaActiva ?? "Escaneo Requerido",
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: kColorText,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          _resetearFormulario();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded, color: kColorTextSecondary),
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
                      if (nombreCeldaActiva == null)
                        InkWell(
                          onTap: () => _abrirEscanerModal(setModalState),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kColorBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 36, color: kColorAccent),
                                SizedBox(height: 10),
                                Text("ESCANEAR CÓDIGO QR DE CELDA",
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kColorText)),
                                SizedBox(height: 4),
                                Text("Apunta con la cámara para sincronizar origen",
                                    style: TextStyle(fontSize: 11.5, color: kColorTextSecondary)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        _buildSelectorFechaModal(setModalState),
                        const SizedBox(height: 16),
                        _buildEtiquetaSeccion("1. ESTABLECIMIENTO"),
                        _buildGridOpciones(
                          establecimientos,
                          (v) async {
                            setModalState(() => establecimientoSel = v);
                            setState(() => establecimientoSel = v);
                            await _cargarCuadros(v);
                            setModalState(() {});
                          },
                          establecimientoSel,
                        ),
                        if (establecimientoSel != null) ...[
                          const SizedBox(height: 16),
                          _buildEtiquetaSeccion("2. CUADRO"),
                          _buildGridOpciones(
                            cuadros.map((e) => e['cuadro'] as String).toList(),
                            (v) {
                              setModalState(() => cuadroSel = v);
                              setState(() => cuadroSel = v);
                            },
                            cuadroSel,
                          ),
                        ],
                        if (cuadroSel != null) ...[
                          const SizedBox(height: 16),
                          _buildEtiquetaSeccion("3. CALIDAD COMERCIAL"),
                          _buildGridOpciones(
                            calidades.isNotEmpty ? calidades : ['ESTANDAR', 'PRIMERA', 'COMERCIAL', 'DESCARTE'],
                            (v) {
                              setModalState(() => calidadSel = v);
                              setState(() => calidadSel = v);
                            },
                            calidadSel,
                          ),
                        ],
                        if (calidadSel != null) ...[
                          const SizedBox(height: 16),
                          _buildEtiquetaSeccion("4. DISTRIBUCIÓN DE CALIBRES (%)"),
                          _buildFormCalibres(setModalState),
                          const SizedBox(height: 24),
                          _buildBotonGuardarModal(context),
                        ]
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
                          Text("VOLVER",
                              style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
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
                        Text("CONTROL DE CALIDAD",
                            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText)),
                        Text("Monitoreo de Celdas",
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _cargarHistorial,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kColorAccentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kColorAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: kColorAccentDark),
                          SizedBox(width: 4),
                          Text("🔃", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorAccentDark)),
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
          // PANEL DE BÚSQUEDA + FILTRO HORIZONTAL DE PRODUCTORES
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kColorSurface,
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Column(
              children: [
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
                    onChanged: (val) {
                      queryBusqueda = val;
                      _aplicarFiltros();
                    },
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kColorText),
                    decoration: InputDecoration(
                      hintText: "Buscar por celda, lote, variedad o cuadro...",
                      hintStyle: const TextStyle(fontSize: 12, color: kColorTextSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kColorTextSecondary),
                      suffixIcon: queryBusqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: kColorTextSecondary),
                              onPressed: () {
                                _searchController.clear();
                                queryBusqueda = "";
                                _aplicarFiltros();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botones horizontales de filtro por productor
                if (productoresDisponibles.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildChipFiltroProductor("TODOS", null),
                        ...productoresDisponibles.map((prod) => _buildChipFiltroProductor(prod, prod)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // BARRA DE SOLAPAS TIPO ARCHIVERO AGROSOFT
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: kColorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kColorBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: kColorSurface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: kColorBorder),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    labelColor: kColorAccentDark,
                    unselectedLabelColor: kColorTextSecondary,
                    labelStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, fontSize: 11),
                    tabs: [
                      Tab(text: "ACTIVAS (${registrosHistorialFiltrados.length})"),
                      Tab(text: "RANKING (${registrosRankingFiltrados.length})"),
                      Tab(text: "ARCHIVERO (${registrosPasivosFiltrados.length})"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO DE SOLAPAS
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaArchivero(esPasivo: false),
                _buildListaRankingCalidadEnVivo(),
                _buildListaArchivero(esPasivo: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _resetearFormulario();
          _abrirModalFormulario();
        },
        backgroundColor: kColorAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: const Text("NUEVA LECTURA",
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.4)),
      ),
    );
  }

  Widget _buildChipFiltroProductor(String label, String? valor) {
    final bool seleccionado = productorFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            productorFiltro = valor;
            _aplicarFiltros();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionado ? kColorAccentDark : kColorBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: seleccionado ? kColorAccentDark : kColorBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: seleccionado ? Colors.white : kColorTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SOLAPA RANKING EN VIVO CON CUADRO DE CALIDAD RESALTADO Y PRODUCTOR/FECHA
  // =========================================================================
  Widget _buildListaRankingCalidadEnVivo() {
    if (cargandoHistorial) {
      return const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5));
    }

    if (registrosRankingFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_rounded, size: 48, color: kColorTextSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text("No hay celdas activas para rankear",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorTextSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      color: kColorAccent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: registrosRankingFiltrados.length,
        itemBuilder: (context, index) {
          final item = registrosRankingFiltrados[index];
          final String calidad = (item['calidad_final'] ?? 'ESTANDAR').toString().toUpperCase();
          final int posicion = index + 1;

          String label1 = item['cal1'] ?? "C1";
          String label2 = item['cal2'] ?? "C2";
          String label3 = item['cal3'] ?? "C3";
          String label4 = item['cal4'] ?? "C4";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: posicion == 1 ? kColorAccent : kColorBorder, width: posicion == 1 ? 1.8 : 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: posicion == 1 ? kColorAccentDark : kColorBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kColorBorder),
                        ),
                        child: Center(
                          child: Text(
                            "#$posicion",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: posicion == 1 ? Colors.white : kColorTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "CELDA ${item['cod_celda']}".toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kColorText),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: kColorBg,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    "LOTE ${item['lote_proceso'] ?? 'S/L'}",
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kColorTextSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Prod: ${(item['productor'] ?? 'S/P').toString().toUpperCase()}",
                              style: const TextStyle(fontSize: 11.5, color: kColorText, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 11, color: kColorTextSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  "${item['fecha_reg'] ?? ''} ${item['hora'] ?? ''}",
                                  style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: calidad == 'PRIMERA' ? kColorAccentSoft : kColorActivaIconBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: calidad == 'PRIMERA' ? kColorAccent : kColorActivaBorder,
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              calidad,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: calidad == 'PRIMERA' ? kColorAccentDark : kColorActivaText,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kColorAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.layers_clear_rounded, size: 15),
                              label: const Text("VOLCAR", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.3)),
                              onPressed: () => _volcarCelda(item['reg_local'], item['lote_proceso']),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: kColorBorder),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildMiniCalibreBarra(label1, item['nro_1'])),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniCalibreBarra(label2, item['nro_2'])),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniCalibreBarra(label3, item['nro_3'])),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniCalibreBarra(label4, item['nro_4'])),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniCalibreBarra(String nombre, String? porcentaje) {
    final double num = double.tryParse(porcentaje?.replaceAll('%', '').trim() ?? '0') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(nombre, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kColorTextSecondary)),
            Text("${num.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorText)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (num / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: kColorBg,
            color: num > 40 ? kColorAccent : (num > 20 ? const Color(0xFF34C759) : kColorTextSecondary.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  // --- LISTADO ARCHIVERO (ACTIVAS Y PASIVAS) ---
  Widget _buildListaArchivero({required bool esPasivo}) {
    final lista = esPasivo ? registrosPasivosFiltrados : registrosHistorialFiltrados;
    final cargando = esPasivo ? cargandoPasivos : cargandoHistorial;

    if (cargando) {
      return const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5));
    }

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(esPasivo ? Icons.inventory_2_outlined : Icons.warehouse_rounded, size: 48, color: kColorTextSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(esPasivo ? "Archivero vacío" : "No hay celdas activas registradas",
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorTextSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: esPasivo ? _cargarArchiveroPasivos : _cargarHistorial,
      color: kColorAccent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final item = lista[index];
          final String calidad = (item['calidad_final'] ?? 'ESTANDAR').toString().toUpperCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _mostrarFichaDetallesModal(item, esPasivo: esPasivo),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: esPasivo ? kColorBg : kColorAccentSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kColorBorder),
                        ),
                        child: Icon(
                          esPasivo ? Icons.archive_outlined : Icons.warehouse_rounded,
                          color: esPasivo ? kColorTextSecondary : kColorAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${item['cod_celda']}".toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kColorText),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kColorBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: kColorBorder),
                                  ),
                                  child: Text("LOTE ${item['lote_proceso'] ?? 'S/L'}",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Prod: ${(item['productor'] ?? 'S/P').toString().toUpperCase()} • Cuadro: ${item['cuadro'] ?? 'S/C'}",
                              style: const TextStyle(fontSize: 11.5, color: kColorText, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 11, color: kColorTextSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  "${item['fecha_reg']} • ${item['hora'] ?? ''} • ${item['variedad'] ?? 'Nuez'}",
                                  style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: esPasivo ? kColorBorder : kColorAccentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              calidad,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: esPasivo ? kColorTextSecondary : kColorAccentDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MODAL DETALLES / TRAZA ---
  void _mostrarFichaDetallesModal(Map<String, dynamic> item, {required bool esPasivo}) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(esPasivo ? "HISTORIAL DE BAJA" : "FICHA DE CONTROL ACTIVO",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5)),
                      Text("CELDA ${item['cod_celda']}".toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: kColorText)),
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
                  if (!esPasivo)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kColorText,
                              side: const BorderSide(color: kColorBorder),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text("EDITAR", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context);
                              _prepararEdicion(item);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kColorDanger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.archive_outlined, size: 18),
                            label: const Text("VOLCAR (BAJA)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context);
                              _volcarCelda(item['reg_local'], item['lote_proceso']);
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  _buildEtiquetaSeccion("TRAZABILIDAD DE ORIGEN"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRenglonDato("Lote Proceso", item['lote_proceso']),
                        _buildRenglonDato("Establecimiento", item['establecimiento']),
                        _buildRenglonDato("Cuadro", item['cuadro']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Variedad / Especie", "${item['variedad'] ?? 'Nuez'} (${item['cultivo'] ?? 'Frutos'})"),
                        _buildRenglonDato("Fecha y Hora", "${item['fecha_reg']} • ${item['hora'] ?? ''}"),
                        _buildRenglonDato("Estado de Celda", item['estado'] ?? (esPasivo ? 'PASIVO' : 'ACTIVO')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEtiquetaSeccion("DISTRIBUCIÓN DE CALIBRES"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRenglonProgreso(item['cal1'] ?? "Calibre 1", item['nro_1']),
                        _buildRenglonProgreso(item['cal2'] ?? "Calibre 2", item['nro_2']),
                        _buildRenglonProgreso(item['cal3'] ?? "Calibre 3", item['nro_3']),
                        _buildRenglonProgreso(item['cal4'] ?? "Calibre 4", item['nro_4']),
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

  // --- ELEMENTOS REUTILIZABLES ---
  Widget _buildEtiquetaSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kColorTextSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _buildRenglonDato(String etiqueta, String? valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
          Text(valor ?? "S/D", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kColorText)),
        ],
      ),
    );
  }

  Widget _buildRenglonProgreso(String nombre, String? porcentaje) {
    final double num = double.tryParse(porcentaje?.replaceAll('%', '').trim() ?? '0') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kColorText)),
              Text("${num.toStringAsFixed(1)} %",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kColorAccentDark)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (num / 100).clamp(0.0, 1.0),
              backgroundColor: kColorSurface,
              color: kColorAccent,
              minHeight: 6,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSelectorFechaModal(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Fecha de Recepción:",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kColorTextSecondary)),
          InkWell(
            onTap: () async {
              final DateTime? p = await showDatePicker(
                context: context,
                initialDate: fechaSel,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (p != null) {
                setModalState(() => fechaSel = p);
                setState(() => fechaSel = p);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kColorSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kColorBorder),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(fechaSel),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kColorAccentDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridOpciones(List<String> opciones, Function(String) onSelect, String? seleccionado) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((opt) {
        final bool esIgual = opt == seleccionado;
        return InkWell(
          onTap: () => onSelect(opt),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: esIgual ? kColorAccent : kColorSurface,
              border: Border.all(color: esIgual ? kColorAccentDark : kColorBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              opt.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: esIgual ? Colors.white : kColorText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormCalibres(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        children: calibres.map((cal) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(cal, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kColorText)),
                ),
                SizedBox(
                  width: 80,
                  height: 38,
                  child: TextField(
                    controller: controladoresCalibre[cal],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kColorText),
                    decoration: InputDecoration(
                      hintText: "0%",
                      filled: true,
                      fillColor: kColorSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kColorBorder)),
                    ),
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBotonGuardarModal(BuildContext ctx) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: () => _guardarRegistro(ctx),
        child: const Text(
          "GUARDAR REGISTRO Y ARCHIVAR",
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  // ESTO LO MODIFIQUE: Persistencia local e inyección del usuario activo con sync background
  Future<void> _guardarRegistro(BuildContext ctx) async {
    final db = await dbHelper.database;
    if (nombreCeldaActiva == null || establecimientoSel == null || cuadroSel == null) {
      _mostrarToast("Faltan datos obligatorios", tipo: 'error');
      return;
    }

    String fechaHoy = DateFormat('yyyy-MM-dd').format(fechaSel);
    String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    String fechaParaLote = DateFormat('ddMMyyyy').format(fechaSel);

    try {
      if (regLocalEditando != null) {
        await db.transaction((txn) async {
          await txn.update(
            'celdas_recepcion',
            {
              'cuadro': cuadroSel,
              'cod_celda': nombreCeldaActiva,
              'celda_numero': nombreCeldaActiva,
              'sincronizado': 0,
            },
            where: 'reg_local = ?',
            whereArgs: [regLocalEditando],
          );

          await txn.update(
            'control_calidad',
            {
              'establecimiento': establecimientoSel,
              'cuadro': cuadroSel,
              'cod_celda': nombreCeldaActiva,
              'celda_nro': nombreCeldaActiva,
              'usuario': usuarioActivo,
              'sincronizado': 0,
            },
            where: 'reg_celda = ?',
            whereArgs: [regLocalEditando],
          );

          await txn.update(
            'celdas_control_calidad_calibre',
            {
              'calidad_final': calidadSel,
              'cod_celda': nombreCeldaActiva,
              'nro_1': calibres.isNotEmpty ? controladoresCalibre[calibres[0]]?.text ?? '0' : '0',
              'nro_2': calibres.length > 1 ? controladoresCalibre[calibres[1]]?.text ?? '0' : '0',
              'nro_3': calibres.length > 2 ? controladoresCalibre[calibres[2]]?.text ?? '0' : '0',
              'nro_4': calibres.length > 3 ? controladoresCalibre[calibres[3]]?.text ?? '0' : '0',
              'sincronizado': 0,
            },
            where: 'reg_local = ? or cod_historial = ?',
            whereArgs: [regLocalEditando, regLocalEditando],
          );
        });
        _mostrarToast("Registro actualizado localmente", tipo: 'exito');
      } else {
        String regLocalCabecera = String.fromCharCodes(
            Iterable.generate(8, (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.codeUnitAt(Random().nextInt(36))));
        final List<Map<String, dynamic>> resContador =
            await db.rawQuery("SELECT COUNT(*) as total FROM celdas_recepcion WHERE fecha_reg = ?", [fechaHoy]);
        int contador = ((resContador.first['total'] as int?) ?? 0) + 1;

        String loteProceso = "$fechaParaLote-${contador.toString().padLeft(4, '0')}";

        await db.transaction((txn) async {
          final List<Map<String, dynamic>> infoInv = await txn.query(
            'inventario',
            where: 'establecimiento = ? AND cuadro = ?',
            whereArgs: [establecimientoSel, cuadroSel],
            limit: 1,
          );
          String productor = (infoInv.isNotEmpty ? infoInv.first['productor'] : "S/P") ?? "S/P";
          String variedad = (infoInv.isNotEmpty ? infoInv.first['variedad'] : "S/V") ?? "S/V";
          String cultivo = (infoInv.isNotEmpty ? infoInv.first['cultivo'] : "S/C") ?? "S/C";

          await txn.insert('celdas_recepcion', {
            'fecha_reg': fechaHoy,
            'hora': horaHoy,
            'cod_celda': nombreCeldaActiva,
            'cuadro': cuadroSel,
            'celda_numero': nombreCeldaActiva,
            'productor': productor,
            'cultivo': cultivo,
            'variedad': variedad,
            'lote_proceso': loteProceso,
            'estado': 'ACTIVO',
            'reg_local': regLocalCabecera,
            'sincronizado': 0,
          });

          await txn.insert('control_calidad', {
            'reg_local': DatabaseHelper().generarIdCorto(),
            'reg_celda': regLocalCabecera,
            'cod_celda': nombreCeldaActiva,
            'celda_nro': nombreCeldaActiva,
            'lote_proceso': loteProceso,
            'fecha': fechaHoy,
            'hora': horaHoy,
            'usuario': usuarioActivo,
            'establecimiento': establecimientoSel,
            'cuadro': cuadroSel,
            'variedad': variedad,
            'sincronizado': 0,
          });

          await txn.insert('celdas_control_calidad_calibre', {
            'cod_historial': regLocalCabecera,
            'reg_local': regLocalCabecera,
            'fecha': fechaHoy,
            'cod_celda': nombreCeldaActiva,
            'productor': productor,
            'lote_proceso': loteProceso,
            'calidad_final': calidadSel ?? "ESTANDAR",
            'cal1': calibres.isNotEmpty ? calibres[0] : null,
            'nro_1': (calibres.isNotEmpty ? controladoresCalibre[calibres[0]]?.text : '0') ?? '0',
            'cal2': calibres.length > 1 ? calibres[1] : null,
            'nro_2': (calibres.length > 1 ? controladoresCalibre[calibres[1]]?.text : '0') ?? '0',
            'cal3': calibres.length > 2 ? calibres[2] : null,
            'nro_3': (calibres.length > 2 ? controladoresCalibre[calibres[2]]?.text : '0') ?? '0',
            'cal4': calibres.length > 3 ? calibres[3] : null,
            'nro_4': (calibres.length > 3 ? controladoresCalibre[calibres[3]]?.text : '0') ?? '0',
            'estado_celda': 'ACTIVO',
            'sincronizado': 0,
          });
        });
        _mostrarToast("Lote $loteProceso registrado", tipo: 'exito');
      }

      _resetearFormulario();
      Navigator.pop(ctx);
      _cargarHistorial();
      _tabController.animateTo(0);

      // Sincronización en segundo plano
      PaginaSincronizar.sincronizarCeldas(usuario: usuarioActivo).catchError((e) {
        debugPrint("Sincronización de Celdas diferida: $e");
        return 0;
      });
    } catch (e) {
      _mostrarToast("Error: $e", tipo: 'error');
    }
  }

  void _resetearFormulario() {
    setState(() {
      qrEscaneado = null;
      nombreCeldaActiva = null;
      establecimientoSel = null;
      cuadroSel = null;
      calidadSel = null;
      regLocalEditando = null;
      for (var c in controladoresCalibre.values) {
        c.clear();
      }
    });
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
      bg = kColorWaSoft;
      colorTxt = const Color(0xFF128C7E);
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