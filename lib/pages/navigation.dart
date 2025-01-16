import 'package:flutter/material.dart';
import 'package:ecub_delivery/pages/home.dart';
import 'package:ecub_delivery/pages/Orders.dart';
import 'package:ecub_delivery/pages/Earnings.dart';
import 'package:ecub_delivery/pages/profile.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    HomeScreen(),
    OrdersPage(),
    EarningsPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: isSelected ? 20 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        border: isSelected ? Border.all(
          color: Colors.purple[200]!.withOpacity(0.5),
          width: 1,
        ) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: Duration(milliseconds: 200),
            scale: isSelected ? 1.1 : 1.0,
            curve: Curves.easeOutCubic,
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.purple[700] : Colors.grey[600],
              size: 24,
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  if (isSelected) ...[
                    SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 70,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () => _onItemTapped(0),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(1),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(1, Icons.list_alt_outlined, Icons.list_alt, 'Orders'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(2),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Earnings'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(3),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
