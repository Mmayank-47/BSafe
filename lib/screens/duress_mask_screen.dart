import 'package:flutter/material.dart';

/// Duress Visual Disguise Screen.
/// Activated when secondary Duress PIN (9999) is entered under restraint.
/// Disguises the app as a harmless utility note-taking interface while silently escalating to Tier 2 in background.
class DuressMaskScreen extends StatefulWidget {
  const DuressMaskScreen({super.key});

  @override
  State<DuressMaskScreen> createState() => _DuressMaskScreenState();
}

class _DuressMaskScreenState extends State<DuressMaskScreen> {
  final TextEditingController _noteController = TextEditingController(
    text: "Grocery List:\n- Milk\n- Bread\n- Eggs\n- Apples"
  );

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write a note...',
                ),
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Saved locally to device storage',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
