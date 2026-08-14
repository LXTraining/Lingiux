# Arquitectura de Grupos de Estudio Cooperativos y Mascota Compartida

Este documento detalla la especificación técnica de la funcionalidad de **Grupos de Estudio Cooperativos** en Lingiux. La característica permite a los estudiantes agruparse en salones de clase o grupos de estudio virtuales para cooperar en el desarrollo y crecimiento de una mascota o planta compartida, utilizando sus rachas de aprendizaje individuales para ganar puntos de evolución, chateando en tiempo real con interactividad de palabras cliqueables y gestionando participantes mediante invitaciones directas.

---

## 1. Estructura del Proyecto y Archivos Afectados

El desarrollo se integró de forma modular respetando los patrones de diseño establecidos en el codebase de Lingiux (Clean Architecture en la capa de presentación y datos).

```text
lingiux_app/
├── lib/
│   └── features/
│       ├── chat/
│       │   ├── domain/
│       │   │   └── entities/
│       │   │       ├── chat_entity.dart
│       │   │       └── study_group.dart              <--- [NUEVO] Entidad de datos del Grupo de Estudio
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── chat_provider.dart            <--- [MODIFICADO] CRUD de grupos, stream de grupos y filtros
│       │       ├── widgets/
│       │       │   └── message_bubble.dart           <--- [MODIFICADO] Soporte de avatar/nombre de integrantes en burbuja
│       │       └── screens/
│       │           ├── chat_detail_screen.dart       <--- [MODIFICADO] Exposición pública de OverlayEntrance y FlippableCard
│       │           ├── chats_list_screen.dart        <--- [MODIFICADO] Integración de pestaña de grupos y modal de creación
│       │           └── group_detail_screen.dart      <--- [NUEVO] Pantalla con las 3 pestañas principales (Chat, Mascota y Miembros)
│       └── profile/
│           └── presentation/
│               └── providers/
│                   ├── profile_provider.dart         <--- [REFERENCIADO] Datos del usuario y su racha diaria (streak_count)
│                   └── added_people_provider.dart    <--- [REFERENCIADO] Listado de personas agregadas para invitar
└── resources/
    └── mds_relevantes/
        └── arquitectura_grupos_estudio_y_mascota_cooperativa.md <--- [NUEVO] Este documento de arquitectura
```

---

## 2. Diseño de Base de Datos y Seguridad (Supabase)

Para persistir los grupos de estudio de forma robusta e impedir vulnerabilidades, se crearon dos nuevas tablas con soporte para Row Level Security (RLS) en PostgreSQL.

### A. Tabla `public.study_groups`
Guarda el nombre, la descripción, el creador, el enlace a la conversación y los puntos de evolución de la mascota.

```sql
CREATE TABLE public.study_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    conversation_id UUID UNIQUE NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    growth_type TEXT NOT NULL DEFAULT 'PLANT', -- 'PLANT' o 'TAMAGOTCHI'
    growth_points INTEGER NOT NULL DEFAULT 0,
    level INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### B. Tabla `public.group_contributions`
Registra el historial de aportes de rachas de cada usuario para asegurar que cada miembro solo aporte una vez al día. Cuenta con una clave única compuesta (`unique_daily_contribution`) que rechaza automáticamente en base de datos cualquier intento duplicado.

```sql
CREATE TABLE public.group_contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    points INTEGER NOT NULL,
    contributed_at DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT unique_daily_contribution UNIQUE (group_id, profile_id, contributed_at)
);
```

### C. Políticas de Seguridad RLS (Row Level Security)
Para asegurar que los datos no puedan ser manipulados de manera externa:
* **Lectura:** Cualquier usuario autenticado en Lingiux puede leer los grupos.
* **Creación:** Cualquier usuario autenticado puede crear un grupo.
* **Actualización:** Solo el creador del grupo o un miembro registrado del grupo (que exista en `conversation_participants` para esa conversación) puede editar el grupo o sumarle puntos.
* **Aportes:** Un usuario solo puede insertar un registro de contribución para sí mismo (`auth.uid() = profile_id`).

```sql
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_contributions ENABLE ROW LEVEL SECURITY;

-- Políticas study_groups
CREATE POLICY "Cualquiera autenticado puede leer grupos" ON public.study_groups FOR SELECT TO authenticated USING (true);
CREATE POLICY "Usuarios autenticados pueden crear grupos" ON public.study_groups FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Solo miembros o creador pueden actualizar grupo" ON public.study_groups FOR UPDATE TO authenticated USING (
    auth.uid() = creator_id OR EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_id = study_groups.conversation_id AND profile_id = auth.uid()
    )
);

