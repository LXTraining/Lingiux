# Arquitectura e Implementación: Barra Superior de Gamificación (Header Stats) e Interfaces Modales 📊

Este documento técnico describe de manera exhaustiva el diseño, la implementación, las dependencias y el protocolo de mantenimiento de la **Barra Superior de Gamificación** en la pantalla principal (**FeedScreen**) de Lingiux.

---

## 🌿 1. Introducción y Justificación del Diseño

Para incrementar el engagement de los usuarios (retención diaria) y dotar a la aplicación de un diseño de vanguardia similar a referentes como Duolingo, se reemplazó la cabecera estándar de la AppBar (que contenía únicamente el título "INICIO" y una campana de notificaciones) por un **Panel de Estadísticas de Gamificación** interactivo y responsive.

Este panel expone en tiempo real cinco métricas clave que rigen el ecosistema de aprendizaje de la aplicación:
1.  **Selector de Idioma:** Muestra la bandera del curso activo (ej. `🇺🇸` o `🇩🇪`) con retroalimentación para alternar cursos.
2.  **Racha Diaria (`🔥`):** Días continuos de estudio. Es de lectura directa de la base de datos Supabase (`streak_count`).
3.  **Moneda Virtual (`💎`):** Balance de gemas del estudiante. Se enlaza conceptualmente con la tienda de accesorios para la mascota (Tamagotchi).
4.  **Vidas / Energía (`❤️`):** Barra de vidas disponibles para realizar lecciones. La comisión de errores en los cuestionarios resta vidas, y estas se regeneran con el tiempo o mediante lecciones de repaso.
5.  **Puntos de Experiencia (`⚡`):** Nivel acumulado de esfuerzo (XP) del usuario. Se vincula con el sistema de clasificaciones semanales (Ligas).

---

## 📂 2. Estructura del Proyecto y Archivos Afectados

Las modificaciones se concentran de forma modular en la pantalla principal del feed:

```text
lingiux_app/
├── lib/
│   └── features/
│       └── feed/
│           └── presentation/
│               └── screens/
│                   └── feed_screen.dart      <--- [MODIFICADO] Implementa el diseño de la AppBar,
│                                                   las funciones _buildAppBarStat y las ventanas
│                                                   modales _showLanguageSelectorBottomSheet, etc.
└── resources/
    └── mds_relevantes/
        └── arquitectura_stats_header_gamificacion_feedscreen.md <--- [NUEVO] Este manual técnico
```

### Librerías y Servicios Utilizados
*   **`package:flutter/material.dart`:** Proporciona el componente `AppBar`, las alineaciones horizontales `Row` y las hojas inferiores de diálogo `showModalBottomSheet`.
*   **`package:flutter/services.dart`:** Utiliza la API del sistema operativo para detonar retroalimentación háptica (`HapticFeedback.lightImpact()` y `HapticFeedback.mediumImpact()`) en cada pulsación.
*   **`profileProvider` (Riverpod):** Proporciona la consulta reactiva del perfil del usuario logueado en Supabase, extrayendo las columnas `streak_count` y `target_language`.

---

## ⚙️ 3. Especificaciones Técnicas e Implementación Código a Código

### A. Estructura del Header en la AppBar
La fila de estadísticas se coloca en la propiedad `title` de la `AppBar`. Para garantizar que se expanda horizontalmente y ocupe todo el ancho de la cabecera, se eliminaron los widgets del parámetro `actions` de la AppBar, dándole un ancho completo al contenedor:

```dart
appBar: AppBar(
  leading: Builder( ... ), // Avatar del perfil y cajón de navegación (Drawer)
  title: Builder(
    builder: (context) {
      final profile = ref.watch(profileProvider).value;
      final streakCount = profile?['streak_count'] as int? ?? 0;
      final targetLanguage = profile?['target_language'] as String? ?? 'Inglés';
      final flag = targetLanguage == 'Alemán' ? '🇩🇪' : '🇺🇸';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selector de Idioma
          GestureDetector(
            onTap: () => _showLanguageSelectorBottomSheet(context, targetLanguage),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.7), size: 14),
              ],
            ),
          ),
          // Racha (Fuego)
          _buildAppBarStat(
            icon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9600), size: 20),
            value: '$streakCount',
            onTap: () => _showStreakBottomSheet(context, streakCount),
          ),
          // Gemas (Diamante)
          _buildAppBarStat(
            icon: const Icon(Icons.diamond_rounded, color: Color(0xFF00D2FF), size: 20),
            value: '350',
            onTap: () => _showGemsBottomSheet(context),
          ),
          // Vidas (Corazón)
          _buildAppBarStat(
            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4B4B), size: 20),
            value: '5',
            onTap: () => _showLivesBottomSheet(context),
          ),
          // XP (Rayo)
          _buildAppBarStat(
            icon: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD000), size: 20),
            value: '1.2k',
            onTap: () => _showXPBottomSheet(context),
          ),
        ],
      );
    },
  ),
  actions: const [], // Elimina la campana de notificaciones para dar espacio
)
```

El constructor de cada métrica `_buildAppBarStat` optimiza el renderizado y centraliza las vibraciones hápticas en un solo lugar:
```dart
Widget _buildAppBarStat({
  required Widget icon,
  required String value,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ],
    ),
  );
}
```

