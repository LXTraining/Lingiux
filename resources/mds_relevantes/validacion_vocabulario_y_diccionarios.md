# Guía Maestra de Arquitectura para Validación de Vocabulario: Diccionarios Locales, APIs en la Nube, NLP (spaCy) y Sincronización Híbrida Offline (Estilo Kindle)

Este documento técnico sirve como guía definitiva y manual de arquitectura para la implementación del sistema de validación de vocabulario en **Lingiux**. Abarca la investigación, comparación y viabilidad técnica de las soluciones analizadas para garantizar que cada tarjeta de vocabulario (**Word Card**) contenga información verídica, estructuralmente correcta y enriquecida con metadatos reales, evitando el registro de palabras inventadas o errores de tipeo (ej. *"fefnsdjofjsod"*).

---

## 📋 1. El Desafío de la Validación de Vocabulario

En una aplicación educativa de idiomas como Lingiux, el flujo de creación de tarjetas no puede depender únicamente de la entrada manual libre del usuario. Si un usuario ingresa una palabra inválida, el sistema debe detectarlo antes de subir la información a la base de datos distribuida en Supabase.

### Objetivos del Sistema de Validación:
*   **Filtro Antispam/Errores:** Bloquear palabras que no pertenezcan al léxico del idioma objetivo (ej. secuencias aleatorias de teclado como *"fefnsdjofjsod"* o *"asdasd"*).
*   **Enriquecimiento Automático de Datos:** Al validar la palabra, el sistema debe intentar extraer de forma automática su fonética (ej. pronunciación en alfabeto fonético internacional como `/ˌserənˈdipədē/`), su categoría gramatical (sustantivo, verbo, adjetivo) y una definición corta para pre-rellenar el formulario y mejorar la experiencia de usuario (UX).
*   **Consistencia Lingüística:** Uniformar las entradas a su forma base o lema (ej. sugerir guardar *"comer"* en lugar de *"comiendo"*) para mejorar la organización del aprendizaje.

---

## 🔌 2. Análisis Comparativo de APIs de Diccionario

### A. Opciones de Uso Gratuito y Comunitarias

#### 1. Free Dictionary API
*   **URL Base:** `https://api.dictionaryapi.dev/api/v2/entries/en/<word>`
*   **Cómo Funciona:** Se realiza una petición HTTP `GET` al endpoint pasando la palabra en la URL. 
*   **Comportamiento de la Respuesta:**
    *   **Palabra Válida (HTTP 200 OK):** Retorna un JSON estructurado con una lista de acepciones. Incluye:
        *   `word`: Confirmación de la palabra.
        *   `phonetics`: Array con transcripciones fonéticas (`text`) y enlaces a archivos de audio de pronunciación en formato MP3 (`audio`).
        *   `meanings`: Array con definiciones agrupadas por categoría gramatical (`partOfSpeech`), definiciones semánticas, sinónimos y antónimos.
    *   **Palabra Inválida (HTTP 404 Not Found):** Retorna un objeto JSON de error:
        ```json
        {
          "title": "No Definitions Found",
          "message": "Sorry pal, we couldn't find definitions for the word you were looking for."
        }
        ```
*   **Restricciones:** No requiere credenciales ni API Key. Está limitado casi por completo al **inglés**. No es útil para un entorno multilingüe real.

#### 2. Wiktionary API (Wikimedia)
*   **URL de Consulta:** Endpoint oficial de la API de Wikipedia orientado a búsquedas lexicográficas.
*   **Cómo Funciona:** Consultas a través de su API REST en formato JSON.
*   **Idiomas:** Soporta prácticamente **todos los idiomas** del planeta gracias a su naturaleza colaborativa.
*   **Desventajas:** La estructura del JSON que devuelve es sumamente compleja, caótica y variable. La información no está normalizada y el cliente Flutter requeriría algoritmos de filtrado (parsing) muy complejos y propensos a romperse cuando la comunidad cambie el formato de una página.

---

### B. Opciones Profesionales y de Pago

