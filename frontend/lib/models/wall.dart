class Wall {
  final String id;
  final String name;
  final String description;
  final String difficulty;
  final String wallType;
  final String? ownerName;

  Wall({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.wallType,
    this.ownerName,
  });

  factory Wall.fromJson(Map<String, dynamic> json) {
    String? owner;
    if (json['wallType'] == 'IndoorWall' && json['facility'] != null) {
      owner = json['facility']['username'];
    } else if (json['wallType'] == 'OutdoorWall' &&
        json['publicBody'] != null) {
      owner = json['publicBody']['username'];
    }

    return Wall(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Wall',
      description: json['description'] ?? 'No description available.',
      difficulty: json['difficulty'] ?? 'BEGINNER',
      wallType: json['wallType'] ?? 'Wall',
      ownerName: owner ?? 'Unknown Owner',
    );
  }
}
