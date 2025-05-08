import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pedometer/pedometer.dart';
import 'package:percent_indicator/percent_indicator.dart';

class StepCounter extends StatefulWidget {
  @override
  _StepCounterState createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> {
  late Stream<StepCount> _stepCountStream;
  String _steps = '0'; // Initialize steps to '0'
  int _goal = 10000; // Default goal
  DateTime? selectedDate;
  DateTime today = DateTime.now();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime(today.year, today.month, today.day);
    initPlatformState();
    _loadGoal();
    _loadStepsForDate(
        selectedDate!); // Load steps for the selected date immediately on init
  }

  void onStepCount(StepCount event) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    if (selectedDate!.year == today.year &&
        selectedDate!.month == today.month &&
        selectedDate!.day == today.day) {
      setState(() {
        _steps = event.steps.toString();
      });
      saveData(int.tryParse(_steps) ?? 0);
    }
  }

  void onStepCountError(error) {
    setState(() {
      _steps = '0'; // Use '0' as a safe default to prevent format exceptions.
    });
  }

  void initPlatformState() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);
  }

  double calculateCalories(int steps) {
    // Rough estimation: 0.04 kcal per step
    return steps * 0.04;
  }

  double calculateDistance(int steps) {
    // Assuming average step length of 76 centimetres (30 inches)
    return steps * 0.000762;
  }

  void updateGoal() {
    TextEditingController goalController =
        TextEditingController(text: _goal.toString());
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Your Daily Step Goal'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return TextField(
                controller: goalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter your step goal (e.g., 10000)",
                  errorText: errorMessage,
                ),
                onChanged: (value) {
                  if (int.tryParse(value) == null && value.isNotEmpty) {
                    setState(
                        () => errorMessage = 'Please enter a numerical value');
                  } else {
                    setState(() => errorMessage = null);
                  }
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Set', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                if (errorMessage == null && goalController.text.isNotEmpty) {
                  setState(() {
                    _goal = int.parse(goalController.text);
                    Navigator.of(context).pop();
                  });
                  saveGoal(_goal);
                }
              },
            )
          ],
        );
      },
    );
  }

  void saveData(int steps) {
    if (user != null &&
        selectedDate != null &&
        selectedDate!.isAtSameMomentAs(DateTime.now())) {
      _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('stepsData')
          .doc(selectedDate!.toString().substring(0, 10))
          .set({'steps': steps, 'date': selectedDate}, SetOptions(merge: true));
    }
  }

  void saveGoal(int goal) {
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('goals')
          .doc('dailyGoal')
          .set({'goal': goal});
    }
  }

  void _loadGoal() async {
    if (user != null) {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('goals')
          .doc('dailyGoal')
          .get();
      if (doc.exists) {
        setState(() {
          _goal = doc.get('goal') ?? 10000;
        });
      }
    }
  }

  void _loadStepsForDate(DateTime date) async {
    String formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    DocumentSnapshot snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('stepsData')
        .doc(formattedDate)
        .get();
    var data = snapshot.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey('steps')) {
      int newSteps = data['steps'];
      setState(() {
        _steps = newSteps.toString();
      });
      // This will ensure any new steps counted after loading will be added
      // on top of the loaded value.
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen((event) {
        if (event.steps > newSteps) {
          onStepCount(event);
        }
      }).onError(onStepCountError);
    } else {
      setState(() {
        _steps = '0'; // Reset to '0' if no data is found
      });
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
        _loadStepsForDate(
            selectedDate!); // Reload steps immediately after date change
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double calories = calculateCalories(int.tryParse(_steps) ?? 0);
    double distance = calculateDistance(int.tryParse(_steps) ?? 0);
    double percent = (int.tryParse(_steps) ?? 0) / _goal;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Step Counter'),
          backgroundColor: Colors.blue[300],
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: _selectDate,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 0.0),
              child: Text(
                "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularPercentIndicator(
                      radius: 170.0,
                      lineWidth: 25.0,
                      animation: true,
                      percent: percent.clamp(
                          0.0, 1.0), // Ensure percent does not exceed 100%
                      center: Text(
                        "${_steps} of $_goal steps",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: Colors.blue[500]),
                      ),
                      circularStrokeCap: CircularStrokeCap.round,
                      progressColor: Colors.blue,
                      backgroundColor: const Color.fromARGB(255, 203, 203, 203),
                    ),
                    SizedBox(height: 10),
                    Text('Distance: ${distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Calories Burned: ${calories.round()} kcal',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      child: Text("Set Target Steps"),
                      onPressed: updateGoal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[300],
                        foregroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        textStyle: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        padding:
                            EdgeInsets.symmetric(horizontal: 50, vertical: 10),
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
