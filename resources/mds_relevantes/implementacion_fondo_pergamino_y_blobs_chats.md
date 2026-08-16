# Especificación Técnica: Diseño de Fondo Parchment y Blobs en Chats Individuales y Grupales 🎨

Este documento detalla la arquitectura, el diseño estético, la estructura del código y el proceso de reversión para la implementación del fondo personalizado en los chats de Lingiux, homólogo al de la pantalla de lectura de relatos.

---

## 🌿 1. Introducción y Propósito Estético

Para unificar la línea gráfica del lector de relatos (historias interactivas) con el módulo de comunicación en tiempo real (chats), implementamos un fondo de pergamino con blobs orgánicos translúcidos tanto en los **chats individuales** (`ChatDetailScreen`) como en los **chats grupales** (`GroupDetailScreen`).

Esta actualización de diseño reemplaza el fondo blanco plano por:
1.  **Gradiente Parchment Base:** Un gradiente lineal suave de crema cálido (`#FDFBF7`) a sepia beige suave (`#F5EDE0`).
2.  **Blob Peach (Melón Suave) 🍑:** Círculo translúcido superior derecho (`Color(0xFFEADCC9).withValues(alpha: 0.35)`) que suaviza la cabecera.
3.  **Blob Lavender (Lavanda) 🪻:** Círculo translúcido inferior izquierdo (`Color(0xFFDCD3FF).withValues(alpha: 0.25)`) ubicado por encima de la barra de entrada de texto.

Adicionalmente, se configuraron las cabeceras (`AppBar`) y los fondos de los `Scaffold` en modo transparente para que los colores y formas decorativas se fusionen orgánicamente con el fondo del chat.

---

## 📂 2. Archivos Afectados en la Estructura

```text
lib/
└── features/
    └── chat/
        └── presentation/
            └── screens/
                ├── chat_detail_screen.dart   <--- [MODIFICADO] Configurada la AppBar, Scaffold 
│                                                    transparente y Stack de blobs en chat individual.
                └── group_detail_screen.dart  <--- [MODIFICADO] Modificado _buildChatTab() para aplicar
                                                     el fondo degradado, blobs y caja de texto translúcida.
resources/
└── mds_relevantes/
    └── implementacion_fondo_pergamino_y_blobs_chats.md <--- [NUEVO] Documentación técnica.
```

---

## ⚙️ 3. Detalles de la Implementación del Código

### A. Chats Individuales (`chat_detail_screen.dart`)

En `_buildConversationPage`, modificamos las propiedades del Scaffold y envolvemos el cuerpo en un `Container` con gradiente y un `Stack`:

```dart
  Widget _buildConversationPage(BuildContext context, ChatEntity chatEntity) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fondo de Scaffold transparente
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar transparente
        elevation: 0,
        title: Row(
          children: [
            _Avatar( ... ),
            ...
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDFBF7), // Warm parchment cream
              Color(0xFFF5EDE0), // Soft sepia beige
            ],
          ),
        ),
        child: Stack(
          children: [
            // Blob decorativo superior derecho (Melón suave)
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEADCC9).withValues(alpha: 0.35),
                ),
              ),
            ),
            // Blob decorativo inferior izquierdo (Lavanda de la marca)
            Positioned(
              bottom: 120,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDCD3FF).withValues(alpha: 0.25),
                ),
              ),
            ),
            // Contenido principal
            Column(
              children: [
                if (_isFlagRibbonOpen) _buildFlagRibbon(context, chatEntity),
                Expanded(
                  child: ref.watch(messagesProvider(widget.chat.id)).when( ... ),
                ),
                _InputBar(controller: _controller, onSend: _sendMessage),
              ],
            ),
          ],
        ),
      ),
    );
  }
```

---

### B. Chats Grupales (`group_detail_screen.dart`)

En `_buildChatTab`, envolvemos el retorno en la misma decoración, y además estilizamos el cajón de entrada de texto (`TextField`) para que tenga bordes redondeados y un fondo blanco semi-translúcido para una legibilidad superior:

```dart
  Widget _buildChatTab() {
    final messagesAsync = ref.watch(messagesProvider(widget.group.conversationId));
    final membersAsync = ref.watch(groupMembersProvider(widget.group.conversationId));
    final currentUserId = ref.watch(authProvider).user?.id ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDFBF7), // Warm parchment cream
            Color(0xFFF5EDE0), // Soft sepia beige
          ],
        ),
      ),
      child: Stack(
        children: [
          // Blob decorativo superior derecho
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEADCC9).withValues(alpha: 0.35),
              ),
            ),
          ),
          // Blob decorativo inferior izquierdo
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDCD3FF).withValues(alpha: 0.25),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: messagesAsync.when( ... ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.transparent, // Barra de entrada transparente
                  border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7), // Caja de texto translúcida
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: AppColors.onSurface),
                          decoration: const InputDecoration(
                            hintText: 'Enviar mensaje...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
```

---

## 🔄 4. Protocolo de Reversión (Regresar a Diseño Anterior)

Si deseas remover este fondo pergamino con blobs y retornar al fondo plano original de los chats:

### Reversión en Chat Individual:
1.  Abra [`chat_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/chat_detail_screen.dart).
2.  Remueva `backgroundColor: Colors.transparent` del Scaffold.
3.  En la `AppBar`, elimine `backgroundColor: Colors.transparent` y `elevation: 0`.
4.  En el `body`, remueva el `Container` y el `Stack`, dejando únicamente la `Column` como hijo directo de `body: Column(...)`.

### Reversión en Chat Grupal:
1.  Abra [`group_detail_screen.dart`](file:///c:/Users/sebas/OneDrive/Escritorio/Lingiux/lingiux_app/lib/features/chat/presentation/screens/group_detail_screen.dart).
2.  En `_buildChatTab()`, elimine el `Container` decorativo y el `Stack`.
3.  Restaurar el `Column` original directamente en el retorno.
4.  Revierta el diseño de la barra de texto inferior quitando el Container de bordes redondeados y estableciendo el color de la caja a `Colors.white`.
