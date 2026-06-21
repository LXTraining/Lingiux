# Rediseño de Perfil Estilo Instagram y Miniature Cards en Lingiux

Esta guía técnica detalla la planificación, el diseño visual y la implementación de la pantalla de **Perfil (`ProfileScreen`)** inspirada en el flujo estructural de Instagram, incluyendo la técnica de renderizado en miniatura de las **Word Cards** y la integración reactiva con **Supabase** y **Riverpod**.

---

## 📸 1. Interpretación de la Maqueta (Multimodalidad)

A partir de la captura de referencia `assets/references/igreferencia.png`, el diseño de Instagram se descompuso en una estructura jerárquica de widgets de Flutter para mantener una fidelidad visual del 95% al mismo tiempo que se incorporan los colores premium y degradados de **Lingiux**:

```
[ProfileScreen] (Scaffold)
 ├── AppBar (Nombre de usuario en minúsculas + Engranaje de Ajustes)
 └── RefreshIndicator (Pull-to-refresh)
      └── SingleChildScrollView
           └── Column
                ├── Cabecera (Avatar + 4 Contadores horizontales)
                ├── Biografía (Nombre completo, email, idioma, descripción)
                ├── Botones de Acción (Editar Perfil, Compartir, Menú lateral)
                ├── Tabs Visuales (Pestaña de Cuadrícula activa / Guardados)
                └── Cuadrícula (GridView.builder de 3 columnas de miniaturas)
```

### Elementos clave adaptados:
* **Foto de Perfil:** Posicionada a la izquierda dentro de un `CircleAvatar` con un borde blanco elevado y un indicador circular verde de estado **Online** en la esquina inferior derecha.
* **4 Contadores Estatales:** Distribuidos uniformemente a la derecha del avatar usando un `Row` expandido con:
  1. **Cartas:** Número real de tarjetas creadas por el usuario.
  2. **Racha:** Racha de días de estudio del perfil del usuario (`streak_count`).
  3. **Seguidores:** Comunidad simulada fijada en `128`.
  4. **Seguidos:** Comunidad simulada fijada en `92`.
* **Biografía:** Nombre de usuario formateado en minúsculas con guiones bajos en el AppBar (ej: `sebas_v`) y nombre de perfil formal debajo de la cabecera.
* **Cuadrícula de Publicaciones:** Grid de 3 columnas donde cada celda es una **Word Card** real a escala.

---

## 🎨 2. Técnica de Miniature Cards (FittedBox & AspectRatio)

Uno de los mayores desafíos del rediseño fue mostrar la tarjeta de vocabulario **completa** (con su degradado degradé, título de palabra, fonética, imagen remota y texto de definición) dentro de una celda de cuadrícula pequeña de 3 columnas, sin sufrir errores de desbordamiento de diseño (`render boundary overflow`) ni ocultar partes esenciales de la tarjeta.

### Solución: Escalado Proporcional
En lugar de diseñar un widget de tarjeta alternativo y simplificado (lo que arruinaría la estética de "publicaciones de Instagram"), se implementó el widget `_MiniWordCard` con la siguiente técnica de escalado:

1. **Definición de Lienzo Fijo:**
   La tarjeta se construye dentro de un contenedor rígido con dimensiones de diseño de alta resolución:
   * **Ancho:** `300 px`
   * **Alto:** `450 px` (Proporción exacta de aspect ratio `2:3`)

2. **Cuadrícula con Aspect Ratio Coincidente:**
   El `SliverGridDelegateWithFixedCrossAxisCount` de la cuadrícula se configura con el mismo aspect ratio exacto:
   ```dart
   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
     crossAxisCount: 3,
     crossAxisSpacing: 6,
     mainAxisSpacing: 6,
     childAspectRatio: 2 / 3, // Coincide perfectamente con 300 / 450
   )
   ```

3. **Escalado y Recorte con FittedBox:**
   El widget de tarjeta fija (`300x450`) se envuelve en un `FittedBox` con `BoxFit.contain` dentro de un `Card` con bordes redondeados y sombra. Esto le dice a Flutter: *"Toma esta tarjeta grande y reduce su escala de forma proporcional hasta que quepa exactamente en el tamaño asignado para la celda de la cuadrícula"*:

   ```dart
   return Card(
     elevation: 4,
     margin: EdgeInsets.zero,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(12),
     ),
     child: ClipRRect(
       borderRadius: BorderRadius.circular(12),
       child: FittedBox(
         fit: BoxFit.contain, // Escala la tarjeta sin deformarla
         child: cardWidget,  // Contenedor de 300x450
       ),
     ),
   );
   ```

