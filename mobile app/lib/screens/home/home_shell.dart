import "package:flutter/material.dart";

import "../../utils/app_colors.dart";
import "../../widgets/curved_bottom_nav_bar.dart";
import "../alerts/alerts_screen.dart";
import "../box/box_screen.dart";
import "../patient/patient_screen.dart";
import "../profile/profile_screen.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1;

  static const double _navBarTotalHeight = 102;

  late final List<Widget> _tabs = <Widget>[
    const PatientScreen(),
    const BoxScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: _navBarTotalHeight),
            child: IndexedStack(index: _index, children: _tabs),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CurvedBottomNavBar(
              currentIndex: _index,
              onTap: (int i) => setState(() => _index = i),
              items: const <CurvedNavItem>[
                CurvedNavItem(icon: Icons.person_rounded, label: "Patient"),
                CurvedNavItem(icon: Icons.inventory_2_rounded, label: "Box"),
                CurvedNavItem(
                  icon: Icons.notifications_active_rounded,
                  label: "Alerts",
                ),
                CurvedNavItem(
                  icon: Icons.account_circle_rounded,
                  label: "Profile",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
