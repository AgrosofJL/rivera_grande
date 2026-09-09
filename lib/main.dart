import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'base_datos.dart';
import 'logueo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sqlite3WasmUri: Uri.parse('sqlite3.wasm'),
        sharedWorkerUri: Uri.parse('sqflite_sw.js'),
      ),
    );
  }

  await initializeDateFormatting('es_ES', null);

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
      home: const PaginaLogeo(),
    );
  }
}