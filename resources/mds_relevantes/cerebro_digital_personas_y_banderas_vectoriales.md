# 🧠 Cerebro Digital de Personas: Agrupamiento por Chats Activos y Banderas Vectoriales

Este documento detalla la reingeniería y la arquitectura del sistema implementadas para integrar la red social de contactos en el **Cerebro Digital** de **Lingiux**, agrupando a los usuarios con chats activos bajo sus respectivas nacionalidades representadas por banderas vectoriales circulares, conservando intacto el comportamiento original de la constelación de palabras.

---

## 📌 1. Planteamiento del Problema y Desafío Tecnológico

El Cerebro Digital original de Lingiux permitía la visualización e interacción tridimensional de palabras y sus categorías gramaticales mediante físicas elásticas. El objetivo consistió en duplicar este comportamiento para visualizar la red social de personas con chats activos, agrupándolas bajo nodos madre correspondientes a sus nacionalidades. 

### El Problema de las Banderas en Windows
Inicialmente, los nodos madre de nacionalidad utilizaban emojis de banderas Unicode (`🇲🇽`, `🇺🇸`, etc.). Esto presentaba dos graves problemas:
1. **Inconsistencia Estética**: Los emojis varían según el sistema operativo (iOS, Android, macOS).
2. **Invisibilidad en Windows**: Windows no posee soporte nativo para renderizar emojis de banderas, representándolos como cajas vacías o textos abreviados (`MX`, `US`). En el lienzo del `CustomPainter`, los emojis no se dibujaban, dejando el nodo como un círculo de color plano sin diseño identificativo.

### La Solución Vectorial (SVG)
Para resolver esto de forma profesional y multiplataforma, se decidió rellenar la totalidad del nodo madre con la bandera en formato vectorial. Para ello, se utilizaron los gráficos vectoriales diseñados a mano en código XML dentro del directorio `assets/flags/` (`mx.svg`, `us.svg`, `de.svg`, etc.), pre-cargándolos asíncronamente y pintándolos con recorte circular directamente sobre el canvas.

---

## 🗄️ 2. Estructura y Preparación de la Base de Datos (Supabase)

Para persistir y consultar la nacionalidad de los usuarios, se añadieron modificaciones a la tabla de perfiles en Supabase.

### Consulta SQL de Creación de Columna
Se ejecutó la siguiente consulta en la base de datos para añadir el soporte de nacionalidad en los perfiles:
```sql
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nationality text DEFAULT 'México';
```

### Inicialización de Usuarios de Prueba
Con la finalidad de probar los agrupamientos físicos y el comportamiento elástico del grafo de personas, se asociaron las siguientes nacionalidades en los perfiles de la base de datos:
*   **Sebas** (Usuario actual): `México` 🇲🇽
*   **Pepito** (Contacto de chat): `Estados Unidos` 🇺🇸
*   **LX OFICIAL** (Contacto de chat): `Alemania` 🇩🇪

---

## 🔄 3. Restructuración y Flujo de Datos (Subsistema de Chat)

Para alimentar el grafo de personas en tiempo real sin obligar al usuario a agregar contactos de forma manual (lo cual se descartó para priorizar interacciones fluidas), los nodos se sincronizan directamente con las **conversaciones activas**. 

Se realizaron cambios en tres archivos clave del módulo de chat para transportar la nacionalidad de los participantes:

### A. Modificación de Entidad: [chat_entity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/domain/entities/chat_entity.dart)
Se añadieron los campos opcionales `otherUserId` y `nationality` para representar al otro participante de la conversación:
```dart
class ChatEntity {
  final String id;
  final String name;
  final String initials;
  final int avatarColorIndex;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<MessageEntity> messages;
  final String? avatarUrl;
  final String? otherUserId; // ID del otro participante
  final String? nationality; // Nacionalidad del otro participante

  const ChatEntity({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColorIndex,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
    required this.messages,
    this.avatarUrl,
    this.otherUserId,
    this.nationality,
  });
}
```

