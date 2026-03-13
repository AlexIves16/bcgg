# Chat Cache Implementation Guide

## Overview
Digital Ether now includes persistent chat history using local caching. Messages are stored on-device and persist across app restarts.

## Features Implemented (v32)

### ✅ Message Persistence
- **Local Storage**: All P2P chat messages saved to SharedPreferences
- **Auto-Load**: Chat history loads automatically when opening chat screen
- **Deduplication**: Smart duplicate prevention using unique message IDs
- **Size Limiting**: Maximum 500 messages per chat (auto-cleanup)

### ✅ How It Works

```
User sends message
    ↓
1. WebRTC broadcasts to peers
2. Message saved to local cache (sender)
3. Message added to UI stream
    ↓
Peer receives message
    ↓
1. WebRTC data channel delivers
2. Message saved to cache (receiver)
3. Message added to UI stream
```

### File Structure
```
lib/network/
├── webrtc_manager.dart   # Main WebRTC logic + cache integration
├── chat_cache.dart       # Cache storage/retrieval logic
└── chat_screen.dart      # UI with auto-load on init
```

## Technical Details

### Message Format
```dart
{
  "text": "Hello!",
  "senderId": "user123",
  "senderName": "Alice",
  "timestamp": 1678901234567,
  "messageId": "user123_1678901234567"  // Unique ID for deduplication
}
```

### Storage Keys
Messages stored per group:
- Key format: `chat_messages_{groupId}`
- Example: `chat_messages_abc123xyz`

### Deduplication Logic
```dart
// Check if message already exists by messageId
final bool exists = jsonList.any((json) {
  final existingMsgId = json['messageId'] as String?;
  return existingMsgId == message.messageId;
});
```

### Auto-Cleanup
When cache exceeds 500 messages:
```dart
if (jsonList.length > 500) {
  jsonList.removeRange(0, jsonList.length - 500);
}
```
Oldest messages removed first (FIFO).

## Usage

### Loading Messages
```dart
// Automatic in ChatScreen initState
@override
void initState() {
  super.initState();
  _loadCachedMessages(); // Loads from SharedPreferences
  // ... rest of init
}

Future<void> _loadCachedMessages() async {
  final cached = await ChatCache().loadMessages(widget.groupId);
  setState(() => _messages.addAll(cached));
}
```

### Saving Messages
Automatic in two places:

**1. Sender (broadcastMessage)**
```dart
void broadcastMessage(String text) {
  final msg = GroupMessage(...);
  
  // Send via WebRTC
  _dataChannels.values.forEach((dc) => dc.send(json));
  
  // Save to cache
  ChatCache().saveMessage(_currentGroupId!, msg);
  
  // Add to stream
  _messageController.add(msg);
}
```

**2. Receiver (onMessage)**
```dart
dc.onMessage = (message) {
  final msg = GroupMessage.fromJson(jsonDecode(message.text));
  
  // Save to cache
  ChatCache().saveMessage(_currentGroupId!, msg);
  
  // Add to stream
  _messageController.add(msg);
};
```

## Testing Scenarios

### Scenario 1: App Restart
1. Open chat → Send 5 messages
2. Close app completely
3. Reopen app → Navigate to chat
4. **Expected**: All 5 messages appear immediately

### Scenario 2: Multiple Chats
1. Chat with Group A → Send messages
2. Switch to Group B → Send messages
3. Return to Group A
4. **Expected**: Each group has separate cached history

### Scenario 3: Large History
1. Send 600 messages in same group
2. Reopen app
3. **Expected**: Only last 500 messages remain

### Scenario 4: Duplicate Prevention
1. Send message "Hello"
2. Close/reopen chat quickly
3. Send another message
4. **Expected**: No duplicate "Hello" messages

## Debugging

### Check Cache Contents
```dart
// In chat_screen.dart, add debug button:
TextButton(
  onPressed: () async {
    final msgs = await ChatCache().loadMessages(widget.groupId);
    print('Cached messages: ${msgs.length}');
    msgs.forEach((m) => print('- ${m.senderName}: ${m.text}'));
  },
  child: Text('Debug Cache'),
)
```

### Clear Cache
```dart
// Clear specific chat cache
final prefs = await SharedPreferences.getInstance();
await prefs.remove('chat_messages_$groupId');

// Clear all chat caches
final keys = prefs.getKeys().where((k) => k.startsWith('chat_messages_'));
for (var key in keys) {
  await prefs.remove(key);
}
```

## Performance Considerations

### Storage Size
- Average message JSON: ~150 bytes
- 500 messages ≈ 75 KB per chat
- Negligible impact on app size

### Load Time
- Typical load: <50ms for 500 messages
- Async loading prevents UI blocking
- Sorted by timestamp after load

### Memory Usage
- Messages kept in RAM while chat screen open
- Released on dispose()
- Stream subscriptions properly cancelled

## Known Limitations

1. **No Cloud Backup**: Cache is device-specific
   - Workaround: Future Firebase sync integration

2. **No Media Support**: Text-only messages
   - Future: Image/file attachments with separate storage

3. **No Search**: Can't search old messages
   - Future: Implement search functionality

4. **500 Message Limit**: Hard cap per chat
   - Configurable in code (increase if needed)

## Future Enhancements

### Planned (v33+)
- [ ] Message reactions (emoji)
- [ ] Read receipts
- [ ] Typing indicators
- [ ] Voice messages (audio blobs)
- [ ] End-to-end encryption

### Under Consideration
- [ ] Unlimited scroll (lazy loading)
- [ ] Export chat history
- [ ] Star/favorite messages
- [ ] Message replies/threads

---

**Status**: ✅ Complete (v32)  
**Next**: Sound Combat Balance, Anti-Cheat for Sensors
