# Guía Técnica de Implementación: Asistente Progresivo del Editor de Cartas (Wizard/Stepper)

Esta es una excelente iniciativa. El editor de cartas es el corazón de la creación de contenido del usuario en Lingiux, y diseñarlo mediante un flujo por pasos (Wizard/Stepper) es la mejor decisión para evitar abrumar al usuario con demasiados campos a la vez.

Aquí te comparto mi análisis profesional sobre la experiencia de usuario (UX), el flujo de pasos óptimo y las decisiones de diseño para el editor.

---

## 🧠 1. Decisiones de Diseño de UX (La Filosofía del Editor)

### ¿Qué es mejor primero: validar la palabra o subir la foto?
Sin duda alguna: **Validar la palabra primero (Paso 1)**.

En diseño de UX existe un principio llamado *"Falla Rápido" (Fail Fast)*. El esfuerzo del usuario debe protegerse. Subir una foto de la galería, recortarla y ajustarla requiere una carga cognitiva y un tiempo considerables. Si dejas la validación de la palabra para el final y esta resulta ser inválida (porque no existe, está mal escrita o ya la tiene agregada), el usuario sentirá una enorme frustración al perder todo el trabajo de edición visual previo.

**Ventajas de validar la palabra primero:**
* **Flujo lógico:** El "alma" de la carta es la palabra. La imagen es solo un soporte nemotécnico (un apoyo visual para memorizar). Primero definimos qué estamos aprendiendo y luego cómo lo representamos.
* **Automatización del Paso 2:** Si validas la palabra primero, el sistema puede consultar una base de datos o API en segundo plano y, cuando el usuario pase al siguiente paso, sugerirle automáticamente la definición, ejemplos de uso e incluso sugerencias de imágenes para que no dependa únicamente de subir fotos de su propia galería.

### ¿Dónde iría mejor colocado el botón de + para subir la foto?
Si el editor se realiza por pasos y de manera visual, **el botón de + debe estar integrado dentro del lienzo de la propia carta vacía en el Paso 2**.

* **Diseño visual:** En el paso de la imagen, muestra una silueta o maqueta de la carta con un borde punteado o discontinuo (*dashed border*), un fondo sutilmente degradado y un icono grande de `+` en el centro con un texto que diga: *"Toca para añadir una imagen nemotécnica de tu galería"*.
* **Por qué es mejor UX:** Esto le da al usuario un modelo mental instantáneo de lo que está haciendo. En lugar de presionar un botón flotante genérico que ande suelto por la pantalla, el usuario interactúa directamente con el área donde se renderizará su foto. Al darle tap, se abre la galería del teléfono y, una vez seleccionada, la imagen llena el espacio de la carta de forma inmediata y en tiempo real.

---

## 🎨 2. Propuesta de Experiencia de Usuario (UX/UI) Paso a Paso para Lingiux

En lugar de utilizar el widget Stepper clásico de Flutter (que suele verse rígido, corporativo y ocupa mucho espacio en pantalla), decidimos implementar una **barra de progreso lineal minimalista de 3px** y usar un `PageView` con desplazamiento controlado programáticamente.

Aquí tienes el flujo de 4 pasos premium propuesto:

### Paso 1: Identidad (Palabra e Idioma)
* **Interfaz:** Un campo de entrada de texto limpio con tipografía grande (*Inter*) centrado en la pantalla y un selector elegante del idioma de la tarjeta.
* **Interacción:** El usuario escribe la palabra y presiona "Siguiente". El sistema valida rápidamente.
* **Micro-animación:** Si es válida, el campo muestra un check de color verde brillante con un leve rebote y pasa automáticamente a la siguiente pantalla con una transición suave.

### Paso 2: Contenido Semántico y Nemotécnico (Imagen y Definición)
* **Interfaz:** En la parte superior, se muestra el lienzo de la carta con el botón de `+` central en *dashed border* para seleccionar la imagen. Abajo, se ubican los campos para la definición/traducción y algún ejemplo opcional (los cuales pueden venir autocompletados gracias a la validación del paso 1).
* **Interacción:** El usuario sube la foto de su galería y escribe/valida la definición.

