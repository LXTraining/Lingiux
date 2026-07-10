# Diseño Técnico Futuro: Algoritmos de Recomendación Adaptativos y Ponderados para Cartas

Este documento define la especificación técnica, la arquitectura de base de datos en Supabase, los fundamentos matemáticos y las implementaciones de código de referencia para la futura evolución de la plataforma **Lingiux** hacia un sistema inteligente de recomendación y aprendizaje adaptativo.

---

## 📖 1. Introducción y Objetivos de la Recomendación

El objetivo de un algoritmo de recomendación en una plataforma educativa es maximizar el enganche del usuario (*engagement*) y optimizar el tiempo de retención del conocimiento. A medida que la base de datos de tarjetas crece, la aleatoriedad simple uniforme pierde efectividad. 

Este diseño propone dos fases evolutivas para guiar la selección de tarjetas cuando un usuario hace tap sobre una palabra clave:
1.  **Fase Ponderada (Nivel 1)**: Basada en el rendimiento o valoración directa de la tarjeta (calificaciones/ratings).
2.  **Fase Predictiva de Comportamiento (Nivel 2)**: Basada en similitud semántica de categorías (estilo TikTok/YouTube) utilizando inteligencia artificial y búsqueda vectorial nativa en Supabase con PostgreSQL.
3.  **Fase de Repetición Espaciada (Nivel 3 - SRS)**: Basada en la curva del olvido para mostrar la tarjeta exacta en el momento en que el usuario está a punto de olvidarla.

---

## 🎲 2. Fase Ponderada: Selección Aleatoria Ponderada (Por Rating)

En lugar de que todas las tarjetas que coincidan con la palabra clave tengan la misma probabilidad ($1/N$), cada tarjeta posee un "peso" o calificación. Las tarjetas mejor puntuadas (o aquellas marcadas como más efectivas para el aprendizaje) aparecen con mayor frecuencia.

### A. Fundamentos Matemáticos
Dada una lista de $N$ tarjetas que coinciden con una palabra, donde cada tarjeta $i$ tiene un peso asignado $w_i > 0$:

1.  **Suma de Pesos**:
    $$W_{\text{total}} = \sum_{i=1}^{N} w_i$$
2.  **Densidad de Probabilidad**: La probabilidad $P(i)$ de seleccionar la tarjeta $i$ es:
    $$P(i) = \frac{w_i}{W_{\text{total}}}$$
