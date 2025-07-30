class SavedTrip {
  final String title;
  final Map<String, dynamic> itinerary;
  final DateTime createdAt;

  SavedTrip({
    required this.title,
    required this.itinerary,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'itinerary': itinerary,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static SavedTrip fromMap(Map<String, dynamic> map) {
    return SavedTrip(
      title: map['title'],
      itinerary: Map<String, dynamic>.from(map['itinerary']),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