### Paso 3: Estética y Personalización
* **Interfaz:** El lienzo ahora muestra la carta armada con su foto, palabra y definición. En la parte inferior, aparece un carrusel horizontal con opciones de personalización visual:
  * **Fondos:** Una selección curada de degradados premium (evitando selectores de color RGB infinitos que puedan arruinar la consistencia estética de la app).
  * **Marcos:** Selección de marcos decorativos (bronce, plata, oro, neón) que el usuario posea o tenga desbloqueados.
* **Interacción:** Cada vez que el usuario presiona un estilo o marco, la carta en el lienzo se actualiza con una transición de desvanecimiento suave.

### Paso 4: Previsualización 3D y Publicación
* **Interfaz:** La carta se muestra flotando en el centro de la pantalla.
* **Interacción:** Aquí integramos el widget de volteo. El usuario puede darle Tap a la carta y ver físicamente cómo se voltea en 3D para verificar cómo quedó el frente y cómo se verá el reverso con la definición.
* **Acción Final:** Un botón prominente abajo que diga "Crear Tarjeta Mental". Al presionarlo, la tarjeta se rasteriza, se sube a Supabase y se agrega a su cerebro digital.

### ¿Cómo se estructura en Flutter?
Para lograr esto con un alto nivel de pulido:
* Usamos un `PageView` con `physics: const NeverScrollableScrollPhysics()` para evitar que el usuario se salte los pasos deslizando el dedo lateralmente sin completar las validaciones de cada etapa.
* Controlamos la navegación con botones inferiores de "Atrás" y "Continuar" (estilo pastilla negra Soft UI).
* En la parte superior, colocamos una barra de progreso delgada de 3px de grosor que se llene suavemente con una animación de duración corta (ej. 250ms) a medida que avanzas en los pasos. Esto fue sumamente importante para dar feedback interactivo continuo al usuario.

---

## 🏗️ 3. Arquitectura Técnica de la Implementación

El asistente se estructura mediante un `PageView` controlado de forma no deslizable, asegurando que la navegación ocurra exclusivamente mediante los botones de acción inferior que validan el estado de cada pantalla.

```mermaid
graph TD
    A[CreateCardScreen - Scaffold Central] --> B[Step 1: Identidad - step_word_identity.dart]
    A --> C[Step 2: Nemotecnia - step_word_mnemonics.dart]
    A --> D[Step 3: Estética - step_card_aesthetics.dart]
    A --> E[Step 4: Previsualización 3D - step_card_preview.dart]
    
    A -- Mantiene Estado Común -- F[TextControllers, Bytes Imagen, Ruta Audio, Estilos]
    A -- Evento Guardar -- G[Subida paralela a Storage -> Inserta en Supabase -> Resetea Formulario -> Navega a pestaña Feed]
```

---

## 📂 4. Archivos Creados y Modificados

### A. Nuevos Archivos
1. **[step_word_identity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_identity.dart) (Paso 1):** 
   * Captura palabra, traducción/fonética, idioma, categoría gramatical.
   * Integra el grabador de audio por micrófono y reproductor de muestra.
2. **[step_word_mnemonics.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_mnemonics.dart) (Paso 2):** 
   * Dibuja el lienzo con borde discontinuo (`DashedRectPainter`) y maneja el selector de imágenes de galería.
   * Recoge definición y frase de ejemplo.
3. **[step_card_aesthetics.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_card_aesthetics.dart) (Paso 3):**
   * Contiene selectores horizontales interactivos para el gradiente de fondo de la carta y el tipo de marco.
4. **[step_card_preview.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_card_preview.dart) (Paso 4):**
   * Implementa la previsualización 3D interactiva utilizando transformaciones con proyección cónica sobre la matriz de perspectiva.
5. **[navigation_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/home/presentation/providers/navigation_provider.dart):**
   * Proveedor de Riverpod (`activeTabProvider`) para sincronizar y manipular la pestaña seleccionada del menú principal.

