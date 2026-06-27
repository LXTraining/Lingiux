# 🎨 Banderas SVG Vectoriales y Rediseño de Interfaz en el Editor de Tarjetas

Este documento detalla la reingeniería visual y de experiencia de usuario (UX) aplicada al primer paso del editor de tarjetas de Lingiux. Explica la elección del formato vectorial para las banderas de idiomas, incluye el código fuente XML de los gráficos diseñados y describe la resolución del bug crítico de desbordamiento horizontal de pantalla (RenderFlex Overflow).

---

## 🗺️ 1. Elección Tecnológica: Banderas en Formato Vectorial (SVG)

Para diseñar el selector de idiomas en el editor de tarjetas, los profesionales de desarrollo móvil evalúan tres opciones de recursos visuales:

| Formato | Pros | Contras | Recomendación |
| :--- | :--- | :--- | :--- |
| **Emojis Unicode** | Peso cero. Carga inmediata sin dependencias de red. | Inconsistencia extrema (iOS y Android usan familias de fuentes distintas). No se renderizan en Windows (muestra texto como `US` o `MX`), afectando la portabilidad web/escritorio. Cero control de diseño (no se les puede redondear esquinas o poner bordes). | **Descartado** para interfaces de nivel comercial. |
| **Imágenes de Mapa de Bits (PNG/WebP)** | Consistencia visual multiplataforma. | Se pixelan o distorsionan en pantallas de alta densidad (Retina, AMOLED) a menos que se carguen en resoluciones duplicadas (@2x, @3x). Añaden peso muerto innecesario al instalable de la app. | **Descartado** para iconos sencillos. |
| **Gráficos Vectoriales (SVG)** | Escalabilidad infinita sin pérdida de nitidez. Consistencia absoluta en cualquier sistema operativo. Peso ultra reducido (<1 KB por archivo). Control total sobre la estética (se pueden redondear con `ClipRRect` y añadir sombras). | Requiere instalar una biblioteca de renderizado vectorial (`flutter_svg`). | **Seleccionado** como el estándar premium de la industria. |

---

## 💻 2. Código Fuente XML Geométrico de las Banderas Creadas

Las banderas fueron diseñadas a mano utilizando código XML limpio de formas vectoriales de la especificación SVG, almacenadas en la ruta `assets/flags/`. Al no contener datos de metadatos complejos ni paths redundantes, su renderizado en caliente en Flutter es instantáneo:

### A. 🇲🇽 México (`mx.svg`)
Diseño de tres franjas verticales con una composición simplificada del escudo nacional en el centro usando círculos concéntricos y curvas bezier estilizadas para máxima visibilidad en tamaño miniatura:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 21 12">
  <rect width="7" height="12" fill="#006847"/>
  <rect x="7" width="7" height="12" fill="#FFF"/>
  <rect x="14" width="7" height="12" fill="#C8102E"/>
  <circle cx="10.5" cy="6" r="1.5" fill="#8B5A2B"/>
  <circle cx="10.5" cy="5.5" r="0.8" fill="#1E5631"/>
  <path d="M 9.5 7.5 Q 10.5 8.5 11.5 7.5" fill="none" stroke="#D09B00" stroke-width="0.4"/>
