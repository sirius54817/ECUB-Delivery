import 'package:ecub_delivery/pages/home.dart';
import 'package:ecub_delivery/pages/init.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw 'No authenticated user found';
      }

      String status = _selectedIndex == 0 ? 'in_transit' : 'delivered';
      
      // Query orders with both status and del_agent filters
      final QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: status)
          .where('del_agent', isEqualTo: currentUser.uid)
          .get();

      // Convert the documents to a list of maps
      List<Map<String, dynamic>> orders = ordersSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id; // Add the document ID to the data
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTabButton(int index, String label) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              _fetchOrders();
            });
          }
        },
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple[700] : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.purple[200]!.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                index == 0 ? Icons.delivery_dining : Icons.check_circle,
                color: isSelected ? Colors.white : Colors.purple[700],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.purple[900],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'ECUB Delivery',
              style: TextStyle(
                color: Colors.purple[900],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.purple[300],
                fontSize: 22,
              ),
            ),
            Text(
              'Orders',
              style: TextStyle(
                color: Colors.purple[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton(0, 'In Transit'),
                _buildTabButton(1, 'Completed'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              color: Colors.purple[700],
            ))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedIndex == 0 
                          ? Icons.delivery_dining 
                          : Icons.check_circle,
                        size: 64,
                        color: Colors.purple[200],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No ${_selectedIndex == 0 ? "in-transit" : "completed"} orders',
                        style: TextStyle(
                          color: Colors.purple[900],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
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
                              Colors.purple[50]!.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              order['isVeg'] == true ? Icons.eco : Icons.restaurant,
                              color: Colors.purple[700],
                            ),
                          ),
                          title: Text(
                            order['itemName'] ?? 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text('Price: ₹${order['itemPrice'] ?? 'N/A'}'),
                              Text('Customer: ${order['userId'] ?? 'N/A'}'),
                              Text('Address: ${order['address'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.purple[700],
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GoogleMapPage(
                                  oder: OrdersSam.fromMap(order),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
