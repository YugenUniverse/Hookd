import 'package:flutter/material.dart';
import '../services/wall_service.dart';
import '../models/wall.dart';
import '../dialogs/wall_details_dialog.dart';

class WallsPage extends StatefulWidget {
  @override
  _WallsScreenState createState() => _WallsScreenState();
}

class _WallsScreenState extends State<WallsPage> {
  final WallService _wallService = WallService();
  late Future<List<Wall>> _wallsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the walls when the screen loads
    _wallsFuture = _wallService.fetchAllWalls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Climbing Walls')),
      body: FutureBuilder<List<Wall>>(
        future: _wallsFuture,
        builder: (context, snapshot) {
          // 1. Show a loading spinner while waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // 2. Show an error message if something broke
          else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // 3. Show a message if the database is empty
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No walls found.'));
          }

          // 4. Build the list of walls!
          final walls = snapshot.data!;
          return ListView.builder(
            itemCount: walls.length,
            itemBuilder: (context, index) {
              final wall = walls[index];

              // Change the icon based on if it's indoors or outdoors
              IconData wallIcon = wall.wallType == 'IndoorWall'
                  ? Icons.domain
                  : Icons.landscape;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(wallIcon, size: 40, color: Colors.blueGrey),
                  title: Text(
                    wall.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${wall.difficulty} • By ${wall.ownerName}'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return WallDetailsDialog(wall: wall);
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
