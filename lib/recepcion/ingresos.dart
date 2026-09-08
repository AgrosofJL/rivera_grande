import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../base_datos.dart';
import '../sincronizar.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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

class PaginaIngresos extends StatefulWidget {
  const PaginaIngresos({super.key});

  @override
  State<PaginaIngresos> createState() => _PaginaIngresosState();
}

class _PaginaIngresosState extends State<PaginaIngresos> {
  final dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> registrosLocales = [];
  List<Map<String, dynamic>> registrosFiltrados = [];
  bool _isLoading = true;
  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  // Catálogos para el modal de nuevo ingreso
  List<String> establecimientos = [];
  List<Map<String, dynamic>> cuadros = [];
  List<Map<String, dynamic>> celdasParam = [];

  // Estados temporales del formulario
  String? qrEscaneado;
  String? celdaSeleccionada;
  String? establecimientoSel;
  String? cuadroSel;
  DateTime fechaSel = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ESTO LO MODIFIQUE: Consulta completa de recepciones ordenada de forma descendente
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final db = await dbHelper.database;
    final res = await db.query('celdas_recepcion', orderBy: 'fecha_reg DESC, hora DESC, id DESC');
    setState(() {
      registrosLocales = res;
      _aplicarFiltro(queryBusqueda);
      _isLoading = false;
    });
  }

  Future<void> _cargarCatalogos() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> estRes =
        await db.rawQuery('SELECT establecimiento FROM inventario GROUP BY establecimiento');
    final List<Map<String, dynamic>> celRes = await db.query('parametros_celdas');

    setState(() {
      establecimientos = estRes.map((e) => e['establecimiento'] as String).toList();
      celdasParam = celRes;
    });
  }

  Future<void> _cargarCuadros(String est) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res =
        await db.query('inventario', where: 'establecimiento = ?', whereArgs: [est]);
    setState(() {
      cuadros = res;
      cuadroSel = null;
    });
  }

  // ACA ES LO NUEVO: Motor de filtrado reactivo en tiempo real
  void _aplicarFiltro(String query) {
    setState(() {
      queryBusqueda = query.toLowerCase().trim();
      if (queryBusqueda.isEmpty) {
        registrosFiltrados = List.from(registrosLocales);
      } else {
        registrosFiltrados = registrosLocales.where((r) {
          final celda = (r['cod_celda'] ?? '').toString().toLowerCase();
          final lote = (r['lote_proceso'] ?? '').toString().toLowerCase();
          final prod = (r['productor'] ?? '').toString().toLowerCase();
          final cuadro = (r['cuadro'] ?? '').toString().toLowerCase();
          final variedad = (r['variedad'] ?? '').toString().toLowerCase();
          return celda.contains(queryBusqueda) ||
              lote.contains(queryBusqueda) ||
              prod.contains(queryBusqueda) ||
              cuadro.contains(queryBusqueda) ||
              variedad.contains(queryBusqueda);
        }).toList();
      }
    });
  }

  // --- MODAL DE ESCÁNER QR ---
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
                "ESCANEAR CÓDIGO QR DE CELDA",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: kColorTextSecondary,
                ),
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
                          celdaSeleccionada = res.first['celda_nombre'].toString();
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

  // ACA ES LO NUEVO: Modal Flotante de Alta Precisión para Registro de Recepción
  void _abrirModalNuevoIngreso() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                          const Text(
                            "RECEPCIÓN DE MATERIA PRIMA",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: kColorAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            celdaSeleccionada ?? "Asignar Celda de Descarga",
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
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
                      // Selección o escaneo de celda
                      if (celdaSeleccionada == null) ...[
                        InkWell(
                          onTap: () => _abrirEscanerModal(setModalState),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kColorBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 36, color: kColorAccent),
                                SizedBox(height: 10),
                                Text(
                                  "ESCANEAR QR DE CELDA",
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kColorText),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "O selecciona manualmente del listado inferior",
                                  style: TextStyle(fontSize: 11.5, color: kColorTextSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildEtiquetaSeccion("O SELECCIONAR MANUALMENTE:"),
                        _buildGridOpciones(
                          celdasParam.map((c) => c['celda_nombre'].toString()).toList(),
                          (v) => setModalState(() => celdaSeleccionada = v),
                          celdaSeleccionada,
                        ),
                      ] else ...[
                        // Cabecera de celda fijada
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: kColorAccentSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kColorAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warehouse_rounded, size: 18, color: kColorAccentDark),
                                  const SizedBox(width: 8),
                                  Text(
                                    "CELDA: ${celdaSeleccionada!.toUpperCase()}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: kColorAccentDark,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => setModalState(() => celdaSeleccionada = null),
                                child: const Text("CAMBIAR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kColorAccent)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSelectorFechaModal(setModalState),
                        const SizedBox(height: 16),
                        _buildEtiquetaSeccion("1. ESTABLECIMIENTO"),
                        _buildGridOpciones(
                          establecimientos,
                          (v) async {
                            setModalState(() => establecimientoSel = v);
                            await _cargarCuadros(v);
                            setModalState(() {});
                          },
                          establecimientoSel,
                        ),
                        if (establecimientoSel != null) ...[
                          const SizedBox(height: 16),
                          _buildEtiquetaSeccion("2. CUADRO DE ORIGEN"),
                          _buildGridOpciones(
                            cuadros.map((e) => e['cuadro'] as String).toList(),
                            (v) => setModalState(() => cuadroSel = v),
                            cuadroSel,
                          ),
                        ],
                        if (cuadroSel != null) ...[
                          const SizedBox(height: 24),
                          _buildBotonGuardarModal(context),
                        ],
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
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: kColorTextSecondary,
                            ),
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
                          "RECEPCIÓN DE PLANTA",
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kColorText,
                          ),
                        ),
                        Text(
                          "Registro e Ingreso a Celdas",
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: kColorTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón Acceso Sincronizador
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PaginaSincronizar()),
                    ).then((_) => _cargarDatos()),
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
                          Icon(Icons.sync_alt_rounded, size: 15, color: kColorAccentDark),
                          SizedBox(width: 4),
                          Text(
                            "SYNC",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kColorAccentDark,
                            ),
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
      body: RefreshIndicator(
        color: kColorAccent,
        onRefresh: _cargarDatos,
        child: Column(
          children: [
            // PANEL SUPERIOR: Resumen métrico y buscador
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
                            "INGRESOS REGISTRADOS: ${registrosLocales.length}",
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
                          color: kColorBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kColorBorder),
                        ),
                        child: Text(
                          "${registrosFiltrados.length} VISIBLES",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kColorTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Caja de búsqueda industrial
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
                        hintText: "Buscar por lote, celda, productor o variedad...",
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
                ],
              ),
            ),

            // LISTADO DE RECEPCIONES
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kColorAccent, strokeWidth: 2.5))
                  : registrosFiltrados.isEmpty
                      ? _buildSinDatos()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: registrosFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = registrosFiltrados[index];
                            return _buildCardIngreso(item);
                          },
                        ),
            ),
          ],
        ),
      ),
      // BOTÓN FLOTANTE ESTILO AGROSOFT INDUSTRIAL
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _resetearFormulario();
          _abrirModalNuevoIngreso();
        },
        backgroundColor: kColorAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          "NUEVO INGRESO",
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  // ESTO LO MODIFIQUE: Tarjeta de Ingreso refinada con estado activo e información de origen
  Widget _buildCardIngreso(Map<String, dynamic> item) {
    final bool esActivo = (item['estado'] ?? 'ACTIVO') == 'ACTIVO';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          onTap: () => _mostrarFichaDetalleModal(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: esActivo ? kColorAccentSoft : kColorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: esActivo ? kColorAccent.withOpacity(0.25) : kColorBorder),
                  ),
                  child: Icon(
                    Icons.login_rounded,
                    color: esActivo ? kColorAccent : kColorTextSecondary,
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
                            "CELDA ${item['cod_celda'] ?? item['celda_numero'] ?? 'S/C'}".toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: kColorText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kColorBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Text(
                              "LOTE ${item['lote_proceso'] ?? 'S/L'}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kColorTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${item['productor'] ?? 'S/P'} • Cuadro ${item['cuadro'] ?? 'S/C'} • ${item['variedad'] ?? 'Nuez'}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: kColorTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esActivo ? kColorAccentSoft : kColorDangerSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        esActivo ? "ACTIVO" : "PASIVO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: esActivo ? kColorAccentDark : kColorDanger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${item['fecha_reg'] ?? ''}",
                      style: const TextStyle(fontSize: 10, color: kColorTextSecondary),
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

  Widget _buildSinDatos() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kColorSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: kColorBorder),
                ),
                child: const Icon(Icons.inbox_rounded, size: 40, color: kColorTextSecondary),
              ),
              const SizedBox(height: 14),
              Text(
                queryBusqueda.isNotEmpty ? "Sin coincidencias para la búsqueda" : "No hay ingresos registrados hoy",
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText),
              ),
              const SizedBox(height: 4),
              const Text(
                "Presiona 'NUEVO INGRESO' para asignar materia prima a una celda.",
                style: TextStyle(fontSize: 12, color: kColorTextSecondary),
              ),
            ],
          ),
        )
      ],
    );
  }

  // --- MODAL DE DETALLES DE RECEPCIÓN ---
  void _mostrarFichaDetalleModal(Map<String, dynamic> item) {
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
                      const Text(
                        "FICHA DE RECEPCIÓN",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: kColorAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "LOTE ${item['lote_proceso']}".toUpperCase(),
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
                  _buildEtiquetaSeccion("DATOS GENERALES DE INGRESO"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRenglonDato("Celda Asignada", item['cod_celda'] ?? item['celda_numero'], esDestacado: true),
                        const Divider(height: 14, color: kColorBorder),
                        _buildRenglonDato("Lote Proceso", item['lote_proceso']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Cuadro de Origen", item['cuadro']),
                        _buildRenglonDato("Variedad / Especie", "${item['variedad'] ?? 'Nuez'} (${item['cultivo'] ?? 'Fruto Seco'})"),
                        _buildRenglonDato("Fecha de Carga", item['fecha_reg']),
                        _buildRenglonDato("Hora de Ingreso", item['hora']),
                        _buildRenglonDato("Estado Operativo", item['estado']),
                        _buildRenglonDato("Registro Local", item['reg_local']),
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
  Widget _buildEtiquetaSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: kColorTextSecondary,
          letterSpacing: 0.5,
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
          Text(
            (valor == null || valor.isEmpty) ? "S/D" : valor,
            style: TextStyle(
              fontSize: esDestacado ? 13.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: esDestacado ? kColorAccentDark : kColorText,
            ),
          ),
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
        onPressed: () => _guardarNuevoIngreso(ctx),
        child: const Text(
          "CONFIRMAR Y ASIGNAR INGRESO",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.4),
        ),
      ),
    );
  }

  // --- GUARDADO ESTRICTO EN celdas_recepcion ---
  Future<void> _guardarNuevoIngreso(BuildContext ctx) async {
    final db = await dbHelper.database;
    if (celdaSeleccionada == null || establecimientoSel == null || cuadroSel == null) {
      _mostrarToast("Faltan datos requeridos", tipo: 'error');
      return;
    }

    String fechaHoy = DateFormat('yyyy-MM-dd').format(fechaSel);
    String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    String fechaParaLote = DateFormat('ddMMyyyy').format(fechaSel);

    try {
      // ACA ES LO NUEVO: Generación correlativa Max(registro)+1 para la fecha seleccionada
      final List<Map<String, dynamic>> resContador =
          await db.rawQuery("SELECT COUNT(*) as total FROM celdas_recepcion WHERE fecha_reg = ?", [fechaHoy]);
      int contador = ((resContador.first['total'] as int?) ?? 0) + 1;
      String loteProceso = "${fechaParaLote}&$contador";

      String regLocalKey = String.fromCharCodes(
        Iterable.generate(8, (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.codeUnitAt(Random().nextInt(36))),
      );

      // Traer datos complementarios desde inventario
      final List<Map<String, dynamic>> infoInv = await db.query(
        'inventario',
        where: 'establecimiento = ? AND cuadro = ?',
        whereArgs: [establecimientoSel, cuadroSel],
        limit: 1,
      );

      String productor = (infoInv.isNotEmpty ? infoInv.first['productor'] : "S/P") ?? "S/P";
      String variedad = (infoInv.isNotEmpty ? infoInv.first['variedad'] : "S/V") ?? "S/V";
      String cultivo = (infoInv.isNotEmpty ? infoInv.first['cultivo'] : "S/C") ?? "S/C";

      // Inserción directa en celdas_recepcion
      await db.insert('celdas_recepcion', {
        'fecha_reg': fechaHoy,
        'hora': horaHoy,
        'cod_celda': celdaSeleccionada,
        'cuadro': cuadroSel,
        'celda_numero': celdaSeleccionada,
        'productor': productor,
        'cultivo': cultivo,
        'variedad': variedad,
        'lote_proceso': loteProceso,
        'estado': 'ACTIVO',
        'reg_local': regLocalKey,
      });

      _mostrarToast("Ingreso asignado: Lote $loteProceso", tipo: 'exito');
      _resetearFormulario();
      Navigator.pop(ctx);
      _cargarDatos();
    } catch (e) {
      _mostrarToast("Error al registrar ingreso: $e", tipo: 'error');
    }
  }

  void _resetearFormulario() {
    setState(() {
      qrEscaneado = null;
      celdaSeleccionada = null;
      establecimientoSel = null;
      cuadroSel = null;
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