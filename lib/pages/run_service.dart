import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RunTrackerService {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  List<LatLng> route = [];
  double totalDistance = 0; // in meters
  bool isRunning = false;
  int elapsedSeconds = 0;
  Timer? timer;
  final User? user = FirebaseAuth.instance.currentUser;

  Stream<Position> get positionStream => _geolocatorPlatform.getPositionStream(
          locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ));

  void startRun() {
    isRunning = true;
    route = [];
    totalDistance = 0;
    elapsedSeconds = 0;
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) => elapsedSeconds++);
    print("Run started");
  }

  void stopRun() {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
    isRunning = false;
    print(
        "Run stopped. Total distance: $totalDistance meters. Total time: $elapsedSeconds seconds.");
    saveRun();
    resetRunStats();
  }

  void resetRunStats() {
    route.clear(); // Clear the route list
    totalDistance = 0; // Reset the total distance
    elapsedSeconds = 0; // Reset the time
  }

  void addPosition(Position position) {
    LatLng latLng = LatLng(position.latitude, position.longitude);
    route.add(latLng);
    if (route.length > 1) {
      totalDistance += Geolocator.distanceBetween(
        route[route.length - 2].latitude,
        route[route.length - 2].longitude,
        route[route.length - 1].latitude,
        route[route.length - 1].longitude,
      );
    }
    print("Position added: $latLng. Total distance: $totalDistance meters.");
  }

  double calculateCalories() {
    // Calculating calories burned per kilometer run
    return (totalDistance / 1000) * 60;
  }

  double getAveragePace() {
    if (totalDistance == 0 || elapsedSeconds == 0) return 0;
    double speed = totalDistance / elapsedSeconds; // meters per second
    double pace = (1000 / speed) / 60; // converting m/s to min/km
    return pace;
  }

  Future<void> saveRun() async {
    if (user == null) return;
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    double caloriesBurned = calculateCalories();
    double averagePace = getAveragePace();

    await firestore.collection('users').doc(user!.uid).collection('runs').add({
      'date': Timestamp.fromDate(DateTime.now()),
      'duration': elapsedSeconds,
      'distance': totalDistance,
      'calories': caloriesBurned,
      'averagePace': averagePace,
      'route': route
          .map((point) =>
              {'latitude': point.latitude, 'longitude': point.longitude})
          .toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print("Run saved to Firestore with average pace of $averagePace min/km");
  }
}
