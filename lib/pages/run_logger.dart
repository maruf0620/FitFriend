import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'run_service.dart';
import 'package:intl/intl.dart';

class RunTrackerPage extends StatefulWidget {
  @override
  _RunTrackerPageState createState() => _RunTrackerPageState();
}

class _RunTrackerPageState extends State<RunTrackerPage>
    with SingleTickerProviderStateMixin {
  final RunTrackerService _runTrackerService = RunTrackerService();
  GoogleMapController? _mapController;
  TabController? _tabController;
  Timer? _timer;
  int _elapsedSeconds = 0;

  double lastKnownDistance = 0;
  double lastKnownCalories = 0;
  double lastKnownPace = 0;
  Set<Marker> markers = {};

  bool isViewingRoute = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  void _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.denied) {
      _locateUser();
    } else {
      print('Location permissions are denied');
    }
  }

  void _locateUser() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updateMapLocation(position);
    } catch (e) {
      print("Failed to get current location: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _toggleRun() {
    if (_runTrackerService.isRunning) {
      _stopRun();
    } else {
      _resetRun();
      _startRun();
    }
    setState(() {});
  }

  void _startRun() {
    _runTrackerService.startRun();
    _startTracking();
    _startTimer();
  }

  void _startTracking() {
    _runTrackerService.positionStream.listen((Position position) {
      if (position != null) {
        _runTrackerService.addPosition(position);
        if (!isViewingRoute) {
          _updateLiveStats();
          _updateMapLocation(position);
        }
      }
    }).onError((error) {
      print('Location service error: $error');
    });
  }

  void _updateLiveStats() {
    setState(() {
      lastKnownDistance = _runTrackerService.totalDistance /
          1000; // Convert meters to kilometers
      lastKnownCalories = _runTrackerService.calculateCalories();
      lastKnownPace = _runTrackerService.getAveragePace();
      print(
          "Stats updated - Distance: $lastKnownDistance km, Calories: $lastKnownCalories, Pace: $lastKnownPace min/km");
    });
  }

  void _updateMapLocation(Position position) {
    if (!isViewingRoute) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _stopRun() {
    _stopTimer();
    _runTrackerService.stopRun();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Run Completed!"),
        content: Text("Great job! Here are your stats:\n"
            "Duration: ${_formatDuration(_elapsedSeconds)}\n"
            "Distance: ${lastKnownDistance.toStringAsFixed(1)} km\n"
            "Calories Burned: ${lastKnownCalories.round()} kcal\n"
            "Average Pace: ${lastKnownPace.toStringAsFixed(2)} min/km"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetRun();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return "${hours}h ${minutes}m ${remainingSeconds}s";
  }

  void _resetRun() {
    _runTrackerService.resetRunStats();
    setState(() {
      _elapsedSeconds = 0;
      lastKnownDistance = 0;
      lastKnownCalories = 0;
      lastKnownPace = 0;
      markers.clear();
      isViewingRoute = false;
    });
  }

  Widget buildTrackerTab() {
    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(0, 0), // Default location, will update on startup
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: {
              Polyline(
                polylineId: PolylineId('route'),
                visible: true,
                points: _runTrackerService.route,
                color: Colors.blue,
                width: 6,
              ),
            },
            markers: markers,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Duration: ${_formatDuration(_elapsedSeconds)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              Text("Distance: ${lastKnownDistance.toStringAsFixed(1)} km",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
              Text("Calories Burnt: ${lastKnownCalories.round()} kcal",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              Text("Average Pace: ${lastKnownPace.toStringAsFixed(2)} min/km",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Container(
            width: 220,
            child: TextButton(
              onPressed: _toggleRun,
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _runTrackerService.isRunning
                          ? Icons.stop
                          : Icons.directions_run,
                      color: Colors.white,
                    ),
                    SizedBox(width: 10),
                    Text(
                      _runTrackerService.isRunning
                          ? 'Stop Run'
                          : 'Start a New Run',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Run Logger"),
        backgroundColor: Colors.blue.shade300,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.directions_run), text: "Run"),
            Tab(icon: Icon(Icons.history), text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildTrackerTab(),
          buildHistoryTab(),
        ],
      ),
    );
  }

  Widget buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_runTrackerService.user?.uid)
          .collection('runs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var docId = doc.id; // Document ID for operations like delete
            DateTime date = DateTime.fromMillisecondsSinceEpoch(
                doc['date'].millisecondsSinceEpoch);
            String formattedDate = DateFormat('dd-MM-yyyy HH:mm').format(date);
            int seconds = doc['duration'];
            int hours = seconds ~/ 3600;
            int minutes = (seconds % 3600) ~/ 60;
            seconds = seconds % 60;
            double distance =
                (doc['distance'] / 1000).toDouble(); // Distance in km
            int calories = doc['calories'].toInt(); // Convert to integer
            double averagePace = doc['averagePace'] ?? 0;

            return Card(
              margin: EdgeInsets.all(8.0),
              elevation: 4.0,
              child: ExpansionTile(
                leading: Icon(Icons.history, color: Colors.blue.shade300),
                title: Text("Run on $formattedDate",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Duration: ${hours}h ${minutes}m ${seconds}s",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        Text("Distance: ${distance.toStringAsFixed(1)} km",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        Text("Calories Burnt: ${calories} kcal",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        Text(
                            "Average Pace: ${averagePace.toStringAsFixed(2)} min/km",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple)),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: Icon(Icons.map),
                          label: Text("View Route"),
                          onPressed: () {
                            isViewingRoute =
                                true; // Set to true when viewing a route
                            var points = List<LatLng>.from(doc['route']
                                .map((e) => LatLng(e['latitude'], e['longitude'])));
                            _showHistoricalRun(points, distance,
                                calories.toDouble(), averagePace, seconds);
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.delete),
                          label: Text("Delete Run"),
                          onPressed: () => _confirmDeleteRun(context, docId),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRun(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this run?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                _deleteRun(docId);
                Navigator.of(context)
                    .pop(); // Close the dialog after confirming the action
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteRun(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_runTrackerService.user?.uid)
          .collection('runs')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Run deleted successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error deleting run: $e")));
    }
  }

  void _showHistoricalRun(List<LatLng> points, double distance, double calories,
      double pace, int durationSecs) {
    markers.clear(); // Clear previous markers if any
    if (points.isNotEmpty) {
      // Add start and end markers
      markers.add(Marker(
        markerId: MarkerId("start"),
        position: points.first,
        infoWindow: InfoWindow(title: "Start"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));

      markers.add(Marker(
        markerId: MarkerId("end"),
        position: points.last,
        infoWindow: InfoWindow(title: "End"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      LatLngBounds bounds = _getBounds(points);
      Future.delayed(Duration(milliseconds: 500), () {
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      });
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(0, 0),
            zoom: 15,
          ),
        ),
      );
    }

    setState(() {
      _runTrackerService.route = points;
      lastKnownDistance = distance;
      lastKnownCalories = calories;
      lastKnownPace = pace;
      _elapsedSeconds =
          durationSecs; // Update the duration to reflect the historical run
      _tabController!.animateTo(0); // Switch to the run tab
    });
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        northeast: LatLng(0, 0),
        southwest: LatLng(0, 0),
      );
    }

    double northeastLat = points.first.latitude;
    double northeastLng = points.first.longitude;
    double southwestLat = points.first.latitude;
    double southwestLng = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude > northeastLat) northeastLat = point.latitude;
      if (point.longitude > northeastLng) northeastLng = point.longitude;
      if (point.latitude < southwestLat) southwestLat = point.latitude;
      if (point.longitude < southwestLng) southwestLng = point.longitude;
    }

    return LatLngBounds(
      northeast: LatLng(northeastLat, northeastLng),
      southwest: LatLng(southwestLat, southwestLng),
    );
  }
}
