import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

// TONOS PASTEL DE CLASIFICACIÓN
const Color kColorVolcadoBannerBg = Color(0xFFFFFBEB);
const Color kColorVolcadoBannerBorder = Color(0xFFFDE68A);
const Color kColorVolcadoBannerText = Color(0xFF92400E);

class PaginaClasibin extends StatefulWidget {
  const PaginaClasibin({super.key});

  @override
  State<PaginaClasibin> createState() => _PaginaClasibinState();
}

class _PaginaClasibinState extends State<PaginaClasibin> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Estados de datos
  List<Map<String, dynamic>> binsDelDia = [];
  List<Map<String, dynamic>> binsFiltradosDia = [];
  List<Map<String, dynamic>> resumenPorDias = [];
  List<Map<String, dynamic>> resumenPorDiasFiltrado = [];
  List<Map<String, dynamic>> ultimosBolsonesVolcados = [];
  Map<String, dynamic>? bolsonVolcadoActivo;
  bool cargando = false;

  // Catálogos
  List<String> calibresDisponibles = [];
  List<String> depositosDisponibles = [];

  // Filtros
  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  // Estados del Formulario (Modal)
  String? binCodigoFinal;
  bool esIngresoManual = false;
  String? calibreSel;
  String? depositoSel;
  final TextEditingController _numBinManualController = TextEditingController();
  final TextEditingController _kilosController = TextEditingController();

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
    _numBinManualController.dispose();
    _kilosController.dispose();
    super.dispose();
  }

  Future<void> _inicializarPanel() async {
    await _cargarCatalogos();
    await _cargarDatos();
  }

  Future<void> _cargarCatalogos() async {
    final db = await dbHelper.database;
    try {
      final resCal = await db.query('parametros_calibre');
      final resDep = await db.query('parametros_depositos');

      setState(() {
        calibresDisponibles = resCal.map((c) => (c['calibre'] ?? '').toString().trim()).where((c) => c.isNotEmpty).toList();
        if (calibresDisponibles.isEmpty) {
          calibresDisponibles = ['30-32', '32-34', '34-36', '36+'];
        }

        depositosDisponibles = resDep.map((d) => (d['deposito'] ?? '').toString().trim().toUpperCase()).where((d) => d.isNotEmpty).toList();
        if (depositosDisponibles.isEmpty) {
          depositosDisponibles = ['PLANTA CENTRAL', 'DEPÓSITO 1', 'DEPÓSITO 2', 'CÁMARA DE FRÍO'];
        }
      });
    } catch (e) {
      debugPrint("Error cargando catálogos: $e");
    }
  }

  // ESTO LO MODIFIQUE: Consulta del último bolsón volcado en línea + Historial de Bins clasificados
  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    final db = await dbHelper.database;
    final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 1. ACA ES LO NUEVO: Últimos bolsones volcados para arrastre en tiempo real
      final List<Map<String, dynamic>> resVolcados = await db.query(
        'volcado_bag',
        orderBy: 'fecha DESC, hora DESC',
        limit: 10,
      );

      // 2. Bins clasificados hoy (empaque_armado_bins)
      final List<Map<String, dynamic>> resBinsHoy = await db.query(
        'empaque_armado_bins',
        where: "fecha_emb = ? OR fecha = ?",
        whereArgs: [fechaHoy, fechaHoy],
        orderBy: "hora_emb DESC, hora DESC, id DESC",
      );

      // 3. Resumen agrupado por fechas para el Archivero
      final List<Map<String, dynamic>> resDias = await db.rawQuery('''
        SELECT 
          COALESCE(fecha_emb, fecha) as fecha_grupo,
          COUNT(*) as total_bins,
          SUM(CAST(registro_mov AS REAL)) as total_kg
        FROM empaque_armado_bins
        WHERE cod_bin IS NOT NULL AND cod_bin != ''
        GROUP BY COALESCE(fecha_emb, fecha)
        ORDER BY fecha_grupo DESC
      ''');

      setState(() {
        ultimosBolsonesVolcados = resVolcados;
        if (resVolcados.isNotEmpty) {
          bolsonVolcadoActivo = resVolcados.first; // El más reciente en línea
        }
        binsDelDia = resBinsHoy;
        resumenPorDias = resDias;
        _aplicarFiltros();
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos de clasificación: $e");
      setState(() => cargando = false);
    }
  }

  void _aplicarFiltros() {
    final query = queryBusqueda.toLowerCase().trim();

    setState(() {
      // Filtrar del día
      binsFiltradosDia = binsDelDia.where((b) {
        final codBin = (b['cod_bin'] ?? '').toString().toLowerCase();
        final lote = (b['lote_proceso'] ?? b['lote'] ?? '').toString().toLowerCase();
        final prod = (b['productor'] ?? '').toString().toLowerCase();
        final calibre = (b['calibre'] ?? '').toString().toLowerCase();
        final bolson = (b['cod_bigbag'] ?? '').toString().toLowerCase();

        return query.isEmpty ||
            codBin.contains(query) ||
            lote.contains(query) ||
            prod.contains(query) ||
            calibre.contains(query) ||
            bolson.contains(query);
      }).toList();

      // Filtrar archivero por fecha
      resumenPorDiasFiltrado = resumenPorDias.where((d) {
        final fecha = (d['fecha_grupo'] ?? '').toString().toLowerCase();
        return query.isEmpty || fecha.contains(query);
      }).toList();
    });
  }

  double _calcularKilosTotalesDia() {
    double suma = 0;
    for (var item in binsFiltradosDia) {
      final k = double.tryParse(item['registro_mov']?.toString() ?? '0') ?? 0;
      suma += k;
    }
    return suma;
  }

  // --- ESCÁNER QR BIN ---
  void _abrirEscannerBin(StateSetter setModalState) {
    final MobileScannerController scannerController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ESCANEAR CÓDIGO QR DE BIN",
                    style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 12.5, color: kColorTextSecondary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded, size: 20, color: kColorAccent),
                    onPressed: () => scannerController.toggleTorch(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ClipRRect(
                child: MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final codigo = barcodes.first.rawValue ?? barcodes.first.displayValue ?? "";
                      if (codigo.isEmpty) return;

                      await scannerController.stop();
                      scannerController.dispose();
                      Navigator.pop(ctx);

                      setModalState(() {
                        binCodigoFinal = codigo;
                        esIngresoManual = false;
                      });
                      _mostrarToast("QR Bin vinculado: $codigo", tipo: 'info');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => scannerController.dispose());
  }

  void _procesarIngresoManualBin(String valor, StateSetter setModalState) {
    if (valor.trim().isEmpty) {
      setModalState(() => binCodigoFinal = null);
      return;
    }
    int? numero = int.tryParse(valor.trim());
    if (numero != null) {
      String numeroFormateado = numero.toString().padLeft(4, '0');
      setModalState(() {
        binCodigoFinal = "BIN Nº $numeroFormateado";
      });
    } else {
      setModalState(() {
        binCodigoFinal = valor.toUpperCase();
      });
    }
  }

  // =========================================================================
  // PERSISTENCIA LOCAL: REGISTRO DE BIN CON ARRASTRE DE TRAZA DE VOLCADO
  // =========================================================================
  Future<void> _guardarBinClasificado(BuildContext ctx) async {
    if (binCodigoFinal == null || binCodigoFinal!.isEmpty || _kilosController.text.trim().isEmpty) {
      _mostrarToast("Ingresa el código del Bin y los Kilos netos", tipo: 'error');
      return;
    }

    final db = await dbHelper.database;
    final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    final String regLocalUnico = dbHelper.generarIdCorto();

    // ACA ES LO NUEVO: Arrastre completo del bolsón volcado actualmente en línea
    final String codBigBag = bolsonVolcadoActivo?['cod_bigbag'] ?? 'SIN VOLCADO';
    final String productor = bolsonVolcadoActivo?['productor'] ?? 'S/P';
    final String lote = bolsonVolcadoActivo?['lote_proceso'] ?? bolsonVolcadoActivo?['lote'] ?? 'S/L';
    final String especie = bolsonVolcadoActivo?['especie'] ?? 'Nuez';
    final String variedad = bolsonVolcadoActivo?['variedad'] ?? 'S/V';
    final String calidad = bolsonVolcadoActivo?['calidad'] ?? 'ESTANDAR';

    try {
      await db.insert('empaque_armado_bins', {
        'reg_local': regLocalUnico,
        'cod_bin': binCodigoFinal,
        'fecha': fechaHoy,
        'hora': horaHoy,
        'fecha_emb': fechaHoy,
        'hora_emb': horaHoy,
        'registro_mov': _kilosController.text.trim(),
        'cod_bigbag': codBigBag,
        'productor': productor,
        'lote': lote,
        'lote_proceso': lote,
        'especie': especie,
        'variedad': variedad,
        'cliente': '',
        'calibre': calibreSel ?? '',
        'estado': 'PROCESADO',
        'calidad': calidad,
        'fumigado': 'NO',
        'deposito': depositoSel ?? 'PLANTA CENTRAL',
        'sincronizado': 0, // Listo para sincronizar
      });

      _mostrarToast("Bin $binCodigoFinal registrado exitosamente", tipo: 'exito');
      _limpiarFormulario();
      Navigator.pop(ctx);
      _cargarDatos();
    } catch (e) {
      _mostrarToast("Error al guardar bin: $e", tipo: 'error');
    }
  }

  void _limpiarFormulario() {
    setState(() {
      binCodigoFinal = null;
      calibreSel = null;
      depositoSel = null;
      _numBinManualController.clear();
      _kilosController.clear();
    });
  }

  // =========================================================================
  // MODAL CREACIÓN NUEVO BIN
  // =========================================================================
  void _abrirModalNuevoBin() {
    if (calibresDisponibles.isNotEmpty && calibreSel == null) {
      calibreSel = calibresDisponibles.first;
    }
    if (depositosDisponibles.isNotEmpty && depositoSel == null) {
      depositoSel = depositosDisponibles.first;
    }

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
                          const Text(
                            "CLASIFICACIÓN DE MATERIA PRIMA",
                            style: TextStyle(fontFamily: 'Roboto', color: kColorAccent, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.6),
                          ),
                          Text(
                            binCodigoFinal != null ? binCodigoFinal!.toUpperCase() : "Nuevo Bin de Clasificación",
                            style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 19, color: kColorText),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          _limpiarFormulario();
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
                      // 1. ACA ES LO NUEVO: BOLSÓN EN LÍNEA VINCULADO
                      _buildEtiquetaSeccion("1. ORIGEN DE MATERIA PRIMA (BOLSÓN EN LÍNEA)"),
                      _buildSelectorBolsonOrigen(setModalState),
                      const SizedBox(height: 20),

                      // 2. IDENTIFICACIÓN DEL BIN
                      _buildEtiquetaSeccion("2. IDENTIFICACIÓN DEL BIN"),
                      _buildBloqueIdentificadorBin(setModalState),
                      const SizedBox(height: 20),

                      // 3. CALIBRE Y PESAJE
                      _buildEtiquetaSeccion("3. CALIBRE Y PESAJE"),
                      _buildCamposCalibreYPeso(setModalState),
                      const SizedBox(height: 26),

                      // BOTÓN GUARDAR
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => _guardarBinClasificado(context),
                          child: const Text(
                            "GUARDAR Y ASIGNAR BIN",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.4),
                          ),
                        ),
                      ),
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
    final double totalKgHoy = _calcularKilosTotalesDia();
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final int crossAxisCount = anchoPantalla > 650 ? 2 : 1;

    return Scaffold(
      backgroundColor: kColorBg,
      // BARRA SUPERIOR AGROSOFT
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
                          Text(
                            "VOLVER",
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w700, color: kColorTextSecondary),
                          ),
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
                        Text(
                          "CLASIFICACIÓN EN BINS",
                          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText),
                        ),
                        Text(
                          "Llenado y Trazabilidad desde Volcado",
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _cargarDatos,
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
                          Text("ACTUALIZAR", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorAccentDark)),
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
          // ACA ES LO NUEVO: BANNER DEL ÚLTIMO BOLSÓN EN LÍNEA (VOLCADO ACTIVO)
          _buildBannerBolsonVolcadoEnLinea(),

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
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kColorAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "BINS HOY: ${binsFiltradosDia.length}",
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: kColorTextSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kColorAccentSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kColorAccent.withOpacity(0.2)),
                      ),
                      child: Text(
                        "${NumberFormat('#,##0', 'es_ES').format(totalKgHoy)} KG CLASIFICADOS",
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: kColorAccentDark,
                        ),
                      ),
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
                    onChanged: (val) {
                      queryBusqueda = val;
                      _aplicarFiltros();
                    },
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kColorText),
                    decoration: InputDecoration(
                      hintText: "Buscar por bin, lote, productor, calibre o bolsón...",
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
                const SizedBox(height: 12),
                // Solapas
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: kColorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kColorBorder),
                  ),
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
                    tabs: [
                      Tab(text: "BINS DEL DÍA (${binsFiltradosDia.length})"),
                      Tab(text: "ARCHIVERO POR DÍAS (${resumenPorDiasFiltrado.length})"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO DE SOLAPAS
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGridBinsDelDia(crossAxisCount),
                      _buildListaArchiveroDias(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _limpiarFormulario();
          _abrirModalNuevoBin();
        },
        backgroundColor: kColorAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_box_rounded, size: 20),
        label: const Text(
          "NUEVO BIN",
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.4),
        ),
      ),
    );
  }

  // =========================================================================
  // BANNER SUPERIOR: MUESTRA EL BOLSÓN QUE ALIMENTA LA LÍNEA DE CLASIFICACIÓN
  // =========================================================================
  Widget _buildBannerBolsonVolcadoEnLinea() {
    if (bolsonVolcadoActivo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: kColorDangerSoft,
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kColorDanger, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "No hay bolsones en proceso de volcado. Puedes registrar bins pero asegúrate del origen.",
                style: TextStyle(color: kColorDanger, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final codBigBag = (bolsonVolcadoActivo!['cod_bigbag'] ?? 'S/C').toString().toUpperCase();
    final prod = (bolsonVolcadoActivo!['productor'] ?? 'S/P').toString().toUpperCase();
    final lote = bolsonVolcadoActivo!['lote_proceso'] ?? bolsonVolcadoActivo!['lote'] ?? 'S/L';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: kColorVolcadoBannerBg,
        border: Border(bottom: BorderSide(color: kColorVolcadoBannerBorder, width: 1.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kColorVolcadoBannerBorder),
            ),
            child: const Icon(Icons.stream_rounded, color: kColorVolcadoBannerText, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("ALIMENTANDO LÍNEA: ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kColorVolcadoBannerText)),
                    Text(codBigBag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kColorText)),
                  ],
                ),
                Text(
                  "Prod: $prod • Lote: $lote • ${bolsonVolcadoActivo!['variedad'] ?? 'Nuez'}",
                  style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (ultimosBolsonesVolcados.length > 1)
            InkWell(
              onTap: _mostrarModalCambiarBolsonEnLinea,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kColorVolcadoBannerBorder),
                ),
                child: const Text("CAMBIAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorVolcadoBannerText)),
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarModalCambiarBolsonEnLinea() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 44, height: 4, decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text("SELECCIONA EL BOLSÓN EN LÍNEA ACTIVO", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kColorText)),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ultimosBolsonesVolcados.length,
                itemBuilder: (c, i) {
                  final b = ultimosBolsonesVolcados[i];
                  final bool seleccionado = b['reg_local'] == bolsonVolcadoActivo?['reg_local'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: seleccionado ? kColorAccentSoft : kColorBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: seleccionado ? kColorAccent : kColorBorder),
                    ),
                    child: ListTile(
                      title: Text("${b['cod_bigbag']}".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      subtitle: Text("${b['productor']} • Lote ${b['lote_proceso'] ?? b['lote']}", style: const TextStyle(fontSize: 11)),
                      trailing: Text("${b['fecha']} ${b['hora'] ?? ''}", style: const TextStyle(fontSize: 10, color: kColorTextSecondary)),
                      onTap: () {
                        setState(() => bolsonVolcadoActivo = b);
                        Navigator.pop(ctx);
                      },
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
  // SOLAPA 1: BINS DEL DÍA
  // =========================================================================
  Widget _buildGridBinsDelDia(int crossAxisCount) {
    if (binsFiltradosDia.isEmpty) {
      return _buildVacioMensaje("No hay bins clasificados hoy.");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatos,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount > 1 ? 1.9 : 1.7,
        ),
        itemCount: binsFiltradosDia.length,
        itemBuilder: (context, index) {
          final item = binsFiltradosDia[index];
          return _buildCardBin(item);
        },
      ),
    );
  }

  Widget _buildCardBin(Map<String, dynamic> item) {
    final String codBin = (item['cod_bin'] ?? item['cod_bigbag'] ?? 'S/C').toString().toUpperCase();
    final String kilos = item['registro_mov']?.toString() ?? '0';
    final String calibre = (item['calibre'] ?? 'S/C').toString().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarFichaDetalleBin(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kColorAccentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, size: 18, color: kColorAccentDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          codBin,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kColorText),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kColorBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Text(
                        "CALIBRE: $calibre",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorAccentDark),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$kilos KG",
                          style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 20, color: kColorText),
                        ),
                        Text(
                          "Origen: ${item['cod_bigbag'] ?? 'S/B'}",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kColorTextSecondary),
                        ),
                      ],
                    ),
                    Text(
                      "${item['productor'] ?? 'S/P'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                      style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Divider(height: 8, color: kColorBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: kColorTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          "${item['fecha_emb'] ?? item['fecha']} • ${item['hora_emb'] ?? item['hora'] ?? ''}",
                          style: const TextStyle(fontSize: 10, color: kColorTextSecondary),
                        ),
                      ],
                    ),
                    Text(
                      item['deposito'] ?? 'PLANTA CENTRAL',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kColorAccentDark),
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
  // SOLAPA 2: ARCHIVERO CONSOLIDADO POR DÍAS
  // =========================================================================
  Widget _buildListaArchiveroDias() {
    if (resumenPorDiasFiltrado.isEmpty) {
      return _buildVacioMensaje("No hay fechas registradas en el archivero.");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: resumenPorDiasFiltrado.length,
        itemBuilder: (context, index) {
          final dia = resumenPorDiasFiltrado[index];
          final String fecha = dia['fecha_grupo'] ?? '';
          final int totalBins = dia['total_bins'] ?? 0;
          final double totalKg = (dia['total_kg'] as num?)?.toDouble() ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _mostrarModalDetalleDia(fecha),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kColorBorder)),
                            child: const Icon(Icons.calendar_month_rounded, size: 18, color: kColorTextSecondary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("FECHA: $fecha", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kColorText)),
                              Text("$totalBins Bins clasificados", style: const TextStyle(fontSize: 11, color: kColorTextSecondary)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            "${NumberFormat('#,##0', 'es_ES').format(totalKg)} KG",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kColorAccentDark),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kColorTextSecondary),
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

  void _mostrarModalDetalleDia(String fecha) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> binsDelDia = await db.query(
      'empaque_armado_bins',
      where: 'fecha_emb = ? OR fecha = ?',
      whereArgs: [fecha, fecha],
      orderBy: 'hora_emb DESC, hora DESC, id DESC',
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 44, height: 4, decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ARCHIVERO DIARIO DE CLASIFICACIÓN", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent)),
                      Text("FECHA $fecha", style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 19, color: kColorText)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kColorTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: binsDelDia.length,
                itemBuilder: (c, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCardBin(binsDelDia[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ELEMENTOS DEL MODAL NUEVO BIN ---
  Widget _buildSelectorBolsonOrigen(StateSetter setModalState) {
    if (bolsonVolcadoActivo == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kColorBorder)),
        child: const Text("No hay bolsón volcado activo. Se creará sin origen específico.", style: TextStyle(fontSize: 11.5, color: kColorTextSecondary)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kColorVolcadoBannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorVolcadoBannerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${bolsonVolcadoActivo!['cod_bigbag']}".toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kColorVolcadoBannerText),
              ),
              Text(
                "Lote: ${bolsonVolcadoActivo!['lote_proceso'] ?? bolsonVolcadoActivo!['lote']}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Prod: ${bolsonVolcadoActivo!['productor']} • Variedad: ${bolsonVolcadoActivo!['variedad'] ?? 'Nuez'}",
            style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBloqueIdentificadorBin(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kColorBorder)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      esIngresoManual = false;
                      binCodigoFinal = null;
                    });
                    _abrirEscannerBin(setModalState);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !esIngresoManual ? kColorAccent : kColorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: !esIngresoManual ? kColorAccentDark : kColorBorder),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 16, color: !esIngresoManual ? Colors.white : kColorText),
                          const SizedBox(width: 6),
                          Text("ESCANEAR QR", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: !esIngresoManual ? Colors.white : kColorText)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      esIngresoManual = true;
                      binCodigoFinal = null;
                      _numBinManualController.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: esIngresoManual ? kColorAccent : kColorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: esIngresoManual ? kColorAccentDark : kColorBorder),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_rounded, size: 16, color: esIngresoManual ? Colors.white : kColorText),
                          const SizedBox(width: 6),
                          Text("INGRESO MANUAL", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: esIngresoManual ? Colors.white : kColorText)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (esIngresoManual)
            TextField(
              controller: _numBinManualController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText),
              decoration: InputDecoration(
                labelText: "NÚMERO DE BIN",
                hintText: "Ej: 12",
                labelStyle: const TextStyle(fontSize: 12, color: kColorTextSecondary),
                filled: true,
                fillColor: kColorSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kColorBorder)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => _procesarIngresoManualBin(val, setModalState),
            )
          else
            InkWell(
              onTap: () => _abrirEscannerBin(setModalState),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: kColorSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kColorBorder)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: kColorAccent, size: 20),
                    SizedBox(width: 8),
                    Text("DISPARAR LECTOR DE CÁMARA", style: TextStyle(fontWeight: FontWeight.w700, color: kColorAccentDark, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          if (binCodigoFinal != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kColorAccentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kColorAccent.withOpacity(0.3)),
              ),
              child: Text(
                "CÓDIGO ASIGNADO: $binCodigoFinal",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: kColorAccentDark, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCamposCalibreYPeso(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kColorBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CALIBRE DEL BIN:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: calibresDisponibles.map((cal) {
              final bool sel = cal == calibreSel;
              return InkWell(
                onTap: () => setModalState(() => calibreSel = cal),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? kColorAccent : kColorSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? kColorAccentDark : kColorBorder),
                  ),
                  child: Text(
                    cal,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? Colors.white : kColorText),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _kilosController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kColorText),
            decoration: InputDecoration(
              labelText: "KILOS NETOS *",
              hintText: "Ej: 380",
              prefixIcon: const Icon(Icons.scale_rounded, color: kColorAccent, size: 22),
              suffixText: "KG",
              suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: kColorAccentDark),
              labelStyle: const TextStyle(fontSize: 12, color: kColorTextSecondary),
              filled: true,
              fillColor: kColorSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kColorBorder)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          const Text("DEPÓSITO DE DESTINO:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: depositosDisponibles.map((dep) {
                final bool sel = dep == depositoSel;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setModalState(() => depositoSel = dep),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? kColorAccentDark : kColorSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? kColorAccentDark : kColorBorder),
                      ),
                      child: Text(
                        dep,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : kColorTextSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODAL DETALLE BIN ---
  void _mostrarFichaDetalleBin(Map<String, dynamic> item) {
    final String codBin = (item['cod_bin'] ?? item['cod_bigbag'] ?? 'S/C').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 44, height: 4, decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TRAZABILIDAD DE CLASIFICACIÓN", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5)),
                      Text(codBin, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: kColorText)),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kColorBorder)),
                    child: Column(
                      children: [
                        _buildRenglonDato("Kilogramos Netos", "${item['registro_mov'] ?? '0'} KG", esDestacado: true),
                        const Divider(height: 14, color: kColorBorder),
                        _buildRenglonDato("Calibre Clasificado", item['calibre']),
                        _buildRenglonDato("Bolsón de Origen", item['cod_bigbag']),
                        _buildRenglonDato("Lote de Proceso", item['lote_proceso'] ?? item['lote']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Especie / Variedad", "${item['especie'] ?? 'Nuez'} • ${item['variedad'] ?? 'S/V'}"),
                        _buildRenglonDato("Calidad", item['calidad']),
                        _buildRenglonDato("Depósito Actual", item['deposito']),
                        _buildRenglonDato("Fecha Clasificación", "${item['fecha_emb'] ?? item['fecha']} • ${item['hora_emb'] ?? item['hora'] ?? ''}"),
                        _buildRenglonDato("ID Local Único", item['reg_local']),
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
            style: TextStyle(
              fontSize: esDestacado ? 14 : 12.5,
              fontWeight: FontWeight.w700,
              color: esDestacado ? kColorAccentDark : kColorText,
            ),
          ),
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
                child: const Icon(Icons.inventory_2_outlined, size: 38, color: kColorTextSecondary),
              ),
              const SizedBox(height: 14),
              Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText)),
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