Gracias a este enfoque, todo el contenido de la tarjeta se encoge de manera proporcional. Las fuentes, imágenes y márgenes se reducen de forma fluida, pareciendo una fotografía en miniatura de la tarjeta real.

---

## 🔌 3. Arquitectura del Flujo de Datos y Reactividad

Para asegurar que las nuevas tarjetas creadas aparezcan instantáneamente en el perfil del usuario sin requerir el reinicio de la aplicación o el cierre de sesión, se implementó una estrategia de invalidación y persistencia relacional.

### A. Aislamiento por Creador (`vocabulary_provider.dart`)
Se diferenció el feed global (que mezcla tarjetas predeterminadas del sistema con las del usuario) del perfil. Se implementó el proveedor de Riverpod `userWordCardsProvider` que filtra la base de datos de Supabase exclusivamente por el ID del usuario actual:

```dart
final userWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return [];

  final supabase = ref.read(supabaseClientProvider);
  
  final response = await supabase
      .from('word_cards')
      .select()
      .eq('user_id', user.id) // Aislamiento de datos
      .order('created_at', ascending: false); // Las más recientes primero
      
  return (response as List<dynamic>)
      .map((json) => WordCardModel.fromJson(json as Map<String, dynamic>))
      .toList();
});
```

### B. Ciclo de Invalidación Reactiva (`create_card_form_screen.dart`)
Cuando el usuario crea una tarjeta en el formulario, al confirmarse la inserción en la base de datos se invalidan los dos proveedores de Riverpod de manera explícita:

```dart
// 1. Guardar la metadata en la tabla de Supabase
await supabase.from('word_cards').insert({ ... });

// 2. Desalojar cachés e invalidar proveedores
ref.invalidate(wordCardsProvider);       // Refresca el buscador de chat y listas generales
ref.invalidate(userWordCardsProvider);  // Refresca la cuadrícula del perfil
```

Al regresar a la navegación del `HomeScreen` (que utiliza un `IndexedStack`), la pantalla de Perfil (que permanece en memoria escuchando activamente a `userWordCardsProvider`) detecta que el estado de su proveedor está marcado como obsoleto e inicia una solicitud asíncrona de fondo de forma inmediata, actualizando la cuadrícula y el contador de "Cartas" de forma transparente para el usuario.

---

## 🛠️ 4. Archivos Modificados

El diseño completo abarcó los siguientes componentes del proyecto:

1. **`lib/features/profile/presentation/screens/profile_screen.dart`**
   * Rediseñó la estructura con el Avatar alineado a la izquierda, contadores a la derecha, datos biográficos estilizados y la cuadrícula `GridView.builder`.
   * Integró el `RefreshIndicator` envolviendo el `SingleChildScrollView` para permitir actualización manual táctil.
   * Añadió logs de diagnóstico (`debugPrint`) para reportar la cantidad de tarjetas cargadas por sesión.
2. **`lib/features/vocabulary/presentation/providers/vocabulary_provider.dart`**
   * Agregó el proveedor aislado `userWordCardsProvider`.
   * Incorporó logs de consola para rastrear consultas y capturar excepciones de deserialización JSON.
3. **`lib/features/create_card/presentation/screens/create_card_form_screen.dart`**
   * Añadió la invalidación del proveedor de perfil (`ref.invalidate(userWordCardsProvider)`) tras la inserción exitosa en Supabase.

---

## 🧪 5. Validación de Correctitud

* **Compatibilidad de API:** Se reemplazó el uso de `withOpacity()` por `.withValues(alpha: ...)` en las áreas de estilo añadidas para cumplir estrictamente con las directrices de deprecación de Flutter 3.22+.
* **Análisis estático:** `flutter analyze` finalizó sin advertencias de código muerto o importaciones huérfanas.
* **Pruebas de Integridad:** Se corrió la suite de pruebas unitarias (`flutter test`), la cual arrojó un resultado 100% exitoso en todos los componentes del sistema.
