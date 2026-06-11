class CarpoolData {
  static List<Map<String, dynamic>> carpools = [];

  static void addDummyData() {
    if (carpools.isNotEmpty) return;

    carpools.addAll([
      {
        "departure": "수원역",
        "destination": "강원 예비군 훈련장",
        "time": "08:00",
        "maxSeats": 4,
        "currentSeats": 2,
        "minutes": 42,
        "fare": 5000,
        "match": 92,
      },
      {
        "departure": "영통역",
        "destination": "강원 예비군 훈련장",
        "time": "08:15",
        "maxSeats": 3,
        "currentSeats": 1,
        "minutes": 48,
        "fare": 5000,
        "match": 87,
      },
    ]);
  }

  static void addCarpool({
    required String departure,
    required String destination,
    required String time,
    required int maxSeats,
  }) {
    carpools.add({
      "departure": departure,
      "destination": destination,
      "time": time,
      "maxSeats": maxSeats,
      "currentSeats": 1,
      "minutes": 45,
      "fare": 5000,
      "match": 90,
    });
  }

  static bool joinCarpool(int index) {
    final carpool = carpools[index];

    final maxSeats = carpool["maxSeats"] ?? 4;
    final currentSeats = carpool["currentSeats"] ?? 1;

    if (currentSeats >= maxSeats) {
      return false;
    }

    carpool["currentSeats"] = currentSeats + 1;
    return true;
  }
}