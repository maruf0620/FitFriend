import 'package:FitFriend/pages/personal_progress.dart';
import 'package:FitFriend/pages/run_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'workout_tracker.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'calorie_tracker.dart';
import 'step_counter.dart';
import 'video_tutorials.dart';
import 'run_logger.dart';
import 'run_service.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final user = FirebaseAuth.instance.currentUser;

  void signUserOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome to Fit Friend!"),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => signUserOut(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue.shade300,
              ),
              child: Text(user?.email ?? "Guest",
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => HomePage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log out'),
              onTap: () => signUserOut(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: <Widget>[
            FeatureTile(
                icon: Icons.fitness_center_rounded,
                title: "Workout Tracker",
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => WorkoutTracker()))),
            FeatureTile(
                icon: Icons.fastfood,
                title: "Calorie Tracker",
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => CalorieTracker()))),
            FeatureTile(
                icon: Icons.directions_walk,
                title: "Step Counter",
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StepCounter()))),
            FeatureTile(
                icon: Icons.run_circle,
                title: "Run Logger",
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => RunTrackerPage()))),
            FeatureTile(
                icon: Icons.add_chart_rounded,
                title: "Personal Progress",
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => PersonalProgress()))),
            FeatureTile(
                icon: Icons.video_library,
                title: "Video Tutorials",
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => VideoTutorialsPage()))),
          ],
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const FeatureTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: Colors.blue.shade300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 50, color: Colors.white),
              Text(title, style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
