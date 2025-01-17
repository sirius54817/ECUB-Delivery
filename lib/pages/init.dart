import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/pages/home.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class GoogleMapPage extends StatefulWidget {
  final OrdersSam oder;
  const GoogleMapPage({super.key, required this.oder});

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  final locationController = Location();
  Timer? locationUpdateTimer;

  LatLng? currentPosition;
  LatLng? destinationPosition;
  Map<PolylineId, Polyline> polylines = {};
  BitmapDescriptor? currentLocationIcon;
  BitmapDescriptor? destinationIcon;
  String? eta; // Add a variable to store the ETA
  String? distance; // Add this line to store the distance

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      currentLocationIcon = await createBitmapDescriptorFromIcon(Icons.navigation);
      destinationIcon = await createBitmapDescriptorFromIcon(Icons.location_on);
      await initializeMap();
      await fetchAndStoreEstimatedTimeOfArrival();
      setState(() {});

      locationUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        await fetchCurrentLocation();
        await updateLocationInFirestore();
      });
    });
  }

  @override
  void dispose() {
    locationUpdateTimer
        ?.cancel(); // Cancel the timer when the widget is disposed
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<BitmapDescriptor> createBitmapDescriptorFromIcon(
      IconData iconData) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const iconSize = 64.0;
    
    // Add a white circle background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(iconSize/2, iconSize/2), iconSize/2, bgPaint);
    
    // Add a colored border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(iconSize/2, iconSize/2), iconSize/2 - 1.5, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize * 0.7,
        fontFamily: iconData.fontFamily,
        color: Colors.blue,
      ),
    );
    
    textPainter.layout();
    // Center the icon in the circle
    textPainter.paint(
      canvas, 
      Offset(
        (iconSize - textPainter.width) / 2,
        (iconSize - textPainter.height) / 2
      )
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> initializeMap() async {
    try {
      await fetchCurrentLocation();
      
      if (currentPosition == null) {
        debugPrint('Error: Could not get current location');
        return;
      }

      debugPrint('Fetching coordinates for address: ${widget.oder.address}');
      destinationPosition = await fetchCoordinatesFromPlaceName(widget.oder.address);
      
      if (destinationPosition == null) {
        debugPrint('Error: Could not convert address to coordinates');
        return;
      }
      
      debugPrint('Successfully initialized map with:'
          '\nCurrent position: $currentPosition'
          '\nDestination position: $destinationPosition');

      final coordinates = await fetchPolylinePoints();
      if (coordinates.isNotEmpty) {
        await generatePolyLineFromPoints(coordinates);
      } else {
        debugPrint('Error: Could not generate route between points');
      }
    } catch (e) {
      debugPrint('Error in initializeMap: $e');
    }
  }

  Future<void> fetchAndStoreEstimatedTimeOfArrival() async {
    final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
    final origin = '${currentPosition!.latitude},${currentPosition!.longitude}';
    final destination = '${destinationPosition!.latitude},${destinationPosition!.longitude}';
    final url = 'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$origin&destinations=$destination&key=$apiKey';
//
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('API Response: $data');
      if (data['status'] == 'OK') {
        final elements = data['rows'][0]['elements'][0];
        if (elements['status'] == 'OK') {
          final duration = elements['duration']['text'];
          final distanceText = elements['distance']['text'];
          if (mounted) {
            setState(() {
              eta = duration;
              distance = distanceText;
            });
          }
          await storeETDInFirestore(duration, distanceText);
        } else {
          debugPrint('Error fetching ETA: ${elements['status']}');
        }
      } else {
        debugPrint('Error fetching ETA: ${data['status']}');
      }
    } else {
      debugPrint('Error fetching ETA: ${response.statusCode}');
    }
  }

  Future<void> storeETDInFirestore(String etd, String distance) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId);

      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      await orderRef.update({
        'etd': etd,
        'distance': distance,
      });
      debugPrint('ETD and distance stored in Firestore successfully');
    } catch (e) {
      debugPrint('Error storing ETD and distance in Firestore: $e');
    }
  }

  Future<String?> getLoggedInUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> updateOrderStatus(String status) async {
    try {
      debugPrint('Updating order status to $status');
      debugPrint('Item ID: ${widget.oder.orderId}');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw 'User is not logged in';
      }

      // Create a batch to perform multiple operations
      final batch = FirebaseFirestore.instance.batch();

      // Reference to the order document
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId);

      // Check if the document exists
      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      // Create the update data
      Map<String, dynamic> orderUpdateData = {
        'status': status == 'delivered' ? 'completed' : status,
        'del_agent': currentUser.uid,
      };

      // Only add completed_at if the status is being set to completed
      if (status == 'delivered') {
        orderUpdateData['completed_at'] = Timestamp.now();
        orderUpdateData['status'] = 'delivered';
      }

      // Update the order status
      batch.update(orderRef, orderUpdateData);

      // If the order is being completed, update the agent's earnings and history
      if (status == 'delivered') {
        final agentQuery = await FirebaseFirestore.instance
            .collection('delivery_agent')
            .where('email', isEqualTo: currentUser.email)
            .get();

        if (agentQuery.docs.isEmpty) {
          throw 'Delivery agent not found';
        }

        final agentRef = agentQuery.docs.first.reference;
        
        // Create delivery history entry
        Map<String, dynamic> deliveryEntry = {
          'timestamp': Timestamp.now(),
          'amount': 30,
          'location': widget.oder.address,
          'orderId': widget.oder.orderId,
          'distance': distance,
        };

        // Update agent's document
        batch.update(agentRef, {
          'salary': FieldValue.increment(30),
          'rides': FieldValue.increment(1),
          'delivery_history': FieldValue.arrayUnion([deliveryEntry]),
        });
      }

      // Commit all updates in a single batch
      await batch.commit();

      // Update local state
      setState(() {
        widget.oder.status = status == 'delivered' ? 'completed' : status;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'delivered' 
              ? 'Delivery completed successfully! Earnings updated.' 
              : 'Order accepted'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> updateSalaryAndRides() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String agentId = await getLoggedInUserId() ?? '';

    if (agentId.isEmpty) {
      debugPrint('User is not logged in');
      return;
    }

    try {
      DocumentReference agentRef = _firestore.collection('delivery_agent').doc(agentId);
      DocumentSnapshot agentSnapshot = await agentRef.get();

      if (agentSnapshot.exists) {
        int currentSalary = agentSnapshot['salary'] is int
            ? agentSnapshot['salary']
            : (agentSnapshot['salary'] as double).toInt();
        int currentRides = agentSnapshot['rides'] is int
            ? agentSnapshot['rides']
            : (agentSnapshot['rides'] as double).toInt();

        int updatedSalary = currentSalary + 30;
        int updatedRides = currentRides + 1;

        // Create delivery history entry
        Map<String, dynamic> deliveryEntry = {
          'timestamp': FieldValue.serverTimestamp(),
          'amount': 30, // The amount earned for this delivery
          'location': widget.oder.address, // The delivery location
        };

        // Update the document with new salary, rides, and append to delivery history
        await agentRef.update({
          'salary': updatedSalary,
          'rides': updatedRides,
          'delivery_history': FieldValue.arrayUnion([deliveryEntry]),
        });

        debugPrint('Salary, rides, and delivery history updated successfully');
      } else {
        debugPrint('Agent document does not exist');
      }
    } catch (e) {
      debugPrint('Error updating salary and rides: $e');
    }
  }

  Future<void> updateLocationInFirestore() async {
    try {
      final userId = await getLoggedInUserId();
      if (userId == null) {
        throw 'User is not logged in';
      }

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId); // Using orderId which is actually itemId

      // Check if the document exists
      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      await orderRef.update({
        'current_latitude': currentPosition!.latitude,
        'current_longitude': currentPosition!.longitude,
      });

      debugPrint('Location updated in Firestore');
    } catch (e) {
      debugPrint('Error updating location in Firestore: $e');
    }
  }

  Future<bool?> _showDeliveryConfirmationDialog() async {
    String enteredOtp = '';
    bool isOtpValid = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Please confirm the delivery details:'),
                SizedBox(height: 10),
                Text('Customer: ${widget.oder.customerName}'),
                Text('Address: ${widget.oder.address}'),
                if (distance != null) Text('Distance: $distance'),
                SizedBox(height: 20),
                Text(
                  'Enter 6-digit OTP',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 40,
                      child: TextField(
                        controller: _otpControllers[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(context).previousFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                // Clear OTP fields
                _otpControllers.forEach((controller) => controller.clear());
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: Text('Verify & Confirm'),
              onPressed: () async {
                // Concatenate OTP
                enteredOtp = _otpControllers
                    .map((controller) => controller.text)
                    .join();

                // Verify OTP from Firestore
                try {
                  final orderDoc = await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.oder.orderId)
                      .get();

                  if (!orderDoc.exists) {
                    throw 'Order not found';
                  }

                  final storedOtp = orderDoc.data()?['otp'];
                  isOtpValid = storedOtp == enteredOtp;

                  if (isOtpValid) {
                    // Clear OTP fields
                    _otpControllers.forEach((controller) => controller.clear());
                    Navigator.of(context).pop(true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid OTP. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  logger.e('Error verifying OTP: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error verifying OTP: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadDeliveryPhoto(XFile photo) async {
    try {
      final path = 'delivery_photos/${widget.oder.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      
      final file = File(photo.path);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            currentPosition == null || destinationPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition!,
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('currentLocation'),
                        icon: currentLocationIcon ??
                            BitmapDescriptor.defaultMarker,
                        position: currentPosition!,
                      ),
                      Marker(
                        markerId: const MarkerId('destinationLocation'),
                        icon: destinationIcon ?? BitmapDescriptor.defaultMarker,
                        position: destinationPosition!,
                      ),
                    },
                    polylines: Set<Polyline>.of(polylines.values),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Order ID: ${widget.oder.orderId}'),
                    Text('Item Name: ${widget.oder.itemName}'),
                    Text('Customer Name: ${widget.oder.customerName}'),
                    Text('Item Price: ${widget.oder.itemPrice}'),
                    Text('Address: ${widget.oder.address}'),
                    if (eta != null) Text('Estimated Time: $eta'),
                    if (distance != null) Text('Distance: $distance'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            debugPrint('Accept button pressed');
                            await updateOrderStatus('in_transit');
                          },
                          child: Text('Accept'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            debugPrint('Delivered button pressed');
                            
                            final confirmed = await _showDeliveryConfirmationDialog();
                            
                            if (confirmed == true) {
                              try {
                                await updateOrderStatus('delivered'); // This will actually set status to 'completed'
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => HomeScreen()),
                                );
                              } catch (e) {
                                // Error is already shown in updateOrderStatus
                                debugPrint('Failed to complete delivery: $e');
                              }
                            }
                          },
                          child: Text('Delivered'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
      if (!serviceEnabled) {
        debugPrint('Location service is not enabled');
        return;
      }
    }

    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint('Location permission is not granted');
        return;
      }
    }

    LocationData locationData = await locationController.getLocation();
    setState(() {
      currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
    });
    debugPrint('Current position: $currentPosition');
  }

  Future<LatLng?> fetchCoordinatesFromPlaceName(String address) async {
    try {
      // Use a valid API key
      final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo'; // Use the same API key you're using for Distance Matrix
      
      // Properly encode the address for URL
      final encodedAddress = Uri.encodeComponent(address);
      
      // Construct the Geocoding API URL
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=$apiKey'
          '&region=in'; // Add region parameter for better results in India
      
      debugPrint('Fetching coordinates for address: $address');
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      debugPrint('Geocoding API response: ${response.body}');

      if (response.statusCode == 200) {
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          
          debugPrint('Successfully converted address to coordinates: ($lat, $lng)');
          return LatLng(lat, lng);
        } else {
          debugPrint('Geocoding API error: ${data['status']} - ${data['error_message'] ?? 'No results found for the address'}');
          return null;
        }
      } else {
        debugPrint('HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error in fetchCoordinatesFromPlaceName: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<LatLng>> fetchPolylinePoints() async {
    if (currentPosition == null || destinationPosition == null) {
      debugPrint('Error: Current or destination position is null');
      return [];
    }

    final polylinePoints = PolylinePoints();
    
    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo', // Replace with your actual API key
        PointLatLng(currentPosition!.latitude, currentPosition!.longitude),
        PointLatLng(destinationPosition!.latitude, destinationPosition!.longitude),
      );

      if (result.points.isNotEmpty) {
        debugPrint('Polyline points fetched successfully');
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      } else {
        debugPrint('Error fetching polyline points: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      debugPrint('Error in fetchPolylinePoints: $e');
      return [];
    }
  }

  Future<void> generatePolyLineFromPoints(
      List<LatLng> polylineCoordinates) async {
    const PolylineId id = PolylineId('polyline');

    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blueAccent,
      points: polylineCoordinates,
      width: 5,
    );

    if (mounted) {
      setState(() {
        polylines[id] = polyline;
      });
      debugPrint('Polyline added to the map');
    }
  }
}