#### 1. Yandex Dictionary API
*   **Características:** Servicio en la nube optimizado para proveer traducciones y datos detallados de diccionarios.
*   **Idiomas:** Soporte robusto para **español, inglés, francés, alemán, italiano, ruso**, etc.
*   **Ventajas:** Excelente para determinar clases de palabras, sinónimos y emparejamientos gramaticales. Cuenta con un plan gratuito inicial que requiere registrar una API Key.
*   **Desventajas:** Su plan gratuito tiene cuotas diarias estrictas. A gran escala, requiere cambiar a un plan de facturación mensual.

#### 2. Oxford Dictionaries / Merriam-Webster APIs
*   **Características:** Proveedores oficiales y autorizados con los diccionarios más prestigiosos del mundo.
*   **Ventajas:** Calidad y precisión insuperables, ideal para aplicaciones comerciales de alta exigencia.
*   **Desventajas:** Exigen planes de pago costosos para uso comercial (desde $15-$20 USD al mes por límites reducidos). No disponen de flexibilidad para escalar de manera elástica según el uso real de la app, penalizando proyectos pequeños en crecimiento.

---

## 🧠 3. Validación y Enriquecimiento mediante IA (Gemini API)

Integrar la API de Gemini mediante una **Edge Function de Supabase** ofrece un validador universal, inteligente y multilingüe sin depender de contratos con diccionarios tradicionales.

### A. Modelo de Elección: Gemini 1.5 Flash
Es el modelo de Google ideal para tareas rápidas de procesamiento de lenguaje natural y formateo estructurado de datos. Soporta la directiva de responder estrictamente en formato JSON utilizando un esquema predefinido.

### B. Estructura del Prompt del Sistema (System Instructions)
Para validar palabras, la Edge Function envía un prompt especializado que instruye a Gemini a actuar como un lexicógrafo estricto:

> *"Actúa como un validador y diccionario multilingüe para una aplicación de aprendizaje de idiomas. Tu tarea es analizar si la palabra proporcionada existe en el idioma especificado. Debes responder única y exclusivamente en formato JSON estructurado, respetando el siguiente esquema: `{ \"exists\": boolean, \"phonetic\": string, \"category\": string, \"definition\": string }`. Si la palabra no existe (es una combinación aleatoria como 'fefnsdjofjsod' o no tiene significado gramatical), el campo 'exists' debe ser false y el resto de campos nulos o vacíos. No incluyas explicaciones de texto adicionales fuera del JSON."*

---

### C. Estimación y Matemática de Costos (Tokens)

La API de Gemini cobra basándose en la cantidad de **tokens** procesados (un token equivale aproximadamente a 4 caracteres de texto en inglés, o una sílaba).

#### Tarifas de Gemini 1.5 Flash (Pago por uso):
*   **Tokens de Entrada (Input):** $0.075 USD por cada millón de tokens.
*   **Tokens de Salida (Output):** $0.30 USD por cada millón de tokens.

#### Cálculo de consumo por palabra:
1.  **Entrada (Prompt del sistema + Idioma + Palabra del usuario):** ~150 tokens.
2.  **Salida (JSON de respuesta):** ~100 tokens.

$$\text{Costo de Entrada} = 150 \times \left(\frac{0.075}{1,000,000}\right) = 0.00001125\text{ USD}$$
$$\text{Costo de Salida} = 100 \times \left(\frac{0.30}{1,000,000}\right) = 0.00003000\text{ USD}$$
$$\text{Costo Total por Validación} = 0.00004125\text{ USD}$$

#### Costo de Operación según el Volumen de Tarjetas:
*   **1,000 palabras validadas:** $0.04 USD (cuatro centavos de dólar).
*   **10,000 palabras validadas:** $0.41 USD.
*   **100,000 palabras validadas:** $4.12 USD.
*   **1,000,000 de palabras validadas:** $41.25 USD.

> [!NOTE]
> La API de Gemini ofrece un **nivel gratuito de 1,500 consultas al día (RPD)** y 15 consultas por minuto (RPM) en Google AI Studio. Durante el desarrollo y lanzamiento beta de Lingiux, el costo de validación será de **$0.00 USD**.

