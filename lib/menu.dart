import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'base_datos.dart';
import 'package:intl/intl.dart';
import 'stock.dart';
import 'recepcion/ingresos.dart';
import 'celdas/celdas.dart';
import 'calidad/calidad.dart';
import 'llenado/embolsado.dart';
import 'volcado/volcado_bag.dart';
import 'bines/clasibin.dart';
import 'volcado/volcadobin.dart';
import 'despacho/movmateria.dart';
import 'despacho/despacho.dart';
import 'sincronizar.dart';

// TOKENS DE DISEÑO AGROSOFT - ESTILO "APPLE SOFT STUDIO" DE CAMPO.JS
const Color kColorBg = Color(0xFFF5F4F1);
const Color kColorSurface = Color(0xFFFFFFFF);
const Color kColorText = Color(0xFF211C16);
const Color kColorTextSecondary = Color(0xFF6B6255);
const Color kColorBorder = Color(0xFFE0DCD4);
const Color kColorPlant = Color(0xFF1E6B4C);
const Color kColorPlantDark = Color(0xFF123F2C);
const Color kColorPlantSoft = Color(0x1A1E6B4C); // 10%
const Color kColorDanger = Color(0xFFC0483C);

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  Map<String, dynamic>? usuario;
  String fechaActual = "";
  bool _isSyncing = false;

  // KPIs en vivo inspirados en el ecosistema territorial de campo.js
  int celdasActivas = 0;
  int bigBagsProcesados = 0;
  int binsArmados = 0;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _cargarKpisEnVivo();
    try {
      fechaActual = DateFormat("EEEE dd 'DE' MMMM 'DE' yyyy", 'es_ES')
          .format(DateTime.now())
          .toUpperCase();
    } catch (e) {
      fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.now());
    }
  }

  Future<void> _cargarUsuario() async {
    final datos = await DatabaseHelper().obtenerUsuarioLocal();
    if (mounted) setState(() => usuario = datos);
  }

  Future<void> _cargarKpisEnVivo() async {
    try {
      final db = await DatabaseHelper().database;
      final resCeldas = await db.query('celdas_recepcion', where: "estado = 'ACTIVO'");
      final resBags = await db.query('embolsado_bag');
      final resBins = await db.query('empaque_armado_bins');

      if (mounted) {
        setState(() {
          celdasActivas = resCeldas.length;
          bigBagsProcesados = resBags.length;
          binsArmados = resBins.length;
        });
      }
    } catch (e) {
      debugPrint("KPI error: $e");
    }
  }

  // ACA ES LO NUEVO: Notificación Toast flotante estilo Apple Soft (de campo.js)
  void _notificarApple({required String mensaje, required bool esExito}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 25, left: 20, right: 20),
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: esExito ? kColorPlant.withOpacity(0.35) : kColorDanger.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: esExito ? kColorPlantSoft : const Color(0x1AC0483C),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: esExito ? kColorPlant : kColorDanger,
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      esExito ? Icons.check_rounded : Icons.priority_high_rounded,
                      size: 16,
                      color: esExito ? kColorPlantDark : kColorDanger,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    mensaje,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kColorText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ACA ES LO NUEVO: Sincronización in-situ sin salir de la pantalla
  Future<void> _ejecutarSincronizacionDirecta() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final resultado = await PaginaSincronizar.sincronizarTodo(usuario: usuario?['operario']);

      if (mounted) {
        _notificarApple(
          mensaje: resultado,
          esExito: true,
        );
        _cargarKpisEnVivo();
      }
    } catch (e) {
      if (mounted) {
        _notificarApple(
          mensaje: "Fallo en sincronización: $e",
          esExito: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  bool _puedeVer(String modulo) {
    String rol = usuario?['rol'] ?? 'INVITADO';
    if (rol == 'ADM') return true;

    if (rol == 'ADM1') {
      List<String> permitidos = ['EMBOLSADO', 'CALIDAD', 'STOCK', 'RECEPCION', 'CELDAS'];
      return permitidos.contains(modulo);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final String nombreOperario = usuario?['operario'] ?? 'Operador';
    final String rolUsuario = usuario?['rol'] ?? 'GENERAL';
    final double anchoPantalla = MediaQuery.of(context).size.width;

    final int crossAxisCount = anchoPantalla > 900 ? 4 : (anchoPantalla > 600 ? 3 : 2);
    final double childAspectRatio = anchoPantalla > 600 ? 1.08 : 0.98;

    return Scaffold(
      backgroundColor: kColorBg,
      // CABECERA ESTILO APPLE SOFT CON AVATAR, FECHA Y BOTÓN SYNC
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kColorPlantSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kColorPlant.withOpacity(0.3), width: 1.2),
                    ),
                    child: Center(
                      child: Text(
                        nombreOperario.isNotEmpty ? nombreOperario[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: kColorPlantDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fechaActual,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 9.5,
                            color: kColorTextSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nombreOperario,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  color: kColorText,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                rolUsuario,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: kColorTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // BOTÓN SYNC: SIN REDIRECCIÓN, SINCRONIZACIÓN IN-SITU DIRECTA
                  InkWell(
                    onTap: _isSyncing ? null : _ejecutarSincronizacionDirecta,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: kColorPlantSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kColorPlant.withOpacity(0.35), width: 1.2),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kColorPlant),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_rounded, size: 16, color: kColorPlantDark),
                                SizedBox(width: 4),
                                Text(
                                  "SYNC",
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: kColorPlantDark,
                                    letterSpacing: 0.3,
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BARRA RESUMEN DE INDICADORES (FORMATO APPLE SOFT / CAMPO.JS)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kColorSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kColorBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiItem("CELDAS ACTIVAS", "$celdasActivas", Icons.grid_view_rounded),
                  Container(height: 24, width: 1, color: kColorBorder),
                  _buildKpiItem("BOLSONES", "$bigBagsProcesados", Icons.shopping_bag_outlined),
                  Container(height: 24, width: 1, color: kColorBorder),
                  _buildKpiItem("BINS", "$binsArmados", Icons.inventory_2_outlined),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // TÍTULO DE SECCIÓN
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                "MÓDULOS OPERATIVOS DE PLANTA",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: kColorTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // GRILLA DE MÓDULOS CON IMÁGENES AL 60% DE OPACIDAD
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                if (_puedeVer('STOCK'))
                  _buildMenuCard(
                    titulo: "Stock",
                    subtitulo: "Control y Existencias",
                    assetPath: "assets/stock.png",
                    iconoFallback: Icons.inventory_2_outlined,
                    colorBase: const Color(0xFFFF9500),
                    paginaDestino: const PaginaStock(),
                  ),
                if (_puedeVer('RECEPCION'))
                  _buildMenuCard(
                    titulo: "Recepción",
                    subtitulo: "Ingreso de Cosecha",
                    assetPath: "assets/recepcion.png",
                    iconoFallback: Icons.login_rounded,
                    colorBase: kColorPlant,
                    paginaDestino: const PaginaIngresos(),
                  ),
                if (_puedeVer('CELDAS'))
                  _buildMenuCard(
                    titulo: "Celdas",
                    subtitulo: "Distribución de Planta",
                    assetPath: "assets/celdas.png",
                    iconoFallback: Icons.grid_view_rounded,
                    colorBase: const Color(0xFF34C759),
                    paginaDestino: const PaginaCeldas(),
                  ),
                if (_puedeVer('CALIDAD'))
                  _buildMenuCard(
                    titulo: "Calidad",
                    subtitulo: "Inspección y Calibres",
                    assetPath: "assets/calidad.png",
                    iconoFallback: Icons.fact_check_outlined,
                    colorBase: const Color(0xFFAF52DE),
                    paginaDestino: const PaginaCalidad(),
                  ),
                if (_puedeVer('EMBOLSADO'))
                  _buildMenuCard(
                    titulo: "Embolsado",
                    subtitulo: "Llenado de Bolsones",
                    assetPath: "assets/embolsado.png",
                    iconoFallback: Icons.shopping_bag_outlined,
                    colorBase: const Color(0xFF00C7BE),
                    paginaDestino: const PaginaEmbolsado(),
                  ),
                if (_puedeVer('VOLCADO_BB'))
                  _buildMenuCard(
                    titulo: "Volcado BB",
                    subtitulo: "Vaciado de Big Bags",
                    assetPath: "assets/volcado_bb.png",
                    iconoFallback: Icons.layers_clear_outlined,
                    colorBase: const Color(0xFF5856D6),
                    paginaDestino: const PaginaVolcadoBag(),
                  ),
                if (_puedeVer('CLASIF_BINS'))
                  _buildMenuCard(
                    titulo: "Clasif. Bins",
                    subtitulo: "Llenado por Calibre",
                    assetPath: "assets/clasificacion.png",
                    iconoFallback: Icons.account_tree_outlined,
                    colorBase: const Color(0xFFFFB300),
                    paginaDestino: const PaginaClasibin(),
                  ),
                if (_puedeVer('VOLCADO_BINS'))
                  _buildMenuCard(
                    titulo: "Volcado Bins",
                    subtitulo: "Alimentación a Línea",
                    assetPath: "assets/volcado_bins.png",
                    iconoFallback: Icons.delete_sweep_outlined,
                    colorBase: const Color(0xFFFF3B30),
                    paginaDestino: const PaginaVolcadoBin(),
                  ),
                if (_puedeVer('MOVER'))
                  _buildMenuCard(
                    titulo: "Mover",
                    subtitulo: "Traspaso de Depósitos",
                    assetPath: "assets/mover.png",
                    iconoFallback: Icons.local_shipping_outlined,
                    colorBase: const Color(0xFF007AFF),
                    paginaDestino: const PaginaMovMateria(),
                  ),
                if (_puedeVer('DESPACHAR'))
                  _buildMenuCard(
                    titulo: "Despachar",
                    subtitulo: "Salidas y Logística",
                    assetPath: "assets/despachar.png",
                    iconoFallback: Icons.local_post_office_outlined,
                    colorBase: const Color(0xFFFF2D55),
                    paginaDestino: const PaginaDespacho(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(String etiqueta, String valor, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: kColorPlant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 8.5, fontWeight: FontWeight.w700, color: kColorTextSecondary),
            ),
            Text(
              valor,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w900, color: kColorPlantDark),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // TARJETA DE MENÚ CON IMAGEN DE FONDO AL 60% DE OPACIDAD (APPLE SOFT)
  // =========================================================================
  Widget _buildMenuCard({
    required String titulo,
    required String subtitulo,
    required String assetPath,
    required IconData iconoFallback,
    required Color colorBase,
    required Widget paginaDestino,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // IMAGEN AL 60% DE OPACIDAD
            Positioned.fill(
              child: Opacity(
                opacity: 0.60,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colorBase.withOpacity(0.06),
                      child: Icon(iconoFallback, size: 42, color: colorBase.withOpacity(0.25)),
                    );
                  },
                ),
              ),
            ),

            // DEGRADÉ TRASLÚCIDO ESTILO APPLE SOFT
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.50, 1.0],
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.70),
                      Colors.white.withOpacity(0.96),
                    ],
                  ),
                ),
              ),
            ),

            // CONTENIDO Y NAVEGACIÓN
            Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: colorBase.withOpacity(0.12),
                highlightColor: colorBase.withOpacity(0.05),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => paginaDestino),
                ).then((_) => _cargarKpisEnVivo()),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colorBase.withOpacity(0.25), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(iconoFallback, color: colorBase, size: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: kColorTextSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),

                      // ETIQUETA INFERIOR CONTRASTADA
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kColorBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: kColorText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: kColorTextSecondary,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}