</svg>
```

### B. 🇺🇸 Estados Unidos / Inglés (`us.svg`)
Compuesto por 13 franjas rojas y blancas, cantón azul marino en la esquina superior izquierda, y un arreglo de estrellas representadas como puntos blancos circulares (`<circle>`) de alta legibilidad a escala de icono:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 26 14">
  <rect width="26" height="14" fill="#B22234"/>
  <rect y="1.07" width="26" height="1.07" fill="#FFF"/>
  <rect y="3.23" width="26" height="1.07" fill="#FFF"/>
  <rect y="5.38" width="26" height="1.07" fill="#FFF"/>
  <rect y="7.53" width="26" height="1.07" fill="#FFF"/>
  <rect y="9.69" width="26" height="1.07" fill="#FFF"/>
  <rect y="11.84" width="26" height="1.07" fill="#FFF"/>
  <rect width="10.4" height="7.53" fill="#3C3B6E"/>
  <circle cx="1.7" cy="1.2" r="0.25" fill="#FFF"/>
  <circle cx="3.4" cy="1.2" r="0.25" fill="#FFF"/>
  <circle cx="5.2" cy="1.2" r="0.25" fill="#FFF"/>
  <circle cx="7.0" cy="1.2" r="0.25" fill="#FFF"/>
  <circle cx="8.7" cy="1.2" r="0.25" fill="#FFF"/>
  <circle cx="2.5" cy="2.5" r="0.25" fill="#FFF"/>
  <circle cx="4.3" cy="2.5" r="0.25" fill="#FFF"/>
  <circle cx="6.1" cy="2.5" r="0.25" fill="#FFF"/>
  <circle cx="7.8" cy="2.5" r="0.25" fill="#FFF"/>
  <circle cx="1.7" cy="3.8" r="0.25" fill="#FFF"/>
  <circle cx="3.4" cy="3.8" r="0.25" fill="#FFF"/>
  <circle cx="5.2" cy="3.8" r="0.25" fill="#FFF"/>
  <circle cx="7.0" cy="3.8" r="0.25" fill="#FFF"/>
  <circle cx="8.7" cy="3.8" r="0.25" fill="#FFF"/>
  <circle cx="2.5" cy="5.0" r="0.25" fill="#FFF"/>
  <circle cx="4.3" cy="5.0" r="0.25" fill="#FFF"/>
  <circle cx="6.1" cy="5.0" r="0.25" fill="#FFF"/>
  <circle cx="7.8" cy="5.0" r="0.25" fill="#FFF"/>
  <circle cx="1.7" cy="6.3" r="0.25" fill="#FFF"/>
  <circle cx="3.4" cy="6.3" r="0.25" fill="#FFF"/>
  <circle cx="5.2" cy="6.3" r="0.25" fill="#FFF"/>
  <circle cx="7.0" cy="6.3" r="0.25" fill="#FFF"/>
  <circle cx="8.7" cy="6.3" r="0.25" fill="#FFF"/>
</svg>
```

### C. 🇮🇹 Italia (`it.svg`)
Franjas verticales simétricas de color verde, blanco y rojo:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 9 6">
  <rect width="3" height="6" fill="#009246"/>
  <rect x="3" width="3" height="6" fill="#FFF"/>
  <rect x="6" width="3" height="6" fill="#C11B17"/>
</svg>
```

### D. 🇩🇪 Alemania (`de.svg`)
Franjas horizontales de color negro, rojo y oro:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5 3">
  <rect width="5" height="1" fill="#000"/>
  <rect y="1" width="5" height="1" fill="#D00"/>
  <rect y="2" width="5" height="1" fill="#FFCE00"/>
</svg>
```

### E. 🇫🇷 Francia (`fr.svg`)
Franjas verticales de color azul, blanco y rojo:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 9 6">
  <rect width="3" height="6" fill="#002395"/>
  <rect x="3" width="3" height="6" fill="#FFF"/>
  <rect x="6" width="3" height="6" fill="#ED2939"/>
</svg>
```

### F. 🇧🇷 Brasil (`br.svg`)
Fondo verde botella con rombo amarillo central, esfera azul marino y un trazo de curva blanca estilizada representando la banda de la constelación:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 7">
  <rect width="10" height="7" fill="#009739"/>
  <polygon points="5,0.7 9.2,3.5 5,6.3 0.8,3.5" fill="#FFDF00"/>
  <circle cx="5" cy="3.5" r="1.6" fill="#002776"/>
  <path d="M 3.6,3.8 Q 5,3.2 6.4,3.5" fill="none" stroke="#FFF" stroke-width="0.3"/>
</svg>
```

---

## 🛠️ 3. Rediseño del Asistente y Resolución del RenderFlex Overflow

Para alinear el primer paso del editor de tarjetas a la maqueta manual provista por el usuario, se realizó una reestructuración de la distribución de componentes:

### A. Estructura de Fila Horizontal (Row)
* El input de texto de la palabra y el selector de idioma se colocaron horizontalmente mediante un widget `Row`.
* El input de la palabra se envolvió en un `Expanded` para ocupar el espacio dinámico izquierdo de la pantalla.
* Se agregó un `suffixIcon` de check verde (`Icons.check_circle_rounded`) que se activa dinámicamente cuando el input de texto contiene caracteres válidos, mejorando el feedback visual del asistente.

### B. Corrección de Bug de Desbordamiento (RenderFlex Overflow)
* **El Problema:** El botón de idioma es ultra-compacto por diseño (solo muestra la bandera del país seleccionado en la cabecera). Sin embargo, al desplegarse el menú, Flutter intentaba renderizar los `DropdownMenuItem` (los cuales contenían bandera de 22px + espaciado de 10px + texto de idioma completo como "Portugués") forzándolos a ajustarse al ancho mínimo implícito de la cabecera (~60px), lo que causaba un desbordamiento horizontal de 16 píxeles a la derecha arrojando la cinta roja de excepción.
* **La Solución:**
  1. Envolvimos la columna del dropdown en un widget **`SizedBox(width: 105)`** para asegurar un ancho fijo cómodo tanto para la cabecera como para la lista del menú desplegable.
  2. Añadimos la propiedad **`isExpanded: true`** en el `DropdownButton` para que se estire al máximo de los 105px disponibles.
  3. En cada item del menú, envolvemos el widget de texto en un **`Expanded`** y aplicamos **`overflow: TextOverflow.ellipsis`**. Esto garantiza que si el nombre de un idioma excede el límite físico del dropdown, este se recorte con puntos suspensivos en lugar de desbordar la pantalla del dispositivo.

