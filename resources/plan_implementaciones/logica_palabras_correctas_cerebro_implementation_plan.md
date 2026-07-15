# Mostrar solo nodos de tarjetas correctas en el Cerebro Digital

Modificaremos la lógica del Cerebro Digital (sección de Comunidad) para que únicamente muestre los nodos correspondientes a las tarjetas de vocabulario que el usuario ha contestado correctamente en los quizzes (registradas en la tabla `resolved_cards` de Supabase).

## Proposed Changes

### Vocabulary Component

#### [MODIFY] [vocabulary_provider.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/providers/vocabulary_provider.dart)
- Agregar un nuevo provider reactivo `correctWordCardsProvider` que combine y filtre `wordCardsProvider` basándose en los IDs devueltos por `resolvedCardsProvider`.

```dart
final correctWordCardsProvider = FutureProvider.autoDispose<List<WordCardModel>>((ref) async {
  final cards = await ref.watch(wordCardsProvider.future);
  final resolved = await ref.watch(resolvedCardsProvider.future);
  final resolvedCardIds = resolved.map((r) => r['card_id'] as String).toSet();
  return cards.where((card) => resolvedCardIds.contains(card.id)).toList();
});
```

#### [MODIFY] [word_detail_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/vocabulary/presentation/screens/word_detail_screen.dart)
- En la función `_recordCorrectCard()`, invalidar `resolvedCardsProvider` mediante `ref.invalidate(resolvedCardsProvider)` para asegurar que al responder un quiz correctamente, los providers reactivos se actualicen al instante y el Cerebro Digital refleje la nueva palabra de inmediato.

### Community Component

#### [MODIFY] [community_screen.dart](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/community/presentation/screens/community_screen.dart)
- Cambiar la lectura de `wordCardsProvider` a `correctWordCardsProvider` para que la red neuronal solo pinte e inicialice las palabras aprobadas.

```dart
// De:
final wordCardsAsync = ref.watch(wordCardsProvider);
// A:
final wordCardsAsync = ref.watch(correctWordCardsProvider);
```

## Verification Plan

### Automated Tests
- Ejecutar `flutter test` para validar que la compilación de todos los componentes y pantallas permanezca libre de errores.

### Manual Verification
1. Ingresar a la sección principal de estudio de tarjetas.
2. Contestar una tarjeta de forma incorrecta: verificar que la palabra **no** aparezca en el Cerebro Digital.
3. Contestar la tarjeta correctamente en su quiz: verificar que el nodo de la palabra se agregue automáticamente con su respectiva categoría y enlace en el Cerebro Digital.
