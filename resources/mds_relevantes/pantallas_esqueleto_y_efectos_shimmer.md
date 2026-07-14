# Pantallas Esqueleto (Skeleton Screens) y Efectos Shimmer en Flutter

Este documento detalla la especificación de experiencia de usuario (UX), psicología cognitiva del tiempo de espera, impacto en el rendimiento de la GPU y la guía de implementación práctica para sustituir los indicadores de carga circulares (*spinners*) por maquetas animadas de pre-carga (Skeleton Screens / Shimmer) en Lingiux.

---

## 🧠 1. Psicología Cognitiva de la UX: ¿Por qué es superior al Spinner?

En el desarrollo de aplicaciones móviles de alto nivel, la **percepción del tiempo** del usuario es tan importante como el tiempo de carga real de la base de datos.

*   **El problema del Spinner (`CircularProgressIndicator`)**: Un indicador circular dando vueltas en una pantalla vacía le grita al usuario: *"¡Estás esperando! Mira este cargador en lo que responde el servidor"*. Esto enfoca la atención del usuario en el tiempo transcurrido, incrementando la ansiedad cognitiva y haciendo que la carga parezca un 40% más lenta de lo que es en realidad.
*   **La solución del Skeleton Screen (Pantalla Esqueleto)**: Al dibujar de manera inmediata siluetas grises que imitan la estructura del contenido final (un círculo para la foto de perfil, líneas rectangulares redondeadas para los textos), el usuario percibe que la aplicación ya cargó sus cimientos y que el contenido real está a punto de aparecer.
*   **El Shimmer (Barrido Metálico)**: Aplicar un brillo metálico diagonal animado que se desplaza de izquierda a derecha de forma infinita indica visualmente que la aplicación está activa y procesando la consulta en tiempo real, evitando la sensación de que la interfaz está congelada.

---

## 🛠️ 2. Guía de Implementación Práctica en Flutter

La forma profesional de construir este efecto en Flutter es utilizando el paquete oficial de la comunidad **`shimmer`** (añadiendo `shimmer: ^3.0.0` a tu archivo `pubspec.yaml`).

### Código Fuente de Ejemplo de una Celda de Chat Esqueleto:

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ChatListTileSkeleton extends StatelessWidget {
  const ChatListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[350]!,      // Color gris de las siluetas base
      highlightColor: Colors.grey[100]!, // Color del brillo que se desplaza
      period: const Duration(milliseconds: 1500), // Velocidad de la animación
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            // 1. Silueta circular del avatar de usuario
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 15),
            // 2. Siluetas del nombre de usuario y el último mensaje
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Silueta para el Nombre
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Silueta para el mensaje descriptivo
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ⚡ 3. Impacto en el Rendimiento del Dispositivo (GPU vs. CPU)

*   **Costo de Renderizado Mínimo**: El efecto Shimmer utiliza una máscara de mezcla lineal (*Linear Gradient Blending*) que se calcula directamente en la GPU (hardware gráfico) mediante shaders pre-compilados de Skia/Impeller.
*   **Buenas Prácticas de Optimización**:
    1.  **Destrucción del Widget**: En cuanto la llamada asíncrona a la base de datos (Supabase) responda con datos reales, debes retirar el widget `Shimmer` del árbol y pintar el widget definitivo. Mantener el bucle de animación de Shimmer ejecutándose de fondo en un widget invisible consumirá innecesariamente ciclos de reloj de la GPU.
    2.  **Límite en Listas Infinitas**: Si muestras una lista de elementos en precarga, dibuja únicamente los primeros 5 o 6 esqueletos que caben dentro del área visible de la pantalla (*Viewport*). No renderices esqueletos para elementos que están ocultos en el scroll.

---

## 📐 4. ¿En qué Partes Implementarlo y en Cuáles No?

### ✅ Dónde SÍ implementarlo:
*   **Bandejas de Entrada y Listados**: La pantalla principal de chats (`ChatsListScreen`). Es el lugar perfecto porque el usuario sabe exactamente qué tipo de estructura está esperando recibir.
*   **Pantallas de Detalle e Información**: Al cargar los datos de una tarjeta de vocabulario (`WordDetailScreen`) o el perfil del usuario (`ProfileScreen`).
*   **Mazos de Cartas**: Mientras el algoritmo carga las palabras programadas para estudio diario.

### ❌ Dónde NO implementarlo:
*   **Consultas a Caché Local (<100 ms)**: Si el dispositivo lee los datos desde una base de datos local rápida (`SharedPreferences` o `SQLite` local) en menos de 100 milisegundos, mostrar el Shimmer creará un "parpadeo" visual sumamente molesto. En estos casos, es preferible no mostrar ningún cargador o retrasar el Shimmer con un temporizador (*delayed future*) de 150 ms para que solo se muestre en conexiones muy lentas.
*   **Botones y Formularios Cortos**: Para acciones instantáneas como "Iniciar Sesión" o "Enviar Mensaje", es preferible usar un spinner embebido pequeño dentro del propio botón para no deformar la estructura del formulario.

---

## 🔄 5. Alternativas Profesionales de Carga

1.  **Skeletons Estáticos (Sin Animación)**: Siluetas grises fijas sin barrido de brillo. Su impacto en rendimiento es del 0% y proporciona sobriedad a la aplicación.
2.  **BlurHash (Mosaicos Desenfocados)**: Excelente para imágenes de perfil y portadas. Permite guardar en base de datos un string corto que codifica los colores de la foto, renderizando una versión difuminada suave y hermosa mientras se descarga la imagen final de internet.
3.  **Transiciones de Desvanecimiento (Fade-In)**: Cuando la información cargada reemplace al esqueleto, utiliza un widget de transición animada (`AnimatedSwitcher` o `FadeTransition`) de 200 ms para suavizar el intercambio de interfaces y evitar cambios bruscos en pantalla.

---

## 📂 6. Estado de la Implementación en Lingiux

*   **Estado**: **Implementado con Éxito** en la pantalla principal de mensajes (`ChatsListScreen`).
*   **Aproximación Técnica**: Implementamos el efecto Shimmer de forma **100% nativa y offline** mediante un `ShaderMask` animado con un `LinearGradient` deslizante en la GPU (`_ShimmerLoading`). Esto elimina la dependencia de librerías externas (evitando errores de conexión o incompatibilidades en el entorno de compilación) y mantiene el binario final de la aplicación sumamente ligero.
*   **Archivos Modificados**:
    *   [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart): Sustituido el `CircularProgressIndicator` central por una lista de 6 elementos esqueleto (`_ChatListTileSkeleton`) que replican la estructura real de los chats con la animación fluida de barrido.
