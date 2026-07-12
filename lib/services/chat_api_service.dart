import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown whenever the API returns a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ===========================================================================
// Models
// ===========================================================================

class ChatUser {
  final String id;
  final String name;
  final String? avatarUrl;

  ChatUser({required this.id, required this.name, this.avatarUrl});

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isLiked;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isLiked = false,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    senderId: json['senderId'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isLiked: json['isLiked'] as bool? ?? false,
    isRead: json['isRead'] as bool? ?? false,
  );
}

/// `GET /rooms` — a discoverable room, not yet necessarily joined.
///
/// Matches the actual API shape:
/// ```json
/// {
///   "id": "crime-thriller",
///   "title": "Crime & Thriller Readers",
///   "description": "For fans of suspense, mysteries, and thrillers...",
///   "avatar": "plodowski-swabia-by-krimitinten.png",
///   "memberCount": 2
/// }
/// ```
class Room {
  final String id;
  final String title;
  final String description;
  final String avatar;
  final int memberCount;

  Room({
    required this.id,
    required this.title,
    required this.description,
    required this.avatar,
    required this.memberCount,
  });

  String get imageUrl => '${ChatApiService.baseUrl}/assets/$avatar';

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    avatar: json['avatar'] as String,
    memberCount: json['memberCount'] as int? ?? 0,
  );
}

/// `GET /rooms/joined` — a room the user has already joined.
///
/// Response schema for this one wasn't in the Swagger doc, so this keeps the
/// same base fields as [Room] plus the join-specific extras (`isPinned`,
/// `unreadCount`, `lastMessage`). Adjust `fromJson` if the real shape differs.
class ChatRoom {
  final String id;
  final String title;
  final String description;
  final String avatar;
  final int memberCount;
  final bool isPinned;
  final int unreadCount;
  final ChatMessage? lastMessage;

  ChatRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.avatar,
    required this.memberCount,
    this.isPinned = false,
    this.unreadCount = 0,
    this.lastMessage,
  });

  String get imageUrl => '${ChatApiService.baseUrl}/assets/$avatar';

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    avatar: json['avatar'] as String,
    memberCount: json['memberCount'] as int? ?? 0,
    isPinned: json['isPinned'] as bool? ?? false,
    unreadCount: json['unreadCount'] as int? ?? 0,
    lastMessage: json['lastMessage'] == null
        ? null
        : ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
  );
}

/// Wraps `GET /rooms`.
class RoomsResponse {
  final List<Room> rooms;

  RoomsResponse({required this.rooms});

