import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user_profile.dart';
import 'map_page.dart';
import 'dart:async';

class MyRidesPage extends StatefulWidget {
  const MyRidesPage({super.key});

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage> {
  List<dynamic> rides = [];
  bool isLoading = true;
  String myPhone = '';
  Timer? refreshTimer;

  Map<int, Map<String, dynamic>> recommendations = {};
  Set<int> loadingRecommendations = {};

  @override
  void initState() {
    super.initState();

    loadMyRides();
  
    refreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) {
      loadMyRides();
    },
  );
}
  Future<void> loadMyRides() async {
    setState(() {
      isLoading = true;
    });

    try {
      final profile = await UserProfile.getProfile();
      final phone = profile['phone'] ?? '';

      if (phone.isEmpty) {
        if (!mounted) return;

        setState(() {
          myPhone = '';
          rides = [];
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 정보에서 전화번호를 먼저 저장해주세요.')),
        );
        return;
      }

      final data = await ApiService.getMyRides(phone);

      if (!mounted) return;

      setState(() {
        myPhone = phone;
        rides = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내 신청 내역 불러오기 실패: $e')),
      );
    }
  }

  Future<void> loadRecommendation(int carpoolId) async {
    setState(() {
      loadingRecommendations.add(carpoolId);
    });

    try {
      final data = await ApiService.getPickupRecommendation(carpoolId);

      if (!mounted) return;

      setState(() {
        recommendations[carpoolId] = data;
        loadingRecommendations.remove(carpoolId);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingRecommendations.remove(carpoolId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 픽업 추천 실패: $e')),
      );
    }
  }

  int getIntValue(Map<String, dynamic> data, String key, int defaultValue) {
    final value = data[key];

    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;

    return defaultValue;
  }

  String formatCoordinate(dynamic value) {
    if (value == null) return '없음';

    final number = double.tryParse(value.toString());

    if (number == null) return '없음';

    return number.toStringAsFixed(6);
  }
  double? parseDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
  }

  Widget buildRecommendationCard(Map<String, dynamic> rec) {
    final place = rec['recommended_place']?.toString() ?? '추천 장소 없음';
    final address = rec['recommended_address']?.toString() ?? '주소 없음';
    final reason = rec['reason']?.toString() ?? '추천 이유 없음';
    final lat = formatCoordinate(rec['recommended_lat']);
    final lon = formatCoordinate(rec['recommended_lon']);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 추천 픽업 장소',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('장소: $place'),
          Text('주소: $address'),
          Text('위도: $lat'),
          Text('경도: $lon'),
          const SizedBox(height: 6),
          Text('추천 이유: $reason'),
        ],
      ),
    );
  }

  Widget buildRideCard(Map<String, dynamic> ride) {
    final requestId = getIntValue(ride, 'request_id', 0);
    final carpoolId = getIntValue(ride, 'carpool_id', 0);

    final departure = ride['departure']?.toString() ?? '출발지 없음';
    final destination = ride['destination']?.toString() ?? '목적지 없음';
    final time = ride['time']?.toString() ?? '시간 없음';

    final status = ride['status']?.toString() ?? '대기';
    final rideCompleted = getIntValue(ride, 'ride_completed', 0) == 1;

    final pickupLocation = ride['pickup_location']?.toString() ?? '내 승차 위치 없음';
    final pickupLat = formatCoordinate(ride['pickup_lat']);
    final pickupLon = formatCoordinate(ride['pickup_lon']);

    final driverName = ride['driver_name']?.toString() ?? '운전자 정보 없음';
    final driverPhone = ride['driver_phone']?.toString() ?? '전화번호 없음';
    final driverLocation = ride['driver_location']?.toString() ?? '운전자 위치 없음';
    final driverLat = formatCoordinate(ride['driver_lat']);
    final driverLon = formatCoordinate(ride['driver_lon']);

    final minutes = ride['minutes']?.toString() ?? '-';
    final distanceKm = ride['distanceKm']?.toString() ?? '-';
    final fare = ride['fare']?.toString() ?? '-';

    final rec = recommendations[carpoolId];
    final isRecLoading = loadingRecommendations.contains(carpoolId);
    
    final driverLatValue = parseDoubleValue(ride['driver_lat']);
    final driverLonValue = parseDoubleValue(ride['driver_lon']);

    final riderLatValue = parseDoubleValue(ride['pickup_lat']);
    final riderLonValue = parseDoubleValue(ride['pickup_lon']);

    final pickupLatValue =
    rec == null ? null : parseDoubleValue(rec['recommended_lat']);

    final pickupLonValue =
    rec == null ? null : parseDoubleValue(rec['recommended_lon']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$departure → $destination',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('출발 시간: $time'),
            Text('신청 상태: $status'),
            Text('탑승 완료: ${rideCompleted ? "완료" : "미완료"}'),
            Text('예상 이동시간: $minutes분'),
            Text('예상 거리: $distanceKm km'),
            Text('요금: $fare원'),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '내 승차 위치',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('주소: $pickupLocation'),
            Text('위도: $pickupLat'),
            Text('경도: $pickupLon'),
            const SizedBox(height: 12),
            const Text(
              '운전자 정보',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('이름: $driverName'),
            Text('전화번호: $driverPhone'),
            Text('현재 위치: $driverLocation'),
            Text('위도: $driverLat'),
            Text('경도: $driverLon'),
            const SizedBox(height: 12),
            if (status == '승인' && !rideCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRecLoading || carpoolId == 0
                      ? null
                      : () {
                          loadRecommendation(carpoolId);
                        },
                  icon: isRecLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    isRecLoading ? 'AI 픽업 안내 계산 중...' : 'AI 픽업 안내 보기',
                  ),
                ),
              ),
            if (rec != null) buildRecommendationCard(rec),
            if (status == '승인')
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapPage(
              driverLat: driverLatValue,
              driverLon: driverLonValue,
              riderLat: riderLatValue,
              riderLon: riderLonValue,
              pickupLat: pickupLatValue,
              pickupLon: pickupLonValue,
              driverLabel: driverLocation,
              riderLabel: pickupLocation,
              pickupLabel: rec == null
                  ? 'AI 픽업 추천을 먼저 실행해주세요.'
                  : rec['recommended_place']?.toString() ?? 'AI 픽업 위치',
            ),
          ),
        );
      },
      icon: const Icon(Icons.map),
      label: const Text('지도 보기'),
    ),
  ),
            if (status == '대기')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '운전자 승인을 기다리는 중입니다.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            if (status == '거절')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '거절된 신청입니다.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (rideCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '탑승 완료된 카풀입니다.',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? Center(
                  child: Text(
                    myPhone.isEmpty
                        ? '내 정보에서 전화번호를 저장해주세요.'
                        : '신청한 카풀이 없습니다.',
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadMyRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      return buildRideCard(
                        rides[index] as Map<String, dynamic>,
                      );
                    },
                  ),
                ),
    );
  }
  @override
void dispose() {
  refreshTimer?.cancel();
  super.dispose();
}
}