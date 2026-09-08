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

class PaginaVolcadoBag extends StatefulWidget {
  const PaginaVolcadoBag({super.key});

  @override
  State<PaginaVolcadoBag> createState() => _PaginaVolcadoBagState();
}

class _PaginaVolcadoBagState extends State<PaginaVolcadoBag> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Listados de datos
  List<Map<String, dynamic>> todosLosBigBags = [];
  List<Map<String, dynamic>> bolsonesDisponibles = [];
  List<Map<String, dynamic>> historialVolcados = [];
  bool cargando = false;

  // Filtros de búsqueda y fecha
  DateTime? fechaFiltroConfeccion;
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

  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    final db = await dbHelper.database;

    try {
      final List<Map<String, dynamic>> empaqueRes = await db.query(
        'embolsado_bag',
        orderBy: 'fecha DESC, hora DESC, id DESC',
      );

      final List<Map<String, dynamic>> volcadoRes = await db.query(
        'volcado_bag',
        orderBy: 'fecha DESC, hora DESC',
      );

      setState(() {
        todosLosBigBags = empaqueRes;
        historialVolcados = volcadoRes;
        _aplicarFiltros();
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos de volcado: $e");
      setState(() => cargando = false);
    }
  }

  void _aplicarFiltros() {
    final query = queryBusqueda.toLowerCase().trim();
    final fechaStr = fechaFiltroConfeccion != null
        ? DateFormat('yyyy-MM-dd').format(fechaFiltroConfeccion!)
        : null;

    bolsonesDisponibles = todosLosBigBags.where((b) {
      final esActivo = (b['estado'] ?? '').toString().toUpperCase() != 'VOLCADO';
      final cod = (b['cod_bigbag'] ?? '').toString().toLowerCase();
      final lote = (b['lote_proceso'] ?? b['lote'] ?? '').toString().toLowerCase();
      final prod = (b['productor'] ?? '').toString().toLowerCase();
      final variedad = (b['variedad'] ?? '').toString().toLowerCase();
      final celda = (b['celda'] ?? b['cod_bin'] ?? '').toString().toLowerCase();

      final coincideQuery = query.isEmpty ||
          cod.contains(query) ||
          lote.contains(query) ||
          prod.contains(query) ||
          variedad.contains(query) ||
          celda.contains(query);

      final fechaEmb = (b['fecha'] ?? b['fecha_emb'] ?? '').toString();
      final coincideFecha = fechaStr == null || fechaEmb == fechaStr;

      return esActivo && coincideQuery && coincideFecha;
    }).toList();

    if (query.isNotEmpty || fechaStr != null) {
      historialVolcados = historialVolcados.where((v) {
        final cod = (v['cod_bigbag'] ?? '').toString().toLowerCase();
        final lote = (v['lote_proceso'] ?? v['lote'] ?? '').toString().toLowerCase();
        final prod = (v['productor'] ?? '').toString().toLowerCase();
        final variedad = (v['variedad'] ?? '').toString().toLowerCase();

        final coincideQuery = query.isEmpty ||
            cod.contains(query) ||
            lote.contains(query) ||
            prod.contains(query) ||
            variedad.contains(query);

        final fechaEmb = (v['fecha_emb'] ?? v['fecha'] ?? '').toString();
        final coincideFecha = fechaStr == null || fechaEmb == fechaStr;

        return coincideQuery && coincideFecha;
      }).toList();
    }
  }

  // ACA ES LO NUEVO: Escáner QR de búsqueda rápida del ciclo activo
  void _abrirEscanerQRVolcado() {
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
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 44, height: 4, decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("ESCANEAR BOLSÓN PARA VOLCAR", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 12.5, color: kColorTextSecondary)),
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
                      final bolsonActivo = await dbHelper.obtenerBolsonActivoPorQR(codigo);
                      if (bolsonActivo != null) {
                        _mostrarDialogoConfirmarVolcado(bolsonActivo);
                      } else {
                        _mostrarToast("No hay ciclo activo pendiente para el QR $codigo", tipo: 'error');
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

  Future<void> _ejecutarVolcado(Map<String, dynamic> item) async {
    final db = await dbHelper.database;
    final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    final String regLocalVolcado = dbHelper.generarIdCorto();

    try {
      await db.transaction((txn) async {
        await txn.update(
          'embolsado_bag',
          {'estado': 'VOLCADO', 'sincronizado': 0},
          where: 'reg_local = ?',
          whereArgs: [item['reg_local']],
        );

        await txn.insert('volcado_bag', {
          'reg_local': regLocalVolcado,
          'fecha': fechaHoy,
          'hora': horaHoy,
          'registro_emb': item['reg_local'],
          'cod_bigbag': item['cod_bigbag'],
          'fecha_emb': item['fecha'] ?? item['fecha_emb'],
          'hora_emb': item['hora'] ?? item['hora_emb'],
          'productor': item['productor'] ?? 'S/P',
          'especie': item['especie'] ?? 'Nuez',
          'variedad': item['variedad'] ?? 'S/V',
          'lote': item['lote_proceso'] ?? item['lote'] ?? 'S/L',
          'lote_proceso': item['lote_proceso'] ?? item['lote'] ?? 'S/L',
          'calidad': item['calidad'] ?? 'ESTANDAR',
          'fumigado': item['fumigado'] ?? 'NO',
          'sincronizado': 0,
        });
      });
      // Guardó en volcado_bag en SQLite y luego:
      PaginaSincronizar.sincronizarVolcadoBag().catchError((e) {
      debugPrint("Sincronización de Volcado Bag diferida: $e");
      return 0;
      });

      _mostrarToast("Bolsón ${item['cod_bigbag']} volcado con éxito", tipo: 'exito');
      _cargarDatos();
    } catch (e) {
      _mostrarToast("Error al procesar volcado: $e", tipo: 'error');
    }
  }

  void _mostrarDialogoConfirmarVolcado(Map<String, dynamic> item) {
    final String kilos = item['kg']?.toString() ?? item['registro_mov']?.toString() ?? '0';
    final String codBigBag = item['cod_bigbag']?.toString() ?? 'S/C';

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
                  child: const Icon(Icons.layers_clear_rounded, size: 32, color: kColorAccentDark),
                ),
                const SizedBox(height: 16),
                const Text(
                  "¿CONFIRMAR VOLCADO?",
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900, color: kColorText, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  "El bolsón pasará a estado VOLCADO, se descontará del inventario activo y se registrará en la trazabilidad de proceso.",
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
                      Text(codBigBag.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kColorText), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text("$kilos KG NETOS", style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 22, color: kColorAccentDark)),
                      const Divider(height: 16, color: kColorBorder),
                      Text(
                        "${item['productor'] ?? 'S/P'} • ${item['variedad'] ?? 'Nuez'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kColorTextSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Celda Origen: ${item['celda'] ?? item['cod_bin'] ?? 'S/C'}",
                        style: const TextStyle(fontSize: 11, color: kColorTextSecondary),
                      ),
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
                            _ejecutarVolcado(item);
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
                        Text("VOLCADO DE BIG BAGS", style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText)),
                        Text("", style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
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
                            hintText: "Buscar por bolsón, lote, productor o variedad...",
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
                      onTap: _abrirEscanerQRVolcado,
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

                    // Filtro de fecha
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fechaFiltroConfeccion ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            fechaFiltroConfeccion = picked;
                            _aplicarFiltros();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: fechaFiltroConfeccion != null ? kColorAccentSoft : kColorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: fechaFiltroConfeccion != null ? kColorAccent : kColorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 16, color: fechaFiltroConfeccion != null ? kColorAccentDark : kColorTextSecondary),
                            const SizedBox(width: 6),
                            Text(
                              fechaFiltroConfeccion != null ? DateFormat('dd/MM/yy').format(fechaFiltroConfeccion!) : "FECHA",
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fechaFiltroConfeccion != null ? kColorAccentDark : kColorTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                      Tab(text: "LISTOS PARA VOLCADO (${bolsonesDisponibles.length})"),
                      Tab(text: "HISTORIAL DE VOLCADOS (${historialVolcados.length})"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGridDisponiblesGrande(crossAxisCount),
                      _buildListaHistorialCompacto(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridDisponiblesGrande(int crossAxisCount) {
    if (bolsonesDisponibles.isEmpty) {
      return _buildVacioMensaje("No hay bolsones pendientes de volcar");
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
          childAspectRatio: crossAxisCount > 1 ? 1.7 : 1.55,
        ),
        itemCount: bolsonesDisponibles.length,
        itemBuilder: (context, index) {
          final item = bolsonesDisponibles[index];
          return _buildCardBolsonGrande(item);
        },
      ),
    );
  }

  Widget _buildCardBolsonGrande(Map<String, dynamic> item) {
    final String kilos = item['kg']?.toString() ?? item['registro_mov']?.toString() ?? '0';
    final String codBigBag = item['cod_bigbag']?.toString() ?? 'S/C';
    final String fechaEmb = item['fecha']?.toString() ?? item['fecha_emb']?.toString() ?? '';
    final String horaEmb = item['hora']?.toString() ?? item['hora_emb']?.toString() ?? '';

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
          onTap: () => _mostrarDialogoConfirmarVolcado(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: kColorAccentSoft, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.shopping_bag_rounded, color: kColorAccentDark, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              codBigBag.toUpperCase(),
                              style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 15, color: kColorText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kColorBorder)),
                      child: Text("CELDA ${item['celda'] ?? item['cod_bin'] ?? 'S/C'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorTextSecondary)),
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
                        Text("${item['especie'] ?? 'Nuez'} • ${item['variedad'] ?? 'S/V'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kColorTextSecondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kColorAccentSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        (item['tipo_envase'] ?? 'BIG BAG').toString().toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kColorAccentDark),
                      ),
                    ),
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
                            Text("$fechaEmb • $horaEmb", style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: kColorAccent, borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.touch_app_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text("VOLCAR AHORA", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
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
  }

  Widget _buildListaHistorialCompacto() {
    if (historialVolcados.isEmpty) {
      return _buildVacioMensaje("No hay registros en el historial de volcados");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: historialVolcados.length,
        itemBuilder: (context, index) {
          final item = historialVolcados[index];
          final String codBigBag = item['cod_bigbag']?.toString() ?? 'S/C';
          final String fechaVolcado = item['fecha']?.toString() ?? '';
          final String horaVolcado = item['hora']?.toString() ?? '';
          final String celda = item['cod_bin'] ?? item['celda'] ?? 'S/C';
          final String lote = item['lote_proceso'] ?? item['lote'] ?? 'S/L';

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
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _mostrarFichaDetalle(item),
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
                                Text(codBigBag.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: kColorText)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(5)),
                                  child: Text("CELDA $celda", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kColorTextSecondary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${item['productor'] ?? 'S/P'} • ${item['variedad'] ?? 'Nuez'} • Lote $lote",
                              style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          Text("$fechaVolcado $horaVolcado", style: const TextStyle(fontSize: 10, color: kColorTextSecondary)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kColorTextSecondary),
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

  void _mostrarFichaDetalle(Map<String, dynamic> item) {
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
                      const Text("TRAZABILIDAD DE VOLCADO", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5)),
                      Text("${item['cod_bigbag']}".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: kColorText)),
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
                        _buildRenglonDato("Código Bolsón", item['cod_bigbag'], esDestacado: true),
                        const Divider(height: 14, color: kColorBorder),
                        _buildRenglonDato("Celda de Origen", item['cod_bin'] ?? item['celda']),
                        _buildRenglonDato("Lote de Proceso", item['lote_proceso'] ?? item['lote']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Especie / Variedad", "${item['especie'] ?? 'Nuez'} • ${item['variedad'] ?? 'S/V'}"),
                        _buildRenglonDato("Fecha Confección", "${item['fecha_emb'] ?? item['fecha']} • ${item['hora_emb'] ?? item['hora'] ?? ''}"),
                        _buildRenglonDato("Fecha de Volcado", "${item['fecha']} • ${item['hora'] ?? ''}"),
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

  Widget _buildRenglonDato(String etiqueta, String? valor, {bool esDestacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: kColorTextSecondary, fontWeight: FontWeight.w500)),
          Text((valor == null || valor.isEmpty) ? "S/D" : valor, style: TextStyle(fontSize: esDestacado ? 14 : 12.5, fontWeight: FontWeight.w700, color: esDestacado ? kColorAccentDark : kColorText)),
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