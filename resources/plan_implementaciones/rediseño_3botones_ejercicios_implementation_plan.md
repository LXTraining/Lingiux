# Plan de Implementación: Mejoras Estéticas y de Validación en el Quiz del Editor

Este plan detalla el rediseño y las nuevas validaciones para la sección de auto-quiz en el creador de tarjetas de **Lingiux**.

---

## 🎨 1. Rediseño de Botonera de Tipo de Ejercicio
Reemplazaremos la barra de pestañas alargada por **tres botones cuadrados y estéticos**, alineados horizontalmente.

```
+-------------+  +-------------+  +-------------+
|   [Icono]   |  |   [Icono]   |  |   [Icono]   |
|  Pregunta   |  |  Acomodar   |  |  Completar  |
+-------------+  +-------------+  +-------------+
```

*   **Aparición Visual**: Cada botón tendrá un contenedor cuadrado con bordes redondeados (`16px`), un icono representativo y la etiqueta abajo.
*   **Colores de Estado**:
    *   *Seleccionado*: Fondo negro, letras e icono en blanco.
    *   *No Seleccionado (Habilitado)*: Fondo gris claro translúcido, bordes definidos, letras e icono en gris oscuro.
    *   *Desactivado (Bloqueado)*: Fondo gris muy atenuado, letras opacas al 25% y un pequeño candado (`Icons.lock_rounded`) en la esquina superior derecha.

---

## 🔒 2. Lógica de Activación Condicional (Botones Desactivados)
Para evitar que se guarden ejercicios rotos, se desactivarán las opciones según la información que tenga la tarjeta en tiempo real:

1.  **Pregunta (True/False)** y **Completar**:
    *   *Requisito*: Que el usuario haya ingresado la frase de ejemplo en la pestaña "Contenido".
    *   *Si no se cumple*: El botón se mostrará bloqueado. Al tocarlo, un SnackBar sutil le informará: *"Escribe primero una frase de ejemplo en la pestaña Contenido."*
2.  **Acomodar**:
    *   *Requisito*: Que el usuario haya ingresado la frase de ejemplo **Y** haya grabado la pronunciación de voz en la pestaña "Multimedia".
    *   *Si no se cumple*: El botón se mostrará bloqueado. Al tocarlo, el SnackBar le informará: *"Requiere escribir una frase de ejemplo y grabar tu pronunciación de voz."*

---

## ➕ 3. Gestión Interactiva de Distractores (Sin Comas)
En lugar de una caja de texto gigante donde se escriben palabras separadas por comas, crearemos un listado dinámico con límite de hasta 3 distractores:

1.  **Visualización**: Un Wrap horizontal de Chips interactivos que muestran los distractores agregados actualmente. Cada chip tiene un botón de eliminar `(x)`.
2.  **Entrada**:
    *   Una fila con un `TextField` compacto y un botón **"Añadir"** al lado.
    *   Al tocar "Añadir" o presionar enter, se valida:
        *   Que no esté vacío.
        *   Que no esté repetido.
        *   Que no exceda el límite de 3 distractores.
    *   Si se llega a 3, el campo de texto se deshabilita mostrando el texto *"Límite alcanzado (máx 3)"*.

---

## ❓ Preguntas Abiertas para el Usuario

> [!NOTE]
> 1. **Completar Distractores Mínimos**: Para el tipo **Completar**, ¿obligamos a que se agreguen al menos 2 distractores antes de poder guardar la tarjeta (para que el quiz tenga al menos 3 opciones)?
> 2. **Candado e Iconos**: ¿Te parece bien usar los siguientes iconos de Flutter?
>    *   Pregunta: `Icons.help_outline_rounded`
>    *   Acomodar: `Icons.sort_rounded`
>    *   Completar: `Icons.space_bar_rounded`
