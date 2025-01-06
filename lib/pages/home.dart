import 'package:ecub_delivery/pages/init.dart';
import 'package:ecub_delivery/pages/navigation.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/pages/Earnings.dart';
import 'package:ecub_delivery/pages/Orders.dart';
import 'package:ecub_delivery/pages/login.dart';
import 'package:ecub_delivery/pages/profile.dart';
import 'package:ecub_delivery/services/auth_service.dart';
import 'package:ecub_delivery/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersSam {
  final String orderId;
  final String itemName;
  final String customerName;
  final String itemPrice;
  final String address;
  final String vendor;
  String status;

  OrdersSam(
      {required this.orderId,
      required this.itemName,
      required this.customerName,
      required this.itemPrice,
      required this.address,
      required this.vendor,
      required this.status});

  static fromMap(Map<String, dynamic> order) {}
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  final OrdersService _ordersService = OrdersService();
  List<OrdersSam> _orders = [];
  bool _isLoading = true;
  bool _loading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchOrders();
  }

  Future<void> _fetchUserData() async {
    try {
      print("Fetching user data...");
      final userService = UserService();
      final userData = await userService.fetchUserData();
      setState(() {
        _user = userData;
        _loading = false;
      });
      print("User data fetched successfully.");
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("Fetching orders...");
      String status = 'completed';
      List<Map<String, dynamic>> ordersData =
          await _ordersService.fetchOrdersByStatus(status);

      List<OrdersSam> orders = ordersData.map((order) {
        return OrdersSam(
          orderId: order['docId'],
          itemName: order['itemName'],
          customerName: order['userId'],
          itemPrice: order['itemPrice'].toString(),
          address: order['address'],
          vendor: order['vendor'],
          status: order['status'],
        );
      }).toList();

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      print("Orders fetched successfully.");
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Force a refresh of the orders stream
      await FirebaseFirestore.instance.collection('orders').get();
      
      // Optional: Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Orders refreshed'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Show error message if refresh fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh orders'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 240, 240, 240),
          child: ListView(
            padding: const EdgeInsets.all(0),
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.purple[200],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: _user?['photoURL'] != null
                          ? NetworkImage(_user!['photoURL'])
                          : AssetImage('assets/images/man.jpeg')
                              as ImageProvider,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _user?['name'] ?? 'Loading...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(Icons.home, 'Home', () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }),
              _buildDrawerItem(Icons.person, 'Profile', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              }),
              _buildDrawerItem(Icons.currency_rupee, 'My Earnings', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EarningsPage()),
                );
              }),
              _buildDrawerItem(Icons.card_travel, 'Orders', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrdersPage()),
                );
              }),
              _buildDrawerItem(Icons.logout, 'Logout', () async {
                await AuthService().signout(context: context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              }),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          toolbarHeight: 80,
          title: const Text(
            'Ecub Delivery',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: _isRefreshing 
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.refresh),
              onPressed: _refreshOrders,
              tooltip: 'Refresh Orders',
            ),
          ],
        ),
        backgroundColor: Colors.purple[50],
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                Center(child: CircularProgressIndicator())
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Earnings: ${_user?['salary'] ?? 'Loading...'}',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Rides: ${_user?['rides'] ?? 'Loading...'}',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _orders.length,
                                itemBuilder: (context, index) {
                                  OrdersSam order = _orders[index];
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    elevation: 3,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(10),
                                      title: Text(
                                        order.itemName,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Customer: ${order.customerName}\nPrice: ${order.itemPrice}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                      trailing: Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                GoogleMapPage(oder: order),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(text, style: TextStyle(color: Colors.black)),
      onTap: onTap,
    );
  }
}
