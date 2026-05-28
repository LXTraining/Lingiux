import 'package:flutter/material.dart';
import '../../domain/entities/chat_entity.dart';
import '../widgets/message_bubble.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatEntity chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<MessageEntity> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.chat.messages);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(MessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isMe: true,
        time: DateTime.now(),
      ));
    });

    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Avatar(
              initials: widget.chat.initials,
              colorIndex: widget.chat.avatarColorIndex,
              size: 34,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chat.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.chat.isOnline)
                  const Text(
                    'en línea',
                    style: TextStyle(
                      color: AppColors.online,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  MessageBubble(message: _messages[index]),
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final hasText = widget.controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
              decoration: const InputDecoration(
                hintText: AppStrings.escribeMensaje,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _hasText ? widget.onSend : null,
              icon: const Icon(Icons.send_rounded),
              color: _hasText ? AppColors.primary : AppColors.onSurfaceMuted,
              style: IconButton.styleFrom(
                backgroundColor: _hasText
                    ? AppColors.primary.withAlpha(30)
                    : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final int colorIndex;
  final double size;

  const _Avatar({
    required this.initials,
    required this.colorIndex,
    this.size = 54,
  });

  static const List<Color> _colors = AppColors.avatarColors;

  @override
  Widget build(BuildContext context) {
    final color = _colors[colorIndex % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(77), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }
}
