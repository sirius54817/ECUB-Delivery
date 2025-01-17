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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class OrdersSam {
  final String orderId;
  final String itemName;
  final String customerName;
  final String itemPrice;
  final String address;
  final String vendor;
  String status;
  final int itemCount;
  final bool isVeg;
  final String location;
  final Map<String, dynamic> prepTime;
  final String timestamp;
  final Map<String, dynamic>? orderSummary;
  final String paymentStatus;

  OrdersSam({
    required this.orderId,
    required this.itemName,
    required this.customerName,
    required this.itemPrice,
    required this.address,
    required this.vendor,
    required this.status,
    required this.itemCount,
    required this.isVeg,
    required this.location,
    required this.prepTime,
    required this.timestamp,
    this.orderSummary,
    this.paymentStatus = 'pending',
  });

  static OrdersSam fromMap(Map<String, dynamic> order) {
    if (order['order_summary'] != null) {
      final firstItemKey = (order['order_summary'] as Map).keys.first;
      final firstItem = order['order_summary'][firstItemKey] as Map<String, dynamic>;

      return OrdersSam(
        orderId: order['order_id'] ?? '',
        itemName: firstItem['name'] ?? '',
        customerName: order['userId'] ?? '',
        itemPrice: (order['totalPrice'] ?? 0).toString(),
        address: order['address'] ?? '',
        vendor: firstItem['storeName'] ?? '',
        status: order['status'] ?? '',
        itemCount: firstItem['quantity'] ?? 1,
        isVeg: false,
        location: order['location'] ?? '',
        prepTime: {'min': 15, 'max': 30},
        timestamp: order['order_time'] ?? '',
        orderSummary: order['order_summary'],
        paymentStatus: order['payment_status'] ?? 'pending',
      );
    }

    int itemCount;
    if (order['itemCount'] is double) {
      itemCount = (order['itemCount'] as double).toInt();
    } else if (order['itemCount'] is int) {
      itemCount = order['itemCount'];
    } else {
      itemCount = 1;
    }

    return OrdersSam(
      orderId: order['docId'] ?? '',
      itemName: order['itemName'] ?? '',
      customerName: order['userId'] ?? '',
      itemPrice: (order['itemPrice'] ?? 0).toString(),
      address: order['address'] ?? '',
      vendor: order['vendor'] ?? '',
      status: order['status'] ?? '',
      itemCount: itemCount,
      isVeg: order['isVeg'] ?? false,
      location: order['location'] ?? '',
      prepTime: order['prepTime'] ?? {'min': 15, 'max': 30},
      timestamp: order['timestamp'] ?? '',
    );
  }
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
  bool _isFoodOrders = true;
  List<OrdersSam> _medicalOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchOrders();
    _fetchMedicalOrders();
  }

  Future<void> _fetchUserData() async {
    try {
      print("Fetching user data...");
      if (!mounted) return;

      setState(() {
        _loading = true;
      });

      // Get current user's email
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw 'No authenticated user found';
      }

      // Query Firestore for delivery agent data
      final agentSnapshot = await FirebaseFirestore.instance
          .collection('delivery_agent')
          .where('email', isEqualTo: currentUser.email)
          .get();

      if (agentSnapshot.docs.isEmpty) {
        throw 'No delivery agent found for this email';
      }

      // Get the first matching document
      final agentData = agentSnapshot.docs.first.data();
      
      if (!mounted) return;

      setState(() {
        _user = {
          'name': agentData['name'] ?? 'Unknown',
          'photoURL': agentData['photoURL'],
          'email': currentUser.email,
          'salary': agentData['salary'] ?? 0,
          'rides': agentData['rides'] ?? 0,
        };
        _loading = false;
      });
      
      print("User data fetched successfully: ${_user.toString()}");
    } catch (e) {
      print("Error fetching user data: $e");
      if (!mounted) return;

      setState(() {
        _loading = false;
        _user = {
          'name': 'Error loading data',
          'salary': 0,
          'rides': 0,
        };
      });

      // Move SnackBar to the next frame to ensure Scaffold is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load user data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("Fetching orders...");
      
      // Query Firestore directly for pending orders
      final QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .get();

      List<OrdersSam> orders = ordersSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id; // Add the document ID to the data
        return OrdersSam.fromMap(data);
      }).toList();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      print("Orders fetched successfully. Count: ${orders.length}");
    } catch (e) {
      print("Error fetching orders: $e");
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      
      // Move SnackBar to the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch orders: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _fetchMedicalOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      logger.i("Starting medical orders fetch...");
      
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'No authenticated user found';
      logger.d("Current user: ${currentUser.email}");

      // Get all user documents from me_orders collection
      final QuerySnapshot userDocs = await FirebaseFirestore.instance
          .collection('me_orders')
          // .where('status', isEqualTo: 'ordered')
          // .orderBy('order_time', descending: true)
          .limit(100)
          .get();

      logger.d("User docs: ${userDocs.docs}");

      logger.d("Found ${userDocs.docs.length} users in me_orders collection");

      List<OrdersSam> allOrders = [];

      // For each user, get their orders
      for (var userDoc in userDocs.docs) {
        logger.d("Fetching orders for user: ${userDoc.id}");
        
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('me_orders')
            .doc(userDoc.id)
            .collection('orders')
            .where('status', isEqualTo: 'ordered')
            .get();

        logger.d("Found ${ordersSnapshot.docs.length} orders for user ${userDoc.id}");

        // Log the raw data of each order
        for (var doc in ordersSnapshot.docs) {
          logger.d("Raw order data: ${doc.data()}");
        }

        // Convert each order to OrdersSam object
        List<OrdersSam> userOrders = ordersSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['docId'] = doc.id;
          data['userId'] = userDoc.id;
          
          logger.d("Processing order ${doc.id} for user ${userDoc.id}");
          logger.d("Order data after mapping: $data");
          
          return OrdersSam.fromMap(data);
        }).toList();

        logger.d("Converted ${userOrders.length} orders for user ${userDoc.id}");
        allOrders.addAll(userOrders);
      }

      if (!mounted) return;

      setState(() {
        _medicalOrders = allOrders;
        _isLoading = false;
      });
      
      logger.i("Medical orders fetch completed. Total orders: ${allOrders.length}");
      logger.d("Final medical orders: $_medicalOrders");
    } catch (e, stackTrace) {
      logger.e("Error fetching medical orders", error: e, stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch medical orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshOrders() async {
    if (_isRefreshing || !mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await Future.wait([
        _fetchUserData(),
        _fetchOrders(),
        _fetchMedicalOrders(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'ECUB Delivery',
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 22,
              ),
            ),
            Text(
              (_user?['name'] ?? 'Loading...').split(' ').take(2).join(' '),
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing 
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.blue[700],
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.refresh, color: Colors.blue[700]),
            onPressed: _refreshOrders,
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      backgroundColor: Colors.white,
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue[50]!,
                      Colors.blue[100]!,
                      Colors.blue[200]!.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue[200]!.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Watermark icon
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Icon(
                        Icons.delivery_dining,
                        size: 120,
                        color: Colors.blue[200]!.withOpacity(0.3),
                      ),
                    ),
                    // Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.today, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              'Earnings: ₹${_user?['salary'] ?? 'Loading...'}',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.delivery_dining, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              'Rides: ${_user?['rides'] ?? 'Loading...'}',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.white!,
                      Colors.white!.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[300]!,
                      offset: Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.grey[200]!,
                      offset: Offset(0, 2),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Text(
                          'Orders',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        ToggleButtons(
                          isSelected: [_isFoodOrders, !_isFoodOrders],
                          onPressed: (index) {
                            setState(() {
                              _isFoodOrders = index == 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          selectedColor: Colors.white,
                          fillColor: Colors.blue[700],
                          color: Colors.blue[700],
                          constraints: BoxConstraints(
                            minWidth: 100,
                            minHeight: 36,
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Food Orders'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Medical Orders'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _isFoodOrders ? _orders.length : _medicalOrders.length,
                              itemBuilder: (context, index) {
                                OrdersSam order = _isFoodOrders 
                                    ? _orders[index] 
                                    : _medicalOrders[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white,
                                          Colors.blue[50]!.withOpacity(0.3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey[300]!,
                                          offset: Offset(0, 3),
                                          blurRadius: 8,
                                          spreadRadius: -2,
                                        ),
                                        BoxShadow(
                                          color: Colors.grey[200]!,
                                          offset: Offset(0, 1),
                                          blurRadius: 4,
                                          spreadRadius: -1,
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: order.isVeg ? Colors.green[50] : Colors.orange[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: order.isVeg ? Colors.green[100]! : Colors.orange[100]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          order.isVeg ? Icons.eco : Icons.restaurant,
                                          color: order.isVeg ? Colors.green[700] : Colors.orange[700],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        '${order.itemName} (${order.itemCount}x)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Customer: ${order.customerName}'),
                                          Text('Price: ₹${order.itemPrice}'),
                                          Text('Address: ${order.address}'),
                                          Text(
                                            'Status: ${order.status == "completed" ? "Order to be delivered" : "Completed"}',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.blue[700],
                                        size: 20,
                                      ),
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
    );
  }
}
