# Plan de Implementación: Editor de Lecciones Interactivo (Estilo Duolingo)

Este documento establece el plan técnico, arquitectónico y de diseño para implementar el **Creador/Editor de Lecciones** en la tercera pestaña ("Crear") de la aplicación **Lingiux**.

---

## 1. Descripción del Objetivo

El objetivo es permitir a los usuarios de Lingiux diseñar lecciones interactivas personalizadas para la comunidad. Cada lección constará de una secuencia de ejercicios dinámicos (opción múltiple, completar oraciones, traducir palabras, audios) similares a los juegos de Duolingo, SuperChinese y Busuu.

Para lograr una experiencia innovadora y de rápido desarrollo, implementaremos:
1. Un esquema de almacenamiento JSONB flexible en Supabase.
2. Un motor inteligente de **auto-compilación de lecciones** a partir de cartas de vocabulario existentes.
3. Un asistente de creación (wizard) premium paso a paso en el cliente móvil.

---

## 2. Arquitectura de Datos (Supabase SQL)

Para mantener la base de datos veloz y evitar complejas relaciones multinivel que ralentizarían el cliente, utilizaremos una tabla `lessons` que almacenará una estructura JSONB (`exercises`).

### Script de Migración SQL (`lessons`)
```sql
-- Crear tabla de lecciones
CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    language VARCHAR(50) NOT NULL, -- Inglés, Alemán, etc.
    difficulty VARCHAR(10) NOT NULL, -- A1, A2, B1, etc.
    card_ids UUID[] DEFAULT '{}', -- Listado opcional de cartas asociadas
    exercises JSONB NOT NULL DEFAULT '[]'::jsonb, -- Lista de ejercicios interactivos
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
CREATE POLICY "Lecciones públicas para lectura" 
    ON public.lessons FOR SELECT 
    USING (true);

CREATE POLICY "Usuarios pueden crear sus lecciones" 
    ON public.lessons FOR INSERT 
    WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creadores pueden actualizar sus lecciones" 
    ON public.lessons FOR UPDATE 
    USING (auth.uid() = creator_id);

CREATE POLICY "Creadores pueden borrar sus lecciones" 
    ON public.lessons FOR DELETE 
    USING (auth.uid() = creator_id);
```

---

## 3. Modelo de Datos en Dart (Flutter)

Definiremos los modelos correspondientes en Flutter para serializar/deserializar el campo JSONB de ejercicios.

```dart
enum ExerciseType {
  listeningQuiz,      // ¿Qué escuchas? (Selección de audio)
  translateSentence,  // Traduce esta oración (Bloques de palabras)
  multipleChoice,     // Selección múltiple clásica
  mnemonicMatch       // Puzzle de nemotecnia
}

class LessonExercise {
  final String id;
  final ExerciseType type;
  final String question;
  final String? audioUrl;
  final String correctAnswer;
  final List<String> options;
  final List<String>? correctSequence; // Para ordenar palabras

  LessonExercise({
    required this.id,
    required this.type,
    required this.question,
    this.audioUrl,
    required this.correctAnswer,
    required this.options,
    this.correctSequence,
  });

  factory LessonExercise.fromJson(Map<String, dynamic> json) {
    return LessonExercise(
      id: json['id'] as String,
      type: ExerciseType.values.firstWhere((e) => e.name == json['type']),
      question: json['question'] as String,
      audioUrl: json['audio_url'] as String?,
      correctAnswer: json['correct_answer'] as String,
      options: List<String>.from(json['options'] ?? []),
      correctSequence: json['correct_sequence'] != null 
          ? List<String>.from(json['correct_sequence']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'question': question,
      'audio_url': audioUrl,
      'correct_answer': correctAnswer,
      'options': options,
      'correct_sequence': correctSequence,
    };
  }
}
```

---

## 4. Flujo del Editor UI/UX (Asistente Paso a Paso)

Modificaremos la pantalla inicial de la tercera pestaña para añadir el disparador del asistente de lección.

### Paso 1: Configuración Inicial (Metadata)
* Formulario simple:
  * Título de la lección (ej: "Pedir café en París").
  * Descripción.
  * Idioma y dificultad.

### Paso 2: Selección de Cartas Semilla (El Motor)
* El usuario selecciona entre 3 y 6 cartas de vocabulario (desde su librería o cartas públicas).
* **Smart Compiler:** Al presionar "Continuar", un algoritmo analiza las oraciones de ejemplo y audios de las cartas y pre-genera automáticamente una lista de ejercicios interactivos en borrador.

### Paso 3: Organizador de Ejercicios
* Visualización en lista reordenable (`ReorderableListView`) de los ejercicios auto-generados.
* El creador puede:
  * Arrastrar para reordenar la secuencia.
  * Tocar un ejercicio para modificar las opciones falsas o el texto.
  * Agregar un nuevo ejercicio vacío eligiendo una plantilla.
  * Eliminar ejercicios.

### Paso 4: Publicar
* Validación de que la lección contenga al menos 3 ejercicios.
* Envío a Supabase e inserción en la tabla `lessons`.

---

## 5. Plan de Verificación

### Pruebas Automatizadas
* Unit tests para la serialización de `LessonExercise` y `LessonModel`.
* Unit tests para el algoritmo de auto-generación (Smart Compiler) a partir de cartas.

### Verificación Manual
* Ejecutar el wizard en el emulador/dispositivo móvil.
* Verificar inserción correcta de registros JSONB en el panel de Supabase.
* Comprobar la resiliencia del layout ante el teclado y la reordenación táctil.
