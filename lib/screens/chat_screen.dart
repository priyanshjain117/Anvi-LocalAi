import 'package:flutter/material.dart';
import '../models/llm_model.dart';
import '../services/model_manager.dart';
import 'model_picker_screen.dart';

class ChatScreen extends StatefulWidget {
  final LLMModel model;
  const ChatScreen({super.key, required this.model});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _manager = ModelManager();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _thinking = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;

    _controller.clear();
    setState(() {
      _messages.add(_Message(role: 'user', text: text));
      _messages.add(_Message(role: 'assistant', text: ''));
      _thinking = true;
    });
    _scrollToBottom();

    try {
      // _manager.chat() returns a Stream<String> of tokens
      await for (final token in _manager.chat(text)) {
        setState(() {
          _messages.last = _Message(
            role: 'assistant',
            text: _messages.last.text + token,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.last = _Message(role: 'assistant', text: '⚠️ Error: $e');
      });
    } finally {
      setState(() => _thinking = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.model.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            Row(children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              const Text('Running locally',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ]),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(modelName: widget.model.name)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _ChatBubble(message: _messages[i]),
                  ),
          ),
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ask something…',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 15),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _thinking ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _thinking
                        ? Colors.white12
                        : const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _thinking
                        ? Icons.hourglass_top_rounded
                        : Icons.arrow_upward_rounded,
                    color: _thinking ? Colors.white30 : Colors.black,
                    size: 22,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _Message {
  final String role;
  final String text;
  const _Message({required this.role, required this.text});
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF00E5FF).withOpacity(0.15)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFF00E5FF).withOpacity(0.25)
                : Colors.white12,
          ),
        ),
        child: message.text.isEmpty
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF00E5FF)),
              )
            : Text(message.text,
                style: const TextStyle(fontSize: 14.5, height: 1.5)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String modelName;
  const _EmptyState({required this.modelName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFF00E5FF), size: 32),
          ),
          const SizedBox(height: 20),
          Text(modelName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Ask me anything — runs entirely on your device.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}