-- Políticas group_contributions
CREATE POLICY "Lectura de contribuciones para autenticados" ON public.group_contributions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Inserción de contribuciones para miembros" ON public.group_contributions FOR INSERT TO authenticated WITH CHECK (auth.uid() = profile_id);
```

---

## 3. Principio del Chat Polimórfico Profesional

El diseño del chat grupal se estructuró de manera polimórfica sobre la tabla genérica `conversations`. 
* Un chat 1-a-1 es una fila en `conversations` con 2 participantes en `conversation_participants`.
* Un chat grupal es una fila en `conversations` con $N$ participantes, y que **se asocia a una fila en `study_groups`**.

Al hacer esto, **toda la infraestructura de tiempo real de Supabase (`supabase.stream()`) y la inserción de mensajes en la tabla `messages` se reutilizan al 100%**, logrando una excelente modularidad sin crear tablas redundantes. 

Para que la pestaña "Mensajes" y la pestaña "Grupos" no se mezclen en la lista principal, el provider `chatsProvider` realiza un filtrado en memoria comparando los identificadores de conversación activos con las conversaciones de los grupos:

```dart
final groupConvs = await supabase.from('study_groups').select('conversation_id');
final groupConvIds = (groupConvs as List).map((g) => g['conversation_id'] as String).toSet();

return (data as List<dynamic>)
    .where((json) => !groupConvIds.contains(json['id'] as String))
    .map((json) => ChatModel.fromJson(json, user.id))
    .toList();
