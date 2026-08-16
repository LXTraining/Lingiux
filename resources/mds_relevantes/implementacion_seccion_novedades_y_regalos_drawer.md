# Especificación Técnica: Sección de Novedades y Regalos (Inbox) en la Barra Lateral Izquierda (StreakDrawer) 📬

Este documento detalla la arquitectura, el flujo de interacciones, la estructura de código y la guía de mantenimiento de la sección **"Novedades y Regalos"** implementada en el Drawer izquierdo de la pantalla principal.

---

## 🌿 1. Introducción y Motivación

Anteriormente, el panel lateral izquierdo (`StreakDrawer`) mostraba exclusivamente datos repetitivos de la racha (tarjeta de racha de fuego y un calendario de seguimiento semanal). Debido a que la cabecera superior del feed ya incluye la racha diaria en tiempo real y el seguimiento semanal ya está cubierto, rediseñamos la sección superior del panel para transformarla en un **Buzón de Novedades e Inbox Interactivo** que conecta al usuario con otras mecánicas sociales y de gamificación de la app.

Esta nueva sección introduce:
1.  **Cofre de Regalo Sorpresa (`🎁`):** Una tarjeta premium con degradado violeta que representa físicamente un cofre con gemas virtuales enviadas por otro usuario (Ana Smith). Cuenta con un botón de acción dorado interactivo `ABRIR COFRE (+50 💎)` que, al ser pulsado, ejecuta una vibración háptica, abre el cofre con una animación reactiva de éxito y muestra un SnackBar de recompensa.
2.  **Comentario Detallado de Lección (`💬 Eco`):** Una tarjeta física de comentario que muestra el avatar del usuario que comentó (Sophia), el tiempo, la lección objetivo, una etiqueta con estilo "Eco" y una burbuja de chat estilizada con el comentario textual en itálica: *"¡Me encantó la lección! Es súper interactiva y los ejemplos de audio ayudan muchísimo a pronunciar."*.

A continuación del Buzón, se conserva intacta la sección de **Logros de Racha** (medallas de bronce, plata, oro y corona) con su respectiva barra de progreso.

---

## 📂 2. Archivos y Estructura de Componentes Afectados

Las modificaciones se concentran en:

```text
lib/
└── features/
    └── feed/
        └── presentation/
            └── widgets/
                └── streak_drawer.dart    <--- [MODIFICADO] Convertido a ConsumerStatefulWidget,
                                               se eliminó la tarjeta de racha anterior,
                                               y se agregaron los métodos _buildGiftChestCard
                                               y _buildLessonCommentCard.
resources/
└── mds_relevantes/
    └── implementacion_seccion_novedades_y_regalos_drawer.md <--- [NUEVO] Documentación técnica.
```

---

## ⚙️ 3. Detalles de la Implementación de Código

### A. Conversión a StatefulWidget
Para gestionar la interacción de abrir el cofre de gemas (cambiando el estado del botón a "¡Abierto! +50 Gemas 💎" e inhabilitándolo de manera reactiva), se convirtió `StreakDrawer` de un widget estático a un widget de estado mutable:

```dart
class StreakDrawer extends ConsumerStatefulWidget {
  const StreakDrawer({super.key});

  @override
  ConsumerState<StreakDrawer> createState() => _StreakDrawerState();
}

class _StreakDrawerState extends ConsumerState<StreakDrawer> {
  bool _isGiftClaimed = false; // Controla el estado del cofre de gemas
  ...
```

### B. Tarjeta del Cofre de Regalo (`_buildGiftChestCard`)
Implementa la interfaz física del cofre sorpresa mediante un gradiente premium de morado a índigo y un botón dorado de reclamar:

```dart
Widget _buildGiftChestCard(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Text('🎁', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 12),
        const Text('¡Cofre Sorpresa!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('De Ana Smith para ti', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 16),
        if (!_isGiftClaimed)
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _isGiftClaimed = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎁 ¡Gemas reclamadas! +50 gemas agregadas.'),
                  backgroundColor: Color(0xFFFF6B8B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD000), // Botón Dorado
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_open_rounded, size: 16),
                SizedBox(width: 8),
                Text('ABRIR COFRE (+50 💎)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF4CD9A3), size: 18),
                SizedBox(width: 8),
                Text('¡Abierto! +50 Gemas 💎', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    ),
  );
}
```

### C. Tarjeta del Comentario de Lección (`_buildLessonCommentCard`)
Dibuja el comentario de la lección recreando la interfaz del foro social de Lingiux, con avatar del usuario, la etiqueta "Eco" y una burbuja de chat:

```dart
Widget _buildLessonCommentCard(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 0.8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4F46E5),
              child: const Text('SO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sophia', style: TextStyle(color: AppColors.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 1),
                  const Text('Hace 10 min • Lección "Básico 1"', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 10)),
                ],
              ),
            ),
            // Tag Eco
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('💬 Eco', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '“¡Me encantó la lección! Es súper interactiva y los ejemplos de audio ayudan muchísimo a pronunciar.”',
            style: TextStyle(color: AppColors.onSurface, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
```

---

## 🔄 4. Protocolo de Reversión (Revertir Cambios)

Si deseas desinstalar la sección de buzón y regresar al diseño original de Racha Principal y Calendario Semanal:

### Paso 1: Cambiar el Widget de vuelta a Stateless
1.  Abra [`streak_drawer.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/widgets/streak_drawer.dart).
2.  Defina la clase como `ConsumerWidget`:
    ```dart
    class StreakDrawer extends ConsumerWidget {
      const StreakDrawer({super.key});

      @override
      Widget build(BuildContext context, WidgetRef ref) {
        // ...
      }
    }
    ```

### Paso 2: Restaurar el Contenido y la Racha Semanal
Reemplace el cofre de regalo y el comentario por la tarjeta de racha de fuego y el seguimiento semanal:

```dart
// Racha Principal Card (Coral/Orange Gradient)
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(28),
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RACHA ACTUAL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$streakCount días', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      const Text('🔥', style: TextStyle(fontSize: 42)),
    ],
  ),
),
const SizedBox(height: 28),
const Text('Seguimiento Semanal', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
const SizedBox(height: 12),
_buildWeeklyTracker(streakCount),
const SizedBox(height: 28),
```

### Paso 3: Eliminar Métodos de Inbox
Remueva las funciones `_buildGiftChestCard`, `_buildLessonCommentCard` y el estado booleano `_isGiftClaimed`.