### B. Modificación de Modelo: [chat_model.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/data/models/chat_model.dart)
Se actualizó el deserializador `fromJson` para extraer los campos correspondientes desde la relación relacional del JSON devuelto por Supabase:
```dart
class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.name,
    required super.initials,
    required super.avatarColorIndex,
    required super.lastMessage,
    required super.lastMessageTime,
    required super.unreadCount,
    required super.isOnline,
    required super.messages,
    super.avatarUrl,
    super.otherUserId,
    super.nationality,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final participants = json['all_participants'] as List<dynamic>? ?? [];
    
    // Buscar el participante que NO es el usuario actual
    final otherParticipant = participants.firstWhere(
      (p) => p['profile'] != null && p['profile']['id'] != currentUserId,
      orElse: () => null,
    );

    final otherProfile = otherParticipant != null ? otherParticipant['profile'] as Map<String, dynamic> : null;
    final otherName = otherProfile?['full_name'] as String? ?? 'Usuario de Lingiux';
    final avatarUrl = otherProfile?['avatar_url'] as String?;
    final otherUserId = otherProfile?['id'] as String?;
    final nationality = otherProfile?['nationality'] as String?;
    
    final initials = otherName.trim().isNotEmpty
        ? otherName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'LX';

    final avatarColorIndex = otherName.hashCode.abs();

    return ChatModel(
      id: json['id'] as String,
      name: otherName,
      initials: initials,
      avatarColorIndex: avatarColorIndex,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : DateTime.now(),
      unreadCount: 0,
      isOnline: false,
      messages: const [],
      avatarUrl: avatarUrl,
      otherUserId: otherUserId,
      nationality: nationality,
    );
  }
}
```

### C. Modificación de Provider: [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart)
Se modificó la consulta relacional del `chatsProvider` para solicitar explícitamente el campo `nationality` desde la tabla `profiles` mediante la clave foránea en la tabla intermedia `conversation_participants`:
```dart
final chatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  return supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        final data = await supabase
            .from('conversations')
            .select('''
              id,
              last_message,
              last_message_time,
              conversation_participants!inner(profile_id),
              all_participants:conversation_participants(
                profile:profiles(id, full_name, avatar_url, nationality)
              )
            ''')
            .eq('conversation_participants.profile_id', user.id)
            .order('last_message_time', ascending: false);

        return (data as List<dynamic>)
            .map((json) => ChatModel.fromJson(json, user.id))
            .toList();
      });
});
```

---

## 🛠️ 4. Sincronización, Pre-Carga y Renderizado en el Grafo

El archivo [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart) concentra toda la lógica interactiva del mapa mental.

### A. Sincronización de Nodos en Caliente (`_syncPeopleNodes`)
Cuando el usuario activa el modo "Personas", el sistema recibe la lista de chats activos e inicializa los nodos correspondientes.
*   **Nodos Madre (Nacionalidades)**: Extrae el listado de países únicos representados en las conversaciones y crea un nodo de tipo `'nationality'` en una posición radial inicial.
*   **Nodos Hijos (Personas)**: Crea un nodo de tipo `'person'` para cada participante, asignándole una ligera dispersión aleatoria alrededor de su respectivo nodo nacionalidad. Los metadatos del perfil se inyectan en un mapa (`userProfile`) para compatibilidad.
*   **Limpieza de Nodos Huérfanos**: Elimina nodos del grafo si se borra una conversación o si una nacionalidad se queda sin participantes activos.

### B. Pre-carga Asíncrona de Fotos y Banderas Vectoriales
Para no bloquear el renderizado en el hilo principal de la interfaz de usuario, todas las descargas de imágenes y lecturas de vectores se realizan de manera no bloqueante y se almacenan en caches locales:

```dart
// Caché de imágenes de perfil
final Map<String, ui.Image> _profileImagesCache = {};

// Caché de imágenes de banderas pre-cargadas (PictureInfo vectorial)
final Map<String, PictureInfo> _flagPicturesCache = {};
```

1.  **Carga de Fotos de Perfil**:
    Utiliza un `ImageStreamListener` para descargar la imagen de red de manera asíncrona, notificando al canvas para repintarse una vez decodificada en memoria:
    ```dart
    void _preloadProfileImage(String url) {
      if (url.isEmpty || _profileImagesCache.containsKey(url)) return;

      try {
        final imageProvider = NetworkImage(url);
        final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
        stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _profileImagesCache[url] = info.image;
            });
            _repaintNotifier.requestRepaint();
          }
        }));
      } catch (_) {}
    }
    ```

