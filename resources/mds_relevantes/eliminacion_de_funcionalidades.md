# Procedimiento para la Eliminación de Funcionalidades y Desconstrucción de Código

Este documento describe el protocolo a seguir en caso de querer dar marcha atrás a cualquiera de las implementaciones del proyecto. Al mantener una bitácora técnica de cada funcionalidad dentro de la carpeta `resources/mds_relevantes/`, contamos con un mapa preciso (blueprint) para desinstalar componentes de manera limpia, segura y sin dejar código huérfano.

---

## 🗺️ 1. El Rol de la Carpeta de Documentación Relevante

Cada archivo de documentación `.md` en la carpeta `resources/mds_relevantes/` contiene una sección titulada **"Archivos Creados y Modificados"**. Esta sección actúa como un registro de auditoría de los archivos que fueron afectados en cada sprint de desarrollo.

Si deseas eliminar una funcionalidad, bastará con hacer referencia al archivo de documentación correspondiente (ej. `@[rompecabezas_cooperativo_conversaciones.md]` o `@[estadisticas_tarjetas_resueltas_por_idioma.md]`). El agente de IA o desarrollador utilizará este mapa para revertir las modificaciones.

---

## 🛠️ 2. Procedimiento de Eliminación Paso a Paso

Para dar marcha atrás a una funcionalidad de forma manual y limpia, se ejecutan las siguientes tres etapas:

### A. Eliminación Física de Archivos Creados
Todos los archivos marcados como `[NUEVO]` en el documento técnico correspondiente deben eliminarse por completo del sistema de archivos para no acumular código muerto.
*   **Ejemplo**: En el caso del rompecabezas, se eliminaría:
    `lib/features/chat/presentation/providers/chat_puzzle_provider.dart`

### B. Reversión de Cambios en Archivos Modificados
Para cada archivo marcado como `[MODIFY]` en el documento técnico, se debe remover la lógica añadida y restablecer el comportamiento original:
1.  **Remoción de Imports**: Quitar las líneas de importación correspondientes al proveedor o servicio eliminado.
2.  **Limpieza de Constructores y Firmas de Métodos**: Eliminar los parámetros adicionales propagados (como `conversationId` o similares).
3.  **Remoción de Widgets e Interfaz de Usuario**: Sustituir los widgets visuales de la característica por los marcadores o contenedores anteriores (ej. re-instanciar el placeholder en la pantalla de detalles del chat).
4.  **Corte de Pipelines de Datos**: Retirar las invocaciones a base de datos o despachos de Riverpod asociados a la funcionalidad en los eventos de interacción (como resolver un quiz).

### C. Depuración de la Base de Datos (Supabase)
Si la funcionalidad requirió la creación de tablas o políticas RLS en la base de datos de Postgres:
1.  Se debe ejecutar una migración de caída (DDL) para borrar las tablas y liberar recursos:
    ```sql
    DROP TABLE IF EXISTS public.chat_puzzles CASCADE;
    ```
2.  El uso de `CASCADE` asegura que cualquier restricción, política o disparador (trigger) dependiente sea también removido automáticamente de la base de datos de Supabase.

---

## 🔄 3. Alternativa Rápida Mediante Control de Versiones (Git)

Dado que todo el proyecto se gestiona mediante control de versiones en Git, existen alternativas automáticas para revertir los commits específicos:

### A. Revertir un Commit Específico
Si la implementación está aislada en un commit particular (o un rango de commits), puedes deshacer los cambios generando un commit de reversión:
```bash
git log --oneline  # Encuentra el hash del commit (ej. dd85aee)
git revert <hash_del_commit>
```
*   *Nota*: Esto creará un nuevo commit en el historial que aplica de forma inversa exactamente las mismas adiciones y eliminaciones de líneas, preservando la integridad del historial.

### B. Restaurar Archivos Específicos a un Estado Anterior
Si solo deseas restablecer algunos archivos modificados a como estaban antes de la implementación de la característica:
```bash
git checkout <hash_del_commit_anterior> -- <ruta_del_archivo>
```
*   **Ejemplo**: `git checkout main~1 -- lib/features/vocabulary/presentation/screens/word_detail_screen.dart`