  factory RoomsResponse.fromJson(dynamic json) {
    final list = json is List ? json : (json['rooms'] as List);
    return RoomsResponse(
      rooms: list.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Wraps `GET /rooms/joined`.
class JoinedRoomsResponse {
  final List<ChatRoom> rooms;

  JoinedRoomsResponse({required this.rooms});

  factory JoinedRoomsResponse.fromJson(dynamic json) {
    final list = json is List ? json : (json['rooms'] as List);
    return JoinedRoomsResponse(
      rooms: list
          .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Wraps `GET /messages/{roomId}`.
class MessagesResponse {
  final List<ChatMessage> messages;

  MessagesResponse({required this.messages});

  factory MessagesResponse.fromJson(dynamic json) {
    final list = json is List ? json : (json['messages'] as List);
    return MessagesResponse(
      messages: list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `GET /conversations/{roomId}` — messages + users in the room.
class Conversation {
  final String roomId;
  final List<ChatMessage> messages;
  final List<ChatUser> users;

  Conversation({
    required this.roomId,
    required this.messages,
    required this.users,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    roomId: json['roomId'] as String,
    messages: (json['messages'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(),
    users: (json['users'] as List)
        .map((e) => ChatUser.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ===========================================================================
// Service
// ===========================================================================

/// Central HTTP client for the NeubrandenBook chat room API.
///
/// Realtime updates (NEW_MESSAGE) are delivered via Socket.io separately —
/// this class only handles the REST endpoints.
class ChatApiService {
  ChatApiService._internal();
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;

  final http.Client _client = http.Client();

  static const String baseUrl = 'http://10.0.2.2:3000';

  /// Provide the auth token however you store it (SharedPreferences, secure
  /// storage, GetX controller, etc). Kept as a simple override hook.
  String? Function() authTokenProvider = () => null;

  Map<String, String> get _headers {
    final token = authTokenProvider();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final filtered = <String, String>{
      if (query != null)
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value!,
    };
    return Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  /// Decodes the response body as JSON, or throws [ApiException] on failure.
  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {
      // body wasn't JSON, fall back to raw text
    }
    throw ApiException(status, message);
  }

  // ---------------------------------------------------------------------
  // Rooms
  // ---------------------------------------------------------------------

  /// GET /rooms — get all (discoverable) rooms
  Future<RoomsResponse> getRooms() async {
    try {
      final response = await _client.get(_uri('/rooms'), headers: _headers);
      return RoomsResponse.fromJson(_decode(response));
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  /// GET /rooms/joined — get joined rooms
  Future<JoinedRoomsResponse> getJoinedRooms() async {
    try {
      final response = await _client.get(
        _uri('/rooms/joined'),
        headers: _headers,
      );
      return JoinedRoomsResponse.fromJson(_decode(response));
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  /// POST /rooms/{roomId}/join — join a room
  Future<void> joinRoom(String roomId) async {
    final response = await _client.post(
      _uri('/rooms/$roomId/join'),
      headers: _headers,
    );
    _decode(response);
  }

  /// PATCH /rooms/{roomId}/pin — pin/unpin a room
  Future<void> pinRoom(String roomId, {required bool isPinned}) async {
    final response = await _client.patch(
      _uri('/rooms/$roomId/pin'),
      headers: _headers,
      body: jsonEncode({'isPinned': isPinned}),
    );
    _decode(response);
  }

  /// POST /rooms/{roomId}/leave — leave a room
  Future<void> leaveRoom(String roomId) async {
    final response = await _client.post(
      _uri('/rooms/$roomId/leave'),
      headers: _headers,
    );
    _decode(response);
  }

  // ---------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------

  /// GET /conversations/{roomId} — get conversation (messages + users)
  Future<Conversation> getConversation(String roomId) async {
    final response = await _client.get(
      _uri('/conversations/$roomId'),
      headers: _headers,
    );
    return Conversation.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------

  /// GET /messages/{roomId} — get messages, optionally filtered by
  /// [from]/[to] timestamps (ISO-8601, e.g. 2024-01-01T00:00:00Z)
  Future<MessagesResponse> getMessages(
    String roomId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _client.get(
      _uri('/messages/$roomId', {
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
      }),
      headers: _headers,
    );
    return MessagesResponse.fromJson(_decode(response));
  }

  /// POST /messages/{roomId} — send a message
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String content,
  }) async {
    final response = await _client.post(
      _uri('/messages/$roomId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    return ChatMessage.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PATCH /messages/{roomId}/read — mark room as read
  Future<void> markRoomAsRead(String roomId) async {
    final response = await _client.patch(
      _uri('/messages/$roomId/read'),
      headers: _headers,
    );
    _decode(response);
  }

  /// PATCH /messages/{messageId}/reaction — like/unlike a message
  Future<ChatMessage> setReaction(
    String messageId, {
    required bool isLiked,
  }) async {
    final response = await _client.patch(
      _uri('/messages/$messageId/reaction'),
      headers: _headers,
      body: jsonEncode({'isLiked': isLiked}),
    );
    return ChatMessage.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------
  // Assets
  // ---------------------------------------------------------------------

  /// GET /assets/{id} — fetch the asset just to confirm it exists / trigger
  /// caching. Returns nothing; throws [ApiException] on 404 or other errors.
  Future<void> getAsset(String id) async {
    final response = await _client.get(_uri('/assets/$id'), headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(response.statusCode, response.body);
  }

  void dispose() => _client.close();
}
