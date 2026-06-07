# Sistema de Diseño - Lingiux v1.0

## Propósito

Este documento define las reglas visuales, principios de diseño y estándares de interfaz de usuario para Lingiux. 

Todo desarrollador, diseñador o asistente de IA deberá seguir estas reglas al crear nuevas pantallas, componentes o funcionalidades.

El sistema de diseño está inspirado directamente en la estética premium y moderna establecida en el archivo de referencia `referencia_uxuiuni.png`, caracterizada por esquinas extremadamente redondeadas, degradados suaves y el uso de selectores y elementos activos en formato de píldora oscura.

---

# Identidad del Producto

## ¿Qué debe transmitir Lingiux?

Lingiux debe sentirse:

* **Premium e Inmersivo:** Una interfaz de alta fidelidad con acabados limpios y fluidos.
* **Tecnológico y Moderno:** Uso estratégico de degradados sutiles y transparencias.
* **Limpio y Espacioso:** Jerarquía clara con espacios generosos.
* **Inteligente y Enfocado:** Patrones visuales consistentes y directos.
* **Cálido:** Degradados en tonos pastel vibrantes que invitan a la interacción.

---

## ¿Qué NO debe transmitir?

* Infantil o saturado de colores planos estridentes.
* Corporativo tradicional, aburrido o rígido.
* Caótico, desordenado o con bordes toscos.
* Excesivamente contrastado o ruidoso visualmente.

---

# Principios de Diseño

## 1. La claridad es prioridad
El usuario debe identificar inmediatamente el foco de atención. Las palabras y contenidos clave deben tener suficiente espacio y contraste para ser legibles sobre cualquier fondo degradado.

## 2. Consistencia en los Selectores (Píldora Activa)
Los elementos activos seleccionados (como pestañas de navegación inferior, filtros de estado o botones de vista activa) se representarán mediante un contenedor negro sólido en forma de píldora con texto e iconos en color blanco. Los elementos inactivos se mostrarán como texto neutro sin fondo.

## 3. Uso estético de degradados suaves
Los degradados no son decorativos; definen áreas de contenido interactivo o estados destacados (ej. tarjetas de chat, burbujas especiales de conversación o cabeceras). Se deben utilizar las rampas de color pastel definidas en este documento.

## 4. Esquinas ultra-redondeadas (Soft UI)
La interfaz debe evitar esquinas duras o cuadradas. El radio de borde por defecto para tarjetas principales es de `28px` a `32px`, y para botones o píldoras es de `20px` a `24px`.

## 5. Microinteracciones fluidas
Las transiciones de color, aparición de pop-ups y escalas de botones deben ocurrir en un rango de `200ms` a `300ms` con curvas suaves (`Ease Out`), proporcionando retroalimentación inmediata al tacto.

---

# Tema General

## Estrategia
**Light Mode First con Acentos Degradados.**

La interfaz base utilizará fondos claros y limpios (`#F8F9FD`). Las cabeceras principales o pantallas de perfil/vocabulario destacadas pueden adoptar un fondo de degradado completo de color violeta e índigo, utilizando tarjetas blancas con sombreado difuso superpuestas para albergar el contenido.

---

# Paleta de Colores

## Colores Primarios y de Acento

### 1. Gradiente de Marca (Dark Violet)
* **Hex Inicio:** `#815BF5` (Violeta Primario)
* **Hex Fin:** `#5A45FF` (Indigo Principal)
* **Uso:** Encabezados de pantallas destacadas, botones de acciones primarias complejas y acentos institucionales.

### 2. Gradiente Coral (Coral/Orange)
* **Hex Inicio:** `#FF6B8B`
* **Hex Fin:** `#FF8E53`
* **Uso:** Tarjetas de vocabulario de nivel principiante, alertas especiales, o tarjetas de chat con contenidos dinámicos (ej. imágenes o archivos adjuntos).

