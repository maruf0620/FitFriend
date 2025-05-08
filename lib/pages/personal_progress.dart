import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class PersonalProgress extends StatefulWidget {
  @override
  _PersonalProgressState createState() => _PersonalProgressState();
}

class _PersonalProgressState extends State<PersonalProgress> with SingleTickerProviderStateMixin {
  final TextEditingController weightController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String _timescale = 'Week';
  TabController? _tabController;

  String selectedExercise = '';
  List<String> exercises = [];
  List<Map<String, dynamic>> weightData = [];
  List<Map<String, dynamic>> recordData = [];

  String get timescale => _timescale;

  set timescale(String newValue) {
    if (_timescale != newValue) {
      _timescale = newValue;
      fetchWeightData(); // Refetch data when timescale changes
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchExercises();
    fetchData();
  }

  void fetchData() async {
    await fetchWeightData();
    if (exercises.isNotEmpty) {
      await fetchRecordData(exercises.first);
    }
  }

  Future<void> fetchExercises() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance.collection('personal_records').get();
      final exercisesSet = <String>{};
      for (var doc in querySnapshot.docs) {
        exercisesSet.add(doc.data()['exercise'] as String);
      }
      setState(() {
        exercises = exercisesSet.toList();
        if (exercises.isNotEmpty) selectedExercise = exercises.first;
      });
    } catch (e) {
      debugPrint('Error fetching exercises: $e');
    }
  }

    Future<void> fetchWeightData() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    DateTime startDate = DateTime.now();

    // Determine the start date based on the selected timescale
    switch (timescale) {
      case 'Week':
        startDate = DateTime.now().subtract(Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(DateTime.now().year, DateTime.now().month - 1, DateTime.now().day);
        break;
      case 'Year':
        startDate = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
        break;
      case 'All Time':
        startDate = DateTime(2000); // Arbitrary early date
        break;
    }

    try {
      var result = await FirebaseFirestore.instance
          .collection('weightData')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date')
          .get();

      if (mounted) {
        setState(() {
          weightData = result.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            var weight = data['weight'];
            if (weight != null && weight is double && weight.isFinite) {
              return {
                'id': doc.id,
                'date': (data['date'] as Timestamp).toDate(),
                'weight': weight
              };
            }
            return null;
          }).whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch weight data: $e');
    }
  }

  Future<void> fetchRecordData(String exercise) async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Query query = FirebaseFirestore.instance
        .collection('personal_records')
        .where('userId', isEqualTo: userId)
        .where('exercise', isEqualTo: exercise)
        .orderBy('date');

    if (timescale != 'All Time') {
      final now = DateTime.now();
      DateTime start;
      switch (timescale) {
        case 'Week':
          start = now.subtract(Duration(days: 7));
          break;
        case 'Month':
          start = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'Year':
          start = now.subtract(Duration(days: 365));
          break;
        default:
          start = DateTime(2000);
          break;
      }
      query = query.where('date', isGreaterThanOrEqualTo: start); // Makes the date filter covers the proper range
    }

    try {
      var result = await query.get();
      if (mounted) {
        setState(() {
          recordData = result.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            var kilos = data['kilos'];
            if (kilos != null && kilos is double && kilos.isFinite) {
              return {
                'id': doc.id,
                'date': (data['date'] as Timestamp).toDate(),
                'record': kilos
              };
            }
            return null;
          }).whereType<Map<String, dynamic>>().toList();
        });
      }
    }
     catch (e) {
      debugPrint('Failed to fetch record data: $e');
    }
  }

  Future<void> submitWeight(double weight, DateTime date) async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance.collection('weightData').add({
        'userId': userId,
        'date': Timestamp.fromDate(date),
        'weight': weight
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Weight submitted successfully!")));
      fetchWeightData();
    } catch (e) {
      debugPrint('Error submitting weight: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit weight.")));
    }
  }

  Future<void> deleteWeightEntry(String id) async {
    try {
      await FirebaseFirestore.instance.collection('weightData').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Weight entry deleted successfully")));
      fetchWeightData();
    } catch (e) {
      debugPrint('Error deleting weight entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete weight entry")));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Personal Progress Tracker'),
        backgroundColor: Colors.blue.shade300,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Weight Progress'),
            Tab(text: 'Personal Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          weightProgressView(context),
          personalRecordsView(context),
        ],
      ),
    );
  }

  Widget weightProgressView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter your weight (kg)',
                labelStyle: TextStyle(color: Colors.blue.shade800),
                suffixIcon: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blue.shade300),
                      onPressed: () {
                        double? weight = double.tryParse(weightController.text);
                        if (weight != null && weight > 0) {
                          submitWeight(weight, selectedDate);
                          weightController.clear();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Please enter a valid weight"),
                                duration: Duration(seconds: 2)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          DropdownButton<String>(
            value: timescale,
            onChanged: (String? newValue) {
              setState(() {
                timescale = newValue!;
              });
            },
            items: <String>['Week', 'Month', 'Year', 'All Time']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          if (weightData.isNotEmpty) ...[
            Container(
              height: 200,
              child: WeightChart(
                weightData: weightData,
                timescale: timescale
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: weightData.length,
              itemBuilder: (context, index) {
                var data = weightData[index];
                return ListTile(
                  title: Text("${data['weight']} kg on ${DateFormat.yMd().format(data['date'])}"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteWeightEntry(data['id']),
                  ),
                );
              },
            ),
          ] else
            Center(child: Text("No weight data available."))
        ],
      ),
    );
  }

