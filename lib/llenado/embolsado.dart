import 'package:flutter/material.dart';
import 'package:la_rivera_celdas/sincronizar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../base_datos.dart';
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

class PaginaEmbolsado extends StatefulWidget {
  const PaginaEmbolsado({super.key});

  @override
  State<PaginaEmbolsado> createState() => _PaginaEmbolsadoState();
}

class _PaginaEmbolsadoState extends State<PaginaEmbolsado> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  late TabController _tabController;

  // Listados de datos
  List<Map<String, dynamic>> historialEmbolsado = [];
  List<Map<String, dynamic>> bolsonesDelDia = [];
  Map<String, List<Map<String, dynamic>>> historialAgrupadoPorDia = {};
  List<Map<String, dynamic>> celdasPasivasDisponibles = [];
  bool cargando = false;

  String queryBusqueda = "";
  final TextEditingController _searchController = TextEditingController();

  // Estados del Formulario Modal
  Map<String, dynamic>? celdaPasivaSeleccionada;
  String? bigBagCodigoFinal;
  bool esIngresoManual = false;
  final TextEditingController _numManualController = TextEditingController();
  final TextEditingController _kilosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ACA ES LO NUEVO: Solapas de Producción del Día y Archivero Histórico por Días
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _numManualController.dispose();
    _kilosController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await _cargarCeldasPasivas();
    await _cargarHistorialEmbolsado();
  }

  // ESTO LO MODIFIQUE: Carga de celdas en estado PASIVO calculando los kilos acumulados que lleva cargados
  Future<void> _cargarCeldasPasivas() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> res = await db.rawQuery('''
        SELECT r.*, 
          COALESCE((
            SELECT SUM(CAST(e.kg AS REAL)) 
            FROM embolsado_bag e 
            WHERE e.lote_proceso = r.lote_proceso
          ), 0) AS kilos_acumulados
        FROM celdas_recepcion r
        WHERE r.estado = 'PASIVO'
        ORDER BY r.fecha_reg DESC, r.hora DESC
      ''');
      setState(() {
        celdasPasivasDisponibles = res;
      });
    } catch (e) {
      _mostrarToast("Error al cargar celdas pasivas: $e", tipo: 'error');
    }
  }

  // ESTO LO MODIFIQUE: Carga sobre la tabla real embolsado_bag agrupando por fecha
  Future<void> _cargarHistorialEmbolsado() async {
    setState(() => cargando = true);
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> res = await db.query(
        'embolsado_bag',
        orderBy: "fecha DESC, hora DESC, id DESC",
      );

      final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Agrupamiento por fecha para el archivero
      final Map<String, List<Map<String, dynamic>>> agrupado = {};
      for (var row in res) {
        final fecha = row['fecha']?.toString() ?? 'S/F';
        if (!agrupado.containsKey(fecha)) {
          agrupado[fecha] = [];
        }
        agrupado[fecha]!.add(row);
      }

      setState(() {
        historialEmbolsado = res;
        bolsonesDelDia = res.where((b) => (b['fecha']?.toString() ?? '') == fechaHoy).toList();
        historialAgrupadoPorDia = agrupado;
        cargando = false;
      });
    } catch (e) {
      _mostrarToast("Error al cargar historial: $e", tipo: 'error');
      setState(() => cargando = false);
    }
  }

  // Helper para sumar kilos de una lista de bolsones
  double _calcularKilos(List<Map<String, dynamic>> lista) {
    double suma = 0;
    for (var item in lista) {
      final k = double.tryParse(item['kg']?.toString() ?? '0') ?? 0;
      suma += k;
    }
    return suma;
  }

  // --- ESCÁNER QR ---
  void _abrirEscannerBigBag(StateSetter setModalState) {
    final MobileScannerController scannerController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
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
                    "ESCANEAR QR DE BOLSÓN",
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: kColorTextSecondary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded, size: 20, color: kColorAccent),
                    onPressed: () => scannerController.toggleTorch(),
                    tooltip: "Linterna",
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ClipRRect(
                child: MobileScanner(
                  controller: scannerController,
                  fit: BoxFit.cover,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final codigo = barcodes.first.rawValue ?? barcodes.first.displayValue ?? "";
                      if (codigo.isEmpty) return;

                      await scannerController.stop();
                      scannerController.dispose();
                      Navigator.pop(ctx);

                      setModalState(() {
                        bigBagCodigoFinal = codigo;
                        esIngresoManual = false;
                      });
                      _mostrarToast("QR Bolsón vinculado", tipo: 'info');
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

  void _procesarIngresoManual(String valor, StateSetter setModalState) {
    if (valor.trim().isEmpty) {
      setModalState(() => bigBagCodigoFinal = null);
      return;
    }
    int? numero = int.tryParse(valor.trim());
    if (numero != null) {
      String numeroFormateado = numero.toString().padLeft(4, '0');
      setModalState(() {
        bigBagCodigoFinal = "BOLSON Nº $numeroFormateado";
      });
    } else {
      setModalState(() {
        bigBagCodigoFinal = "BOLSON ${valor.toUpperCase()}";
      });
    }
  }

  // ESTO LO MODIFIQUE: Persistencia con suma acumulada y desactivación automática si alcanza 4800 a 5200 kg
  // ESTO LO MODIFIQUE: Persistencia atómica asegurando cierre de ciclo anterior del mismo QR
  Future<void> _registrarEmbolsadoEnBD(BuildContext ctx) async {
    if (celdaPasivaSeleccionada == null || bigBagCodigoFinal == null || _kilosController.text.trim().isEmpty) {
      _mostrarToast("Faltan datos obligatorios (Celda, Identificador o Kilos)", tipo: 'error');
      return;
    }

    final db = await dbHelper.database;
    final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaHoy = DateFormat('HH:mm:ss').format(DateTime.now());
    final String regLocalUnico = dbHelper.generarIdCorto();

    final double kilosNumerico = double.tryParse(_kilosController.text.trim().replaceAll(',', '.')) ?? 0;
    final String tipoEnvaseCalculado = (kilosNumerico<= 550) ? 'BIG BAG CHICO' : 'BIG BAG GRANDE';

    final String codCelda = celdaPasivaSeleccionada!['cod_celda']?.toString() ?? '';
    final String loteProceso = celdaPasivaSeleccionada!['lote_proceso']?.toString() ?? 'S/L';
    final String regLocalCelda = celdaPasivaSeleccionada!['reg_local']?.toString() ?? '';

    try {
      await db.transaction((txn) async {
        // ACA ES LO NUEVO: Cierra cualquier ciclo previo abierto con este mismo QR físico
        await dbHelper.cerrarCicloPrevioQR(
          db: txn,
          nombreTabla: 'embolsado_bag',
          columnaQR: 'cod_bigbag',
          codigoQR: bigBagCodigoFinal!,
          nuevoRegLocal: regLocalUnico,
        );

        // 1. Inserta el nuevo ciclo productivo con reg_local único
        await txn.insert('embolsado_bag', {
          'reg_local': regLocalUnico,
          'registro_emb': regLocalUnico,
          'fecha': fechaHoy,
          'hora': horaHoy,
          'cod_bigbag': bigBagCodigoFinal,
          'celda': codCelda,
          'productor': celdaPasivaSeleccionada!['productor'] ?? 'S/P',
          'especie': celdaPasivaSeleccionada!['cultivo'] ?? 'Nuez',
          'lote': loteProceso,
          'variedad': celdaPasivaSeleccionada!['variedad'] ?? 'S/V',
          'kg': _kilosController.text.trim(),
          'lote_proceso': loteProceso,
          'calibre': '',
          'fumigado': 'NO',
          'estado': 'PROCESADO',
          'tipo_envase': tipoEnvaseCalculado,
          'deposito': 'PLANTA CENTRAL',
          'calidad': '',
          'sincronizado': 0,
        });

        // 2. Control de peso acumulado en celda de origen
        final sumRes = await txn.rawQuery('''
          SELECT SUM(CAST(kg AS REAL)) as total_kg 
          FROM embolsado_bag 
          WHERE celda = ? AND (lote_proceso = ? OR lote = ?)
        ''', [codCelda, loteProceso, loteProceso]);

        final double totalKilosAcumulados = (sumRes.first['total_kg'] as num?)?.toDouble() ?? 0.0;

        if (totalKilosAcumulados >= 4800.0) {
          await txn.update(
            'celdas_recepcion',
            {
              'estado': 'INACTIVO',
              'sincronizado': 0,
            },
            where: 'reg_local = ?',
            whereArgs: [regLocalCelda],
          );

          PaginaSincronizar.sincronizarRecepcion().catchError((e) {
          debugPrint("Sincronización de Recepción en cola (sin red): $e");
          return 0;
          });
        }
      });
      // Guardó en embolsado_bag en SQLite y luego:
      PaginaSincronizar.sincronizarBag().catchError((e) {
      debugPrint("Sincronización de Bag diferida: $e");
      return 0;
      });
      


      _mostrarToast("$bigBagCodigoFinal registrado ($tipoEnvaseCalculado)", tipo: 'exito');
      _limpiarFormularioCompleto();
      Navigator.pop(ctx);
      _cargarTodo();
    } catch (e) {
      _mostrarToast("Error al guardar: $e", tipo: 'error');
    }
  }
  
  void _limpiarFormularioCompleto() {
    setState(() {
      celdaPasivaSeleccionada = null;
      bigBagCodigoFinal = null;
      _numManualController.clear();
      _kilosController.clear();
    });
  }

  // MODAL FLOTANTE COMPLETO PARA NUEVO EMBOLSADO
  void _abrirModalNuevoEmbolsado() {
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
                            "REGISTRO DE PRODUCCIÓN",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: kColorAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            celdaPasivaSeleccionada != null
                                ? "Celda ${celdaPasivaSeleccionada!['cod_celda']}".toUpperCase()
                                : "Nuevo Llenado de Bolsón",
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
                          _limpiarFormularioCompleto();
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
                      // PASO 1: SELECCIONAR CELDA
                      _buildEtiquetaSeccion("1. SELECCIONAR MATERIA PRIMA (CELDAS EN PROCESO)"),
                      _buildSelectorCeldaOrigen(setModalState),
                      const SizedBox(height: 20),

                      if (celdaPasivaSeleccionada != null) ...[
                        // PASO 2: IDENTIFICADOR
                        _buildEtiquetaSeccion("2. IDENTIFICACIÓN DEL BOLSÓN"),
                        _buildBloqueIdentificadorBigBag(setModalState),
                        const SizedBox(height: 20),

                        // PASO 3: DATOS DE PESAJE
                        _buildEtiquetaSeccion("3. DATOS DE PESAJE"),
                        _buildCamposPesaje(),
                        const SizedBox(height: 26),

                        // BOTÓN GUARDAR
                        _buildBotonGuardarModal(context),
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
    final double totalKgDia = _calcularKilos(bolsonesDelDia);

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
                          "MÓDULO EMBOLSADO",
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kColorText,
                          ),
                        ),
                        Text(
                          "Producción y Llenado de Bolsones",
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
                  InkWell(
                    onTap: _cargarTodo,
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
      body: Column(
        children: [
          // PANEL SUPERIOR: Resumen y Solapas
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
                          "HOY: ${bolsonesDelDia.length} BOLSONES",
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
                        "${NumberFormat('#,##0', 'es_ES').format(totalKgDia)} KG HOY",
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
                      Tab(text: "PRODUCCIÓN DEL DÍA (${bolsonesDelDia.length})"),
                      Tab(text: "ARCHIVERO POR DÍAS (${historialAgrupadoPorDia.keys.length})"),
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
                      _buildSolapaDelDia(),
                      _buildSolapaArchiveroPorDias(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _limpiarFormularioCompleto();
          _abrirModalNuevoEmbolsado();
        },
        backgroundColor: kColorAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_box_rounded, size: 20),
        label: const Text(
          "NUEVO EMBOLSADO",
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

  // =========================================================================
  // SOLAPA 1: LISTADO DE PRODUCCIÓN DEL DÍA
  // =========================================================================
  Widget _buildSolapaDelDia() {
    if (bolsonesDelDia.isEmpty) {
      return _buildVacioMensaje("No hay bolsones registrados hoy", "Presiona 'NUEVO EMBOLSADO' para comenzar.");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarTodo,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: bolsonesDelDia.length,
        itemBuilder: (context, index) {
          final item = bolsonesDelDia[index];
          return _buildCardBolson(item);
        },
      ),
    );
  }

  // =========================================================================
  // SOLAPA 2: ARCHIVERO POR DÍAS (CARDS RESUMEN AGRUPADOS)
  // =========================================================================
  Widget _buildSolapaArchiveroPorDias() {
    final fechas = historialAgrupadoPorDia.keys.toList();
    if (fechas.isEmpty) {
      return _buildVacioMensaje("Archivero vacío", "Los registros históricos aparecerán aquí agrupados por fecha.");
    }

    return RefreshIndicator(
      color: kColorAccent,
      onRefresh: _cargarTodo,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: fechas.length,
        itemBuilder: (context, index) {
          final fecha = fechas[index];
          final items = historialAgrupadoPorDia[fecha] ?? [];
          final double kilosTotal = _calcularKilos(items);
          final int grandes = items.where((b) => (b['tipo_envase'] ?? '').toString().contains('GRANDE')).length;
          final int chicos = items.where((b) => (b['tipo_envase'] ?? '').toString().contains('CHICO')).length;

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
                onTap: () => _mostrarModalDetalleDia(fecha, items),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kColorAccentSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kColorAccent.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.folder_open_rounded, color: kColorAccentDark, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fecha,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kColorText),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${items.length} Bolsones procesados ($grandes Grandes • $chicos Chicos)",
                              style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${NumberFormat('#,##0', 'es_ES').format(kilosTotal)} KG",
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: kColorAccentDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text("Ver detalles >", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kColorAccent)),
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

  // --- TARJETA INDIVIDUAL DE BOLSÓN ---
  Widget _buildCardBolson(Map<String, dynamic> item) {
    final String kilosStr = item['kg']?.toString() ?? '0';
    final String tipoEnvase = item['tipo_envase']?.toString() ?? 'BIG BAG';

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
          onTap: () => _mostrarModalTrazabilidadDetallada(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kColorAccentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kColorAccent.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: kColorAccentDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              "${item['cod_bigbag']}".toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: kColorText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kColorBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Text(
                              "CELDA ${item['celda'] ?? 'S/C'}",
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kColorTextSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${item['productor'] ?? 'S/P'} • ${item['variedad'] ?? 'Nuez'} • Lote ${item['lote_proceso'] ?? item['lote'] ?? 'S/L'}",
                        style: const TextStyle(fontSize: 11.5, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: kColorTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            "${item['fecha']} • ${item['hora'] ?? ''}",
                            style: const TextStyle(fontSize: 10.5, color: kColorTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$kilosStr KG",
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: kColorAccentDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kColorBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Text(
                        tipoEnvase,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kColorTextSecondary),
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
  }

  // --- MODAL DE DETALLE POR DÍA (ARCHIVERO) ---
  void _mostrarModalDetalleDia(String fecha, List<Map<String, dynamic>> items) {
    final double totalKg = _calcularKilos(items);

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
                        "ARCHIVERO DIARIO DE PRODUCCIÓN",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5),
                      ),
                      Text(
                        fecha,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: kColorText),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kColorAccentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${NumberFormat('#,##0', 'es_ES').format(totalKg)} KG",
                      style: const TextStyle(fontWeight: FontWeight.w800, color: kColorAccentDark, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kColorBorder),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildCardBolson(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SELECTOR DE CELDAS CON BARRA DE LLENADO ACUMULADO ---
  Widget _buildSelectorCeldaOrigen(StateSetter setModalState) {
    if (celdasPasivasDisponibles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: kColorDanger, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "No hay celdas en estado PASIVO. Primero debés volcar una celda desde el módulo de Calidad.",
                style: TextStyle(color: kColorTextSecondary, fontWeight: FontWeight.w600, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: celdasPasivasDisponibles.map((celda) {
        final bool esIgual = celdaPasivaSeleccionada?['lote_proceso'] == celda['lote_proceso'];
        final double acumulado = (celda['kilos_acumulados'] as num?)?.toDouble() ?? 0;
        final double porcentaje = (acumulado / 5000).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: esIgual ? kColorAccentSoft : kColorSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: esIgual ? kColorAccent : kColorBorder),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setModalState(() {
                  celdaPasivaSeleccionada = celda;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          esIgual ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: esIgual ? kColorAccent : kColorTextSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CELDA ${celda['cod_celda']}".toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: kColorText),
                              ),
                              Text(
                                "Lote: ${celda['lote_proceso']} • Prod: ${celda['productor'] ?? 'S/P'}",
                                style: const TextStyle(fontSize: 11, color: kColorTextSecondary, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${acumulado.toStringAsFixed(0)} / 5000 KG",
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: kColorAccentDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        backgroundColor: kColorBg,
                        color: acumulado >= 4800 ? kColorDanger : kColorAccent,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBloqueIdentificadorBigBag(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      esIngresoManual = false;
                      bigBagCodigoFinal = null;
                    });
                    _abrirEscannerBigBag(setModalState);
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
                          Text(
                            "ESCANEAR QR",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: !esIngresoManual ? Colors.white : kColorText,
                            ),
                          ),
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
                      bigBagCodigoFinal = null;
                      _numManualController.clear();
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
                          Text(
                            "INGRESO MANUAL",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: esIngresoManual ? Colors.white : kColorText,
                            ),
                          ),
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
              controller: _numManualController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText),
              decoration: InputDecoration(
                labelText: "NÚMERO DE BOLSÓN",
                hintText: "Ej: 45",
                labelStyle: const TextStyle(fontSize: 12, color: kColorTextSecondary),
                filled: true,
                fillColor: kColorSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kColorBorder)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) => _procesarIngresoManual(val, setModalState),
            )
          else
            InkWell(
              onTap: () => _abrirEscannerBigBag(setModalState),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kColorSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: kColorAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "DISPARAR LECTOR DE CÁMARA",
                      style: TextStyle(fontWeight: FontWeight.w700, color: kColorAccentDark, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          if (bigBagCodigoFinal != null) ...[
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
                "CÓDIGO ASIGNADO: $bigBagCodigoFinal",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: kColorAccentDark, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCamposPesaje() {
    final String productor = celdaPasivaSeleccionada?['productor'] ?? 'S/P';
    final String variedad = celdaPasivaSeleccionada?['variedad'] ?? 'Nuez';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _kilosController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kColorText),
            decoration: InputDecoration(
              labelText: "KILOS NETOS *",
              hintText: "Ej: 1250",
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded, size: 14, color: kColorTextSecondary),
              const SizedBox(width: 6),
              Text(
                "Productor heredado: $productor ($variedad)",
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kColorTextSecondary),
              ),
            ],
          ),
        ],
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
        onPressed: () => _registrarEmbolsadoEnBD(ctx),
        child: const Text(
          "GUARDAR E INYECTAR BOLSÓN",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.4),
        ),
      ),
    );
  }

  // --- MODAL DE DETALLE Y TRAZABILIDAD ---
  void _mostrarModalTrazabilidadDetallada(Map<String, dynamic> item) {
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
                        "TRAZABILIDAD DE PRODUCCIÓN",
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 11, color: kColorAccent, letterSpacing: 0.5),
                      ),
                      Text(
                        "${item['cod_bigbag']}".toUpperCase(),
                        style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 19, color: kColorText),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kColorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRenglonDato("Kilogramos Netos", "${item['kg'] ?? '0'} KG", esDestacado: true),
                        const Divider(height: 14, color: kColorBorder),
                        _buildRenglonDato("Celda de Origen", item['celda']),
                        _buildRenglonDato("Lote de Proceso", item['lote_proceso'] ?? item['lote']),
                        _buildRenglonDato("Productor", item['productor']),
                        _buildRenglonDato("Especie / Variedad", "${item['especie'] ?? 'Nuez'} • ${item['variedad'] ?? 'S/V'}"),
                        _buildRenglonDato("Tipo de Envase", item['tipo_envase']),
                        _buildRenglonDato("Fecha Embolsado", item['fecha']),
                        _buildRenglonDato("Hora Registro", item['hora']),
                        _buildRenglonDato("Estado Logístico", item['estado']),
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
              fontSize: esDestacado ? 14 : 12.5,
              fontWeight: FontWeight.w700,
              color: esDestacado ? kColorAccentDark : kColorText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacioMensaje(String titulo, String subtitulo) {
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
                decoration: BoxDecoration(
                  color: kColorSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: kColorBorder),
                ),
                child: const Icon(Icons.shopping_bag_outlined, size: 40, color: kColorTextSecondary),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kColorText),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
              ),
            ],
          ),
        )
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