### 3. Gradiente Celeste (Sky/Teal)
* **Hex Inicio:** `#4FA4F4`
* **Hex Fin:** `#4CD9A3`
* **Uso:** Tarjetas de vocabulario de nivel intermedio, indicadores de éxito o confirmación, y tarjetas de chat temáticas.

### 4. Gradiente Orquídea (Orchid/Pink)
* **Hex Inicio:** `#A258F5`
* **Hex Fin:** `#F558C9`
* **Uso:** Tarjetas de vocabulario de nivel avanzado y detalles destacados de interfaz.

---

## Colores de Estado

* **Éxito / Aprobado:** `#4CD9A3` (Integrado en el degradado Celeste)
* **Advertencia / Alerta:** `#FF8E53` (Integrado en el degradado Coral)
* **Error / Crítico:** `#FF5555`

---

# Colores Base

## Fondo Principal (Light)
* **Hex:** `#F8F9FD`
* **Uso:** Fondo general de la aplicación, feed principal y listados de chats.

## Fondo Secundario
* **Hex:** `#F1F5F9`
* **Uso:** Contenedores de inputs y fondos de elementos deshabilitados.

## Superficie (Surface)
* **Hex:** `#FFFFFF`
* **Uso:** Tarjetas de mensajes recibidos en chat, menús de configuración y modales flotantes.

## Borde / Separadores
* **Hex:** `#EBEFFA`
* **Uso:** Líneas de separación muy sutiles (`1px`) entre celdas o bordes de contenedores claros.

---

# Colores de Texto

## Texto Principal (On Light)
* **Hex:** `#0F172A`
* **Uso:** Títulos, nombres de usuario principales y textos destacados sobre fondos claros.

## Texto Secundario (On Light)
* **Hex:** `#64748B`
* **Uso:** Descripciones secundarias, marcas de tiempo y etiquetas de estado inactivas.

## Texto sobre Degradado (On Gradient / Dark Surfaces)
* **Hex:** `#FFFFFF`
* **Uso:** Texto de títulos, subtítulos e información colocada encima de las tarjetas de degradado o botones negros.

---

# Tipografía

## Fuente Principal
**Inter**

## Fallbacks
* **SF Pro**
* **Roboto**

---

# Escala Tipográfica

## Display Grande
* **Tamaño:** 36
* **Peso:** Bold (700)
* **Uso:** Palabras clave de tarjetas de vocabulario y números grandes de estadísticas.

## Título Principal
* **Tamaño:** 28
* **Peso:** Bold (700)
* **Uso:** Títulos de pantalla (ej. "UI/UX University", "Later").

## Título Secundario
* **Tamaño:** 20
* **Peso:** SemiBold (600)
* **Uso:** Encabezados de secciones secundarias y nombres de usuarios en chats.

## Subtítulo / Texto de Tarjetas
* **Tamaño:** 16
* **Peso:** Medium (500) o Regular (400)
* **Uso:** Mensajes de chat, contenido de definiciones.

## Texto Normal / Cuerpo
* **Tamaño:** 14
* **Peso:** Regular (400)
* **Uso:** Descripciones, textos auxiliares y configuraciones.

## Caption
* **Tamaño:** 12
* **Peso:** Regular (400) o Medium (500)
* **Uso:** Horas de mensajes, tags e indicadores de conteo.

---

# Sistema de Espaciado

Unidad base: `4px`
* **XS:** 4px
* **SM:** 8px
* **MD:** 16px
* **LG:** 20px
* **XL:** 24px
* **XXL:** 32px
* **XXXL:** 48px

---

# Sistema de Bordes (Border Radius)

* **Botones e Inputs:** `16px` o `20px` (Esquinas suavizadas).
* **Píldoras de Selección de Pestañas / Filtros:** `20px` (Formato totalmente redondeado/pill).
* **Tarjetas Medianas (Categorías o Chips de Inicio):** `24px`.
* **Tarjetas Grandes (Mensajes o Contenedores de Listas):** `28px` o `32px` (Borde ultra-redondeado característico del diseño).

