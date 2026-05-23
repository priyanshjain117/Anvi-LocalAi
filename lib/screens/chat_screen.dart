import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/theme/anvi_colors.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/ambient_background.dart';
import '../core/widgets/anvi_logo.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/pressable_scale.dart';
import '../models/chat_turn.dart';
import '../models/file_attachment.dart';
import '../models/llm_model.dart';
import '../services/file_attachment_service.dart';
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
  final _fileService = FileAttachmentService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  final List<FileAttachment> _attachedFiles = [];
  StreamSubscription<String>? _streamSub;
  bool _thinking = false;
  bool _pickingFiles = false;
  bool _showJump = false;
  bool _userNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _manager.stopGeneration();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final distance =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    _userNearBottom = distance < 160;
    final shouldShow = distance > 360;
    if (shouldShow != _showJump) setState(() => _showJump = shouldShow);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;

    HapticFeedback.lightImpact();
    _controller.clear();
    final promptAttachments =
        _attachedFiles.where((file) => file.isReady).toList(growable: false);
    final history = _messages
        .where((message) => message.text.trim().isNotEmpty)
        .map((message) => ChatTurn(
              role: message.role == _Role.user
                  ? ChatRole.user
                  : ChatRole.assistant,
              text: message.text,
            ))
        .toList(growable: false);
    setState(() {
      _messages.add(_Message(
        role: _Role.user,
        text: text,
        createdAt: DateTime.now(),
        attachments: promptAttachments,
      ));
      _messages.add(_Message(
        role: _Role.assistant,
        text: '',
        createdAt: DateTime.now(),
      ));
      _attachedFiles.removeWhere((file) => file.isReady);
      _thinking = true;
    });
    _scrollToBottom(force: true);

    final buffer = StringBuffer();
    var lastPaint = DateTime.now();
    await _streamSub?.cancel();
    _streamSub = _manager
        .chat(text, history: history, attachments: promptAttachments)
        .listen((token) {
      buffer.write(token);
      final now = DateTime.now();
      if (now.difference(lastPaint).inMilliseconds < 45) return;
      lastPaint = now;
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] =
            _messages.last.copyWith(text: buffer.toString());
      });
      _scrollToBottom();
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _Message(
          role: _Role.assistant,
          text: _friendlyError(error),
          createdAt: DateTime.now(),
          failed: true,
        );
        _thinking = false;
      });
    }, onDone: () {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: buffer.toString().trim(),
        );
        _thinking = false;
      });
      _scrollToBottom(force: true);
    });
  }

  void _stop() {
    HapticFeedback.selectionClick();
    _streamSub?.cancel();
    _manager.stopGeneration();
    setState(() => _thinking = false);
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_userNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _pickFiles() async {
    if (_pickingFiles || _thinking) return;
    HapticFeedback.selectionClick();
    setState(() => _pickingFiles = true);
    try {
      final files = await _fileService.pickAndParse();
      if (!mounted || files.isEmpty) return;
      setState(() {
        _attachedFiles
          ..removeWhere((file) => !file.isReady)
          ..addAll(files);
      });
      final failed = files.where((file) => !file.isReady).length;
      if (failed > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failed file could not be parsed')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  void _removeAttachment(FileAttachment file) {
    setState(() => _attachedFiles.remove(file));
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('memory') ||
        message.toLowerCase().contains('oom')) {
      return 'I ran out of available memory while generating. Try a shorter prompt or reload a smaller model.';
    }
    return 'I hit an inference error. Please try again with a shorter message.';
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 860;

    return Scaffold(
      drawer: tablet ? null : _AnviDrawer(model: widget.model),
      body: AmbientBackground(
        child: SafeArea(
          child: Row(
            children: [
              if (tablet)
                SizedBox(
                    width: 310,
                    child: _AnviDrawer(model: widget.model, embedded: true)),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _ChatTopBar(model: widget.model, tablet: tablet),
                        Expanded(
                          child: _messages.isEmpty
                              ? _EmptyState(
                                  model: widget.model,
                                  onPrompt: (value) {
                                    _controller.text = value;
                                    _send();
                                  })
                              : ListView.builder(
                                  controller: _scrollController,
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(
                                    tablet ? 36 : 18,
                                    18,
                                    tablet ? 36 : 18,
                                    18,
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    return _ChatBubble(
                                      message: message,
                                      streaming: _thinking &&
                                          index == _messages.length - 1 &&
                                          message.role == _Role.assistant,
                                      onCopy: () => _copyMessage(message.text),
                                    );
                                  },
                                ),
                        ),
                        _Composer(
                          controller: _controller,
                          focusNode: _focusNode,
                          thinking: _thinking,
                          pickingFiles: _pickingFiles,
                          attachments: _attachedFiles,
                          onSend: _send,
                          onStop: _stop,
                          onAttach: _pickFiles,
                          onRemoveAttachment: _removeAttachment,
                        ),
                      ],
                    ),
                    Positioned(
                      right: 24,
                      bottom: 118 + MediaQuery.viewInsetsOf(context).bottom,
                      child: AnimatedScale(
                        scale: _showJump ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: AnviColors.smokedGlass,
                          foregroundColor: AnviColors.champagne,
                          child: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  final LLMModel model;
  final bool tablet;

  const _ChatTopBar({required this.model, required this.tablet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(tablet ? 34 : 14, 14, tablet ? 34 : 14, 8),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            if (!tablet)
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            const AnviLogo(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      _LiveDot(),
                      SizedBox(width: 6),
                      Text('Running locally',
                          style:
                              TextStyle(fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Models',
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                    builder: (_) => const ModelPickerScreen()),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.55,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: AnviColors.success, shape: BoxShape.circle),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool thinking;
  final bool pickingFiles;
  final List<FileAttachment> attachments;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final ValueChanged<FileAttachment> onRemoveAttachment;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.thinking,
    required this.pickingFiles,
    required this.attachments,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 860;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(tablet ? 36 : 16, 8, tablet ? 36 : 16, 16),
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          return GlassPanel(
            glow: focusNode.hasFocus,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachments.isNotEmpty)
                  _AttachmentTray(
                    attachments: attachments,
                    onRemove: onRemoveAttachment,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Attach file',
                      onPressed: thinking || pickingFiles ? null : onAttach,
                      icon: pickingFiles
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded,
                              color: Colors.white54),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 15.5, height: 1.35),
                        decoration: const InputDecoration(
                          hintText: 'Ask Anvi anything...',
                          hintStyle: TextStyle(color: Colors.white38),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                          filled: false,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    PressableScale(
                      onTap: thinking ? onStop : onSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: thinking
                                ? [AnviColors.crimson, AnviColors.ember]
                                : [AnviColors.champagne, AnviColors.ember],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (thinking
                                      ? AnviColors.crimson
                                      : AnviColors.ember)
                                  .withValues(alpha: 0.42),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: Icon(
                          thinking
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          color: AnviColors.voidBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttachmentTray extends StatelessWidget {
  final List<FileAttachment> attachments;
  final ValueChanged<FileAttachment> onRemove;

  const _AttachmentTray({
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: attachments.map((file) {
            final failed = !file.isReady;
            return Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: BoxDecoration(
                color: failed
                    ? AnviColors.crimson.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: failed
                      ? AnviColors.crimson.withValues(alpha: 0.35)
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.description_rounded,
                    size: 15,
                    color: failed ? AnviColors.crimson : AnviColors.champagne,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    constraints:
                        const BoxConstraints.tightFor(width: 30, height: 30),
                    padding: EdgeInsets.zero,
                    onPressed: () => onRemove(file),
                    icon: const Icon(Icons.close_rounded,
                        size: 15, color: Colors.white38),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Message {
  final _Role role;
  final String text;
  final DateTime createdAt;
  final List<FileAttachment> attachments;
  final bool failed;

  const _Message({
    required this.role,
    required this.text,
    required this.createdAt,
    this.attachments = const [],
    this.failed = false,
  });

  _Message copyWith({String? text}) {
    return _Message(
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      attachments: attachments,
      failed: failed,
    );
  }
}

enum _Role { user, assistant }

class _ChatBubble extends StatelessWidget {
  final _Message message;
  final bool streaming;
  final VoidCallback onCopy;

  const _ChatBubble({
    required this.message,
    required this.streaming,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    final maxWidth = MediaQuery.sizeOf(context).width >= 860
        ? 680.0
        : MediaQuery.sizeOf(context).width * 0.82;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GestureDetector(
            onLongPress: message.text.isEmpty ? null : onCopy,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: message.failed
                      ? [
                          AnviColors.crimson.withValues(alpha: 0.18),
                          AnviColors.crimson.withValues(alpha: 0.08),
                        ]
                      : isUser
                          ? [
                              AnviColors.ember.withValues(alpha: 0.28),
                              AnviColors.crimson.withValues(alpha: 0.16),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.075),
                              Colors.white.withValues(alpha: 0.035),
                            ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                border: Border.all(
                  color: isUser
                      ? AnviColors.champagne.withValues(alpha: 0.25)
                      : Colors.white10,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnviLogo(size: 22),
                            SizedBox(width: 8),
                            Text('Anvi',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    if (message.text.isEmpty)
                      const _TypingIndicator()
                    else
                      _MarkdownMessage(text: message.text),
                    if (message.attachments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.attachments
                            .map((file) => _SentAttachmentChip(file: file))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TimeOfDay.fromDateTime(message.createdAt)
                              .format(context),
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.white38),
                        ),
                        if (!isUser && message.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onCopy,
                            borderRadius: BorderRadius.circular(99),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.copy_rounded,
                                  size: 13, color: Colors.white38),
                            ),
                          ),
                        ],
                        if (streaming) ...[
                          const SizedBox(width: 8),
                          const Text('thinking',
                              style: TextStyle(
                                  fontSize: 10.5, color: AnviColors.champagne)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentAttachmentChip extends StatelessWidget {
  final FileAttachment file;

  const _SentAttachmentChip({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_rounded,
              size: 14, color: AnviColors.champagne),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownMessage extends StatelessWidget {
  final String text;

  const _MarkdownMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      fitContent: false,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 14.8, height: 1.5, color: AnviColors.bone),
        code: const TextStyle(
          fontSize: 13,
          color: AnviColors.champagne,
          backgroundColor: Colors.transparent,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        blockquoteDecoration: BoxDecoration(
          color: AnviColors.ember.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              const Border(left: BorderSide(color: AnviColors.ember, width: 3)),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1;
            return Container(
              margin: const EdgeInsets.only(right: 5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color:
                    AnviColors.champagne.withValues(alpha: 0.35 + phase * 0.55),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LLMModel model;
  final ValueChanged<String> onPrompt;

  const _EmptyState({required this.model, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Summarize how this model works on-device.',
      'Write a concise launch pitch for Anvi.',
      'Draft Dart code for a streaming chat UI.',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 44, 22, 150),
      children: [
        Center(
          child: Column(
            children: [
              const AnviLogo(size: 76, pulse: true),
              const SizedBox(height: 22),
              Text(
                'Anvi is ready',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${model.name} is loaded locally. No cloud, no keys, no data leaving your device.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PressableScale(
              onTap: () => onPrompt(prompt),
              child: GlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                borderRadius: BorderRadius.circular(18),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AnviColors.champagne, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(prompt)),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnviDrawer extends StatelessWidget {
  final LLMModel model;
  final bool embedded;

  const _AnviDrawer({required this.model, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = AmbientBackground(
      particles: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AnviLogo(size: 44),
                  SizedBox(width: 12),
                  Text('Anvi',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 26),
              GlassPanel(
                glow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active model',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(model.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DrawerPill(model.performanceLabel),
                        _DrawerPill(model.ramLabel),
                        _DrawerPill(Formatters.bytes(model.sizeBytes)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DrawerTile(
                  icon: Icons.downloading_rounded,
                  label: 'Downloaded models',
                  value: 'Manage'),
              _DrawerTile(
                  icon: Icons.storage_rounded,
                  label: 'Storage usage',
                  value: 'Local files'),
              _DrawerTile(
                  icon: Icons.memory_rounded,
                  label: 'Device capability',
                  value: 'CPU/Metal aware'),
              _DrawerTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'AMOLED theme',
                  value: 'On'),
              const Spacer(),
              Text(
                'Inference runs through fllama and llama.cpp. Keep the app in release mode for best token speed.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white38, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );

    if (embedded) {
      return DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white10))),
        child: content,
      );
    }
    return Drawer(backgroundColor: AnviColors.voidBlack, child: content);
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DrawerTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(13),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Icon(icon, color: AnviColors.champagne, size: 19),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value,
                style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _DrawerPill extends StatelessWidget {
  final String label;

  const _DrawerPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
    );
  }
}