3.  **Mecanismo de Selección**:
    *   Se selecciona un número aleatorio real $R \in [0.0, W_{\text{total}}[$.
    *   Iteramos sobre las tarjetas acumulando sus pesos. Nos detenemos y retornamos la tarjeta $k$ tan pronto como la suma acumulada iguale o supere a $R$:
        $$\sum_{i=1}^{k} w_i \ge R$$

### B. Implementación de Referencia en Dart
Esta lógica se ejecuta localmente en la memoria del dispositivo en tiempo constante o lineal muy ligero:

```dart
import 'dart:math' as math;
import '../../../vocabulary/domain/models/word_card_model.dart';

WordCardModel selectWeightedCard(List<WordCardModel> matches) {
  if (matches.isEmpty) {
    throw ArgumentError('La lista de tarjetas coincidentes no puede estar vacía.');
  }
  
  if (matches.length == 1) {
    return matches.first;
  }

  // 1. Calcular la suma total de pesos (calificaciones).
  // Si rating es null, asignamos un peso neutro de 1.0.
  final double totalWeight = matches.fold(
    0.0, 
    (sum, card) => sum + (card.rating ?? 1.0)
  );

  // 2. Generar un número aleatorio en el rango [0.0, totalWeight[
  final double randomValue = math.Random().nextDouble() * totalWeight;

  // 3. Selección por acumulación lineal
  double cumulativeWeight = 0.0;
  for (final card in matches) {
    cumulativeWeight += (card.rating ?? 1.0);
    if (randomValue <= cumulativeWeight) {
      return card;
    }
  }

  // Fallback en caso de imprecisiones decimales de coma flotante
  return matches.last;
}
```

### C. Análisis de Rendimiento
*   **Complejidad Temporal**: $\mathcal{O}(N)$ debido al bucle de acumulación, donde $N$ es el número de tarjetas coincidentes para esa palabra (típicamente $N < 100$). En términos prácticos de CPU, se ejecuta en menos de **0.1 microsegundos**.
*   **Complejidad Espacial**: $\mathcal{O}(1)$ ya que no requiere almacenar datos temporales adicionales más allá de variables escalares de acumulación.

---

## 👥 3. Fase Predictiva: Recomendación Temática Semántica (Embeddings con Supabase)

Para emular el comportamiento de algoritmos como los de YouTube o TikTok, la aplicación debe rastrear el historial de interacciones del usuario y sugerir tarjetas que se alineen semánticamente con los temas que más le interesan (ej. gastronomía, arquitectura, viajes, tecnología).

### A. Estructura de Base de Datos en Supabase
Para alimentar el perfil del usuario, requerimos registrar sus acciones en una tabla de auditoría de interacciones:

```sql
-- Tabla para registrar el historial de comportamiento del usuario
CREATE TABLE public.user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id UUID REFERENCES public.cards(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- 'view', 'flip', 'quiz_correct', 'quiz_incorrect'
    category VARCHAR(100) NOT NULL,        -- 'gastronomy', 'architecture', etc.
    weight INT NOT NULL,                   -- Valor del evento (ej: view=1, quiz_correct=5)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar índices para optimizar consultas de agrupamiento
CREATE INDEX idx_user_interactions_user_id ON public.user_interactions(user_id);
```

### B. Algoritmo de Similitud Vectorial con `pgvector`
En lugar de contar palabras o categorías simples, convertimos las tarjetas en **vectores numéricos (embeddings)** que representan el significado de la carta en un espacio multidimensional.

1.  **Activación de la Extensión**: Supabase permite habilitar vectores en PostgreSQL de forma nativa:
    ```sql
    CREATE EXTENSION IF NOT EXISTS vector;
    ```
2.  **Vectorizar Tarjetas**: Añadimos una columna `embedding` de tipo vectorial a la tabla `cards`:
    ```sql
    ALTER TABLE public.cards ADD COLUMN embedding vector(1536); -- 1536 dimensiones es el estándar de OpenAI
    ```
3.  **Generación de Perfil de Interés**: Calculamos el vector promedio del perfil de un usuario promediando los vectores de las tarjetas con las que ha tenido interacciones positivas:
    ```sql
    CREATE OR REPLACE FUNCTION get_user_interest_vector(p_user_id UUID)
    RETURNS vector(1536) AS $$
    DECLARE
        v_profile vector(1536);
    BEGIN
        SELECT avg(c.embedding)::vector(1536)
        INTO v_profile
        FROM public.user_interactions ui
        JOIN public.cards c ON ui.card_id = c.id
        WHERE ui.user_id = p_user_id AND ui.weight > 0;
        
        RETURN v_profile;
    END;
    $$ LANGUAGE plpgsql;
    ```
4.  **Consulta SQL de Recomendación**: Cuando el usuario toca una palabra clave, invocamos una función remota (RPC) en Supabase para obtener las tarjetas ordenadas por proximidad semántica utilizando la **Distancia Coseno** (`<=>`):

```sql
CREATE OR REPLACE FUNCTION recommend_cards(p_user_id UUID, p_word TEXT, p_limit INT DEFAULT 5)
RETURNS TABLE (
    id UUID,
    word VARCHAR,
    definition TEXT,
    phonetic VARCHAR,
    image_url TEXT,
    similarity DOUBLE PRECISION
) AS $$
DECLARE
    v_user_vector vector(1536);
BEGIN
    -- 1. Obtener el vector de intereses del usuario
    v_user_vector := get_user_interest_vector(p_user_id);

    -- 2. Retornar las tarjetas coincidentes ordenadas por similitud
    RETURN QUERY
    SELECT 
        c.id,
        c.word,
        c.definition,
        c.phonetic,
        c.image_url,
        1 - (c.embedding <=> v_user_vector) AS similarity -- Similitud de coseno (1 = idéntico, 0 = opuesto)
    FROM public.cards c
    WHERE LOWER(c.word) = LOWER(p_word)
    ORDER BY c.embedding <=> v_user_vector ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
```

---

## 📈 4. Fase Inteligente: Integración de Repetición Espaciada (SRS)

Para optimizar al máximo la retención de vocabulario, podemos integrar un algoritmo clásico de **Spaced Repetition System (SRS)** como el algoritmo **SuperMemo-2 (SM-2)**.

### Variables del SM-2:
*   **Factor de Facilidad ($EF$)**: Métrica de la dificultad intrínseca de la tarjeta para el usuario (inicia en $2.5$).
*   **Intervalo ($I$)**: Número de días recomendados antes de volver a presentar la tarjeta.
*   **Repeticiones ($n$)**: Veces consecutivas que el usuario responde correctamente.

### Fórmulas del SM-2:
Tras evaluar la calidad de la respuesta del usuario $q$ de $0$ a $5$:
1.  **Actualizar Factor de Facilidad**:
    $$EF' = EF + (0.1 - (5 - q) \times (0.08 + (5 - q) \times 0.02))$$
    *(Si $EF' < 1.3$, se fuerza $EF' = 1.3$)*
2.  **Calcular Próximo Intervalo**:
    *   Si $n = 1 \implies I = 1 \text{ día}$
    *   Si $n = 2 \implies I = 6 \text{ días}$
    *   Si $n > 2 \implies I' = \lfloor I \times EF \rfloor \text{ días}$

La tarjeta que tenga el intervalo de revisión más cercano (o vencido) es la que se seleccionará prioritariamente al realizar el tap sobre la palabra.

---

## 📂 5. Impacto en los Archivos Existentes para una Implementación Futura

Para habilitar estas fases en el futuro, los cambios en los archivos modificados en este sprint serían muy organizados:

### A. `chat_detail_screen.dart`
*   Cambiar la firma de `_showWordCard` para despachar una llamada RPC asíncrona a Supabase en lugar de leer el `wordCardsProvider` directamente de memoria, o implementar `selectWeightedCard` directamente sobre la lista cargada por Riverpod.
*   Registrar la interacción del usuario en Supabase (`click_card`) en segundo plano mediante `chatServiceProvider`.

### B. `message_bubble.dart`
*   No requiere cambios estructurales; el pipeline de paso de parámetros `cardId` ya está configurado para heredar y conservar de forma fija cualquier tarjeta sugerida por el backend.

### C. `word_detail_screen.dart`
*   Al reportar una respuesta en el quiz de la tarjeta, despachar el puntaje $q$ obtenido (de 0 a 5) a Supabase para recalcular los intervalos de Repetición Espaciada.

---

## 📚 6. Librerías Futuras Requeridas

1.  **`supabase_flutter`**: Utilizado para disparar las llamadas RPC a bases de datos (`supabase.rpc('recommend_cards', ...)`).
2.  **`google_generative_ai`** o servicios de embeddings de **OpenAI**: Utilizado en el backend (o mediante Supabase Edge Functions) para vectorizar los textos de definiciones cuando el usuario crea o edita una nueva tarjeta.