Widget personalRecordsView(BuildContext context) {
  return SingleChildScrollView(
    child: Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select Exercise',
              labelStyle: TextStyle(color: Colors.blue.shade800),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300),
              ),
            ),
            value: selectedExercise,
            onChanged: (String? newValue) {
              setState(() {
                selectedExercise = newValue!;
                fetchRecordData(newValue);
              });
            },
            items: exercises.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
          DropdownButton<String>(
            value: timescale,
            onChanged: (String? newValue) {
              setState(() {
                timescale = newValue!;
                fetchRecordData(selectedExercise);
              });
            },
            items: <String>['Week', 'Month', 'Year', 'All Time']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          if (recordData.isNotEmpty) ...[
            Container(
              height: 200,  // Provide height to ensure the chart has constraints
              child: PersonalRecordsChart(
                recordData: recordData,
                exercise: selectedExercise,
                timescale: timescale,
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recordData.length,
              itemBuilder: (context, index) {
                var data = recordData[index];
                return ListTile(
                  title: Text("${data['record']} kg on ${DateFormat.yMd().format(data['date'])}"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color:Colors.red ),
                    onPressed: () => deleteRecordEntry(data['id']),
                  ),
                );
              },
            ),
          ] else
            Center(child: Text("No record data available."))
        ],
      ),
    );
  }

  Future<void> deleteRecordEntry(String id) async {
    try {
      await FirebaseFirestore.instance.collection('personal_records').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Record deleted successfully")));
      fetchRecordData(selectedExercise);
    } catch (e) {
      debugPrint('Error deleting record entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete record entry")));
    }
  }
}

class WeightChart extends StatelessWidget {
  final List<Map<String, dynamic>> weightData;
  final String timescale;

  WeightChart({required this.weightData, required this.timescale});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = weightData.map((data) {
      var date = data['date'];
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), data['weight']);
    }).toList();

    if (spots.isEmpty) {
      return Center(child: Text("No data available for the selected period."));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: spots.map((e) => e.y).reduce(min) * 0.9,
          maxY: spots.map((e) => e.y).reduce(max) * 1.1,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final date =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 9.0),
                    child: Text(DateFormat.MMMd().format(date),
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(value.toStringAsFixed(1),
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 10));
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.blue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true, color: Colors.lightBlue.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalRecordsChart extends StatelessWidget {
  final List<Map<String, dynamic>> recordData;
  final String exercise;
  final String timescale;

  PersonalRecordsChart({
    required this.recordData,
    required this.exercise,
    required this.timescale,
  });

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = recordData.map((data) {
      var date = data['date'];
      var record = data['record'];
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), record);
    }).toList();

    if (spots.isEmpty) {
      return Center(child: Text("No data available for the selected period."));
    }

    double minX = spots.map((e) => e.x).reduce(min);
    double maxX = spots.map((e) => e.x).reduce(max);
    double minY = spots.map((e) => e.y).reduce(min) * 0.9;
    double maxY = spots.map((e) => e.y).reduce(max) * 1.1;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final date =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 9.0),
                    child: Text(DateFormat.MMMd().format(date),
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(value.toStringAsFixed(1),
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize:10));
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.blue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true, color: Colors.lightBlue.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