### B. Archivos Modificados
1. **[create_card_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart):** 
   * Rediseñado por completo como el contenedor del Wizard. Centraliza el estado, valida transiciones y realiza la persistencia en Supabase.
2. **[word_card_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/domain/models/word_card_model.dart):** 
   * Actualizado para serializar/deserializar de forma segura el nuevo campo `canvas_design`.
3. **[word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart):** 
   * Modificado el componente interno `_WordCard` para renderizar de manera consistente el fondo y el marco decorativo (bronce, plata, oro, neón) según los datos guardados en Supabase.
4. **[home_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/home/presentation/screens/home_screen.dart):** 
   * Refactorizado de `StatefulWidget` local a `ConsumerWidget` de Riverpod para controlar la pestaña activa de manera global.

---

## 🔍 5. Detalles de la Implementación de Código

A continuación se detalla la lógica de programación y el comportamiento de bajo nivel de cada uno de los módulos clave del editor:

### A. Scaffold Central y Barra de Progreso (`CreateCardScreen`)
* **Barra de Progreso:** Se calcula el progreso de forma dinámica basada en el paso actual `progress = (_currentStep + 1) / 4`. Se dibuja usando un `LayoutBuilder` de ancho completo y un `AnimatedContainer` con una duración de 250ms y una curva de aceleración estándar, logrando una animación muy fluida y orgánica de llenado en Soft UI.
* **Control del PageView:** El `PageView` se configura de forma estricta con `physics: const NeverScrollableScrollPhysics()`. Las transiciones entre pantallas se controlan programáticamente mediante los botones inferiores llamando a:
  ```dart
  _pageController.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOutCubic,
  );
  ```
* **Botonera Soft UI:** Se diseñó un botón tipo pastilla color slate oscuro (`0xFF0F172A`) con `BorderRadius.circular(24)`. Si el proceso de guardado `_isSaving` está activo, se muestra un indicador de carga circular en su interior y se deshabilitan las interacciones.

### B. Identidad de la Palabra e Idioma (`StepWordIdentity`)
* **Alineación Lado a Lado (Boceto de Usuario):** Se reorganizó la fila superior del formulario colocando la caja de entrada `"Ingresa la palabra"` y el dropdown de `"Idioma"` alineados horizontalmente en un `Row`.
* **Dropdown de Idiomas Compacto (Set SVG):** Se implementaron banderas vectoriales SVG locales en la carpeta `assets/flags/` (México, Estados Unidos, Italia, Alemania, Francia, Brasil). El dropdown utiliza `selectedItemBuilder` para renderizar únicamente la bandera del idioma seleccionado en la cabecera (haciéndola ultra compacta y estética), mientras que el menú desplegable muestra la combinación de bandera + etiqueta de texto de manera limpia.
* **Indicador Check Reactivo:** El campo de texto de palabra cuenta con un `suffixIcon` reactivo en su decoración que muestra un icono de verificación en verde (`Icons.check_circle_rounded`) en el instante en que el usuario ingresa caracteres válidos.
* **Grabador de Audio (`record`):** Al tocar el botón de micrófono, se inicializa el stream y se escribe en un archivo temporal de audio mediante `_audioRecorder.start(...)`.
* **Temporizador de Autolimitación (15s):** Para evitar saturar el almacenamiento de Supabase con archivos pesados, un `Timer.periodic` detiene la grabación automáticamente a los 15 segundos de forma local.
* **Reproductor (`audioplayers`):** Permite previsualizar la pista grabada de manera local antes de la subida definitiva mediante `_audioPlayer.play(DeviceFileSource(path))`.

