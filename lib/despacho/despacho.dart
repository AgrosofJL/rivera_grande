import 'package:flutter/material.dart';

class PaginaDespacho extends StatelessWidget { // Cambiar nombre según el archivo
  const PaginaDespacho({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text("MÓDULO EN DESARROLLO"),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.2,
              child: Image.asset('assets/logo_agrosoft.png', height: 150), 
            ),
            const SizedBox(height: 30),
            const Text(
              "Esta sección está lista para recibir lógica de negocio.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black45, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("VOLVER AL MENÚ"),
            )
          ],
        ),
      ),
    );
  }
}