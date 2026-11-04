import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/manejador_clientes.dart';
import '../../database/manejador_pedidos.dart';
import '../../models/pedido.dart';
import '../../utils/responsive.dart';

class DetallePedidoPage extends StatefulWidget {
  final Pedido pedido;

  const DetallePedidoPage({super.key, required this.pedido});

  @override
  State<DetallePedidoPage> createState() => _DetallePedidoPageState();
}

class _DetallePedidoPageState extends State<DetallePedidoPage> {
  late Pedido _pedidoActual;
  late final Stream<List<Pedido>> _pedidosStream;

  @override
  void initState() {
    super.initState();
    _pedidoActual = widget.pedido;
    _pedidosStream = context.read<ManejadorPedidos>().listar();
  }

  // Botón para registrar pagos (totales o parciales)
  Future<void> _registrarPago() async {
    final TextEditingController pagoController = TextEditingController();

    // Por comodidad, pre-llenamos el campo con la deuda restante
    pagoController.text = _pedidoActual.diferencia.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resta pagar: \$${_pedidoActual.diferencia.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pagoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto a ingresar',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Capturamos y limpiamos el monto
              final montoIngresado =
                  double.tryParse(pagoController.text.replaceAll(',', '.')) ??
                  0.0;

              // Validaciones de negocio
              if (montoIngresado <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un monto válido mayor a 0'),
                  ),
                );
                return;
              }

              if (montoIngresado > _pedidoActual.diferencia) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El monto no puede superar la deuda actual'),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              final nuevaSena = _pedidoActual.sena + montoIngresado;
              final pedidoActualizado = Pedido(
                id: _pedidoActual.id,
                idCliente: _pedidoActual.idCliente,
                nombreCliente: _pedidoActual.nombreCliente,
                items: _pedidoActual.items,
                imagen: _pedidoActual.imagen,
                sena: nuevaSena,
                fechaEntrega: _pedidoActual.fechaEntrega,
                fechaEncargo: _pedidoActual.fechaEncargo,
                pagoRealizado: _pedidoActual.total - nuevaSena <= 0,
              );
              try {
                final actualizado = await context
                    .read<ManejadorPedidos>()
                    .actualizar(pedidoActualizado);
                if (!mounted) return;
                if (!actualizado) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se encontró el pedido para actualizar'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pago registrado con éxito',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo registrar el pago: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }

