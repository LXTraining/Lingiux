# Arquitectura de Base de Datos y Sistema de Grupos de Estudio Cooperativos

Este documento contiene la especificación de diseño de base de datos, políticas de seguridad (RLS), y la lógica de negocio implementada para la funcionalidad de **Grupos de Estudio Cooperativos** en Lingiux.

---

## 1. Modelo de Base de Datos (Supabase / PostgreSQL)

Para implementar los grupos de forma profesional, se extendió el modelo de mensajería existente mediante dos nuevas tablas en el esquema `public`.

### A. Tabla `public.study_groups`
Esta tabla contiene los metadatos propios de cada grupo escolar o de estudio y se enlaza directamente con la tabla de conversaciones.

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
Para evitar abusos en el incremento de puntos de evolución, se creó un historial diario de aportes de rachas por integrante del grupo. Cuenta con una restricción única compuesta (`unique_daily_contribution`) que limita a cada usuario a realizar un solo aporte por día por grupo.

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

---

## 2. Políticas de Seguridad (Row Level Security - RLS)

Se definieron políticas estrictas para garantizar la privacidad y la integridad de los datos de los usuarios:

```sql
-- Habilitar RLS en study_groups
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;

-- Políticas para study_groups
CREATE POLICY "Cualquiera autenticado puede leer grupos" 
ON public.study_groups FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Usuarios autenticados pueden crear grupos" 
ON public.study_groups FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Solo miembros o creador pueden actualizar grupo" 
ON public.study_groups FOR UPDATE 
TO authenticated 
USING (
    auth.uid() = creator_id OR 
    EXISTS (
        SELECT 1 FROM public.conversation_participants 
        WHERE conversation_id = study_groups.conversation_id AND profile_id = auth.uid()
    )
);

-- Habilitar RLS en group_contributions
ALTER TABLE public.group_contributions ENABLE ROW LEVEL SECURITY;

-- Políticas para group_contributions
CREATE POLICY "Lectura de contribuciones para autenticados" 
ON public.group_contributions FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Inserción de contribuciones para miembros" 
ON public.group_contributions FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = profile_id);
```

---

## 3. Principio del Chat Polimórfico

Para no duplicar tablas de mensajes ni lógica del frontend, aplicamos un diseño polimórfico en el backend:

1. **Chats directos (1-a-1):** Son registros en `conversations` vinculados a exactamente dos participantes en `conversation_participants` y que **no** tienen ningún registro en `study_groups` que los referencie por su `conversation_id`.
2. **Chats grupales:** Son registros en `conversations` que están vinculados a múltiples participantes y que **sí** cuentan con una fila correspondiente en `study_groups` que describe sus metadatos del juego y de la mascota.

Esto permite reutilizar el stream de mensajes y la inserción de mensajes sin cambios estructurales.

---

## 4. Lógica de Evolución y Crecimiento

El progreso de la mascota cooperativa se calcula de manera matemática simple y deterministicamente basándose en los puntos acumulados en el grupo:

* **Fórmula de Nivel:**
  $$\text{Nivel} = \lfloor\frac{\text{Puntos Totales}}{100}\rfloor + 1$$
* **Fórmula de Progreso en el Nivel Actual:**
  $$\text{Progreso} = \frac{\text{Puntos Totales} \pmod{100}}{100.0}$$

### Etapas visuales de las mascotas:
* **PLANTA DE RACHAS:**
  * **Nivel 1:** Semilla de Racha (icono `spa_rounded`)
  * **Nivel 2:** Brote de Racha (icono `grass_rounded`)
  * **Nivel 3:** Planta Joven (icono `eco_rounded`)
  * **Nivel 4+:** Planta Floreciente (icono `local_florist_rounded`)
* **TAMAGOTCHI GRUPAL:**
  * **Nivel 1:** Huevo Lingiux (icono `egg_rounded`)
  * **Nivel 2:** Mascota Bebé (icono `child_care_rounded`)
  * **Nivel 3:** Tamagotchi Joven (icono `cruelty_free_rounded`)
  * **Nivel 4+:** Dragón Adulto (icono `pets_rounded`)

---

## 5. Procedimiento para Revertir los Cambios

Si en algún momento se desea remover por completo la funcionalidad de los grupos de estudio de la plataforma, se deben seguir los siguientes pasos:

### A. Eliminar Tablas en Supabase
Ejecuta la siguiente consulta SQL en tu editor de Supabase para borrar las tablas en cascada:
```sql
DROP TABLE IF EXISTS public.group_contributions CASCADE;
DROP TABLE IF EXISTS public.study_groups CASCADE;
```

### B. Revertir Cambios en Código Flutter
1. Eliminar el archivo de modelo [study_group.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/domain/entities/study_group.dart).
2. Eliminar la pantalla [group_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/group_detail_screen.dart).
3. Revertir los cambios en [chats_list_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chats_list_screen.dart) para quitar la lógica de renderizado de la pestaña de grupos y el bottom sheet de creación.
4. Quitar los métodos añadidos a `ChatService` y los providers correspondientes en [chat_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/providers/chat_provider.dart).
