import 'utils/theme.dart';

import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'routes/routes.dart';

class DimeelprecioApp extends StatelessWidget {
  const DimeelprecioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dime el precio',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate],
      routes: getApplicationRoutes(),
      initialRoute: '/',
      theme: AppTheme.lightTheme,
    );
  }
}
