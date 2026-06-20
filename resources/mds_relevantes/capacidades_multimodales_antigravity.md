# Capacidades Multimodales de Antigravity

Este documento describe la capacidad del asistente Antigravity para interpretar y trabajar con diversos formatos de archivo en el espacio de trabajo de **Lingiux**.

## 📋 Resumen de Capacidades de Interpretación

Antigravity cuenta con soporte nativo y herramientas integradas para procesar archivos binarios y multimedia, además de código fuente y archivos de texto.

---

### 🖼️ 1. Imágenes y Capturas de Pantalla
* **Formatos soportados:** PNG, JPG, JPEG, WEBP, GIF, entre otros.
* **Capacidades:**
  * Analizar maquetas de diseño o capturas de Figma para generar código Flutter equivalente.
  * Identificar problemas de alineación, fuentes, colores o consistencia visual en capturas de pantalla de la aplicación.
  * Interpretar diagramas de arquitectura, esquemas de bases de datos o flujos de usuario ilustrados.
  * Analizar capturas de pantalla de errores o consolas de depuración para diagnosticar fallos rápidos.

### 🎥 2. Video y Animación
* **Formatos soportados:** MP4, MOV, WEBM, etc.
* **Capacidades:**
  * Analizar grabaciones de pantalla de la aplicación en ejecución.
  * Seguir y entender flujos de navegación complejos o transiciones de UI/UX animadas para proponer mejoras o identificar comportamientos anómalos.
  * Validar micro-animaciones y el diseño dinámico directamente desde la grabación visual.

### 🎵 3. Audio y Archivos Multimedia
* **Formatos soportados:** MP3, WAV, AAC, etc.
* **Capacidades:**
  * Analizar archivos de audio utilizados en el aprendizaje de idiomas de la app (grabaciones de pronunciación, lecciones de audio, etc.).
  * Ayudar a diagnosticar problemas de integración con servicios de reproducción de audio o servicios locales de almacenamiento de voz.

### 🎨 4. Diseños Propietarios y Bocetos (Figma, Sketch, Dibujos a Mano)
* **Forma de trabajo:** Dado que los formatos crudos propietarios (como archivos `.fig`) no se pueden renderizar directamente de forma nativa en la terminal, el flujo recomendado es:
  1. Tomar una **captura de pantalla** o exportar a imagen (PNG/JPG).
  2. Guardarla en el workspace o proporcionarla como contexto.
  3. Antigravity interpretará la interfaz visual al 100% y la traducirá a la estructura de widgets de Flutter.

### 📄 5. Documentos y PDFs
* **Formatos soportados:** PDF, TXT, MD, CSV, JSON, etc.
* **Capacidades:**
  * Leer y estructurar requerimientos funcionales, guías de diseño de marca, manuales técnicos o documentación de APIs externas.
  * Extraer tablas, configuraciones o especificaciones complejas para implementarlas en código limpio.

---

## 🛠️ Herramienta de Acceso: `view_file`

Para abrir e interpretar cualquiera de estos archivos dentro del workspace de Lingiux, el asistente utiliza la herramienta `view_file`. Esta herramienta autodetecta si el archivo es texto o binario y extrae el contexto visual o multimedia correspondiente para que el modelo pueda razonar sobre él.