---

# Sombras y Elevación

## Sombras de Superficie (Glow & Soft Drop Shadows)
Las sombras deben ser sumamente sutiles y difusas, evitando colores negros puros de alta opacidad.
* **Color de sombra recomendado:** `Color(0x0F0F172A)` (Gris oscuro con baja opacidad) o sombras tintadas con el color del gradiente `Color(0x1A815BF5)` para elementos morados.
* **Radio de desenfoque (*blur*):** `16px` a `24px` con desfase vertical de `4px` a `8px`.

---

# Botones

## Botón Píldora Activo (Selected Tab / Filter)
* **Fondo:** `#000000` o `#0F172A` (Negro sólido)
* **Radius:** `20px` (Pill shape)
* **Color de texto/icono:** `#FFFFFF` (Blanco)
* **Altura:** `38px` a `44px`

## Botón Primario Grande (Acción Principal)
* **Fondo:** Gradiente de Marca (`#815BF5` a `#5A45FF`)
* **Radius:** `16px`
* **Texto:** Blanco, Negrita
* **Altura:** `56px`

---

# Inputs / Buscadores

* **Altura:** `48px` a `52px`
* **Radius:** `24px` (Formato redondeado continuo)
* **Fondo:** `#FFFFFF` con un borde sutil de `#EBEFFA` o un fondo gris suave `#F1F5F9` sin borde.
* **Alineación:** Icono de búsqueda a la izquierda, texto centrado o alineado a la izquierda, e icono de filtro a la derecha.

---

# Cards (Tarjetas)

* **Radius:** `28px` o `32px`
* **Fondo:** Blanco (`#FFFFFF`) con sombra difusa para elementos sobre fondo claro, o fondos degradados pastel para elementos de chat llamativos.
* **Padding interno:** `20px` a `24px`

---

# Navegación Inferior (Bottom Navigation Bar)

* **Altura:** `64px` a `72px`
* **Color de barra:** `#FFFFFF` (Blanco limpio) con sombra superior muy suave o borde superior de `1px` de grosor color `#EBEFFA`.
* **Elemento Activo:** Encapsulado en un contenedor negro tipo píldora (`#000000` o `#0F172A`) con icono blanco y etiqueta de texto blanco.
* **Elemento Inactivo:** Icono outline de grosor `2px` en color `#94A3B8` y etiqueta en color `#94A3B8`.

---

# Iconografía

* **Estilo:** Líneas finas (*Outline*) de grosor constante `2px`.
* **Bibliotecas:** Lucide Icons, Material Symbols (Outline).
* **Consistencia:** No mezclar iconos rellenos con iconos outline en el mismo grupo de control.

---

# Animaciones y Transiciones

* **Transición de Tabs y Microinteracciones:** `200ms` con curva `Curves.easeOut`.
* **Desplazamiento y Apertura de Pantallas:** `300ms` con curva `Curves.easeInOut`.
* **Transición de Pop-up (Overlay):** `250ms` con efecto de escala suave (de `0.95` a `1.0`) y desvanecimiento.

---

# Estados de Carga (Skeletons)

* **Prioridad:** Skeleton loading que replique el contorno ultra-redondeado (`28px` de radio) de las tarjetas.
* **Animación:** Pulso de opacidad de `0.4` a `0.7` con duración de ciclo de `1000ms`.

---

# Reglas para el Asistente de IA (Claude)

* **Estilo visual:** Asegurar el uso de esquinas ultra redondeadas (`28px`-`32px`) en las tarjetas.
* **Colores:** Restringir el diseño a fondos claros, selectores de píldora negros y tarjetas con los degradados suaves indicados (Coral, Celeste, Orquídea, Violeta).
* **Consistencia:** Aplicar el mismo estilo de píldora negra para botones de pestañas activas e indicadores en la barra de navegación inferior.
