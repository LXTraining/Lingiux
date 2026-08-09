# Curso Rive: Mi Primera Animación (Círculo Latidor)

Este documento es una guía paso a paso, en puntos breves de máximo dos renglones, para recrear la animación inicial desde que se abre el software por primera vez.

*   **Crear el Archivo**: Abre Rive, haz clic en `New File` en la esquina superior derecha, selecciona `Blank Document` y pulsa `Create`.
*   **Crear el Artboard**: Presiona la tecla `A`, haz clic y arrastra en el lienzo para crear un área de trabajo de tamaño predeterminado (`500x500`).
*   **Dibujar la Figura**: Selecciona la herramienta Elipse presionando la tecla `O`, haz clic y arrastra dentro del Artboard manteniendo presionado `Shift` para hacer un círculo perfecto.
*   **Darle Color**: En la barra lateral derecha, ve a la sección `Fills and Strokes`, haz clic en el color por defecto (`#747474`) y elige un color rojo llamativo.
*   **Pasar al Modo de Animación**: Haz clic en la pestaña `Animate` en la esquina superior derecha (o presiona la tecla `Tab`) para habilitar la línea de tiempo de la animación.
*   **Abrir la Línea de Tiempo**: Haz doble clic rápido sobre el nodo gris `Timeline 1` en el panel de nodos inferior para desplegar la regla de fotogramas.
*   **Seleccionar el Círculo**: Haz clic sobre la figura roja en el lienzo o selecciona la capa `Ellipse` en la lista de capas de la izquierda (`Hierarchy`).
*   **Fijar el Estado Inicial**: Con la aguja azul en el fotograma `00:00s`, ve a la sección `Scale` en el panel derecho y haz clic en los rombos al lado de X e Y.
*   **Crear el Crecimiento (Latido)**: Mueve la aguja azul al fotograma `30F` (medio segundo) y cambia los valores de `Scale X` e `Scale Y` a `130%` en el panel derecho.
*   **Fijar el Retorno al Origen**: Desplaza la aguja al fotograma `01:00s` (un segundo) y vuelve a establecer la escala X e Y en `100%` para completar el ciclo de tamaño.
*   **Seleccionar Fotogramas**: Haz un clic sostenido y arrastra en la línea de tiempo de abajo para envolver y seleccionar todos los rombos azules.
*   **Cambiar Interpolación**: En la esquina inferior derecha del panel, haz clic en el icono de curva `Cubic` para habilitar las curvas Bézier.
*   **Crear Movimiento Orgánico**: Ajusta los tiradores del gráfico en forma de "S" para lograr una aceleración y desaceleración fluida.
*   **Activar la Reproducción Infinita**: En los controles inferiores izquierdos, haz clic en el botón de reproducción hasta seleccionar el modo circular `Loop` (Bucle).
*   **Ver el Resultado**: Presiona la barra espaciadora o el botón de Play en el panel inferior para ver tu círculo latir en tiempo real de forma fluida.

---

## Conceptos Clave: Interpolación de Movimiento

*   **Movimiento Lineal**: La velocidad de cambio es constante en todo momento, generando transiciones rígidas, duras y de aspecto aficionado.
*   **Movimiento Cubic (Curvas)**: La velocidad se calcula con fórmulas de curvas Bézier que imitan la inercia y física real del mundo físico.
*   **Curvas en Forma de S**: Ajuste de tiradores que inicia el movimiento lento, acelera en la mitad y frena de manera suave al final.
