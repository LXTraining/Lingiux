# Estrategia de Escalabilidad: Búsqueda y Carga de Word Cards a Gran Escala

Este documento detalla la estrategia de optimización para garantizar que la carga de tarjetas de vocabulario (Word Cards) desde el chat sea instantánea (menor a 100 ms) incluso si la base de datos de Supabase crece a millones de registros.

---

## El Desafío
En el prototipo inicial, la aplicación utiliza un `FutureProvider` global que descarga todas las palabras de la tabla `word_cards` de una sola vez (`select()`) y realiza la búsqueda en memoria del dispositivo. 

Si la base de datos escala a un volumen masivo (ej. 1,000,000 de palabras), este enfoque causaría:
1. **Consumo excesivo de red**: Descargar megabytes de JSON en cada inicio de la app.
2. **Saturación de memoria**: Mantener miles de objetos en la memoria RAM del dispositivo móvil.
3. **Cuelgues y lentitud**: Bloqueo del hilo de UI al procesar listas gigantes.

---

## Solución de Arquitectura en 4 Pasos

### 1. Búsqueda Bajo Demanda Indexada (Base de Datos)
En lugar de descargar toda la tabla, la aplicación debe consultar a la base de datos únicamente el registro de la palabra seleccionada. Para hacer esto eficiente, debemos definir un **índice de tipo B-Tree** sobre la columna de búsqueda (estandarizando a minúsculas) directamente en PostgreSQL:

```sql
-- Crear índice para búsquedas ultra rápidas sin importar el volumen
CREATE INDEX idx_word_cards_word_lower ON public.word_cards (LOWER(word));
```

La consulta realizada desde el SDK será:
```sql
SELECT * FROM public.word_cards WHERE LOWER(word) = LOWER('tapped_word') LIMIT 1;
```
Esto reduce la complejidad de la búsqueda a **O(log N)**, lo que en PostgreSQL toma menos de **1 ms** de procesamiento.

---

### 2. Consultas Individuales por Familia (`FutureProvider.family`)
En Flutter, reemplazamos el proveedor global por un proveedor parametrizado que realice consultas individuales por demanda utilizando la directiva `.family` de Riverpod:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/word_card_model.dart';

// Proveedor por palabra individual
final wordCardDetailProvider = FutureProvider.family<WordCardModel?, String>((ref, word) async {
  final supabase = Supabase.instance.client;
  
  // Realiza una consulta única para la palabra
  final response = await supabase
      .from('word_cards')
      .select()
      .eq('word', word.trim())
      .maybeSingle(); // Retorna un mapa o null si no existe
      
  if (response == null) return null;
  return WordCardModel.fromJson(response as Map<String, dynamic>);
});
```

En la UI del chat (`_WordMiniCard`), simplemente observamos el estado de esa palabra específica:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Solo se consulta y observa el estado de esta palabra concreta
  final wordCardAsync = ref.watch(wordCardDetailProvider(word));
  
  return wordCardAsync.when(
    data: (wordCard) => _buildCard(wordCard),
    loading: () => _buildSkeleton(),
    error: (err, _) => _buildDefaultCard(),
  );
}
```

---

### 3. Pre-fetch en Segundo Plano (Técnica de UX)
Para evitar que el usuario perciba un retardo al hacer tap, podemos implementar pre-cargas en segundo plano mientras el usuario lee el chat:
1. Al abrir la pantalla de chat o recibir nuevos mensajes, parseamos el texto para identificar términos válidos de vocabulario.
2. Disparamos la lectura del proveedor en segundo plano para esas palabras utilizando `ref.read`:
   ```dart
   // Pre-carga de forma silenciosa para que esté en caché local antes del tap
   ref.read(wordCardDetailProvider('ephemeral').future);
   ```
3. Cuando el usuario hace tap sobre la palabra, los datos ya están en el caché de Riverpod y se muestran con **0 ms de espera**.

---

### 4. Caché Local Persistente (Estrategia Offline-First)
Para un rendimiento óptimo e independiente de la conexión de red, implementamos almacenamiento local utilizando **Isar Database** (incluida en el stack de la aplicación):
- **Estrategia Stale-While-Revalidate**:
  1. El usuario hace tap en una palabra.
  2. La app busca y muestra instantáneamente la palabra guardada en el caché local de Isar.
  3. En paralelo, consulta silenciosamente a Supabase para verificar si ha habido actualizaciones.
  4. Si hay actualizaciones, refresca la UI y actualiza la base de datos local.
