import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';


class WorkoutTracker extends StatefulWidget {
  @override
  _WorkoutTrackerState createState() => _WorkoutTrackerState();
}

class _WorkoutTrackerState extends State<WorkoutTracker> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final exerciseController = TextEditingController();
  final setsController = TextEditingController();
  final repsController = TextEditingController();
  final kilosController = TextEditingController();
  DateTime? selectedDate;
  List<Map<String, dynamic>> workouts = [];
  List<String> allExercises = [];
  String? selectedMuscle;
  List<Map<String, dynamic>> currentExercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchExerciseNames();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    exerciseController.dispose();
    setsController.dispose();
    repsController.dispose();
    kilosController.dispose();
    super.dispose();
  }

  Future<void> fetchExerciseNames() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    var exercisesSnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();

    setState(() {
      allExercises = exercisesSnapshot.docs
          .map((doc) => doc.data()['exercise'] as String)
          .toSet()
          .toList();
    });
  }

Future<void> saveWorkout() async {
  if (selectedDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date first!')));
    return;
  }

  final String exercise = exerciseController.text.trim();
  final int? sets = int.tryParse(setsController.text);
  final int? reps = int.tryParse(repsController.text);
  final double? kilos = double.tryParse(kilosController.text);
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  if (userId.isNotEmpty && exercise.isNotEmpty && sets != null && reps != null && kilos != null) {
    var workout = {
      'userId': userId,
      'exercise': exercise,
      'sets': sets,
      'reps': reps,
      'kilos': kilos,
      'date': Timestamp.fromDate(selectedDate!),  // Ensure using selectedDate
    };

    await checkAndSavePR(userId, exercise, kilos, sets, reps, workout);

    DocumentReference docRef = await FirebaseFirestore.instance.collection('workouts').add(workout);
    workout['id'] = docRef.id;

    setState(() {
      workouts.add(workout);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workout saved successfully')));
    });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter valid workout details')));
  }
}

Future<void> checkAndSavePR(String userId, String exercise, double kilos, int sets, int reps, Map<String, dynamic> workout) async {
  var prSnapshot = await FirebaseFirestore.instance
      .collection('workouts')
      .where('userId', isEqualTo: userId)
      .where('exercise', isEqualTo: exercise)
      .orderBy('kilos', descending: true)
      .limit(1)
      .get();

  double currentPR = 0;
  if (prSnapshot.docs.isNotEmpty) {
    currentPR = prSnapshot.docs.first.data()['kilos'];
  }

  if (kilos > currentPR) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congratulations! New personal record for $exercise: $kilos kg!'))
    );

    await FirebaseFirestore.instance.collection('personal_records').add({
      'userId': userId,
      'exercise': exercise,
      'kilos': kilos,
      'sets': sets,
      'reps': reps,
      'date': Timestamp.fromDate(selectedDate!),  // Use selectedDate here too
    });
  }
}


  Future<void> fetchWorkouts() async {
    if (selectedDate == null) {
      return;
    }

    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    var querySnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: Timestamp.fromDate(selectedDate!))
        .get();

    setState(() {
      workouts = querySnapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    });
  }

  void deleteWorkout(String docId) async {
    await FirebaseFirestore.instance.collection('workouts').doc(docId).delete();
    fetchWorkouts();
  }

  void confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this workout?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                deleteWorkout(docId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
        selectedDate = picked;
        fetchWorkouts();
      });
    }
  }

  // Fetch exercises from the API
  Future<List<Map<String, dynamic>>> fetchExercises({String? muscle, String? type, String? difficulty, int offset = 0}) async {
    var queryParams = {
      'muscle': muscle,
      'type': type,
      'difficulty': difficulty,
      'offset': offset.toString(),
    };
    queryParams.removeWhere((key, value) => value == null);

    var uri = Uri.https('api.api-ninjas.com', '/v1/exercises', queryParams);
    var response = await http.get(uri, headers: {'X-Api-Key': 'WuvIt/PGt1Pz8L0O1IuHOQ==jA1uSxqJZ1EkOHPv'});

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load exercises: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Workout Tracker"),
        backgroundColor: Colors.blue.shade300,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Log Workout"),
            Tab(text: "Suggest Exercises"),
          ],
          indicatorColor: Colors.white,
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildWorkoutLogger(),
          buildWorkoutSuggester(),
        ],
      ),
    );
  }

Widget buildWorkoutLogger() {
    return selectedDate == null
        ? Center(child: Text("Please select a date to view or log workouts."))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return allExercises.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    exerciseController.text = selection;
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    textEditingController.text = exerciseController.text;
                    textEditingController.selection = TextSelection.fromPosition(TextPosition(offset: textEditingController.text.length));
                    textEditingController.addListener(() {
                      exerciseController.text = textEditingController.text;
                    });
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Exercise',
                        labelStyle: TextStyle(color: Colors.blue.shade800),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.shade800),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: setsController,
                  decoration: InputDecoration(
                    labelText: 'Sets',
                    labelStyle: TextStyle(color: Colors.blue.shade800),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade800),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: 8),
                TextField(
                  controller: repsController,
                  decoration: InputDecoration(
                    labelText: 'Repetitions',
                    labelStyle: TextStyle(color: Colors.blue.shade800),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade800),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: 8),
                TextField(
                  controller: kilosController,
                  decoration: InputDecoration(
                    labelText: 'Kilos',
                    labelStyle: TextStyle(color: Colors.blue.shade800),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade800),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saveWorkout,
                  child: Text('Save Workout'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue[300],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchWorkouts,
                    child: ListView.builder(
                      itemCount: workouts.length,
                      itemBuilder: (context, index) {
                        final workout = workouts[index];
                        return ListTile(
                          leading: Icon(Icons.fitness_center, color: Colors.blue.shade800),
                          title: Text(workout['exercise']),
                          subtitle: Text('Sets: ${workout['sets']}, Reps: ${workout['reps']}, Kilos: ${workout['kilos']}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => confirmDelete(workout['id']),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
  }


  Widget buildWorkoutSuggester() {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select muscle group',
                labelStyle: TextStyle(color: Colors.blue.shade800),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
              ),
              items: <String>[
                'abdominals', 'abductors', 'adductors', 'biceps', 'calves', 'chest', 'forearms', 'glutes', 'hamstrings', 'lats', 'lower_back', 'middle_back', 'neck', 'quadriceps', 'traps', 'triceps'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedMuscle = value;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              var exercises = await fetchExercises(muscle: selectedMuscle);
              setState(() {
                currentExercises = exercises;
              });
            },
            child: Text('Get Exercises'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue[300],
            ),
          ),
          currentExercises.isEmpty
            ? Container()
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: currentExercises.length,
                itemBuilder: (context, index) {
                  final exercise = currentExercises[index];
                  return ExpansionTile(
                    leading: Icon(Icons.fitness_center, color: Colors.blue.shade800),
                    title: Text(exercise['name']),
                    subtitle: Text('Type: ${exercise['type']}'),
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(exercise['instructions'] ?? "No instructions provided."),
                      )
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}

