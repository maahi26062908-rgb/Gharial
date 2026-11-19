import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Firebase console se ye 4 values yahan paste karo (README mein steps hain).
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBwAjIihImkKPDubYHykU4v_c9uezWfvqM',
  appId: '1:420281028393:android:ed5c7ea71813392f333138',
  messagingSenderId: '420281028393',
  projectId: 'ghariyal-ae5b5',
);

final _db = FirebaseFirestore.instance;

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Roz app kholne pe streak update karta hai.
Future<void> touchStreak(User u) async {
  final ref = _db.collection('users').doc(u.uid);
  final today = _day(DateTime.now());
  final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));

  await _db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final data = snap.data();
    int streak = 1;
    if (data != null) {
      final last = data['lastActive'] as String?;
      if (last == today) return;
      final old = (data['streak'] ?? 0) as int;
      streak = last == yesterday ? old + 1 : 1;
    }
    tx.set(
      ref,
      {
        'name': u.displayName ?? 'Student',
        'streak': streak,
        'lastActive': today,
      },
      SetOptions(merge: true),
    );
  });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_signup) {
        final cred = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
        final name = _name.text.trim();
        await cred.user?.updateDisplayName(name.isEmpty ? 'Student' : name);
        await cred.user?.reload();
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Kuch gadbad ho gayi');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐊', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text('Gharial',
                    style: Theme.of(context).textTheme.headlineLarge),
                const Text('Padhai bhi, masti bhi'),
                const SizedBox(height: 32),
                if (_signup)
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Tumhara naam',
                        border: OutlineInputBorder()),
                  ),
                if (_signup) const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password (min 6)',
                      border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signup ? 'Account banao' : 'Login'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _signup = !_signup),
                  child: Text(_signup
                      ? 'Pehle se account hai? Login karo'
                      : 'Naya hai? Account banao'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const categories = [
  'JEE',
  'NEET',
  'UPSC',
  'Class 12',
  'Class 10',
  'College',
  'Other',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    touchStreak(user);
  }

  Future<void> _createGroup() async {
    final nameCtl = TextEditingController();
    String cat = categories.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Naya group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Group ka naam'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cat,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setS(() => cat = v ?? cat),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Banao')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtl.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('groups').add({
      'name': nameCtl.text.trim(),
      'category': cat,
      'createdBy': user.uid,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _open(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data()!;
    final members = List<String>.from(data['members'] ?? []);
    if (!members.contains(user.uid)) {
      await doc.reference.update({
        'members': FieldValue.arrayUnion([user.uid]),
      });
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(groupId: doc.id, groupName: data['name']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🐊 Gharial'),
          actions: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                final streak = snap.data?.data()?['streak'] ?? 0;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('🔥 $streak din',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Groups'),
            Tab(text: 'Leaderboard'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createGroup,
          icon: const Icon(Icons.add),
          label: const Text('Naya group'),
        ),
        body: TabBarView(children: [_groupsTab(), _leaderboardTab()]),
      ),
    );
  }

  Widget _groupsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('Abhi koi group nahi. Pehla group tum banao! 👇'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final members = List<String>.from(data['members'] ?? []);
            final joined = members.contains(user.uid);
            return ListTile(
              leading: CircleAvatar(
                child: Text((data['name'] as String).characters.first
                    .toUpperCase()),
              ),
              title: Text(data['name']),
              subtitle:
                  Text('${data['category']} • ${members.length} members'),
              trailing: joined
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Text('Join'),
              onTap: () => _open(d),
            );
          },
        );
      },
    );
  }

  Widget _leaderboardTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('streak', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final medal = i == 0
                ? '🥇'
                : i == 1
                    ? '🥈'
                    : i == 2
                        ? '🥉'
                        : '${i + 1}';
            return ListTile(
              leading: Text(medal, style: const TextStyle(fontSize: 22)),
              title: Text(d['name'] ?? 'Student'),
              trailing: Text('🔥 ${d['streak'] ?? 0}'),
              selected: docs[i].id == user.uid,
            );
          },
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const ChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final _ctl = TextEditingController();
  bool _isDoubt = false;

  CollectionReference<Map<String, dynamic>> get _msgs => FirebaseFirestore
      .instance
      .collection('groups')
      .doc(widget.groupId)
      .collection('messages');

  Future<void> _send(String text, {bool doubt = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _msgs.add({
      'text': t,
      'uid': user.uid,
      'name': user.displayName ?? 'Student',
      'isDoubt': doubt,
      'solved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendFromInput() async {
    final text = _ctl.text;
    _ctl.clear();
    final doubt = _isDoubt;
    setState(() => _isDoubt = false);
    await _send(text, doubt: doubt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _msgs
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Pehla message bhejo 👋'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _bubble(docs[i]),
                );
              },
            ),
          ),
          _quickEmojis(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final mine = d['uid'] == user.uid;
    final doubt = d['isDoubt'] == true;
    final solved = d['solved'] == true;
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final scheme = Theme.of(context).colorScheme;

    Color bg = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    if (doubt) {
      bg = solved ? Colors.green.shade100 : Colors.orange.shade100;
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Text(d['name'] ?? 'Student',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            if (doubt)
              Text(solved ? '✅ Solved' : '❓ Doubt',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            Text(d['text'] ?? '', style: const TextStyle(fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ts != null)
                  Text(DateFormat('hh:mm a').format(ts),
                      style: const TextStyle(fontSize: 10)),
                if (doubt && !solved) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => doc.reference.update({'solved': true}),
                    child: const Text('Solved mark karo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickEmojis() {
    const emojis = ['😂', '🔥', '👍', '🤯', '😭', '💪'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: emojis
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _send(e),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Doubt'),
              selected: _isDoubt,
              onSelected: (v) => setState(() => _isDoubt = v),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _ctl,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendFromInput(),
                decoration: InputDecoration(
                  hintText: _isDoubt ? 'Apna doubt likho...' : 'Message...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendFromInput,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const GharialApp());
}

class GharialApp extends StatelessWidget {
  const GharialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gharial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasData) return const HomeScreen();
          return const AuthScreen();
        },
      ),
    );
  }
}
