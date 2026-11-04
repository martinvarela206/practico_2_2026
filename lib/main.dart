import 'package:flutter/material.dart';
import 'package:practico_2/src/database/manejador_pedidos.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/database/database.dart';
import 'src/database/manejador_clientes.dart';
import 'src/database/manejador_productos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (context) => AppDatabase(),
          dispose: (context, db) => db.close(),
        ),
        ProxyProvider<AppDatabase, ManejadorClientes>(
          update: (context, db, previous) => previous ?? ManejadorClientes(db),
        ),
        // Inyección del manejador de productos conectado a la base compartida:
        ProxyProvider<AppDatabase, ManejadorProductos>(
          update: (context, db, previous) => previous ?? ManejadorProductos(db),
        ),
        ProxyProvider<AppDatabase, ManejadorPedidos>(
          update: (context, db, previous) => previous ?? ManejadorPedidos(db),
        ),
      ],
      child: const DimeelprecioApp(),
    ),
  );
}
