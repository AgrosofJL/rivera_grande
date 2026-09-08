import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_datos.dart';
import 'logueo.dart';
import 'menu.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await initializeDateFormatting('es_ES', null);
  
  try {
    await Supabase.initialize(
      url: 'https://izspbluodbxvaskelzjr.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6c3BibHVvZGJ4dmFza2VsempyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3NTUxMzksImV4cCI6MjA5MzMzMTEzOX0.oP9Xlf2D6MSNLD8QzOJVG_-rppGBjN5lOREp40FZ5Xo',
    );
  } catch (e) {
    debugPrint("Error al iniciar Supabase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Rivera - Celdas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        fontFamily: 'Roboto',
      ),
      home: const VerificadorSesion(),
    );
  }
}

class VerificadorSesion extends StatelessWidget {
  const VerificadorSesion({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DatabaseHelper().obtenerUsuarioLocal(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF3F5F1),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6B4C)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MenuPrincipal();
        }
        return const PaginaLogeo();
      },
    );
  }
}