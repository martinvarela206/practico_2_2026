import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;

void main() {
  testWidgets('el selector de clientes se construye y abre su menú', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: Scaffold(
          body: mui.Material(
            child: DropdownSearch<String>(
              items: (filter, loadProps) => const ['Cliente'],
              popupProps: PopupProps.menu(showSearchBox: true),
              decoratorProps: DropDownDecoratorProps(
                decoration: const mui.InputDecoration(labelText: 'Cliente'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Cliente'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