### C. Lienzo con Borde Discontinuo (`StepWordMnemonics`)
* **Pintado Personalizado del Contorno:** Si el usuario no ha subido una foto, se dibuja un lienzo de tarjeta vacía utilizando un `CustomPaint` gobernado por `DashedRectPainter`. Este pintor personalizado calcula la métrica del `RRect` redondeado y dibuja líneas discontinuas espaciadas mediante un bucle `while (distance < pathMetric.length)` incrementando la distancia en múltiplos del `gap` definido.
* **Carga de Imagen Local en Caliente:** Para evitar subir archivos innecesarios al servidor antes de finalizar el proceso completo, al seleccionar una imagen de la galería usando `ImagePicker().pickImage()`, se leen sus bytes en caliente usando `await image.readAsBytes()`. Estos bytes se almacenan en memoria (`Uint8List`) y se renderizan localmente mediante un `Image.memory(bytes, fit: BoxFit.cover)` simulando que la imagen ya se encuentra incrustada en la tarjeta.

### D. Reglas de Estética y Pintura de Marcos (`StepCardAesthetics`)
Muestra la tarjeta armada y permite cambiar entre 8 paletas de degradados precargadas y 5 tipos de marcos visuales de clasificación mediante la propiedad `decoration` de un `Container`:
* **Normal:** Sin borde adicional, sombra difuminada basada en el color dominante del degradado de fondo.
* **Bronce:** Borde de 6px con color de cobre sólido (`0xFFCD7F32`) y una sombra difusa marrón de `spreadRadius: 1`.
* **Plata:** Borde de 6px color aluminio cepillado (`0xFFE0E0E0`) y sombra difuminada gris de `spreadRadius: 1.5`.
* **Oro:** Borde de 6px color oro (`0xFFFFD700`) con una doble capa de sombras: una sombra dorada de base con gran difuminación (`blurRadius: 16`) y una sombra interior blanca brillante para simular reflejos metálicos.
* **Neón:** Borde de 5px color rosa fluorescente (`0xFFEC4899`) con una sombra densa de `spreadRadius: 3.5` y `blurRadius: 18` para proyectar el efecto de luminiscencia neon sobre el fondo.

### E. Transformación Física de Volteo 3D (`StepCardPreview`)
El volteo 3D de la tarjeta se logra mediante el widget `AnimatedBuilder` que varía un ángulo de rotación de $0$ a $\pi$ ($180^\circ$) al hacer tap:
* **Matriz de Perspectiva:** Se modifica la matriz de transformación del widget para simular profundidad cónica inclinando la perspectiva del eje Z:
  ```dart
  final transform = Matrix4.identity()
    ..setEntry(3, 2, 0.0015) // Perspectiva de profundidad cónica
    ..rotateY(angle);       // Rotación en eje Y
  ```
* **Corrección de Espejo:** Cuando una tarjeta se rota $180^\circ$, por física óptica las letras del reverso se verían invertidas horizontalmente (efecto espejo). Para solucionar esto, si el ángulo supera los $90^\circ$ ($\pi/2$), se renderiza la UI del reverso rotada otros $180^\circ$ en el eje Y de forma programática. Esto neutraliza el efecto espejo y permite que el texto se lea correctamente de izquierda a derecha.

---

## 📦 6. Librerías y Módulos Externos Utilizados

1. **`record` (Módulo de grabación):**
   * *Uso:* Captura la voz del usuario directamente a través del micrófono del móvil en formato `.m4a` de forma asíncrona.
   * *Detalle:* Permite definir la tasa de muestreo, tasa de bits y validar los permisos de hardware antes de iniciar la captura.
2. **`audioplayers` (Módulo de audio):**
   * *Uso:* Reproduce la grabación local en tiempo real para que el usuario verifique si su pronunciación es correcta antes de subirla.
3. **`image_picker` (Selector de Galería):**
   * *Uso:* Accede de forma nativa a la galería de fotos del dispositivo del usuario para seleccionar una foto de referencia visual.
4. **`cached_network_image` (Caché de Imágenes):**
   * *Uso:* Renderiza la imagen nemotécnica en la tarjeta dentro del feed de manera óptima reduciendo el consumo de ancho de banda.

---

## 💾 7. Persistencia y Base de Datos (Supabase Integration)

### A. Migración de Esquema (jsonb)
Añadimos la columna `canvas_design` de tipo `jsonb` en la tabla `word_cards` de Supabase:
```sql
ALTER TABLE word_cards ADD COLUMN IF NOT EXISTS canvas_design jsonb;
```
Esto permite guardar un objeto estructurado dinámico y extensible:
```json
{
  "gradient_index": 2,
  "frame_type": "oro"
}
```

