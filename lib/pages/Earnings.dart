import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveryHistory = [];
  double _totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _fetchDeliveryHistory();
  }

  Future<void> _fetchDeliveryHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        throw 'No authenticated user found';
      }

      final agentSnapshot = await FirebaseFirestore.instance
          .collection('delivery_agent')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      if (agentSnapshot.docs.isEmpty) {
        throw 'No delivery agent found';
      }

      final agentData = agentSnapshot.docs.first.data();
      final deliveryHistory = agentData['delivery_history'] ?? [];
      
      setState(() {
        _deliveryHistory = List<Map<String, dynamic>>.from(deliveryHistory);
        _totalEarnings = (agentData['salary'] ?? 0).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching delivery history: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load delivery history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Earnings',
              style: TextStyle(
                color: Colors.purple[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.purple[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Earnings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '₹${_totalEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[900],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _deliveryHistory.isEmpty
                      ? Center(
                          child: Text(
                            'No delivery history yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _deliveryHistory.length,
                          itemBuilder: (context, index) {
                            final delivery = _deliveryHistory[index];
                            final timestamp = delivery['timestamp'] as Timestamp;
                            final date = DateFormat('MMM dd, yyyy hh:mm a')
                                .format(timestamp.toDate());

                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(
                                  '₹${delivery['amount']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(date),
                                    Text(
                                      delivery['location'] ?? 'Location not available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Icon(Icons.delivery_dining),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
