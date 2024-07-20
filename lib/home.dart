
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final String contactId;

  const ChatPage({required this.contactId, Key? key}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String _contactUsername = 'Loading...';

  late DatabaseReference _messagesRef;
  late User _currentUser;
  StreamSubscription<DatabaseEvent>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _messagesRef = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(_currentUser.uid)
        .child(widget.contactId);

    _fetchContactUsername();

    _messagesSubscription = _messagesRef.onValue.listen((event) {
      final messages = <Map<String, dynamic>>[];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final message = Map<String, dynamic>.from(value);
          messages.add({'id': key, ...message});
        });
        // Sort messages by timestamp
        messages.sort((a, b) {
          final timestampA = a['timestamp'] as int?;
          final timestampB = b['timestamp'] as int?;
          return (timestampA ?? 0).compareTo(timestampB ?? 0);
        });
      }
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
      }
    });
  }

  Future<void> _fetchContactUsername() async {
    try {
      final contactRef = FirebaseDatabase.instance.ref().child('users').child(widget.contactId);
      final snapshot = await contactRef.child('name').get();

      if (snapshot.exists) {
        setState(() {
          _contactUsername = snapshot.value.toString();
        });
      } else {
        setState(() {
          _contactUsername = 'Unknown User';
        });
      }
    } catch (e) {
      setState(() {
        _contactUsername = 'Error Fetching Username';
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final messageRef = _messagesRef.push();
      final messageId = messageRef.key;
      final timestamp = ServerValue.timestamp;

      messageRef.set({
        'text': _controller.text,
        'senderId': _currentUser.uid,
        'timestamp': timestamp,
        'edited': false,
      });

      // Add the message to the recipient's chat
      final recipientMessagesRef = FirebaseDatabase.instance
          .ref()
          .child('chats')
          .child(widget.contactId)
          .child(_currentUser.uid)
          .child(messageId!);
      recipientMessagesRef.set({
        'text': _controller.text,
        'senderId': _currentUser.uid,
        'timestamp': timestamp,
        'edited': false,
      });

      _controller.clear();
    }
  }

  void _editMessage(String messageId, String newText) {
    final timestamp = ServerValue.timestamp;

    // Update the message in the current user's chat
    _messagesRef.child(messageId).update({
      'text': newText,
      'edited': true,
      'timestamp': timestamp,
    });

    // Update the message in the recipient's chat
    final recipientMessagesRef = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(widget.contactId)
        .child(_currentUser.uid)
        .child(messageId);
    recipientMessagesRef.update({
      'text': newText,
      'edited': true,
      'timestamp': timestamp,
    });
  }

  void _deleteMessage(String messageId) {
    // Delete the message from the current user's chat
    _messagesRef.child(messageId).remove();

    // Delete the message from the recipient's chat
    final recipientMessagesRef = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(widget.contactId)
        .child(_currentUser.uid)
        .child(messageId);
    recipientMessagesRef.remove();
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  void _showEditDialog(String messageId, String currentText) {
    final TextEditingController _editController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: _editController,
            decoration: const InputDecoration(
              labelText: 'Edit your message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _editMessage(messageId, _editController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final bool isMe = message['senderId'] == _currentUser.uid;
    final timestamp = message['timestamp'];
    final messageText = message['text'] ?? '';
    final displayTime = _formatTimestamp(timestamp as int?);
    final messageId = message['id'];
    final edited = message['edited'] ?? false;

    return GestureDetector(
      onLongPress: () {
        if (isMe) {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showEditDialog(messageId, messageText);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Delete'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteMessage(messageId);
                    },
                  ),
                ],
              );
            },
          );
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                messageText,
                style: TextStyle(color: isMe ? Colors.white : Colors.black),
              ),
              Text(
                'Sent at $displayTime' + (edited ? ' (edited)' : ''),
                style: TextStyle(color: isMe ? Colors.white60 : Colors.black, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with $_contactUsername'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
