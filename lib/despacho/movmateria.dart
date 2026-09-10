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

class PaginaMovMateria extends StatefulWidget {
  const PaginaMovMateria({super.key});

  @override
  State<PaginaMovMateria> createState() => _PaginaMovMateriaState();
}

class _PaginaMovMateriaState extends State<PaginaMovMateria> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Listas de datos
  List<Map<String, dynamic>> bolsones = [];
  List<Map<String, dynamic>> bolsonesFiltrados = [];
  List<Map<String, dynamic>> bins = [];
  List<Map<String, dynamic>> binsFiltrados = [];
  List<String> depositosDisponibles = [];
  bool cargando = false;

  // Filtros
  String? depositoFiltro;
  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _inicializar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _cargarDepositos();
    await _cargarDatos();
  }

  // Carga de depósitos maestros desde parámetros
  Future<void> _cargarDepositos() async {
    try {
      final dynamic db = await dbHelper.database;
      final List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from(
        await db.query('parametros_depositos')
      );
      setState(() {
        if (res.isNotEmpty) {
          depositosDisponibles = res
              .map((d) => (d['deposito'] ?? '').toString().trim().toUpperCase())
              .where((d) => d.isNotEmpty)
              .toSet()
              .toList();
        } else {
          depositosDisponibles = ['PLANTA CENTRAL', 'DEPÓSITO 1', 'DEPÓSITO 2', 'CÁMARA DE FRÍO', 'DESPACHO'];
        }
      });
    } catch (e) {
      debugPrint("Error cargando depósitos: $e");
      depositosDisponibles = ['PLANTA CENTRAL', 'DEPÓSITO 1', 'DEPÓSITO 2', 'CÁMARA DE FRÍO', 'DESPACHO'];
    }
  }

  // ESTO LO MODIFIQUE: Consulta robusta que carga materias activas tanto en Web como en Móvil
  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    final dynamic db = await dbHelper.database;

    try {
      // 1. Bolsones (Big Bags)
      final List<Map<String, dynamic>> resBolsones = List<Map<String, dynamic>>.from(
        await db.query(
          'embolsado_bag',
          where: "estado != 'VOLCADO'",
          orderBy: 'fecha DESC, hora DESC, id DESC',
        )
      );

      // 2. Bins de empaque
      final List<Map<String, dynamic>> resBins = List<Map<String, dynamic>>.from(
        await db.query(
          'empaque_armado_bins',
          where: "estado != 'VOLCADO'",
          orderBy: 'fecha_emb DESC, hora_emb DESC, id DESC',
        )
      );

      setState(() {
        bolsones = resBolsones;
        bins = resBins;
        _aplicarFiltros();
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando materias: $e");
      setState(() => cargando = false);
    }
  }

  void _aplicarFiltros() {
    final query = queryBusqueda.toLowerCase().trim();

    // Filtro Bolsones
    bolsonesFiltrados = bolsones.where((item) {
      final cod = (item['cod_bigbag'] ?? '').toString().toLowerCase();
      final lote = (item['lote_proceso'] ?? item['lote'] ?? '').toString().toLowerCase();
      final prod = (item['productor'] ?? '').toString().toLowerCase();
      final dep = (item['deposito'] ?? 'PLANTA CENTRAL').toString().toUpperCase();

      final coincideQuery = query.isEmpty || cod.contains(query) || lote.contains(query) || prod.contains(query);
      final coincideDep = depositoFiltro == null || dep == depositoFiltro;

      return coincideQuery && coincideDep;
    }).toList();

    // Filtro Bins
    binsFiltrados = bins.where((item) {
      final cod = (item['cod_bin'] ?? item['cod_bigbag'] ?? '').toString().toLowerCase();
      final lote = (item['lote_proceso'] ?? item['lote'] ?? '').toString().toLowerCase();
      final prod = (item['productor'] ?? '').toString().toLowerCase();
      final dep = (item['deposito'] ?? 'PLANTA CENTRAL').toString().toUpperCase();

      final coincideQuery = query.isEmpty || cod.contains(query) || lote.contains(query) || prod.contains(query);
      final coincideDep = depositoFiltro == null || dep == depositoFiltro;

      return coincideQuery && coincideDep;
    }).toList();
  }

  Future<void> _moverMateria({
    required String tabla,
    required String regLocal,
    required String nuevoDeposito,
    required String codigoItem,
  }) async {
    final dynamic db = await dbHelper.database;
    try {
      await db.update(
        tabla,
        {
          'deposito': nuevoDeposito,
          'sincronizado': 0,
        },
        where: 'reg_local = ?',
        whereArgs: [regLocal],
      );

      _mostrarToast("$codigoItem trasladado a $nuevoDeposito", tipo: 'exito');
      _cargarDatos();
    } catch (e) {
      _mostrarToast("Error al mover: $e", tipo: 'error');
    }
  }

  void _abrirEscanerRapido() {
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
                    "ESCANEAR QR PARA BUSCAR / TRASLADAR",
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

                      setState(() {
                        queryBusqueda = codigo;
                        _searchController.text = codigo;
                        _aplicarFiltros();
                      });
                      _mostrarToast("Filtro aplicado: $codigo", tipo: 'info');
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

  void _mostrarModalSeleccionDeposito({
    required BuildContext context,
    required String tabla,
    required Map<String, dynamic> item,
    required bool esBolson,
  }) {
    final String codigo = (esBolson ? item['cod_bigbag'] : (item['cod_bin'] ?? item['cod_bigbag']))?.toString() ?? 'S/C';
    final String depositoActual = (item['deposito'] ?? 'PLANTA CENTRAL').toString().toUpperCase();

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TRANSFERENCIA DE UBICACIÓN",
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5),
                      ),
                      Text(
                        codigo.toUpperCase(),
                        style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 18, color: kColorText),
                      ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kColorBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kColorBorder)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: kColorAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Ubicación actual: ",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kColorTextSecondary),
                    ),
                    Text(
                      depositoActual,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kColorAccentDark),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "SELECCIONA EL DEPÓSITO O CÁMARA DESTINO:",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorTextSecondary),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: depositosDisponibles.length,
                itemBuilder: (c, index) {
                  final dep = depositosDisponibles[index];
                  final bool esMismo = dep == depositoActual;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: esMismo ? kColorAccentSoft : kColorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: esMismo ? kColorAccent : kColorBorder),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: esMismo
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _moverMateria(
                                  tabla: tabla,
                                  regLocal: item['reg_local'],
                                  nuevoDeposito: dep,
                                  codigoItem: codigo,
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warehouse_rounded,
                                    size: 18,
                                    color: esMismo ? kColorAccentDark : kColorTextSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    dep,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: esMismo ? kColorAccentDark : kColorText,
                                    ),
                                  ),
                                ],
                              ),
                              if (esMismo)
                                const Text("ACTUAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kColorAccentDark))
                              else
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: kColorAccent),
                            ],
                          ),
                        ),
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
                          "MOVIMIENTO INTERNO",
                          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15, color: kColorText),
                        ),
                        Text(
                          "Gestión de Stock en Depósitos",
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
                        border: Border.all(color: kColorAccent.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 15, color: kColorAccentDark),
                          SizedBox(width: 4),
                          Text(
                            "ACTUALIZAR",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorAccentDark),
                          ),
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
          // PANEL DE BÚSQUEDA + ESCÁNER + FILTRO POR DEPÓSITO
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
                            hintText: "Buscar por código, lote o productor...",
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

                    InkWell(
                      onTap: _abrirEscanerRapido,
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
                  ],
                ),
                const SizedBox(height: 10),

                // Filtro Horizontal de Depósitos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildChipFiltroDeposito("TODOS", null),
                      ...depositosDisponibles.map((dep) => _buildChipFiltroDeposito(dep, dep)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // SOLAPAS: BOLSONES / BINS
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
                      Tab(text: "BOLSONES (${bolsonesFiltrados.length})"),
                      Tab(text: "BINS (${binsFiltrados.length})"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO DE LAS SOLAPAS
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGridItems(bolsonesFiltrados, esBolson: true, crossAxisCount: crossAxisCount),
                      _buildGridItems(binsFiltrados, esBolson: false, crossAxisCount: crossAxisCount),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltroDeposito(String label, String? valor) {
    final bool seleccionado = depositoFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            depositoFiltro = valor;
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

  Widget _buildGridItems(List<Map<String, dynamic>> lista, {required bool esBolson, required int crossAxisCount}) {
    if (lista.isEmpty) {
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
                  child: Icon(esBolson ? Icons.shopping_bag_outlined : Icons.inventory_2_outlined, size: 38, color: kColorTextSecondary),
                ),
                const SizedBox(height: 14),
                Text(
                  esBolson ? "No hay bolsones en este depósito" : "No hay bins en este depósito",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText),
                ),
              ],
            ),
          ),
        ],
      );
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
          childAspectRatio: crossAxisCount > 1 ? 1.85 : 1.65,
        ),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final item = lista[index];
          return _buildCardItemMateria(item, esBolson: esBolson);
        },
      ),
    );
  }

  Widget _buildCardItemMateria(Map<String, dynamic> item, {required bool esBolson}) {
    final String codigo = (esBolson ? item['cod_bigbag'] : (item['cod_bin'] ?? item['cod_bigbag']))?.toString() ?? 'S/C';
    final String kilos = (esBolson ? item['kg'] : item['registro_mov'])?.toString() ?? '0';
    final String depositoActual = (item['deposito'] ?? 'PLANTA CENTRAL').toString().toUpperCase();
    final String tablaDestino = esBolson ? 'embolsado_bag' : 'empaque_armado_bins';

    return Container(
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kColorAccentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(esBolson ? Icons.shopping_bag_rounded : Icons.inventory_2_rounded, size: 18, color: kColorAccentDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          codigo.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kColorText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: kColorAccentSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kColorAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: kColorAccentDark),
                      const SizedBox(width: 3),
                      Text(
                        depositoActual,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: kColorAccentDark),
                      ),
                    ],
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
                      style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 18, color: kColorText),
                    ),
                    Text(
                      "${item['productor'] ?? 'S/P'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                      style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  item['variedad'] ?? 'Nuez',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorTextSecondary),
                ),
              ],
            ),

            const Divider(height: 8, color: kColorBorder),

            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.sync_alt_rounded, size: 16),
                label: const Text(
                  "MOVER DEPOSITO",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.3),
                ),
                onPressed: () => _mostrarModalSeleccionDeposito(
                  context: context,
                  tabla: tablaDestino,
                  item: item,
                  esBolson: esBolson,
                ),
              ),
            ),
          ],
        ),
      ),
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