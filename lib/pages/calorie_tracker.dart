import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; 

class CalorieTracker extends StatefulWidget {
  const CalorieTracker({Key? key}) : super(key: key);

  @override
  _CalorieTrackerState createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();
  final TextEditingController _extrasController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _activityLevelController =
      TextEditingController();

  bool _isMale = true;
  String _goal = 'maintain';
  DateTime? _selectedDate;
  User? user = FirebaseAuth.instance.currentUser;
  TabController? _tabController;

  Map<String, List<dynamic>> _meals = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
    'Extras': []
  };

  Map<String, double> _totals = {
    'Calories': 0,
    'Protein': 0,
    'Carbs': 0,
    'Fat': 0
  };

  double? _calorieGoal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchDataFromFirestore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _extrasController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _activityLevelController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> fetchDataFromFirestore() async {
    if (user == null || _selectedDate == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('foodEntries')
        .where('date', isEqualTo: Timestamp.fromDate(_selectedDate!))
        .orderBy('lastUpdated', descending: true)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var latestEntry = snapshot.docs.first.data();
        setState(() {
          _meals = Map<String, List<dynamic>>.from(latestEntry['meals'] ?? {});
          _totals = Map<String, double>.from(latestEntry['totals'] ?? {});
          _calorieGoal = latestEntry['calorieGoal'];
        });
      } else {
        setState(() {
          _meals = {'Breakfast': [], 'Lunch': [], 'Dinner': [], 'Extras': []};
          _totals = {'Calories': 0, 'Protein': 0, 'Carbs': 0, 'Fat': 0};
          _calorieGoal = null;
        });
      }
    });
  }

  Future<void> getFoodInfo(String query, String mealType) async {
    const String apiKey =
        'WuvIt/PGt1Pz8L0O1IuHOQ==vPLZlUluXLk5fm63'; 
    final Uri uri =
        Uri.https('api.calorieninjas.com', '/v1/nutrition', {'query': query});
    try {
      final response = await http.get(uri, headers: {'X-Api-Key': apiKey});
      if (response.statusCode == 200 &&
          json.decode(response.body)['items'].isNotEmpty) {
        final item = json.decode(response.body)['items'][0];
        setState(() {
          _meals[mealType]!.add(item);
          _calculateTotals();
        });
        saveDataToFirestore(); // Automatically save data after adding a meal
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Food Not Found"),
              content: Text(
                  "The item was not found in our database. Please check the spelling or enter the food manually."),
              actions: <Widget>[
                TextButton(
                  child: Text("Manually Enter Food"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    manuallyAddFoodItem(mealType);
                  },
                ),
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

void _calculateTotals() {
  _totals = {'Calories': 0, 'Protein': 0, 'Carbs': 0, 'Fat': 0};

  _meals.forEach((key, value) {
      for (var item in value) {
        _totals['Calories'] =
            (_totals['Calories'] ?? 0) + (item['calories'] as num? ?? 0);
        _totals['Protein'] =
            (_totals['Protein'] ?? 0) + (item['protein_g'] as num? ?? 0);
        _totals['Carbs'] = (_totals['Carbs'] ?? 0) +
            (item['carbohydrates_total_g'] as num? ?? 0);
        _totals['Fat'] =
            (_totals['Fat'] ?? 0) + (item['fat_total_g'] as num? ?? 0);
      }
    });

  // Rectifying excessive decimal place problem
  if (_totals['Calories'] != null)
    _totals['Calories'] = double.parse(_totals['Calories']!.toStringAsFixed(0)); // Calories as whole number
  if (_totals['Protein'] != null)
    _totals['Protein'] = double.parse(_totals['Protein']!.toStringAsFixed(1));   // One decimal place for macronutrients
  if (_totals['Carbs'] != null)
    _totals['Carbs'] = double.parse(_totals['Carbs']!.toStringAsFixed(1));
  if (_totals['Fat'] != null)
    _totals['Fat'] = double.parse(_totals['Fat']!.toStringAsFixed(1));

  setState(() {});
}


  void _calculateCalorieGoal() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    int age = int.tryParse(_ageController.text) ?? 0;
    double bmr = _isMale
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;
    double activityMultiplier = 1.2 +
        (_activityLevelController.text.isEmpty
            ? 0
            : int.parse(_activityLevelController.text) *
                0.175); // Basic activity multiplier adjustments
    _calorieGoal = (bmr * activityMultiplier) +
        (_goal == 'lose'
            ? -500 // Subtract 500 calories for weight loss
            : _goal == 'gain'
                ? 500 // Add 500 calories for weight gain
                : 0); // Maintain weight
    setState(() {});
  }

  Future<void> saveDataToFirestore() async {
    if (user == null || _selectedDate == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('foodEntries')
        .add({
      'meals': _meals,
      'totals': _totals,
      'calorieGoal': _calorieGoal,
      'weight': _weightController.text,
      'height': _heightController.text,
      'age': _ageController.text,
      'activityLevel': _activityLevelController.text,
      'isMale': _isMale,
      'goal': _goal,
      'date': Timestamp.fromDate(_selectedDate!),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  TextEditingController getControllerForMealType(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return _breakfastController;
      case 'Lunch':
        return _lunchController;
      case 'Dinner':
        return _dinnerController;
      case 'Extras':
        return _extrasController;
      default:
        return TextEditingController();
    }
  }

  void _deleteFoodEntry(String mealType, dynamic item) {
    setState(() {
      _meals[mealType]?.remove(item);
      _calculateTotals();
    });
    saveDataToFirestore(); // Automatically save data after deleting a meal
  }

  Widget _mealInput(String mealType) {
    TextEditingController controller = getControllerForMealType(mealType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mealType, style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Enter food for $mealType',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: Colors.blue.shade800),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  getFoodInfo(controller.text, mealType);
                  controller.clear();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.green),
              onPressed: () => manuallyAddFoodItem(mealType),
            )
          ],
        ),
        if (_meals[mealType] != null)
          ..._meals[mealType]!
              .map((meal) => ListTile(
                    title: Text(meal['name']),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFoodEntry(mealType, meal),
                    ),
                  ))
              .toList(),
      ],
    );
  }

  Widget _calorieGoalInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _weightController,
          decoration: InputDecoration(
            labelText: 'Weight (kg)',
            labelStyle: TextStyle(color: Colors.blue.shade800),
            border: OutlineInputBorder(),
            errorText: _weightController.text.isNotEmpty &&
                    !_validateNumber(_weightController.text)
                ? 'Only numeric values are allowed'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: 8),
        TextField(
          controller: _heightController,
          decoration: InputDecoration(
            labelText: 'Height (cm)',
            labelStyle: TextStyle(color: Colors.blue.shade800),
            border: OutlineInputBorder(),
            errorText: _heightController.text.isNotEmpty &&
                    !_validateNumber(_heightController.text)
                ? 'Only numeric values are allowed'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: 8),
        TextField(
          controller: _ageController,
          decoration: InputDecoration(
            labelText: 'Age',
            labelStyle: TextStyle(color: Colors.blue.shade800),
            border: OutlineInputBorder(),
            errorText: _ageController.text.isNotEmpty &&
                    !_validateNumber(_ageController.text)
                ? 'Only numeric values are allowed'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: 8),
        TextField(
          controller: _activityLevelController,
          decoration: InputDecoration(
            labelText: 'Activity level (times per week)',
            labelStyle: TextStyle(color: Colors.blue.shade800),
            border: OutlineInputBorder(),
            errorText: _activityLevelController.text.isNotEmpty &&
                    !_validateNumber(_activityLevelController.text)
                ? 'Only numeric values are allowed'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: 16),
        ListTile(
          title: Text('Male', style: TextStyle(color: Colors.blue.shade800)),
          leading: Radio<bool>(
            value: true,
            groupValue: _isMale,
            onChanged: (bool? value) {
              setState(() => _isMale = value!);
            },
          ),
        ),
        ListTile(
          title: Text('Female', style: TextStyle(color: Colors.blue.shade800)),
          leading: Radio<bool>(
            value: false,
            groupValue: _isMale,
            onChanged: (bool? value) {
              setState(() => _isMale = value!);
            },
          ),
        ),
        DropdownButton<String>(
          value: _goal,
          items: const ['lose', 'maintain', 'gain'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(color: Colors.blue.shade800)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _goal = value!);
          },
        ),
        ElevatedButton(
          onPressed: _calculateCalorieGoal,
          child: Text('Calculate Calorie Goal'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue[300],
          ),
        ),
        if (_calorieGoal != null)
          Text('Calorie Goal: ${_calorieGoal!.toStringAsFixed(2)} kcal',
              style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        SizedBox(height: 20),
      ],
    );
  }

  // Helper function to validate numeric input
  bool _validateNumber(String input) {
    return RegExp(r'^\d+$').hasMatch(input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calorie Tracker'),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
          ),
          Tooltip(
            message: "Tap here for help with the Calorie Tracker.",
            child: IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("How to use the Calorie Tracker"),
                      content: Text(
                          "Firstly, select the day you would like to add food entries to. Next, enter the food you have eaten, one entry at a time. If the amount of food is not specified, the tracker will automatically assume it is a 100 gram serving. Example Entry: 50 gram croissant."),
                      actions: <Widget>[
                        TextButton(
                          child: Text("Got it!",
                              style: TextStyle(color: Colors.blue.shade800)),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fastfood), text: 'Food Log'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Calorie Goal'),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _selectedDate == null
              ? Center(child: Text("Please select a date to view or log food."))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _mealInput('Breakfast'),
                      _mealInput('Lunch'),
                      _mealInput('Dinner'),
                      _mealInput('Extras'),
                      const Text('Total Macros and Calories:',
                          style: TextStyle(fontSize: 19)),
                      Text('Total Calories: ${_totals['Calories']} kcal',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                      Text('Total Protein: ${_totals['Protein']} g',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      Text('Total Carbs: ${_totals['Carbs']} g',
                          style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 206, 185, 0),
                              fontWeight: FontWeight.bold)),
                      Text('Total Fat: ${_totals['Fat']} g',
                          style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 243, 112, 255),
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _calorieGoalInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        fetchDataFromFirestore();
      });
    }
  }

  Future<void> manuallyAddFoodItem(String mealType) async {
    TextEditingController foodController = getControllerForMealType(mealType);
    TextEditingController caloriesController = TextEditingController();
    TextEditingController proteinController = TextEditingController();
    TextEditingController carbsController = TextEditingController();
    TextEditingController fatController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Manually Add Food"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: foodController,
                decoration: InputDecoration(
                  labelText: 'Enter food for $mealType',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              SizedBox(height: 8),
              Text('Enter Calories:'),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              SizedBox(height: 8),
              Text('Enter Macros (g):'),
              TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Protein',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Carbohydrates',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Fat',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Add"),
              onPressed: () {
                if (foodController.text.isNotEmpty &&
                    caloriesController.text.isNotEmpty &&
                    proteinController.text.isNotEmpty &&
                    carbsController.text.isNotEmpty &&
                    fatController.text.isNotEmpty) {
                  setState(() {
                    _meals[mealType]!.add({
                      'name': foodController.text,
                      'calories': double.parse(caloriesController.text),
                      'protein_g': double.parse(proteinController.text),
                      'carbohydrates_total_g':
                          double.parse(carbsController.text),
                      'fat_total_g': double.parse(fatController.text),
                    });
                    _calculateTotals();
                  });
                  saveDataToFirestore(); // Automatically save data after adding a meal
                  foodController.clear();
                  caloriesController.clear();
                  proteinController.clear();
                  carbsController.clear();
                  fatController.clear();
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                foodController.clear();
                caloriesController.clear();
                proteinController.clear();
                carbsController.clear();
                fatController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
