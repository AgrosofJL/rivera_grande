import 'package:flutter/material.dart';
import 'package:la_rivera_celdas/sincronizar.dart';
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

class PaginaVolcadoBin extends StatefulWidget {
  const PaginaVolcadoBin({super.key});

  @override
  State<PaginaVolcadoBin> createState() => _PaginaVolcadoBinState();
}

class _PaginaVolcadoBinState extends State<PaginaVolcadoBin> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Listados de datos
  List<Map<String, dynamic>> todosLosBins = [];
  List<Map<String, dynamic>> binsDisponibles = [];
  List<Map<String, dynamic>> historialVolcadosBins = [];
  bool cargando = false;

  // Catálogos y filtros dinámicos
  List<String> calibresDisponibles = [];
  String? calibreFiltro;
  DateTime? fechaFiltro;
  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Carga reactiva de Bins activos y volcados
  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    final db = await dbHelper.database;

    try {
      // 1. Catálogo de Bins registrados
      final List<Map<String, dynamic>> resBins = await db.query(
        'empaque_armado_bins',
        where: "cod_bin IS NOT NULL AND cod_bin != ''",
        orderBy: 'fecha_emb DESC, hora_emb DESC, id DESC',
      );

      // 2. Historial de Bins volcados a línea
      final List<Map<String, dynamic>> resVolcados = await db.query(
        'volcado_bins',
        orderBy: 'fecha DESC, hora DESC',
      );

      // Extraer calibres únicos para filtros
      final Set<String> cals = {};
      for (var b in resBins) {
        final c = (b['calibre'] ?? '').toString().trim().toUpperCase();
        if (c.isNotEmpty) cals.add(c);
      }

      setState(() {
        todosLosBins = resBins;
        historialVolcadosBins = resVolcados;
        calibresDisponibles = cals.toList()..sort();
        _aplicarFiltros();
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando volcado bins: $e");
      setState(() => cargando = false);
    }
  }

  void _aplicarFiltros() {
    final query = queryBusqueda.toLowerCase().trim();
    final fechaStr = fechaFiltro != null ? DateFormat('yyyy-MM-dd').format(fechaFiltro!) : null;

    // Filtrar Bins activos listos para volcar
    binsDisponibles = todosLosBins.where((b) {
      final esActivo = (b['estado'] ?? '').toString().toUpperCase() != 'VOLCADO' &&
          (b['estado'] ?? '').toString().toUpperCase() != 'INACTIVO';
      final codBin = (b['cod_bin'] ?? '').toString().toLowerCase();
      final lote = (b['lote_proceso'] ?? b['lote'] ?? '').toString().toLowerCase();
      final prod = (b['productor'] ?? '').toString().toLowerCase();
      final cal = (b['calibre'] ?? '').toString().toUpperCase();
      final bolson = (b['cod_bigbag'] ?? '').toString().toLowerCase();

      final coincideQuery = query.isEmpty ||
          codBin.contains(query) ||
          lote.contains(query) ||
          prod.contains(query) ||
          cal.toLowerCase().contains(query) ||
          bolson.contains(query);

      final fechaItem = (b['fecha_emb'] ?? b['fecha'] ?? '').toString();
      final coincideFecha = fechaStr == null || fechaItem == fechaStr;
      final coincideCalibre = calibreFiltro == null || cal == calibreFiltro;

      return esActivo && coincideQuery && coincideFecha && coincideCalibre;
    }).toList();

    // Filtrar histórico
    if (query.isNotEmpty || fechaStr != null) {
      historialVolcadosBins = historialVolcadosBins.where((v) {
        final codBin = (v['cod_bin'] ?? '').toString().toLowerCase();
        final lote = (v['lote_proceso'] ?? v['lote'] ?? '').toString().toLowerCase();
        final prod = (v['productor'] ?? '').toString().toLowerCase();

        final coincideQuery = query.isEmpty || codBin.contains(query) || lote.contains(query) || prod.contains(query);
        final fechaItem = (v['fecha'] ?? '').toString();
        final coincideFecha = fechaStr == null || fechaItem == fechaStr;

        return coincideQuery && coincideFecha;
      }).toList();
    }
  }

  // =========================================================================
  // ESCÁNER QR DINÁMICO CON DETECCIÓN DEL CICLO ACTIVO
  // =========================================================================
  void _abrirEscanerQRBin() {
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
                    "ESCANEAR BIN PARA VOLCADO",
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

                      // Busca el ciclo activo vigente del QR escaneado
                      final binActivo = await dbHelper.obtenerBinActivoPorQR(codigo);
                      if (binActivo != null) {
                        _mostrarDialogoConfirmarVolcadoBin(binActivo);
                      } else {
                        // Si no lo encuentra por coincidencia exacta, intenta buscarlo en los disponibles cargados
                        try {
                          final match = binsDisponibles.firstWhere((b) =>
                              (b['cod_bin'] ?? '').toString().toUpperCase() == codigo.toUpperCase() ||
                              (b['cod_bin'] ?? '').toString().toUpperCase().contains(codigo.toUpperCase()));
                          _mostrarDialogoConfirmarVolcadoBin(match);
                        } catch (_) {
                          _mostrarToast("El Bin $codigo no posee un ciclo activo pendiente de volcado", tipo: 'error');
                        }
                      }
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

  // =========================================================================
  // EJECUCIÓN ATÓMICA DE VOLCADO A LÍNEA DE PROCESO
  // =========================================================================
  Future<void> _ejecutarVolcadoBin(Map<String, dynamic> item) async {
    final db = await dbHelper.database;
    final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    final String regLocalVolcado = dbHelper.generarIdCorto();

    final String codBin = (item['cod_bin'] ?? item['cod_bigbag'] ?? 'S/C').toString().toUpperCase();
    final String kilos = item['registro_mov']?.toString() ?? '0';

    try {
      await db.transaction((txn) async {
        // 1. Dar de baja al bin en empaque_armado_bins cambiando su estado a 'VOLCADO'
        await txn.update(
          'empaque_armado_bins',
          {
            'estado': 'VOLCADO',
            'sincronizado': 0,
          },
          where: 'reg_local = ?',
          whereArgs: [item['reg_local']],
        );
         PaginaSincronizar.sincronizarBins().catchError((e) {
         debugPrint("Sincronización de Bins diferida: $e");
         return 0;
        });

        // 2. Registrar en volcado_bins arrastrando toda la trazabilidad hacia la cinta de proceso
        await txn.insert('volcado_bins', {
          'reg_local': regLocalVolcado,
          'id': regLocalVolcado,
          'fecha': fechaHoy,
          'hora': horaHoy,
          'reg_bin': item['reg_local'],
          'cod_bin': codBin,
          'cliente': item['cliente'] ?? '',
          'productor': item['productor'] ?? 'S/P',
          'lote': item['lote'] ?? 'S/L',
          'lote_proceso': item['lote_proceso'] ?? item['lote'] ?? 'S/L',
          'kilos': kilos,
          'sincronizado': 0,
        });
      });
       
       // Guardó en empaque_armado_bins o volcado_bins en SQLite y luego:
      PaginaSincronizar.sincronizarBins().catchError((e) {
      debugPrint("Sincronización de Bins diferida: $e");
      return 0;
      });

      _mostrarToast("Bin $codBin volcado a línea de producción", tipo: 'exito');
      _cargarDatos();
    } catch (e) {
      _mostrarToast("Error al procesar volcado de bin: $e", tipo: 'error');
    }
  }

  // =========================================================================
  // MODAL GIGANTE TÁCTIL DE CONFIRMACIÓN PARA TABLET
  // =========================================================================
  void _mostrarDialogoConfirmarVolcadoBin(Map<String, dynamic> item) {
    final String kilos = item['registro_mov']?.toString() ?? '0';
    final String codBin = (item['cod_bin'] ?? item['cod_bigbag'] ?? 'S/C').toString().toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: kColorSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: kColorAccentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: kColorAccent.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, size: 32, color: kColorAccentDark),
                ),
                const SizedBox(height: 16),
                const Text(
                  "¿VOLCAR BIN A LÍNEA?",
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900, color: kColorText, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  "El bin se descargará hacia la cinta de procesamiento y pasará a estado VOLCADO, liberando su ciclo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: kColorTextSecondary, height: 1.3),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kColorBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kColorBorder),
                  ),
                  child: Column(
                    children: [
                      Text(codBin, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kColorText), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text("$kilos KG NETOS", style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 22, color: kColorAccentDark)),
                      const Divider(height: 16, color: kColorBorder),
                      Text(
                        "${item['productor'] ?? 'S/P'} • Calibre: ${item['calibre'] ?? 'S/C'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kColorTextSecondary),
                      ),
                      if (item['cod_bigbag'] != null && item['cod_bigbag'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Origen: ${item['cod_bigbag']}",
                          style: const TextStyle(fontSize: 11, color: kColorTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kColorBorder, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCELAR", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 13, color: kColorTextSecondary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text("VOLCAR", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _ejecutarVolcadoBin(item);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final int crossAxisCount = anchoPantalla > 650 ? 2 : 1;

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
                        Text("VOLCADO DE BINS", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText)),
                        Text("Puesto Operativo de Descarga a Línea", style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
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
          // PANEL DE BÚSQUEDA + ESCÁNER + FILTRO POR CALIBRE Y FECHA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kColorSurface,
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            hintText: "Buscar por bin, lote, productor o calibre...",
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
                    ),
                    const SizedBox(width: 8),

                    // Botón Escáner QR Rápido
                    InkWell(
                      onTap: _abrirEscanerQRBin,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: kColorAccentSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kColorAccent.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: kColorAccentDark),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Selector de fecha
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fechaFiltro ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            fechaFiltro = picked;
                            _aplicarFiltros();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: fechaFiltro != null ? kColorAccentSoft : kColorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: fechaFiltro != null ? kColorAccent : kColorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 16, color: fechaFiltro != null ? kColorAccentDark : kColorTextSecondary),
                            const SizedBox(width: 4),
                            Text(
                              fechaFiltro != null ? DateFormat('dd/MM/yy').format(fechaFiltro!) : "FECHA",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fechaFiltro != null ? kColorAccentDark : kColorTextSecondary),
                            ),
                            if (fechaFiltro != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    fechaFiltro = null;
                                    _aplicarFiltros();
                                  });
                                },
                                child: const Icon(Icons.close_rounded, size: 14, color: kColorAccentDark),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (calibresDisponibles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildChipFiltroCalibre("TODOS", null),
                        ...calibresDisponibles.map((cal) => _buildChipFiltroCalibre(cal, cal)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
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
                    tabs: [
                      Tab(text: "BINS DISPONIBLES (${binsDisponibles.length})"),
                      Tab(text: "HISTORIAL DE VOLCADOS (${historialVolcadosBins.length})"),
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
                      _buildGridBinsDisponibles(crossAxisCount),
                      _buildListaHistorialVolcados(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltroCalibre(String label, String? valor) {
    final bool seleccionado = calibreFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            calibreFiltro = valor;
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
  // SOLAPA 1: BINS DISPONIBLES EN CARDS GRANDES Y TÁCTILES PARA TABLET
  // =========================================================================
  Widget _buildGridBinsDisponibles(int crossAxisCount) {
    if (binsDisponibles.isEmpty) {
      return _buildVacioMensaje("No hay bins pendientes de volcado a línea");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatos,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount > 1 ? 1.75 : 1.6,
        ),
        itemCount: binsDisponibles.length,
        itemBuilder: (context, index) {
          final item = binsDisponibles[index];
          final String codBin = (item['cod_bin'] ?? item['cod_bigbag'] ?? 'S/C').toString().toUpperCase();
          final String kilos = item['registro_mov']?.toString() ?? '0';
          final String calibre = (item['calibre'] ?? 'S/C').toString().toUpperCase();

          return Container(
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kColorAccent.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: kColorAccent.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _mostrarDialogoConfirmarVolcadoBin(item),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(color: kColorAccentSoft, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.inventory_2_rounded, color: kColorAccentDark, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(codBin, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 15, color: kColorText)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kColorBorder)),
                            child: Text("CAL: $calibre", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorAccentDark)),
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
                              Text("$kilos KG", style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 24, color: kColorAccentDark, letterSpacing: -0.5)),
                              Text("${item['productor'] ?? 'S/P'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kColorTextSecondary)),
                            ],
                          ),
                          Text(item['deposito'] ?? 'PLANTA CENTRAL', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
                        ],
                      ),
                      Column(
                        children: [
                          const Divider(height: 12, color: kColorBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 12, color: kColorTextSecondary),
                                  const SizedBox(width: 4),
                                  Text("${item['fecha_emb'] ?? item['fecha']} • ${item['hora_emb'] ?? item['hora'] ?? ''}", style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: kColorAccent, borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.touch_app_rounded, size: 13, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text("VOLCAR A LÍNEA", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                                  ],
                                ),
                              ),
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
        },
      ),
    );
  }

  // =========================================================================
  // SOLAPA 2: HISTORIAL COMPACTO DE VOLCADOS
  // =========================================================================
  Widget _buildListaHistorialVolcados() {
    if (historialVolcadosBins.isEmpty) {
      return _buildVacioMensaje("No hay registros en el historial de volcados");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: historialVolcadosBins.length,
        itemBuilder: (context, index) {
          final item = historialVolcadosBins[index];
          final String codBin = (item['cod_bin'] ?? 'S/C').toString().toUpperCase();
          final String kilos = item['kilos']?.toString() ?? '0';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kColorBorder)),
                    child: const Icon(Icons.check_circle_outline_rounded, color: kColorTextSecondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(codBin, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: kColorText)),
                            const SizedBox(width: 6),
                            Text("$kilos KG", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kColorAccentDark)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${item['productor'] ?? 'S/P'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                          style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kColorDangerSoft, borderRadius: BorderRadius.circular(6)),
                        child: const Text("VOLCADO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kColorDanger)),
                      ),
                      const SizedBox(height: 3),
                      Text("${item['fecha']} ${item['hora'] ?? ''}", style: const TextStyle(fontSize: 10, color: kColorTextSecondary)),
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

  Widget _buildVacioMensaje(String texto) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: kColorSurface, shape: BoxShape.circle, border: Border.all(color: kColorBorder)), child: const Icon(Icons.inventory_2_outlined, size: 38, color: kColorTextSecondary)),
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