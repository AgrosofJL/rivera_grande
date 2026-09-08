import 'package:flutter/material.dart';
import 'base_datos.dart';
import 'package:intl/intl.dart';
import 'logueo.dart';
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
import 'dart:async';
import 'sincronizar.dart';

// =========================================================================
// TOKENS DE DISEÑO AGROSOFT INDUSTRIAL (ESTILO APPLE SOFT)
// =========================================================================
const Color kColorBg = Color(0xFFF4F6F2);
const Color kColorSurface = Color(0xFFFFFFFF);
const Color kColorText = Color(0xFF1B231D);
const Color kColorTextSecondary = Color(0xFF5F6B62);
const Color kColorAccent = Color(0xFF1E6B4C);
const Color kColorAccentDark = Color(0xFF123F2C);
const Color kColorAccentSoft = Color(0x1A1E6B4C); // 10%
const Color kColorDanger = Color(0xFFC0483C);
const Color kColorDangerSoft = Color(0x1FC0483C);
const Color kColorBorder = Color(0x1F1B231D); // 12%

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  Map<String, dynamic>? usuario;
  String fechaActual = "";
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
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

  // ESTO LO MODIFIQUE: Sincronización completa con notificación flotante estilizada
  Future<void> _sincronizarTodo() async {
    setState(() => _isSyncing = true);
    try {
      final resultado = await PaginaSincronizar.sincronizarTodo(usuario: usuario?['operario']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resultado,
                    style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: kColorAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Error de sincronización: $e",
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: kColorDanger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
          ),
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

    // ACA ES LO NUEVO: Grid responsivo (2 columnas en móviles, 3 o 4 columnas en tablets industriales)
    final int crossAxisCount = anchoPantalla > 900 ? 4 : (anchoPantalla > 600 ? 3 : 2);
    final double childAspectRatio = anchoPantalla > 600 ? 1.05 : 0.96;

    return Scaffold(
      backgroundColor: kColorBg,
      // CABECERA SUPERIOR INDUSTRIAL AGROSOFT
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: const BoxDecoration(
            color: kColorSurface,
            border: Border(bottom: BorderSide(color: kColorBorder, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
              child: Row(
                children: [
                  // Logo / Avatar de Operador
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kColorAccentSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kColorAccent.withOpacity(0.25)),
                    ),
                    child: Center(
                      child: Text(
                        nombreOperario.isNotEmpty ? nombreOperario[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: kColorAccentDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Información del Operario y Fecha
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fechaActual,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10,
                            color: kColorTextSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: kColorBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kColorBorder),
                              ),
                              child: Text(
                                rolUsuario,
                                style: const TextStyle(
                                  fontSize: 9.5,
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

                  // Botón de Sync Superior Derecho
                  InkWell(
                    onTap: _isSyncing ? null : _sincronizarTodo,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kColorAccentSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kColorAccent.withOpacity(0.35)),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: kColorAccent),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_rounded, size: 17, color: kColorAccentDark),
                                SizedBox(width: 5),
                                Text(
                                  "SYNC",
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: kColorAccentDark,
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
      body: GridView.count(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
        physics: const BouncingScrollPhysics(),
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
              colorBase: kColorAccent,
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
    );
  }

  // =========================================================================
  // TARJETA INDUSTRIAL CON IMAGEN FULL-BLEED AL 60% DE OPACIDAD
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kColorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 1. IMAGEN DE FONDO: Ocupa todo el alto y ancho con 60% de opacidad
            Positioned.fill(
              child: Opacity(
                opacity: 0.60,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colorBase.withOpacity(0.08),
                      child: Icon(iconoFallback, size: 48, color: colorBase.withOpacity(0.3)),
                    );
                  },
                ),
              ),
            ),

            // 2. FILTRO DEGRADÉ SUAVE: Garantiza contraste y estética Apple Soft
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      Colors.white.withOpacity(0.20),
                      Colors.white.withOpacity(0.65),
                      Colors.white.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ),

            // 3. CAPA INTERACTIVA Y CONTENIDO
            Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: colorBase.withOpacity(0.15),
                highlightColor: colorBase.withOpacity(0.06),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => paginaDestino),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cabecera: Icono identificador + Flecha
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorBase.withOpacity(0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(iconoFallback, color: colorBase, size: 20),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: kColorTextSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),

                      // Textos inferiores destacados
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kColorBorder.withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
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
                                fontSize: 14.5,
                                color: kColorText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
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