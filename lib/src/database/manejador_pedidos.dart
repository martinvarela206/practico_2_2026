import 'package:drift/drift.dart';

import '../models/itemproducto.dart' as modelo;
import '../models/pedido.dart' as modelo;
import 'database.dart' hide Pedido;

class ManejadorPedidos {
  final AppDatabase db;

  ManejadorPedidos(this.db);

  Stream<List<modelo.Pedido>> listar() {
    return db.select(db.pedidos).watch().asyncMap((filas) async {
      if (filas.isEmpty) return <modelo.Pedido>[];

      final ids = filas.map((fila) => fila.id).toList();
      final filasItems = await (db.select(
        db.itemsPedido,
      )..where((item) => item.idPedido.isIn(ids))).get();
      final itemsPorPedido = <int, List<modelo.ItemProducto>>{};

      for (final item in filasItems) {
        itemsPorPedido
            .putIfAbsent(item.idPedido, () => [])
            .add(
              modelo.ItemProducto(
                idProducto: item.idProducto.toString(),
                nombreProducto: item.nombreProducto,
                precioUnitario: item.precioUnitario,
                cantidad: item.cantidad,
              ),
            );
      }

      return filas
          .map(
            (fila) => modelo.Pedido(
              id: fila.id.toString(),
              idCliente: fila.idCliente.toString(),
              nombreCliente: fila.nombreCliente,
              items: itemsPorPedido[fila.id] ?? [],
              imagen: fila.imagen,
              sena: fila.sena,
              fechaEntrega: fila.fechaEntrega,
              fechaEncargo: fila.fechaEncargo,
              pagoRealizado: fila.pagoRealizado,
            ),
          )
          .toList();
    });
  }

  Future<int> agregar(modelo.Pedido pedido) {
    final idCliente = int.tryParse(pedido.idCliente);
    if (idCliente == null) {
      throw ArgumentError.value(pedido.idCliente, 'idCliente');
    }

    return db.transaction(() async {
      final idPedido = await db
          .into(db.pedidos)
          .insert(
            PedidosCompanion.insert(
              idCliente: idCliente,
              nombreCliente: pedido.nombreCliente,
              imagen: pedido.imagen,
              sena: pedido.sena,
              fechaEntrega: pedido.fechaEntrega,
              fechaEncargo: pedido.fechaEncargo,
              pagoRealizado: pedido.pagoRealizado,
            ),
          );
      await _insertarItems(idPedido, pedido.items);
      return idPedido;
    });
  }

  Future<bool> actualizar(modelo.Pedido pedido) {
    final idPedido = int.tryParse(pedido.id ?? '');
    if (idPedido == null) return Future.value(false);

    final idCliente = int.tryParse(pedido.idCliente);
    if (idCliente == null) {
      throw ArgumentError.value(pedido.idCliente, 'idCliente');
    }

    return db.transaction(() async {
      final actualizado = await db
          .update(db.pedidos)
          .replace(
            PedidosCompanion(
              id: Value(idPedido),
              idCliente: Value(idCliente),
              nombreCliente: Value(pedido.nombreCliente),
              imagen: Value(pedido.imagen),
              sena: Value(pedido.sena),
              fechaEntrega: Value(pedido.fechaEntrega),
              fechaEncargo: Value(pedido.fechaEncargo),
              pagoRealizado: Value(pedido.pagoRealizado),
            ),
          );
      if (!actualizado) return false;

      await (db.delete(
        db.itemsPedido,
      )..where((item) => item.idPedido.equals(idPedido))).go();
      await _insertarItems(idPedido, pedido.items);
      return true;
    });
  }

  Future<int> eliminar(String id) {
    final idPedido = int.tryParse(id);
    if (idPedido == null) return Future.value(0);

    return db.transaction(() async {
      await (db.delete(
        db.itemsPedido,
      )..where((item) => item.idPedido.equals(idPedido))).go();
      return (db.delete(
        db.pedidos,
      )..where((pedido) => pedido.id.equals(idPedido))).go();
    });
  }

  Future<void> _insertarItems(
    int idPedido,
    List<modelo.ItemProducto> items,
  ) async {
    if (items.isEmpty) return;

    final companions = items.map((item) {
      final idProducto = int.tryParse(item.idProducto);
      if (idProducto == null) {
        throw ArgumentError.value(item.idProducto, 'idProducto');
      }

      return ItemsPedidoCompanion.insert(
        idPedido: idPedido,
        idProducto: idProducto,
        nombreProducto: item.nombreProducto,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidad,
      );
    }).toList();

    await db.batch((batch) {
      batch.insertAll(db.itemsPedido, companions);
    });
  }
}
