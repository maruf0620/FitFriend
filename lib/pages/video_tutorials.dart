import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoTutorial {
  final String title;
  final List<String> paths;
  final List<String> steps;

  VideoTutorial({required this.title, required this.paths, required this.steps});
}

class VideoCategory {
  final String name;
  final List<VideoTutorial> videos;

  VideoCategory({required this.name, required this.videos});
}

class VideoTutorialsPage extends StatelessWidget {
  final List<VideoCategory> categories = [
    VideoCategory(
      name: 'Chest',
      videos: [
        VideoTutorial(
          title: 'Bench Press',
          paths: ['lib/videos/Bench_Press.mov'],
          steps: [
            '1. Position your body flat on the bench with your eyes under the bar. Keep your feet flat and your back arched. Make sure your glutes are in contact with the bench throughout the lift.',
            '2. Grab the bar slightly wider than shoulder-width apart. Unrack the barbell and take a breath before lowering the bar to your midchest, allowing it touch your chest slightly.',
            '3. Once at the bottom portion of the lift, press the weight upwards and breathe out once you have finished the repetition. Repeat as necessary.'
          ],
        ),
      ],
    ),
    VideoCategory(
      name: 'Shoulders',
      videos: [
        VideoTutorial(
          title: 'Standing Shoulder Press',
          paths: ['lib/videos/Shoulder_Press.mov'],
          steps: [
            '1. Make sure the bar is racked around your shoulder height. Grab the bar slightly wider than shoulder-width apart',
            '2. Lift the bar off the rack, then take a few steps back. Once you are in position, take a deep breath to brace your core. ',
            '3. Squeeze your glutes and press the bar upwards until your arms are fully extended. Lower the bar to around your collar bone and repeat as necessary.'
          ],
        ),
      ],
    ),
    VideoCategory(
      name: 'Lower Body',
      videos: [
        VideoTutorial(
          title: 'Deadlift',
          paths: ['lib/videos/Deadlift_back.mov', 'lib/videos/Deadlift_Front.mov'],
          steps: [
            '1. Stand with your feet hip-width apart, with bar above the mid-section of your feet. The bar should be around 3-4 inches from your shins',
            '2. Bend at the hips and knees, grab the bar with a shoulder-width grip. Your shins should be touching the bar.',
            '3. Take a deep breath to brace your core and while keeping your back straight, lift the bar by straightening your hips and knees. Keep the bar in contact with your shins when lifting it.',
            '4. Lower the bar and control the descent of the bar. You can now exhale. Repeat as necessary. Do not just drop the bar as this can cause injury.'
          ],
        ),
        VideoTutorial(
          title: 'Squat',
          paths: ['lib/videos/Squat_Side.mov', 'lib/videos/Squat_Rear.MOV'],
          steps: [
            '1. Position yourself underneath the bar in the middle. The bar should rest on your rear shoulder muscles. Keep your hands and elbows as close as you comfortably can, as this makes the bar more stable on your back.',
            '2. Unrack the barbell and take 3 small steps backwards. Position your feet slightly wider than hip width and angle your toes slightly outwards. Take a deep breath to brace your core and start your descent.',
            '3. When descending, think of it as sitting down into a chair. Try to descend as deep as you comfortably can, and then push yourself back up explosively. You can now exhale. Repeat these steps as necessary.'
          ],
        ),
      ],
    ),
    VideoCategory(
      name: 'Upper Back',
      videos: [
        VideoTutorial(
          title: 'Pull Ups',
          paths: ['lib/videos/Pull_ups.MOV'],
          steps: [
            '1. Grab the bar slightly wider than shoulder width',
            '2. Pull yourself up imagining pulling your elbows down and behind you, to visualize it easier you can imagine it as pulling your elbows towards your back pockets.',
            '3. Make sure your chin is slightly above the bar and then lower yourself until your arms are locked out.'
          ],
        ),
      ],
    ),
    VideoCategory(
      name: 'Lower Back',
      videos: [
        VideoTutorial(
          title: 'Deadlift',
          paths: ['lib/videos/Deadlift_back.mov', 'lib/videos/Deadlift_Front.mov'],
          steps: [
            '1. Stand with your feet hip-width apart, with bar above the mid-section of your feet. The bar should be around 3-4 inches from your shins',
            '2. Bend at the hips and knees, grab the bar with a shoulder-width grip. Your shins should be touching the bar.',
            '3. Take a deep breath to brace your core and while keeping your back straight, lift the bar by straightening your hips and knees. Keep the bar in contact with your shins when lifting it.',
            '4. Lower the bar and control the descent of the bar. You can now exhale. Repeat as necessary. Do not just drop the bar as this can cause injury.'
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Tutorials'),
        backgroundColor: Colors.blue[300], 
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.blue[400], // Blue background for each category
              borderRadius: BorderRadius.circular(10),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                categories[index].name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for the category names
                ),
              ),
              children: categories[index].videos.map((video) {
                return ListTile(
                  title: Text(
                    video.title,
                    style: TextStyle(color: Colors.white), // White text for video titles
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(videoTutorial: video),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final VideoTutorial videoTutorial;

  VideoPlayerScreen({Key? key, required this.videoTutorial}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  void initializePlayer() {
    _controller = VideoPlayerController.asset(widget.videoTutorial.paths[_currentVideoIndex])
      ..initialize().then((_) {
        setState(() {});  // Refresh the state to display video after initialization
      })
      ..setLooping(true)
      ..play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoTutorial.title),
        backgroundColor: Colors.blue[300], 
      ),
      body: _controller.value.isInitialized
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                if (widget.videoTutorial.paths.length > 1)
                  Container(
                    margin: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.blue[50], // Light blue for button background
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: ToggleButtons(
                      fillColor: Colors.blue[200],
                      selectedBorderColor: Colors.blue[800],
                      selectedColor: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      children: widget.videoTutorial.paths.map((path) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("View ${widget.videoTutorial.paths.indexOf(path) + 1}"),
                      )).toList(),
                      isSelected: List.generate(widget.videoTutorial.paths.length, (index) => index == _currentVideoIndex),
                      onPressed: (index) {
                        setState(() {
                          _currentVideoIndex = index;
                        });
                        _controller.pause();
                        _controller.dispose();
                        initializePlayer();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.videoTutorial.steps.map((step) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(step, style: TextStyle(fontSize: 16)),
                    )).toList(),
                  ),
                ),
              ],
            ),
          )
        : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[300],
        onPressed: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
