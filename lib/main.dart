import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Importante para usar kIsWeb
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_datos.dart';
import 'logueo.dart';
import 'menu.dart';
import 'package:intl/date_symbol_data_local.dart';

// Importaciones para soportar sqflite en Web

import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  
  // ACA ES LO NUEVO: Configuración obligatoria para que sqflite funcione en Web
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Inicialización de Supabase
  await Supabase.initialize(
    url: 'https://izspbluodbxvaskelzjr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6c3BibHVvZGJ4dmFza2VsempyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3NTUxMzksImV4cCI6MjA5MzMzMTEzOX0.oP9Xlf2D6MSNLD8QzOJVG_-rppGBjN5lOREp40FZ5Xo',
  );

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MenuPrincipal();
        }
        return const PaginaLogeo();
      },
    );
  }
}