### B. Serialización Segura (Evitando TypeErrors)
En Flutter, el parser decodifica los tipos de columnas JSON de PostgreSQL como `Map<dynamic, dynamic>`. Realizar un casteo directo `as Map<String, dynamic>` provocaría un error fatal. Se solucionó en el constructor `fromJson` con:
```dart
canvasDesign: json['canvas_design'] is Map
    ? Map<String, dynamic>.from(json['canvas_design'] as Map)
    : null,
```

---

## 🛠️ 8. Resolución de Bugs Críticos en Caliente

### Bug A: Pantalla Negra y Congelamiento (ANR) al Guardar
* **Síntoma:** Al presionar "Crear Tarjeta", la aplicación cargaba por 2 segundos y se ponía en negro por completo, arrojando a los 20 segundos una alerta de que no respondía.
* **Causa:** El widget `CreateCardScreen` está empotrado de forma fija en la pestaña indexada número 2 de `HomeScreen`. El flujo original del formulario anterior usaba `Navigator.pop(context)` porque se abría mediante un `Navigator.push`. Al intentar hacer `pop` en un widget pestaña fijo, Flutter eliminaba el propio `HomeScreen` (la raíz), dejando la pila de navegación vacía (pantalla negra) y rompiendo el hilo de ejecución del sistema operativo.
* **Solución:** Reemplazamos `Navigator.pop(context)` por una refactorización de navegación global mediante `activeTabProvider` en Riverpod. Tras guardar la tarjeta:
  1. Se limpian todos los controladores y variables del formulario.
  2. Se resetea internamente el `PageView` al Paso 1.
  3. Se cambia el índice de la pestaña de `HomeScreen` a la pestaña del Feed (Pestaña 0):
     ```dart
     ref.read(activeTabProvider.notifier).state = 0;
     ```
  4. Esto redirige al usuario de forma segura al inicio y refresca la lista con la tarjeta recién creada.

---

## 🔗 9. Integración del Flujo de Palabras del Chat (Click to Create)

Diseñamos una integración contextual entre las conversaciones del Chat y el editor para que el usuario pueda registrar palabras desconocidas al instante sin romper el flujo de su experiencia:

### A. Detección de Tarjetas en el Chat
Al presionar una palabra del chat en [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart), el sistema consulta reactivamente `wordCardsProvider` para verificar si el término ya existe en el vocabulario del usuario.

### B. Adaptación Dinámica de la Mini-Tarjeta
* **Frontal (`_WordMiniCardFront`):** Si la palabra no tiene tarjeta asociada, el icono cambia a `Icons.add_circle_outline_rounded` y la acción inferior de apertura se modifica mostrando `+ Crear` en una pastilla de color con mayor contraste.
* **Reverso (`_WordMiniCardBack`):** Al voltear la mini-tarjeta, el icono superior cambia a `Icons.style_outlined` y la sección de traducción muestra un llamado a la acción persuasivo: *"Esta palabra no tiene tarjeta aún. ¡Toca aquí para crearla y memorizarla!"*.

### C. Redirección y Precarga Reactiva
Al tocar la mini-tarjeta (por el frente o reverso) sin contenido:
1. Se descarta el overlay flotante.
2. Se escribe la palabra seleccionada en `pendingWordProvider`.
3. Se actualiza `activeTabProvider` al índice `2` (Pestaña del editor).
4. El widget `CreateCardScreen` escucha a `pendingWordProvider` en su método `build` mediante:
   ```dart
   ref.listen<String?>(pendingWordProvider, (previous, next) {
     if (next != null && next.trim().isNotEmpty) {
       _wordController.text = next.trim();
       ref.read(pendingWordProvider.notifier).state = null;
     }
   });
   ```
   Esto precarga la palabra en el cuadro de texto del **Paso 1** de forma automática y transparente, eliminando la necesidad de escribirla manualmente.