2.  **Carga de Banderas vectoriales (SVG)**:
    Utiliza el motor de `flutter_svg` para leer los bytes del asset local, interpretarlos vectorialmente en una estructura `PictureInfo` (que contiene el set de comandos de dibujo de canvas de Flutter) y guardarlo de forma inmediata sin rasterizaciones costosas:
    ```dart
    void _preloadFlagImage(String nationality) {
      final asset = _getNationalityFlagAsset(nationality);
      if (asset.isEmpty || _flagPicturesCache.containsKey(asset)) return;

      try {
        final SvgAssetLoader loader = SvgAssetLoader(asset);
        vg.loadPicture(loader, null).then((pictureInfo) {
          if (mounted) {
            setState(() {
              _flagPicturesCache[asset] = pictureInfo;
            });
            _repaintNotifier.requestRepaint();
          }
        }).catchError((_) {});
      } catch (_) {}
    }
    ```

---

## 🎨 5. Dibujo de Nodos sobre el Canvas (CustomPainter)

El pintor de gráficos personalizado `VocabularyGraphPainter` dibuja frame a frame la constelación. Se agregaron operaciones especializadas de recorte circular y transformaciones afines para pintar las banderas vectoriales.

### Recorte Circular y Centrado Vectorial de Bandera (`BoxFit.cover`)
El CustomPainter recibe el mapa `flagImages` cacheado. Cuando debe pintar un nodo nacionalidad:
1.  **Salva el estado del canvas** (`canvas.save()`).
2.  **Genera una máscara circular** utilizando un `Path` y restringe el canvas a este clip circular (`canvas.clipPath(clipPath)`).
3.  **Calcula las proporciones matemáticas** para estirar la bandera cubriendo todo el círculo (simulando `BoxFit.cover`):
    *   Determina el diámetro del nodo: `nodeDiameter = radius * 2`.
    *   Compara la relación de aspecto del SVG (`loadedFlag.size.width` y `loadedFlag.size.height`) contra el diámetro del nodo para seleccionar el factor de escala máximo (`math.max(scaleX, scaleY)`).
    *   Calcula el desfase de alineación (`dx` y `dy`) para que el centro del SVG coincida con el centro geométrico del nodo.
4.  **Aplica las transformaciones afines** de traslación y escala sobre el canvas.
5.  **Dibuja la Picture en caliente** (`canvas.drawPicture(loadedFlag.picture)`).
6.  **Restaura el canvas** (`canvas.restore()`).

```dart
      } else if (node.type == 'nationality') {
        final asset = _getNationalityFlagAsset(node.label);
        final loadedFlag = flagImages[asset];

        if (loadedFlag != null) {
          canvas.save();
          // Clip circular del área
          final Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: node.position, radius: radius - 0.5));
          canvas.clipPath(clipPath);

          // Escalar y centrar la Picture para simular BoxFit.cover
          final svgSize = loadedFlag.size;
          final double nodeDiameter = (radius - 0.5) * 2;
          final double scaleX = nodeDiameter / svgSize.width;
          final double scaleY = nodeDiameter / svgSize.height;
          final double scale = math.max(scaleX, scaleY);

          final double dx = node.position.dx - (svgSize.width * scale) / 2;
          final double dy = node.position.dy - (svgSize.height * scale) / 2;

          canvas.translate(dx, dy);
          canvas.scale(scale);
          canvas.drawPicture(loadedFlag.picture);
          canvas.restore();
        } else {
          // Fallback en Windows si el SVG no existe (Dibuja emoji)
          final flag = _getNationalityFlag(node.label);
          final flagSpan = TextSpan(
            text: flag,
            style: const TextStyle(fontSize: 16),
          );
          final flagPainter = TextPainter(
            text: flagSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          flagPainter.paint(
            canvas,
            node.position - Offset(flagPainter.width / 2, flagPainter.height / 2),
          );
        }
      }
```

---

## ⚡ 6. Conservación del Cerebro de Palabras y Físicas Originales

Para cumplir con la directiva estricta de no alterar el comportamiento visual ni de rendimiento del Cerebro Mental original de palabras, se realizaron las siguientes integraciones:

1.  **Restauración del Fondo espacial original**:
    Se restauró el degradado espacial en pila (`Stack`) y el `Scaffold` con fondo transparente original de la vista del Cerebro Digital:
    ```dart
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientBgStart.withValues(alpha: 0.55),
              AppColors.gradientBgEnd.withValues(alpha: 0.55),
              AppColors.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
    ```
