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
    Center(child: Text('Vault: Your Evidences')),
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
}\n