```dart
// Lado Derecho: Idioma (Compacto, sólo bandera + flecha)
SizedBox(
  width: 105, // Ancho fijo garantizado para evitar RenderFlex overflow
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Idioma', style: TextStyle(...)),
      const SizedBox(height: 8),
      Container(
        height: 52,
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.selectedLanguage,
            isExpanded: true, // Estira al ancho del contenedor
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.onSurfaceMuted),
            onChanged: widget.onLanguageChanged,
            selectedItemBuilder: (BuildContext context) {
              return _languages.map<Widget>((String lang) {
                final flagAsset = _languageFlags[lang] ?? 'assets/flags/us.svg';
                return Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SvgPicture.asset(flagAsset, width: 28, height: 20, fit: BoxFit.cover),
                  ),
                );
              }).toList();
            },
            items: _languages.map((lang) {
              final flagAsset = _languageFlags[lang] ?? 'assets/flags/us.svg';
              return DropdownMenuItem<String>(
                value: lang,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SvgPicture.asset(flagAsset, width: 22, height: 16, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Expanded( // Trunca textos largos para evitar overflow en el popup
### B. Caja Unificada e Integrada (Palabra + Idioma)
* **El Problema Inicial:** El botón de idioma era un contenedor separado, lo cual provocaba un aspecto discontinuo en el formulario y causaba el desbordamiento RenderFlex.
* **La Solución Unificada:**
  * Creamos un solo contenedor de entrada estilo barra de búsqueda unificada `Container(borderRadius: BorderRadius.circular(24))`.
  * A la izquierda se inserta el `TextFormField` sin bordes visibles (`InputBorder.none`).
  * En medio se añade un separador vertical sutil (`Container` de ancho `1px` y color de borde atenuado).
  * A la derecha se coloca el `DropdownButtonHideUnderline` con la bandera del idioma seleccionado y la flecha hacia abajo.
  * Esto unifica la entrada y el selector en una única barra Soft UI integrada.

### C. Animación de Carta Vacía (Oscilación a 35 Grados)
* Se integró una simulación de tarjeta de memoria vacía (`width: 130`, `height: 190`) con un gradiente sutil y un icono central púrpura.
* Mediante un `AnimationController` repetitivo en auto-reversa y `Transform.rotate` la carta oscila suavemente en el eje Z de izquierda a derecha (entre `-0.6` y `0.6` radianes, equivalentes a aproximadamente **35 grados**), dotando de dinamismo a la pantalla inicial del asistente.

### D. Botón de Verificación Redondo
* Se colocó un botón circular de verificación púrpura (`width: 60`, `height: 60`) con un icono de check (`Icons.check_rounded`) de color blanco en el centro, simulando la acción futura de verificar la existencia semántica del término.

### E. Reubicación de Campos (Paso 2)
* Los campos de **Categoría gramatical**, **Pronunciación Fonética** y el **Grabador de Audio de voz** fueron reubicados al Paso 2 (`StepWordMnemonics`) para mantener el Paso 1 enfocado exclusivamente en la palabra, su idioma, la carta animada y el botón de verificación rápida.

---

## 📂 4. Inventario de Archivos Editados y Creados

* 🛠️ [pubspec.yaml](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/pubspec.yaml): Incorporación de la dependencia `flutter_svg: ^2.0.10` y registro del directorio `assets/flags/`.
* 🛠️ [create_card_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/screens/create_card_screen.dart): Reubicación de parámetros de estado para instanciar correctamente `StepWordIdentity` y `StepWordMnemonics`.
* 🛠️ [step_word_identity.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_identity.dart): Rediseño del primer paso con animación, input de barra unificada y botón redondo de check.
* 🛠️ [step_word_mnemonics.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/create_card/presentation/widgets/step_word_mnemonics.dart): Integración de los campos de Categoría, Fonética y Grabadora de Audio reubicados, junto con la nemotecnia original.
* 📂 **Assets de Banderas Creadas:**
  * [mx.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/mx.svg) (México)
  * [us.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/us.svg) (EE.UU.)
  * [it.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/it.svg) (Italia)
  * [de.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/de.svg) (Alemania)
  * [fr.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/fr.svg) (Francia)
  * [br.svg](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/assets/flags/br.svg) (Brasil)