---

### B. Diseño Detallado de las Hojas de Diálogo Táctiles (Modals)

Cada métrica superior es pulsable y despliega una ventana modal interactiva desde el borde inferior de la pantalla:

#### 1. Selector de Idioma (`_showLanguageSelectorBottomSheet`)
*   **Contenido:** Muestra una lista de cursos. El idioma activo se renderiza con un fondo translúcido violeta (`Color(0xFF7C3AED).withValues(alpha: 0.08)`) y borde marcado de `1.5` de grosor con un checkmark verde.
*   **Acción:** Cuenta con un botón inferior para "+ Agregar Curso" que simboliza la expansión de catálogo de aprendizaje.

#### 2. Racha de Aprendizaje (`_showStreakBottomSheet`)
*   **Contenido:** Un icono grande de llama naranja con la estadística numérica de días continuos.
*   **Calendario Semanal:** Muestra los días de la semana actual con pequeños círculos grises. El día de hoy (Sábado) se resalta con color naranja vivo y el icono de fuego para simular que la racha del día actual ya se ha completado y está activa.

#### 3. Moneda del Juego (`_showGemsBottomSheet`)
*   **Contenido:** Un diamante azul turquesa.
*   **Propósito:** Explica el uso de la moneda en la tienda para comprar accesorios para el Tamagotchi (juguetes, comida, gorros). Esto fomenta la conexión cruzada de funcionalidades dentro del ecosistema de Lingiux.

#### 4. Barra de Energía/Vidas (`_showLivesBottomSheet`)
*   **Contenido:** Un corazón rojo.
*   **Propósito:** Detalla el mecanismo de vidas (5/5). Si el usuario comete un error en las lecciones, restará una vida. Las vidas se regeneran automáticamente (1 vida cada 4 horas) o practicando lecciones de repaso de su vocabulario.

#### 5. Puntos de Esfuerzo (`_showXPBottomSheet`)
*   **Contenido:** Un rayo amarillo.
*   **Propósito:** Muestra los puntos totales acumulados (1.2k) y los vincula con el sistema competitivo de ligas semanales contra la comunidad.

---

## 🔄 4. Protocolo de Reversión (Desinstalación Completa)

Si en el futuro se decide remover esta funcionalidad superior y volver al diseño de cabecera estándar de Lingiux:

### Paso 1: Revertir la Cabecera de la AppBar
Abra [`feed_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/feed/presentation/screens/feed_screen.dart), localice el widget `AppBar` y reemplace sus propiedades `title` y `actions` por su código original:

```diff
-              title: Builder(
-                builder: (context) {
-                  final profile = ref.watch(profileProvider).value;
-                  final streakCount = profile?['streak_count'] as int? ?? 0;
-                  final targetLanguage = profile?['target_language'] as String? ?? 'Inglés';
-                  final flag = targetLanguage == 'Alemán' ? '🇩🇪' : '🇺🇸';
-
-                  return Row(
-                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
-                    children: [
-                      GestureDetector(
-                        onTap: () => _showLanguageSelectorBottomSheet(context, targetLanguage),
-                        child: Row(
-                          mainAxisSize: MainAxisSize.min,
-                          children: [
-                            Text(flag, style: const TextStyle(fontSize: 16)),
-                            const SizedBox(width: 2),
-                            Icon(
-                              Icons.keyboard_arrow_down_rounded,
-                              color: Colors.white.withValues(alpha: 0.7),
-                              size: 14,
-                            ),
-                          ],
-                        ),
-                      ),
-                      _buildAppBarStat(
-                        icon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9600), size: 20),
-                        value: '$streakCount',
-                        onTap: () => _showStreakBottomSheet(context, streakCount),
-                      ),
-                      _buildAppBarStat(
-                        icon: const Icon(Icons.diamond_rounded, color: Color(0xFF00D2FF), size: 20),
-                        value: '350',
-                        onTap: () => _showGemsBottomSheet(context),
-                      ),
-                      _buildAppBarStat(
-                        icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4B4B), size: 20),
-                        value: '5',
-                        onTap: () => _showLivesBottomSheet(context),
-                      ),
-                      _buildAppBarStat(
-                        icon: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD000), size: 20),
-                        value: '1.2k',
-                        onTap: () => _showXPBottomSheet(context),
-                      ),
-                    ],
-                  );
-                },
-              ),
-              actions: const [],
+              title: const Text(AppStrings.navInicio),
+              actions: [
+                IconButton(
+                  icon: const Icon(Icons.notifications_outlined),
+                  onPressed: () {},
+                ),
+              ],
```

### Paso 2: Eliminar Funciones Auxiliares
Remueva del cuerpo de `_FeedScreenState` los siguientes métodos auxiliares de estadísticas y bottom sheets:
*   `_buildAppBarStat`
*   `_showLanguageSelectorBottomSheet`
*   `_buildLanguageItem`
*   `_showStreakBottomSheet`
*   `_showGemsBottomSheet`
*   `_showLivesBottomSheet`
*   `_showXPBottomSheet`

### Paso 3: Limpiar Archivos de Especificación
Elimine el archivo de documentación [`arquitectura_stats_header_gamificacion_feedscreen.md`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/resources/mds_relevantes/arquitectura_stats_header_gamificacion_feedscreen.md) del disco.