---

### D. Estrategia de Caché e Integración en Supabase

Para reducir las llamadas a la API de Gemini a largo plazo y optimizar los tiempos de respuesta, se debe implementar un mecanismo de almacenamiento en caché en la base de datos de Supabase.

1.  **Creación de la Tabla de Caché:**
    Se implementa una tabla llamada `public.validated_words` con la siguiente estructura:
    ```sql
    create table public.validated_words (
      word text not null,
      language text not null,
      exists boolean not null,
      phonetic text,
      definition text,
      category text,
      created_at timestamp with time zone default timezone('utc'::text, now()),
      primary key (word, language)
    );
    ```

2.  **Algoritmo del Servicio de Validación:**
    *   **Consulta de Caché (Local/DB):** Al enviar la palabra, la aplicación ejecuta una consulta rápida a `validated_words`:
        ```sql
        select exists, phonetic, definition, category 
        from public.validated_words 
        where lower(word) = lower(in_word) and lower(language) = lower(in_language);
        ```
    *   **Caso Éxito (Hit):** Si se encuentra la fila, se leen los datos y se procesa el formulario. **Costo de API = $0.00 USD**. **Tiempo de respuesta = ~15ms**.
    *   **Caso Fallo (Miss):** Si la palabra no ha sido buscada antes por ningún usuario, se realiza la llamada HTTP a la Edge Function conectada a Gemini API. Al obtener la respuesta, se guarda el resultado en la tabla `validated_words` para futuras consultas de cualquier otro estudiante y luego se autoriza la creación de la carta.

---

## 🐍 5. Procesamiento de Lenguaje Natural (spaCy)

**spaCy** es una biblioteca avanzada de Procesamiento de Lenguaje Natural (NLP) escrita en Python y Cython, muy utilizada en la industria para analizar estructuras lingüísticas complejas.

### A. Capacidades Lingüísticas de spaCy:
*   **Lematización Inteligente:** Identifica la palabra raíz del léxico. Por ejemplo, analiza formas conjugadas e irregulares de verbos y sustantivos plurales y los convierte a su forma de diccionario:
    *   *Español:* `"comiendo"`, `"comió"`, `"comeremos"` $\rightarrow$ lema `"comer"`. `"perritos"` $\rightarrow$ lema `"perro"`.
    *   *Inglés:* `"running"`, `"ran"`, `"runs"` $\rightarrow$ lema `"run"`. `"mice"` $\rightarrow$ lema `"mouse"`.
*   **Etiquetado de Partes del Discurso (POS Tagging):** Asigna de forma precisa etiquetas gramaticales basadas en el contexto de la oración (ej. distingue si `"corte"` actúa como sustantivo o como verbo).
*   **Análisis Sintáctico (Dependency Parsing):** Examina las relaciones de dependencia gramatical entre las palabras de una frase.
*   **Reconocimiento de Entidades Nombradas (NER):** Detecta elementos del mundo real (nombres de personas, organizaciones como *"Apple"*, localizaciones geográficas como *"California"*, fechas y cantidades).
*   **Vectores de Palabras (Word Embeddings):** Permite calcular la similitud semántica entre palabras mediante representaciones vectoriales multidimensionales.

### B. Desafío de Integración en Lingiux
*   **Dependencia del Entorno Python:** spaCy no se puede ejecutar en Dart (el lenguaje de Flutter) ni en Deno/TypeScript (el entorno de las Edge Functions de Supabase). Requiere un entorno de ejecución Python instalado.
*   **Consumo de Memoria:** Los modelos de lenguaje de spaCy (incluso los modelos pequeños como `es_core_news_sm`) pesan entre 15MB y 50MB y requieren una carga en memoria significativa, lo cual los hace inviables para ser embebidos directamente en una aplicación móvil.
*   **Arquitectura Requerida:** Para usar spaCy, se tendría que crear, mantener y pagar un **microservicio en Python** (utilizando FastAPI o Flask montado en un contenedor Docker en AWS o Render) para actuar como puente, lo que incrementaría la complejidad y el costo de mantenimiento del proyecto.

