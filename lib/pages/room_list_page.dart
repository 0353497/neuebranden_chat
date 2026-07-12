import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:neuebranden_chat/pages/conversation_page.dart';
import 'package:neuebranden_chat/pages/room_discovary_modal.dart';
import 'package:neuebranden_chat/services/chat_api_service.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final ChatApiService _api = ChatApiService();

  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _api.getJoinedRooms();
      final rooms = response.rooms;
      _sortRooms(rooms);
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _sortRooms(List<ChatRoom> rooms) {
    rooms.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aTime = a.lastMessage?.createdAt;
      final bTime = b.lastMessage?.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  }

  Future<void> _leaveRoom(ChatRoom room) async {
    final confirmed = await Get.dialog<bool>(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Are you sure to leave this room?"),
              Row(
                spacing: 12,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text("No"),
                  ),
                  ElevatedButton(
                    style: const ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.redAccent),
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                    ),
                    onPressed: () => Get.back(result: true),
                    child: const Text("Yes"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final previousRooms = List<ChatRoom>.from(_rooms);
    setState(() => _rooms.removeWhere((r) => r.id == room.id));

    try {
      await _api.leaveRoom(room.id);
    } catch (e) {
      setState(() => _rooms = previousRooms);
      Get.snackbar("Couldn't leave room", e.toString());
    }
  }

  Future<void> _togglePin(ChatRoom room) async {
    final newPinned = !room.isPinned;
    final index = _rooms.indexWhere((r) => r.id == room.id);
    if (index == -1) return;

    final updated = ChatRoom(
      id: room.id,
      title: room.title,
      description: room.description,
      avatar: room.avatar,
      memberCount: room.memberCount,
      isPinned: newPinned,
      unreadCount: room.unreadCount,
      lastMessage: room.lastMessage,
    );

    setState(() {
      _rooms[index] = updated;
      _sortRooms(_rooms);
    });

    try {
      await _api.pinRoom(room.id, isPinned: newPinned);
    } catch (e) {
      setState(() {
        final rollbackIndex = _rooms.indexWhere((r) => r.id == room.id);
        if (rollbackIndex != -1) _rooms[rollbackIndex] = room;
      });
      Get.snackbar("Couldn't update pin", e.toString());
    }
  }

  Future<void> _openRoomDiscovery() async {
    await Get.dialog(const RoomDiscovaryModal());
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NeubrandenBook"),
            Text("Book Club Chats", style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openRoomDiscovery,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Get.theme.primaryColor),
              foregroundColor: WidgetStatePropertyAll(
                Get.theme.colorScheme.onPrimary,
              ),
            ),
            onPressed: _openRoomDiscovery,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text("Couldn't load rooms\n$_error", textAlign: TextAlign.center),
            ElevatedButton(onPressed: _loadRooms, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Text("You haven't joined any rooms yet"),
            ElevatedButton(
              onPressed: _openRoomDiscovery,
              child: const Text("Find a room"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return SizedBox(
            height: 64,
            child: PageView(
              controller: PageController(initialPage: 1),
              children: [
                TextButton.icon(
                  style: const ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                    backgroundColor: WidgetStatePropertyAll(Colors.redAccent),
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () => _leaveRoom(room),
                  label: const Text("Leave"),
                ),
                ListTile(
                  onTap: () {
                    Get.to(() => ConversationPage(room: room));
                  },
                  leading: Badge.count(
                    count: room.unreadCount,
                    isLabelVisible: room.unreadCount > 0,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(room.imageUrl),
                    ),
                  ),
                  title: Text(room.title),
                  subtitle: Text(
                    room.lastMessage?.content ?? "No messages yet",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: room.lastMessage != null
                      ? Text(
                          DateFormat(
                            "dd/MM/yyyy",
                          ).format(room.lastMessage!.createdAt),
                          style: const TextStyle(color: Colors.grey),
                        )
                      : null,
                ),
                TextButton.icon(
                  icon: Icon(
                    room.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  onPressed: () => _togglePin(room),
                  label: Text(room.isPinned ? "Unpin" : "Pin"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
