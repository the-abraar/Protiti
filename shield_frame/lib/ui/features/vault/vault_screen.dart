import 'package:flutter/material.dart';
import '../panic/panic_screen.dart';
import '../complaint/complaint_wizard_screen.dart';
import '../support/support_screen.dart';

class VaultScreen extends StatefulWidget {
  @override
  _VaultScreenState createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    VaultGridScreen(),
    ComplaintWizardScreen(),
    PanicScreen(),
    SupportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vault')),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Panic'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'Support'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ) : null,
    );
  }
}

class VaultGridScreen extends StatelessWidget {
  final List<Map<String, dynamic>> mockEvidence = [
    {'title': 'Screenshot_1.png', 'icon': Icons.image, 'date': 'Oct 1, 2026'},
    {'title': 'Audio_Record.m4a', 'icon': Icons.audiotrack, 'date': 'Sep 29, 2026'},
    {'title': 'Threat_Text.pdf', 'icon': Icons.picture_as_pdf, 'date': 'Sep 28, 2026'},
    {'title': 'Video_Evidence.mp4', 'icon': Icons.video_file, 'date': 'Sep 25, 2026'},
    {'title': 'Chat_Log.txt', 'icon': Icons.description, 'date': 'Sep 20, 2026'},
    {'title': 'Web_Link', 'icon': Icons.link, 'date': 'Sep 15, 2026'},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: mockEvidence.length,
      itemBuilder: (context, index) {
        final item = mockEvidence[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item['icon'], size: 48, color: Theme.of(context).primaryColor),
              SizedBox(height: 16),
              Text(
                item['title'],
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                item['date'],
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
