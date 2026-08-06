import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../models/usage_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/limits_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/markdown_renderer.dart';
import '../shell/main_shell.dart';

class ChatScreen extends StatefulWidget {
  final String uid;
  const ChatScreen({super.key, required this.uid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatItem> _items = [];
  String? _chatId;
  bool _sending = false;
  bool _searchEnabled = false;
  int _bonusChats = 0;
  bool _streamingFailed = false;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final user = await AuthService.instance.userOnce(widget.uid);
    if (!mounted || user == null) return;
    setState(() => _bonusChats = user.bonusChats);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    // Gate + consume a chat credit (mirrors web checkAndGate).
    final result = await LimitsService.instance.consume(
      widget.uid,
      type: UsageType.chat,
      plan: 'free',
      bonusChats: _bonusChats,
    );
    if (!mounted) return;
    if (!result.allowed) {
      showAquilaSnack(context, 'Daily chat limit reached — upgrade for unlimited chats.', error: true);
      return;
    }

    setState(() {
      _items.add(_ChatItem.user(text));
      _sending = true;
      _streamingFailed = false;
      _items.add(_ChatItem.assistant(''));
    });
    _input.clear();
    _scrollToBottom();

    try {
      final assistantId = _items.length - 1;
      _chatId ??= await ChatService.instance.createSession(widget.uid);
      await ChatService.instance.saveMessage(widget.uid, _chatId!, 'user', text);

      // Build the message payload (mirrors web chat.js).
      final system = await ChatService.instance.buildSystemPrompt(widget.uid);
      final history = await ChatService.instance.loadHistory(widget.uid, _chatId!);
      var userPayload = text;
      if (_searchEnabled) {
        final searchCtx = await ChatService.instance.buildSearchContext(text);
        if (searchCtx != null) userPayload = '$text\n$searchCtx';
      }
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': system},
        ...history,
        {'role': 'user', 'content': userPayload},
      ];

      var full = '';
      await for (final delta in ApiClient.instance.streamJson(
        AppConfig.groqProxyPath,
        {
          'model': AppConfig.chatModel,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
          'stream': true,
        },
      )) {
        full += delta;
        if (!mounted) return;
        setState(() {
          _items[assistantId] = _ChatItem.assistant(full);
        });
        _scrollToBottom();
      }

      if (!mounted) return;
      final finalText = full.trim();
      if (finalText.isEmpty) {
        setState(() => _streamingFailed = true);
      } else {
        await ChatService.instance.saveMessage(widget.uid, _chatId!, 'assistant', finalText);
      }
    } on ApiException catch (e) {
      _failCount++;
      if (mounted) {
        setState(() {
          _items.removeLast();
          if (_items.isNotEmpty && _items.last.isUser) {
            _items.add(_ChatItem.error('${_errorText(e)} ($_failCount)'));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _items.removeLast();
          if (_items.isNotEmpty && _items.last.isUser) {
            _items.add(_ChatItem.error('Could not reach Aquila. Check your connection.'));
          }
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _errorText(ApiException e) {
    if (e.statusCode == 503) {
      return 'The AI is busy right now (queue full). Please try again in a moment.';
    }
    return '${e.message} — tap again to retry.';
  }

  Future<void> _newChat() async {
    setState(() {
      _chatId = null;
      _items.clear();
      _streamingFailed = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Aquila AI'),
        actions: [
          IconButton(
            tooltip: _searchEnabled ? 'Web search: ON' : 'Web search: OFF',
            onPressed: () => setState(() => _searchEnabled = !_searchEnabled),
            icon: Icon(
              _searchEnabled ? Icons.public : Icons.public_off,
              color: _searchEnabled ? AquilaColors.accent : ext.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? _emptyState(ext)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => _ChatBubble(item: _items[i]),
                  ),
          ),
          if (_streamingFailed) _retryBar(ext),
          _inputBar(ext),
        ],
      ),
    );
  }

  Widget _emptyState(AquilaThemeExt ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AquilaLogo(size: 64),
            const SizedBox(height: 20),
            const Text(
              'What shall we learn today?',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AquilaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask anything — Aquila teaches, tests recall,\nand adapts to how you learn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 13,
                height: 1.5,
                color: ext.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final chip in const [
                  'Explain Newton\'s second law',
                  'Give me a quiz on redox',
                  'Help me with integration',
                  'Summarize cell division',
                ])
                  ActionChip(
                    label: Text(chip, style: const TextStyle(fontSize: 12)),
                    backgroundColor: ext.bgCard,
                    side: BorderSide(color: ext.border),
                    labelStyle: TextStyle(color: ext.textPrimary),
                    onPressed: () {
                      _input.text = chip;
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _retryBar(AquilaThemeExt ext) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      color: ext.bgCard,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AquilaColors.accent4),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The AI was interrupted.',
              style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 12.5, color: ext.textSecondary),
            ),
          ),
          TextButton(onPressed: _send, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _inputBar(AquilaThemeExt ext) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: ext.bgBase,
        border: Border(top: BorderSide(color: ext.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message Aquila…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _sending ? AquilaColors.textMuted : AquilaColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(
                    Icons.arrow_upward,
                    color: AquilaColors.onAccentText,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem {
  final String role; // user | assistant | error
  final String text;
  const _ChatItem(this.role, this.text);

  factory _ChatItem.user(String t) => _ChatItem('user', t);
  factory _ChatItem.assistant(String t) => _ChatItem('assistant', t);
  factory _ChatItem.error(String t) => _ChatItem('error', t);

  bool get isUser => role == 'user';
}

class _ChatBubble extends StatelessWidget {
  final _ChatItem item;
  const _ChatBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (item.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AquilaColors.buttonGradientStart, AquilaColors.buttonGradientEnd],
            ),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: const Radius.circular(4),
            ),
          ),
          child: Text(
            item.text,
            style: const TextStyle(
              fontFamily: AquilaColors.fontMain,
              fontSize: 14.5,
              height: 1.45,
              color: AquilaColors.onAccentText,
            ),
          ),
        ),
      );
    }
    if (item.role == 'error') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AquilaColors.bgCard,
            borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
            border: Border.all(color: AquilaColors.accent3.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 16, color: AquilaColors.accent3),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.text,
                  style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13, color: ext.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(color: ext.border),
        ),
        child: item.text.isEmpty
            ? _typingDots(ext)
            : const MarkdownRenderer().render(item.text, context),
      ),
    );
  }

  Widget _typingDots(AquilaThemeExt ext) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: Duration(milliseconds: 600 + i * 150),
              builder: (context, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AquilaColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}