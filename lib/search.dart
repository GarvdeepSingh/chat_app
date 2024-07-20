
import 'package:chatapp/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserListPage extends StatefulWidget {
  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late User _currentUser;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _fetchUsers();
  }

  void _fetchUsers() {
    DatabaseReference usersRef = FirebaseDatabase.instance.ref().child('users');
    usersRef.onValue.listen((event) {
      final users = <Map<String, dynamic>>[];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          if (key != _currentUser.uid) {
            users.add({'uid': key, ...Map<String, dynamic>.from(value)});
          }
        });
      }
      setState(() {
        _users = users;
      });
    });
  }

  void _navigateToChat(String contactId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(contactId: contactId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final username = user['name'] ?? 'User';
            return Card(
              margin: EdgeInsets.symmetric(vertical: 5.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    username[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Tap to chat'),
                onTap: () => _navigateToChat(user['uid']),
                trailing: Icon(Icons.chat_bubble, color: Colors.blueAccent),
              ),
            );
          },
        ),
      ),
    );
  }
}
