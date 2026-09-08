import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_datos.dart'; 
import 'menu.dart';

class PaginaLogeo extends StatefulWidget {
  const PaginaLogeo({super.key});
  @override
  State<PaginaLogeo> createState() => _PaginaLogeoState();
}

class _PaginaLogeoState extends State<PaginaLogeo> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _verificarSesionLocal();
  }

  Future<void> _verificarSesionLocal() async {
    final usuario = await DatabaseHelper().obtenerUsuarioLocal();
    if (usuario != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuPrincipal()));
    }
  }

  Future<String> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id.trim(); 
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor?.trim() ?? 'UNKNOWN_IOS';
      }
    } catch (e) { 
      return 'ERROR_ID'; 
    }
    return 'UNKNOWN_PLATFORM';
  }

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _mostrarError("Por favor, completá todos los campos.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      String idHardware = await _getDeviceId();

      // Consulta relacional exacta contra tu tabla remota 'usuarios'
      final res = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('correo', _emailController.text.trim())
          .eq('pass', _passwordController.text.trim()) 
          .eq('device', idHardware) 
          .maybeSingle();

      if (res != null) {
        // Validación de Licencia Corporativa
        if (res['licencia'] != null && res['licencia'].toString().toUpperCase() != 'ACTIVA') {
           throw 'Licencia inactiva. Contactar soporte de AgroSoft J&L.';
        }

        // Persistencia relacional en la base de datos SQLite local
        await DatabaseHelper().guardarUsuario({
          'id': res['id'],
          'correo': res['correo'],
          'operario': res['operario'],
          'establecimiento': 'LA RIVERA', 
          'clave': _passwordController.text.trim(),
          'device_id': idHardware,
          'rol': res['rol']
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged', true);

        // CORREGIDO: Llamado al nuevo método espejo optimizado en el DatabaseHelper
        await DatabaseHelper().descargarTodoDesdeSupabase(); 

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuPrincipal()));
        }
      } else {
        _mostrarDialogoHabilitacion(idHardware, titulo: "Acceso Denegado");
      }
    } catch (e) {
      _mostrarError("$e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // Fondo limpio estilo iOS
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 35.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 25),
                const Text(
                  "LA RIVERA", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.black87)
                ),
                const Text(
                  "TRAZABILIDAD DE NUEZ", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 0.8)
                ),
                const SizedBox(height: 45),
                
                _buildSoftTextField(
                  controller: _emailController, 
                  hintText: "Correo Usuario", 
                  icon: Icons.person_search_rounded
                ),
                const SizedBox(height: 16),
                _buildSoftTextField(
                  controller: _passwordController, 
                  hintText: "Contraseña", 
                  icon: Icons.lock_open_rounded, 
                  isPassword: true, 
                  obscureText: _obscurePassword,
                  onSuffixIconPressed: () => setState(() => _obscurePassword = !_obscurePassword)
                ),
                const SizedBox(height: 35),
                
                _isLoading 
                    ? const CircularProgressIndicator(color: Colors.blueAccent) 
                    : _buildBotonIngresar(),
                    
                const SizedBox(height: 25),
                TextButton.icon(
                  onPressed: () async => _mostrarDialogoHabilitacion(await _getDeviceId()), 
                  icon: const Icon(Icons.important_devices_rounded, size: 16, color: Colors.blueGrey),
                  label: const Text("Ver ID del equipo", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 13))
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DISEÑO DE LOGO INDUSTRIAL ---
  Widget _buildLogo() {
    return Container(
      height: 110, width: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.06), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset(
          'assets/logo_agrosoft.png',
          fit: BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) {
            // Fallback elegante si la imagen no se encuentra mapeada en los assets
            return const Icon(Icons.eco_rounded, size: 55, color: Colors.blueAccent);
          },
        ),
      ),
    );
  }

  Widget _buildBotonIngresar() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25), 
            blurRadius: 15, 
            offset: const Offset(0, 6)
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _iniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent, 
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: const Text("INICIAR SESIÓN ASISTIDA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildSoftTextField({
    required TextEditingController controller, 
    required String hintText, 
    required IconData icon, 
    bool isPassword = false, 
    bool obscureText = false, 
    VoidCallback? onSuffixIconPressed
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18), 
        border: Border.all(color: Colors.black.withOpacity(0.03), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black26, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.black38, size: 20), 
                  onPressed: onSuffixIconPressed
                ) 
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  void _mostrarDialogoHabilitacion(String id, {String titulo = "ID Hardware Requerido"}) {
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Este dispositivo requiere autorización. Copiá el código único de vinculación y envialo al administrador:",
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black12)
              ),
              child: SelectableText(
                id, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 16, letterSpacing: 0.5)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent))
          )
        ],
      )
    );
  }

  void _mostrarError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.redAccent, 
        behavior: SnackBarBehavior.floating, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
      )
    );
  }
}