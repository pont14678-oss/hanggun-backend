import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user_profile.dart';

class CreateCarpoolPage extends StatefulWidget {
  const CreateCarpoolPage({super.key});

  @override
  State<CreateCarpoolPage> createState() => _CreateCarpoolPageState();
}

class _CreateCarpoolPageState extends State<CreateCarpoolPage> {
  final departureController = TextEditingController();
  final destinationController = TextEditingController();
  final timeController = TextEditingController();
  final seatController = TextEditingController();

  double? departureLat;
  double? departureLon;
  double? destinationLat;
  double? destinationLon;

  bool isLoading = false;

  Future<void> searchPlace({
    required TextEditingController controller,
    required bool isDeparture,
  }) async {
    final keyword = controller.text.trim();

    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색어를 입력해주세요.')),
      );
      return;
    }

    try {
      final results = await ApiService.searchPlace(keyword);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (_) {
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final place = results[index];

              final name = place['name'] ?? '이름 없음';
              final address = place['address'] ?? '주소 없음';
              final lat = double.tryParse(place['lat'].toString());
              final lon = double.tryParse(place['lon'].toString());

              return ListTile(
                title: Text(name),
                subtitle: Text('$address\nlat: $lat, lon: $lon'),
                isThreeLine: true,
                onTap: () {
                  setState(() {
                    controller.text = name;

                    if (isDeparture) {
                      departureLat = lat;
                      departureLon = lon;
                    } else {
                      destinationLat = lat;
                      destinationLon = lon;
                    }
                  });

                  Navigator.pop(context);
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('장소 검색 실패: $e')),
      );
    }
  }

  Future<void> createCarpool() async {
    final departure = departureController.text.trim();
    final destination = destinationController.text.trim();
    final time = timeController.text.trim();
    final seats = int.tryParse(seatController.text.trim());

    final profile = await UserProfile.getProfile();

if (!mounted) return;

final driverName = profile['name'] ?? '';
final driverPhone = profile['phone'] ?? '';

    if (driverName.isEmpty || driverPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 내 정보에서 이름과 전화번호를 저장해주세요.')),
      );
      return;
    }

    if (departure.isEmpty ||
        destination.isEmpty ||
        time.isEmpty ||
        seats == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 올바르게 입력해주세요.')),
      );
      return;
    }

    if (departureLat == null ||
        departureLon == null ||
        destinationLat == null ||
        destinationLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 목적지는 검색 결과에서 선택해주세요.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ApiService.createCarpool(
        departure: departure,
        destination: destination,
        time: time,
        maxSeats: seats,
        departureLat: departureLat,
        departureLon: departureLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        driverName: driverName,
        driverPhone: driverPhone,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버에 카풀 등록 완료')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    departureController.dispose();
    destinationController.dispose();
    timeController.dispose();
    seatController.dispose();
    super.dispose();
  }

  Widget placeInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDeparture,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              searchPlace(
                controller: controller,
                isDeparture: isDeparture,
              );
            },
            child: const Text('검색'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDepartureCoord = departureLat != null && departureLon != null;
    final hasDestinationCoord = destinationLat != null && destinationLon != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('카풀 생성'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.directions_car, size: 70),
            const SizedBox(height: 20),

            placeInput(
              label: '출발지',
              hint: '예: 수원역',
              controller: departureController,
              isDeparture: true,
            ),

            if (hasDepartureCoord)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '출발지 좌표 저장됨: $departureLat, $departureLon',
                  style: const TextStyle(fontSize: 12),
                ),
              ),

            const SizedBox(height: 14),

            placeInput(
              label: '목적지',
              hint: '예: 강릉역',
              controller: destinationController,
              isDeparture: false,
            ),

            if (hasDestinationCoord)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '목적지 좌표 저장됨: $destinationLat, $destinationLon',
                  style: const TextStyle(fontSize: 12),
                ),
              ),

            const SizedBox(height: 14),

            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: '출발 시간',
                hintText: '예: 08:00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: seatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '최대 탑승 인원',
                hintText: '예: 4',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : createCarpool,
                child: Text(isLoading ? '등록 중...' : '카풀 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}