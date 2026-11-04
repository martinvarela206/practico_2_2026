# Que se hizo

## Main fundacional (drift y estructura)

- `flutter pub add drift drift_flutter path_provider`
- `flutter pub add -d drift_dev build_runner`

## Estructura de la base de datos
- Se creó la estructura de la base de datos con Drift, definiendo las tablas y relaciones necesarias para la aplicación.
- Se generaron los archivos necesarios para la base de datos utilizando `build_runner`.
- Se instalo el paquete `provider` para el manejo de MultiProvider y la gestión del estado de la aplicación.
    - `flutter pub add provider`

## CRUD Productos

- Desacoplador de la BBDD: `lib/src/database/database.dart`
- Manejador de productos: `lib/src/database/manejador_productos.dart`
- Generar la migración: `dart run build_runner build --delete-conflicting-outputs`
- Conectar el catalogo (`lib/src/pages/productos/productos_page.dart`) a la base de datos por medio del manejador (`_manejador.listar()`).
- Conectar el nuevo producto (`lib/src/pages/productos/nuevoproducto_page.dart`) a la base de datos por medio del manejador (`_manejador.agregar(...)`).
- Conectar la edición de producto (`lib/src/pages/productos/editarproducto_page.dart`) a la base de datos por medio del manejador (`Future<void> _guardarProducto()`).
- Añadir el provider al main para trabajar con una misma instancia de la base de datos.
- Usar el provider en nuevoproducto_page.dart, editarproducto_page.dart y producto_page.dart.

## Correcciones de Build y Entorno Android

### 1. Fijación de versión de NDK instalada
- **Motivo:** Gradle requería automáticamente NDK `28.2.13676358` (`Android sdkmanager did not install NDK...`), pero en el SDK local de Android la versión instalada era la `30.0.16138531`.
- **Archivo modificado:** `android/app/build.gradle.kts`
- **Valor original:** `ndkVersion = flutter.ndkVersion`
- **Nuevo valor:** `ndkVersion = "30.0.16138531"`

### 2. Desactivación de compilación incremental de Kotlin
- **Motivo:** En Windows, al estar el proyecto en un disco (`D:\`) diferente al SDK y caché de Pub (`C:\`), el daemon de Kotlin falla al calcular rutas relativas entre unidades distintas (`Could not close incremental caches ... class-fq-name-to-source.tab`).
- **Archivo modificado:** `android/gradle.properties`
- **Valor original:** *(No existía, por defecto Kotlin compila de forma incremental)*
- **Nuevo valor:** `kotlin.incremental=false`


## CRUD Pedidos
- Manejador de pedidos: `lib/src/database/manejador_pedidos.dart`

## Error al seleccionar clientes en pedidos

### Causa

Al crear o editar un pedido, `DropdownSearch` utiliza widgets de `material_ui` (incluido `InkResponse`) que buscan un ancestro `Material` de esa misma biblioteca. El `Scaffold` de la pantalla usa el `Material` de Flutter; aunque ambos tienen el mismo nombre y propósito, no satisfacen entre sí esa búsqueda. Por eso se producía la aserción `No Material widget found` al construir el selector de clientes. Además, el campo de búsqueda del menú requiere las localizaciones propias de `material_ui`, que no estaban registradas en la aplicación.

### Cambio realizado

Se envolvió el `DropdownSearch<Cliente>` de las pantallas de nuevo y edición de pedidos con `mui.Material`, y se registró `mui.DefaultMaterialLocalizations.delegate` en `MaterialApp` para el campo de búsqueda del menú. Así el selector y sus elementos interactivos tienen el ancestro y las localizaciones requeridas, manteniendo el comportamiento y la presentación existentes.

### Verificación

Se agregó una prueba de widget que verifica que el selector se construye y abre el menú sin lanzar la aserción. `flutter analyze` pasó. 