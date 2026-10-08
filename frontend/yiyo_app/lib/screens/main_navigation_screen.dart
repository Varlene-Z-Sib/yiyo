import 'package:flutter/material.dart';

import 'events_screen.dart';
import 'map_screen.dart';


class MainNavigationScreen
    extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen>
      createState() =>
          _MainNavigationScreenState();
}


class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    MapScreen(),
    EventsScreen(),
  ];


  void _selectTab(
    int index,
  ) {
    if (index == _selectedIndex) {
      return;
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar:
          NavigationBar(
        height: 76,

        selectedIndex:
            _selectedIndex,

        labelBehavior:
            NavigationDestinationLabelBehavior
                .alwaysShow,

        onDestinationSelected:
            _selectTab,

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons
                  .explore_outlined,
            ),
            selectedIcon: Icon(
              Icons.explore,
            ),
            label:
                "Discover",
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .celebration_outlined,
            ),
            selectedIcon: Icon(
              Icons.celebration,
            ),
            label:
                "Events",
          ),
        ],
      ),
    );
  }
}