---

## 📖 6. Arquitectura de Consulta Offline (Estilo Kindle)

Los dispositivos **Amazon Kindle** son famosos por su capacidad de mostrar definiciones al pulsar sobre cualquier palabra de un libro electrónico de manera instantánea, incluso estando en el modo avión (100% offline).

### A. ¿Cómo funciona la arquitectura de Kindle?

1.  **Archivos de Diccionario Locales:** Kindle almacena diccionarios completos en formatos indexados altamente comprimidos (derivados de Mobipocket o bases de datos binarias similares) dentro del almacenamiento físico del dispositivo.
2.  **Lematizador Nativo Embebido:** El sistema operativo del lector electrónico ejecuta un módulo de lematización básico (escrito en lenguajes nativos de bajo nivel como C/C++ o Java). Cuando el usuario selecciona *"caminábamos"*, el software no busca esa palabra exacta en el diccionario; primero procesa morfológicamente el texto para extraer su lema base (*"caminar"*) y luego realiza la consulta.
3.  **Consulta Directa a Memoria Flash:** Al no haber latencia de red ni llamadas a servidores remotos, la búsqueda se completa en un intervalo de **1 a 5 milisegundos**.

---

### B. Implementación del Modelo Kindle en Lingiux (Híbrido Local-Nube)

Para implementar esta funcionalidad en Lingiux y dar al usuario una experiencia de velocidad instantánea e inmunidad al modo offline, se propone un modelo de **Sincronización Híbrida Local-Cloud**:

```
                  Usuario introduce una palabra en la app
                                     │
                                     ▼
                ¿Existe en la Base de Datos SQLite local?
                 ├─── ( Sí ) ───► Cargar datos al instante (Offline / ~2ms)
                 │
                ( No )
                 │
                 ▼
                ¿El dispositivo cuenta con Internet?
                 ├─── ( No ) ───► Alerta: "Conéctate para validar términos nuevos"
                 └─── ( Sí ) ───► Petición HTTP a la API (Edge Function / Gemini)
                                         │
                                         ▼
                               ¿La palabra es válida?
                                 ├─── ( No ) ───► Rechazar creación de la tarjeta
                                 └─── ( Sí ) ───► Guardar en SQLite local y crear carta
```

#### Detalles de la Implementación en Flutter:

1.  **Bases de Datos SQLite Locales por Idioma:**
    *   Compilamos diccionarios optimizados en archivos SQLite (`.db`), conteniendo un set básico pero amplio de palabras del idioma (ej. las 50,000 palabras más comunes en inglés y español con definición y fonética).
    *   El tamaño de esta base de datos es de apenas **8 MB a 12 MB** por idioma.
    *   El archivo se añade en los `assets` del proyecto. Al iniciar la aplicación por primera vez, Flutter copia el archivo desde el bundle de assets hacia la carpeta de documentos local del dispositivo mediante el plugin `path_provider` y `sqflite`:
        ```dart
        // Ejemplo lógico del copiado inicial de base de datos
        var path = join(await getDatabasesPath(), "diccionario_es.db");
        if (!await File(path).exists()) {
          ByteData data = await rootBundle.load("assets/diccionario_es.db");
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await File(path).writeAsBytes(bytes);
        }
        ```

2.  **Índices para Búsqueda Instantánea:**
    *   La tabla interna de la base de datos de SQLite debe contar con índices únicos para garantizar búsquedas en milisegundos:
        ```sql
        create unique index idx_vocabulary_word on vocabulary(word);
        ```

3.  **Crecimiento Orgánico del Diccionario Local:**
    *   Cuando el dispositivo está en línea y consulta una palabra nueva que no estaba en su SQLite local, la Edge Function de Supabase (Gemini) devuelve los datos correspondientes. 
    *   Al guardarse la tarjeta, la app inserta esta nueva definición en la base de datos SQLite local del dispositivo. De esta forma, el diccionario offline del usuario crece y se personaliza de manera automática a medida que estudia.