  // Eliminar Pedido
  Future<void> _confirmarEliminacion() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Pedido'),
          ],
        ),
        content: const Text('¿Eliminar este pedido permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // cierra el alerta
              try {
                final eliminados = await context
                    .read<ManejadorPedidos>()
                    .eliminar(_pedidoActual.id ?? '');
                if (!mounted) return;
                if (eliminados == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se encontró el pedido para eliminar'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo eliminar el pedido: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // WhatsApp
  Future<void> _enviarWhatsApp() async {
    try {
      final clientes = await context.read<ManejadorClientes>().listar().first;
      final cliente = clientes
          .where((cliente) => cliente.id == _pedidoActual.idCliente)
          .firstOrNull;
      if (cliente == null || cliente.telefono.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró el teléfono del cliente')),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln(
        'Hola *${_pedidoActual.nombreCliente}*, te confirmo los detalles de tu pedido:\n',
      );

      for (var item in _pedidoActual.items) {
        buffer.writeln('▪️ ${item.cantidad}x ${item.nombreProducto}');
      }

      final String fechaE =
          '${_pedidoActual.fechaEntrega.day}/${_pedidoActual.fechaEntrega.month}/${_pedidoActual.fechaEntrega.year}';
      buffer.writeln('\n📅 *Fecha de entrega acordada:* $fechaE');
      buffer.writeln('💰 *Total:* \$${_pedidoActual.total.toStringAsFixed(2)}');

      if (_pedidoActual.diferencia > 0) {
        buffer.writeln(
          '⚠️ *Resta abonar:* \$${_pedidoActual.diferencia.toStringAsFixed(2)}',
        );
      } else {
        buffer.writeln('✅ *Estado:* Totalmente abonado.');
      }

      String numeroLimpio = cliente.telefono.replaceAll(RegExp(r'[^0-9]'), '');
      if (!numeroLimpio.startsWith('54')) numeroLimpio = '549$numeroLimpio';

      final Uri url = Uri.parse(
        'https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(buffer.toString())}',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
        );
      }
    }
  }

  // Visualizador de Imagen a Pantalla Completa
  void _verImagenCompleta() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              // Permite hacer zoom pellizcando
              panEnabled: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.5,
              maxScale: 3,
              child: Image.file(File(_pedidoActual.imagen)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    return StreamBuilder<List<Pedido>>(
      stream: _pedidosStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Pedido')),
            body: Center(child: Text('Error al cargar el pedido: ${snapshot.error}')),
          );
        }
        if (snapshot.hasData) {
          final pedidoEnDb = snapshot.data!
              .where((pedido) => pedido.id == widget.pedido.id)
              .firstOrNull;
          if (pedidoEnDb == null) {
            return const Scaffold(
              body: Center(child: Text('Este pedido ya no existe')),
            );
          }
          _pedidoActual = pedidoEnDb;
        }

        final String fechaEncargo =
            '${_pedidoActual.fechaEncargo.day}/${_pedidoActual.fechaEncargo.month}/${_pedidoActual.fechaEncargo.year}';
        final String fechaEntrega =
            '${_pedidoActual.fechaEntrega.day}/${_pedidoActual.fechaEntrega.month}/${_pedidoActual.fechaEntrega.year}';
        final bool estaPagado =
            _pedidoActual.pagoRealizado || _pedidoActual.diferencia <= 0;

        return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Pedido'),
        actions: DateTime.now().isBefore(_pedidoActual.fechaEntrega)
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/editar_pedido',
                      arguments: _pedidoActual,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: _confirmarEliminacion,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _cabecera(responsive, theme, fechaEntrega, fechaEncargo),
                    _listaItems(responsive, theme),
                  ],
                ),
              ),
            ),
            _footer(responsive, theme, estaPagado),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _cabecera(
    Responsive responsive,
    ThemeData theme,
    String fechaEntrega,
    String fechaEncargo,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.wp(5)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente',
                    style: TextStyle(
                      fontSize: responsive.dp(1.4),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _pedidoActual.nombreCliente,
                    style: TextStyle(
                      fontSize: responsive.dp(2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_pedidoActual.imagen.isNotEmpty)
                InkWell(
                  onTap: _verImagenCompleta,
                  child: Container(
                    width: responsive.dp(6),
                    height: responsive.dp(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(_pedidoActual.imagen)),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: responsive.hp(2)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Encargado: $fechaEncargo',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Entrega: $fechaEntrega',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaItems(Responsive responsive, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(responsive.wp(4)),
      itemCount: _pedidoActual.items.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final item = _pedidoActual.items[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text('${item.cantidad}'),
          ),
          title: Text(
            item.nombreProducto,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('\$${item.precioUnitario.toStringAsFixed(2)} c/u'),
          trailing: Text(
            '\$${item.subtotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: responsive.dp(1.8),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(Responsive responsive, ThemeData theme, bool estaPagado) {
    return Container(
      padding: EdgeInsets.all(responsive.wp(5)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _total(responsive, theme),
          const SizedBox(height: 4),
          _senia(responsive, theme),
          const Divider(),
          _pagado(responsive, theme, estaPagado),
          SizedBox(height: responsive.hp(2)),
          _acciones(responsive, theme, estaPagado),
        ],
      ),
    );
  }

  Widget _total(Responsive responsive, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Total:', style: TextStyle(fontSize: 16)),
        Text(
          '\$${_pedidoActual.total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _senia(Responsive responsive, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Seña abonada:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          '\$${_pedidoActual.sena.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _pagado(Responsive responsive, ThemeData theme, bool estaPagado) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          estaPagado ? 'ESTADO:' : 'RESTA PAGAR:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: estaPagado ? Colors.green : Colors.orange.shade700,
          ),
        ),
        Text(
          estaPagado
              ? 'PAGADO'
              : '\$${_pedidoActual.diferencia.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: estaPagado ? Colors.green : Colors.orange.shade700,
          ),
        ),
      ],
    );
  }

  Widget _acciones(Responsive responsive, ThemeData theme, bool estaPagado) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
              foregroundColor: Colors.green,
            ),
            onPressed: _enviarWhatsApp,
            child: const Icon(Icons.wechat_rounded),
          ),
        ),
        if (!estaPagado) ...[
          SizedBox(width: responsive.wp(3)),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text(
                'Registrar Pago',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _registrarPago,
            ),
          ),
        ],
      ],
    );
  }
}