2.  **Restauración del Carrusel de Cápsulas**:
    Se devolvió el diseño soft UI de filtros en carrusel horizontal (`_buildCapsuleFilter`) y la barra de filtros original en lugar de menús de selección planos.
3.  **Física de Expansión Original**:
    Al hacer clic sobre un nodo de categoría gramatical, se restauró el empuje de velocidad física original que da un efecto bouncy de dispersión elástica a los nodos hijos:
    ```dart
    child.position = node.position +
        Offset(
          (random.nextDouble() - 0.5) * 20,
          (random.nextDouble() - 0.5) * 20,
        );
    child.velocity = Offset(
      (random.nextDouble() - 0.5) * 45,
      (random.nextDouble() - 0.5) * 45,
    );
    ```

---

## 📦 7. Bibliotecas y Dependencias Utilizadas

Para materializar esta solución, se utilizaron paquetes de alta confiabilidad integrados en el archivo de dependencias del proyecto (`pubspec.yaml`):

1.  **`flutter_svg` (v2.0.10)**:
    *   **Propósito**: Lectura y deserialización del código XML de gráficos vectoriales desde la carpeta `assets/flags/`.
    *   **Utilidad**: Nos provee de clases clave como `SvgAssetLoader` y el objeto global `vg` (Vector Graphics API) para cargar los archivos como `PictureInfo` directamente en la caché del lienzo en tiempo de ejecución.
2.  **`flutter_riverpod` (v2.6.1)**:
    *   **Propósito**: Gestión reactiva del estado y acoplamiento de proveedores en la UI.
    *   **Utilidad**: Permite observar reactivamente el flujo dinámico de chats activos mediante `ref.watch(chatsProvider)` y actualizar los nodos sin interrumpir las físicas del grafo.
3.  **`supabase_flutter` (v2.9.1)**:
    *   **Propósito**: Conectividad de base de datos en la nube.
    *   **Utilidad**: Realiza queries relacionales unificadas y mantiene sincronizadas las conversaciones del usuario en tiempo real vía streams reactivos de bases de datos relacionales Postgres.

---

## 🚀 8. Proyecciones y Diseño a Futuro para Nodos Vectoriales

Para elevar el acabado del Cerebro Digital de Personas a un estándar ultra premium, se proponen las siguientes evoluciones arquitectónicas y de experiencia de usuario:

### A. Volumen Esférico 3D (Efecto Glassmorphic)
Para dar a los nodos de bandera un aspecto de "canica de cristal", se puede superponer una capa de luz reflectiva en el pintor. Esto se logra dibujando un degradado blanco radial semitransparente descentrado justo encima de la bandera clipada:
```dart
final glassPaint = Paint()
  ..shader = ui.Gradient.radial(
    node.position - Offset(radius * 0.3, radius * 0.3), // Foco de luz descentrado
    radius,
    [
      Colors.white.withOpacity(0.35),
      Colors.white.withOpacity(0.0),
    ],
  );
canvas.drawCircle(node.position, radius, glassPaint);
```

### B. Iluminación Dinámica Neón por Notificaciones
Para notificar visualmente un mensaje pendiente dentro de la constelación:
*   Si el chat asociado tiene mensajes sin leer, el pintor puede dibujar un anillo exterior con un blur gausiano (`MaskFilter.blur(BlurStyle.normal, 12.0)`) pulsante en el color principal de la nacionalidad.

### C. Distribución por CDN (Content Delivery Network)
*   **Implicación**: Evita sobrecargar el instalable de la app con assets de banderas si se añaden más países.
*   **Solución**: Subir los archivos SVG a Supabase Storage y cargarlos remotamente. `SvgNetworkLoader(url)` reemplazaría a `SvgAssetLoader(asset)`, guardando los datos vectoriales en la base de datos de almacenamiento en disco local del usuario.

### D. Repercusión en Rendimiento y Mitigación
*   **Costo de GPU**: El uso excesivo de `clipPath` con suavizado de bordes e `ImageFilter.blur` puede causar fatiga de hardware en dispositivos gama media-baja.
*   **Mitigación**: Generar la máscara de canica de cristal una sola vez y renderizarla utilizando `Picture` en caché, o desactivar reflejos complejos si el hardware del cliente detecta una caída sostenida por debajo de 60 FPS.
