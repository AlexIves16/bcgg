import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'webrtc_manager.dart';

class ChatCache {
  static final ChatCache _instance = ChatCache._internal();
  factory ChatCache() => _instance;
  ChatCache._internal();

  /// Loads the message history for a specific group id
  Future<List<GroupMessage>> loadMessages(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_messages_$groupId';
    final String? jsonString = prefs.getString(key);
    
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => GroupMessage.fromJson(json)).toList();
    } catch (e) {
      print('[ChatCache] Error decoding messages: $e');
      return [];
    }
  }

  /// Appends a single message to the cache
  Future<void> saveMessage(String groupId, GroupMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_messages_$groupId';
    
    // 1. Load existing
    final String? jsonString = prefs.getString(key);
    List<dynamic> jsonList = [];
    if (jsonString != null) {
      try {
        jsonList = jsonDecode(jsonString);
      } catch (e) {
        // ignore corrupted cache
        print('[ChatCache] Corrupted cache for $groupId, starting fresh');
      }
    }
    
    // 2. Check for duplicates before adding
    final bool exists = jsonList.any((json) {
      final existingMsgId = json['messageId'] as String?;
      return existingMsgId == message.messageId;
    });
    
    if (!exists) {
      // Append new message
      jsonList.add(message.toJson());
      
      // Sort by timestamp
      jsonList.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    }
    
    // 3. Limit cache size to last 500 messages per chat
    if (jsonList.length > 500) {
      jsonList.removeRange(0, jsonList.length - 500);
    }
    
    // 4. Save back
    await prefs.setString(key, jsonEncode(jsonList));
  }

  /// Clear all messages for a group
  Future<void> clearMessages(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_messages_$groupId';
    await prefs.remove(key);
  }
}