```

---

## 4. Mecánica de Evolución y Crecimiento Cooperativo

Los puntos acumulados por los aportes diarios de racha de los miembros determinan directamente el nivel de la mascota del grupo mediante una fórmula matemática simple:

$$\text{Nivel} = \lfloor\frac{\text{Puntos Totales}}{100}\rfloor + 1$$

El progreso se visualiza en una barra de progreso que divide el módulo del total entre 100 para obtener el porcentaje exacto:

$$\text{Progreso} = \frac{\text{Puntos} \pmod{100}}{100.0}$$

### Etapas de Evolución por Nivel:

| Nivel | Planta de Racha (`PLANT`) | Tamagotchi Grupal (`TAMAGOTCHI`) | Etapa |
| :--- | :--- | :--- | :--- |
| **Nivel 1** | Semilla de Racha 🍃 (`spa_rounded`) | Huevo Lingiux 🥚 (`egg_rounded`) | Semilla / Huevo |
| **Nivel 2** | Brote de Racha 🌱 (`grass_rounded`) | Mascota Bebé 🍼 (`child_care_rounded`) | Bebé |
| **Nivel 3** | Planta Joven 🌿 (`eco_rounded`) | Tamagotchi Joven 🐰 (`cruelty_free_rounded`) | Juvenil |
| **Nivel 4+** | Planta Floreciente 🌸 (`local_florist_rounded`) | Dragón Adulto 🐲 (`pets_rounded`) | Adulto |

Al presionar "Aportar Racha", si el usuario no ha realizado su aporte diario, el sistema consulta su racha personal (`streak_count`), la registra en `group_contributions` y le suma el puntaje al grupo, detonando un cuadro de diálogo de felicitaciones con vibración física en el teléfono.

---

## 5. Interactividad de Palabras Cliqueables y Solución al Desbordamiento (Popup Card)

Para habilitar la capacidad de cliquear palabras en los mensajes grupales de forma consistente con los chats individuales, se implementaron soluciones clave de optimización:

### A. Exposición de Componentes
Convertimos las clases de superposición privadas `_OverlayEntrance` en públicas (`OverlayEntrance`) en [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart). Esto permitió a la pantalla de grupo reutilizar todo el código de animaciones complejas, opacidad de fondo e interactividad de la tarjeta flotante sin duplicar código.

### B. Adaptación de `MessageBubble`
El widget [message_bubble.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/widgets/message_bubble.dart) se actualizó para aceptar `senderName` y `senderAvatar`. Cuando se pasan estos campos, el widget añade el avatar circular del miembro emisor a la izquierda y su nombre encima de la burbuja, alineándolos de manera premium en los grupos escolares.

### C. Solución del Desbordamiento ("Bottom Overflowed by 8.0 Pixels")
En la versión inicial, se envolvió el `FlippableCard` dentro de un `SizedBox` con una altura restrictiva de `136.0` (`cardHeight`). 
* El diseño de la tarjeta `WordMiniCardFront` (o `Back`) mide exactamente **`136.0 píxeles`** de alto.
* Sin embargo, `FlippableCard` añade una flecha indicadora (apuntando a la palabra cliqueada) pintada mediante un `CustomPaint` (`ArrowPainter`) que mide exactamente **`8.0 píxeles`** de alto.
* La altura total del widget es de **`144.0 píxeles`** (`136.0` de tarjeta + `8.0` de flecha).
* Al forzar un contenedor de `136.0`, Flutter arrojaba la barra amarilla indicando que faltaban exactamente `8.0 píxeles` de espacio en la parte inferior.
* **Solución:** Removemos el `SizedBox` restrictivo, permitiendo que la tarjeta tome su tamaño natural (`144.0`) de forma elástica tal como en el chat individual.

### D. Habilitación de Gesto de Giro (Swipe to Flip)
Para permitir que la tarjeta flotante pudiera voltearse y mostrar la traducción/significado, se vinculó la propiedad `onHorizontalDragEnd` en el constructor de `OverlayEntrance`:

```dart
onHorizontalDragEnd: (details) {
  if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 200) {
    final swipeRight = details.primaryVelocity! > 0;
    cardController.flip(swipeRight: swipeRight); // Gira la tarjeta 180°
    HapticFeedback.selectionClick();
  }
}
```

---

## 6. Librerías y Dependencias Utilizadas

* **`flutter_riverpod`**: Provee la gestión de estado reactiva en toda la aplicación. Se utilizó `StreamProvider.autoDispose` para escuchar los mensajes y los grupos en tiempo real con Supabase.
* **`supabase_flutter`**: Cliente oficial de Supabase. Conecta las operaciones CRUD de base de datos (`insert`, `select`, `update`) y maneja la replicación en tiempo real a través de WebSockets.
* **`flutter/services`**: Provee acceso a las capacidades de hardware del dispositivo, específicamente `HapticFeedback.vibrate()` y `HapticFeedback.lightImpact()` para la respuesta háptica táctil.
* **`dart:math`**: Utilizada para operaciones matemáticas (ej. calcular el giro de 180° en radianes `math.pi` en la animación 3D de la tarjeta, y para generar índices aleatorios de caché).

---

## 7. Protocolo de Reversión (Desinstalación Completa)

Si en un futuro decides eliminar esta característica para volver al chat tradicional, sigue este plan paso a paso:

### Paso A: Eliminar Tablas en Supabase
Ejecuta la siguiente sentencia SQL en la consola de comandos o editor SQL de Supabase para borrar los esquemas y datos de grupos en cascada:

```sql
DROP TABLE IF EXISTS public.group_contributions CASCADE;
DROP TABLE IF EXISTS public.study_groups CASCADE;
```

### Paso B: Revertir Archivos y Métodos en Flutter

1. **Eliminar archivos creados:**
   ```powershell
   Remove-Item .\lib\features\chat\domain\entities\study_group.dart
   Remove-Item .\lib\features\chat\presentation\screens\group_detail_screen.dart
   ```
2. **Revertir [message_bubble.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/widgets/message_bubble.dart):**
   * Quitar los parámetros opcionales `senderName` y `senderAvatar` del constructor y campos finales de `MessageBubble`.
   * Remover los bloques condicionales `if (!isMe && senderName != null)` en el método `build()` y `_buildSharedCardBubble()`.
3. **Revertir [chat_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart):**
   * Renombrar la clase `OverlayEntrance` de vuelta a privada `_OverlayEntrance`.
4. **Revertir [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart):**
   * Quitar la pestaña de grupos del selector segmentado.
   * Eliminar el floating action button de grupos y la lógica de renderizado del `userGroupsProvider`.
   * Borrar las clases privadas auxiliares `_EmptyGroups`, `_GroupListTile` y `_CreateGroupSheet`.
5. **Revertir [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart):**
   * Quitar los métodos `createGroup`, `inviteMember`, `contributeStreak`, `hasContributedToday`, `getGroupMembers` y `getGroupMembersWithContributions` de la clase `ChatService`.
   * Remover el provider `userGroupsProvider`.
   * Quitar el filtro de IDs de grupos en el fetch de `chatsProvider` para que vuelva a mostrar todas las conversaciones sin discriminación.
