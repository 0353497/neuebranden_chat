import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neuebranden_chat/services/chat_api_service.dart';

class RoomDiscovaryModal extends StatefulWidget {
  const RoomDiscovaryModal({super.key});

  @override
  State<RoomDiscovaryModal> createState() => _RoomDiscovaryModalState();
}

class _RoomDiscovaryModalState extends State<RoomDiscovaryModal> {
  final SearchController searchController = SearchController();
  final ChatApiService _api = ChatApiService();

  List<Room> _allRooms = [];
  List<Room> _filteredRooms = [];
  bool _isLoading = true;
  String? _error;

  Set<String> _joinedRoomIds = {};

  final Set<String> _joiningRoomIds = {};

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _loadRooms();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      _filteredRooms = query.isEmpty
          ? _allRooms
          : _allRooms
                .where((room) => room.title.toLowerCase().contains(query))
                .toList();
    });
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getRooms(),
        _api.getJoinedRooms(),
      ]);
      final roomsResponse = results[0] as RoomsResponse;
      final joinedResponse = results[1] as JoinedRoomsResponse;
      setState(() {
        _allRooms = roomsResponse.rooms;
        _filteredRooms = roomsResponse.rooms;
        _joinedRoomIds = joinedResponse.rooms.map((r) => r.id).toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinRoom(Room room) async {
    setState(() => _joiningRoomIds.add(room.id));
    try {
      await _api.joinRoom(room.id);
      setState(() => _joinedRoomIds.add(room.id));
    } catch (e) {
      Get.snackbar("Couldn't join room", e.toString());
    } finally {
      setState(() => _joiningRoomIds.remove(room.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Get.height * .6,
      width: Get.width * .9,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const SizedBox(),
                  const Text(
                    "Discover Rooms",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                "Join book clubs and chat with other readers and authors",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SearchBar(
                elevation: const WidgetStatePropertyAll(1),
                controller: searchController,
                leading: const Icon(Icons.search),
                hintText: "Search for rooms...",
              ),
              Expanded(child: _buildRoomList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomList() {
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

    if (_filteredRooms.isEmpty) {
      return const Center(child: Text("No rooms found"));
    }

    return ListView.separated(
      itemBuilder: (context, index) {
        final room = _filteredRooms[index];
        final isJoined = _joinedRoomIds.contains(room.id);
        final isJoining = _joiningRoomIds.contains(room.id);

        return SizedBox(
          height: 160,
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(backgroundImage: NetworkImage(room.imageUrl)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("${room.memberCount} members"),
                          Flexible(
                            child: Text(
                              room.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isJoined || isJoining
                        ? null
                        : () => _joinRoom(room),
                    child: isJoining
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isJoined ? "Joined" : "Join"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: _filteredRooms.length,
    );
  }
}
