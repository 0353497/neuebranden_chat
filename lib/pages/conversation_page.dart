import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:neuebranden_chat/pages/mini_profile_modal.dart';
import 'package:neuebranden_chat/services/chat_api_service.dart';

const _pollInterval = Duration(seconds: 4);

const _groupWindow = Duration(minutes: 5);

const _bottomThreshold = 80.0;

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.room});
  final ChatRoom room;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final ChatApiService _api = ChatApiService();
  late final ScrollController scrollController;
  final TextEditingController _textController = TextEditingController();

  List<ChatMessage> _messages = [];
  Map<String, ChatUser> _usersById = {};

  bool _isLoading = true;
  String? _error;
  bool _isAtBottom = true;
  bool _hasText = false;

  final Set<String> _pendingMessageIds = {};
  final Set<String> _failedMessageIds = {};

  Timer? _pollTimer;
  DateTime? _lastMessageTime;

  String get _currentUserId => _api.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _loadConversation();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final atBottom =
        position.maxScrollExtent - position.pixels <= _bottomThreshold;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final target = scrollController.position.maxScrollExtent;
      if (animate) {
        scrollController.animateTo(
          target,
          duration: 250.milliseconds,
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadConversation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final conversation = await _api.getConversation(widget.room.id);
      final messages = List<ChatMessage>.from(conversation.messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      setState(() {
        _messages = messages;
        _usersById = {for (final u in conversation.users) u.id: u};
        _lastMessageTime = messages.isEmpty ? null : messages.last.createdAt;
        _isLoading = false;
      });
      // requirement 3: always land at the bottom when the room is first opened
      _scrollToBottom(animate: false);
      _startPolling();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollNewMessages());
  }

  Future<void> _pollNewMessages() async {
    try {
      final response = await _api.getMessages(
        widget.room.id,
        from: _lastMessageTime,
      );
      if (response.messages.isEmpty) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final newOnes =
          response.messages.where((m) => !existingIds.contains(m.id)).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (newOnes.isEmpty) return;

      // requirement 4: don't yank the view down if the user scrolled up
      final wasAtBottom = _isAtBottom;

      setState(() {
        _messages = [..._messages, ...newOnes];
        _lastMessageTime = _messages.last.createdAt;
      });

      if (wasAtBottom) _scrollToBottom();
    } catch (_) {
      // silent failure on a background poll tick; next tick will retry
    }
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      senderId: _currentUserId,
      content: content,
      createdAt: DateTime.now(),
    );

    _textController.clear();
    setState(() {
      _messages = [..._messages, optimisticMessage];
      _pendingMessageIds.add(tempId);
      _lastMessageTime = optimisticMessage.createdAt;
    });
    // sending is always assumed to want to see your own message land
    _isAtBottom = true;
    _scrollToBottom();

    try {
      final sent = await _api.sendMessage(widget.room.id, content: content);
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) _messages[index] = sent;
        _pendingMessageIds.remove(tempId);
        _lastMessageTime = _messages.last.createdAt;
      });
    } catch (e) {
      setState(() {
        _pendingMessageIds.remove(tempId);
        _failedMessageIds.add(tempId);
      });
      Get.snackbar("Message failed to send", e.toString());
    }
  }

  Future<void> _toggleReaction(ChatMessage message) async {
    final newLiked = !message.isLiked;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    final updated = ChatMessage(
      id: message.id,
      senderId: message.senderId,
      content: message.content,
      createdAt: message.createdAt,
      isLiked: newLiked,
      isRead: message.isRead,
    );
    setState(() => _messages[index] = updated);

    try {
      final result = await _api.setReaction(message.id, isLiked: newLiked);
      final resultIndex = _messages.indexWhere((m) => m.id == message.id);
      if (resultIndex != -1) setState(() => _messages[resultIndex] = result);
    } catch (e) {
      final rollbackIndex = _messages.indexWhere((m) => m.id == message.id);
      if (rollbackIndex != -1) {
        setState(() => _messages[rollbackIndex] = message);
      }
      Get.snackbar("Couldn't update reaction", e.toString());
    }
  }

  void _copyMessage(ChatMessage message) {
    Clipboard.setData(ClipboardData(text: message.content));
    Get.snackbar("Copied", "Message copied to clipboard");
  }

  void _showMessageMenu(ChatMessage message, Offset tapPosition) {
    if (_pendingMessageIds.contains(message.id) ||
        _failedMessageIds.contains(message.id)) {
      return;
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx,
        tapPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: 'copy', child: Text("Copy")),
        PopupMenuItem(
          value: 'react',
          child: Text(message.isLiked ? "Remove reaction" : "React with ❤️"),
        ),
      ],
    ).then((value) {
      if (value == 'copy') _copyMessage(message);
      if (value == 'react') _toggleReaction(message);
    });
  }

  bool _isGroupStart(int index) {
    if (index == 0) return true;
    final current = _messages[index];
    final previous = _messages[index - 1];
    if (current.senderId != previous.senderId) return true;
    return current.createdAt.difference(previous.createdAt) > _groupWindow;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Row(
          spacing: 4,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(foregroundImage: NetworkImage(widget.room.imageUrl)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${widget.room.memberCount} members",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(child: _buildMessageArea()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              "Couldn't load conversation\n$_error",
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: _loadConversation,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }
    bool showTimestamp(int index) {
      if (index == 0) return true;

      final previous = _messages[index - 1];
      final current = _messages[index];

      return current.createdAt.difference(previous.createdAt) >
          const Duration(minutes: 15);
    }

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            final isMe = message.senderId == _currentUserId;
            final groupStart = _isGroupStart(index);
            return Column(
              children: [
                if (showTimestamp(index))
                  _SystemMessage(
                    message: DateFormat("hh:mm a").format(message.createdAt),
                  ),

                Padding(
                  padding: EdgeInsets.only(top: groupStart ? 12 : 4),
                  child: _MessageBubble(
                    message: message,
                    sender: _usersById[message.senderId],
                    isMe: isMe,
                    showSenderInfo: groupStart && !isMe,
                    isPending: _pendingMessageIds.contains(message.id),
                    isFailed: _failedMessageIds.contains(message.id),
                    onLongPressAt: (position) =>
                        _showMessageMenu(message, position),
                    onAvatarTap: () => Get.to(() => MiniProfileModal()),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: _BackToBottomButton(
            visible: !_isAtBottom,
            onPressed: () {
              _isAtBottom = true;
              _scrollToBottom();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return SizedBox(
      height: 120,
      child: Card(
        child: Row(
          spacing: 4,
          children: [
            IconButton(
              // visual placeholder only, per spec
              onPressed: null,
              icon: Transform.rotate(
                angle: .8,
                child: const Icon(Icons.attach_file),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  suffixIcon: Icon(Icons.mood),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            Transform.rotate(
              angle: -.9,
              child: IconButton(
                onPressed: _hasText ? _sendMessage : null,
                icon: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.isMe,
    required this.showSenderInfo,
    required this.isPending,
    required this.isFailed,
    required this.onLongPressAt,
    required this.onAvatarTap,
  });

  final ChatMessage message;
  final ChatUser? sender;
  final bool isMe;
  final bool showSenderInfo;
  final bool isPending;
  final bool isFailed;
  final void Function(Offset position) onLongPressAt;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final bubble = GestureDetector(
      onLongPressStart: (details) => onLongPressAt(details.globalPosition),
      child: Opacity(
        opacity: isPending ? 0.6 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              color: isMe ? Get.theme.primaryColor : null,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Get.theme.colorScheme.onPrimary : null,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 4,
                      children: [
                        if (isFailed)
                          const Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                        if (isPending)
                          const SizedBox(
                            height: 10,
                            width: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            color: isMe
                                ? Get.theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.7,
                                  )
                                : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // reaction badge, scales in/out when toggled
            Positioned(
              bottom: -6,
              right: isMe ? null : -6,
              left: isMe ? -6 : null,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${message.id}-${message.isLiked}'),
                tween: Tween(
                  begin: message.isLiked ? 0.0 : 1.0,
                  end: message.isLiked ? 1.0 : 0.0,
                ),
                duration: 200.milliseconds,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: message.isLiked
                    ? const Text("❤️", style: TextStyle(fontSize: 16))
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    if (sender == null) {
      return Align(
        alignment: Alignment.center,
        child: Chip(label: Text(message.content)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSenderInfo && sender != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4),
            child: Row(
              spacing: 6,
              children: [
                InkWell(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 12,
                    foregroundImage: sender?.avatarUrl != null
                        ? NetworkImage(sender!.avatarUrl)
                        : null,
                  ),
                ),
                Text(
                  sender?.name ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (sender?.isAuthor ?? false)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified, size: 14, color: Colors.blue),
                  ),
              ],
            ),
          ),
        bubble,
      ],
    );
  }
}

class _BackToBottomButton extends StatelessWidget {
  const _BackToBottomButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: 250.milliseconds,
      curve: Curves.easeOut,
      offset: visible ? Offset.zero : const Offset(0, 0.5),
      child: AnimatedOpacity(
        duration: 250.milliseconds,
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Get.theme.primaryColor),
              foregroundColor: WidgetStatePropertyAll(
                Get.theme.colorScheme.onPrimary,
              ),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_downward),
          ),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
