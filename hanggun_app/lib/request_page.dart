import 'package:flutter/material.dart';
import 'api_service.dart';

class RequestPage extends StatefulWidget {
  final int carpoolId;

  const RequestPage({
    super.key,
    required this.carpoolId,
  });

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  List<dynamic> requests = [];
  bool isLoading = true;

  Map<String, dynamic>? pickupRecommendation;
  bool isRecommending = false;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getRideRequests(widget.carpoolId);

      if (!mounted) return;

      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청자 목록 불러오기 실패: $e')),
      );
    }
  }

  Future<void> loadPickupRecommendation() async {
    setState(() {
      isRecommending = true;
    });

    try {
      final data = await ApiService.getPickupRecommendation(widget.carpoolId);

      if (!mounted) return;

      setState(() {
        pickupRecommendation = data;
        isRecommending = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isRecommending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 픽업 추천 실패: $e')),
      );
    }
  }

  Future<void> handleApprove(int requestId) async {
    try {
      await ApiService.approveRequest(requestId);

      if (!mounted) return;

      await loadRequests();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('승인 완료')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('승인 실패: $e')),
      );
    }
  }

  Future<void> handleReject(int requestId) async {
    try {
      await ApiService.rejectRequest(requestId);

      if (!mounted) return;

      await loadRequests();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거절 완료')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거절 실패: $e')),
      );
    }
  }

  Future<void> handleComplete(int requestId) async {
    try {
      await ApiService.completeRequest(requestId);

      if (!mounted) return;

      await loadRequests();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탑승 완료 처리됨')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탑승 완료 실패: $e')),
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

  Widget buildRecommendationCard() {
    if (pickupRecommendation == null) {
      return const SizedBox.shrink();
    }

    final place =
        pickupRecommendation!['recommended_place']?.toString() ?? '추천 장소 없음';
    final address =
        pickupRecommendation!['recommended_address']?.toString() ?? '주소 없음';
    final reason =
        pickupRecommendation!['reason']?.toString() ?? '추천 이유 없음';
    final lat = formatCoordinate(pickupRecommendation!['recommended_lat']);
    final lon = formatCoordinate(pickupRecommendation!['recommended_lon']);
    final count = pickupRecommendation!['participants_count']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'AI 픽업 장소 추천',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              place,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('주소: $address'),
            Text('위도: $lat'),
            Text('경도: $lon'),
            Text('계산 인원: $count명'),
            const SizedBox(height: 8),
            Text('추천 이유: $reason'),
          ],
        ),
      ),
    );
  }

  Widget buildRequestCard(Map<String, dynamic> r) {
    final id = getIntValue(r, 'id', 0);
    final name = r['rider_name']?.toString() ?? '이름 없음';
    final phone = r['rider_phone']?.toString() ?? '전화번호 없음';
    final status = r['status']?.toString() ?? '대기';

    final pickupLocation =
        r['pickup_location']?.toString() ?? '위치 정보 없음';
    final pickupLat = formatCoordinate(r['pickup_lat']);
    final pickupLon = formatCoordinate(r['pickup_lon']);

    final driverLocation =
        r['driver_location']?.toString() ?? '운전자 위치 정보 없음';
    final driverLat = formatCoordinate(r['driver_lat']);
    final driverLon = formatCoordinate(r['driver_lon']);

    final rideCompleted = getIntValue(r, 'ride_completed', 0) == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('전화번호: $phone'),
            Text('상태: $status'),
            Text('탑승 완료: ${rideCompleted ? "완료" : "미완료"}'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '신청자 승차 위치',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('주소: $pickupLocation'),
            Text('위도: $pickupLat'),
            Text('경도: $pickupLon'),
            const SizedBox(height: 12),
            const Text(
              '운전자 현재 위치',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('주소: $driverLocation'),
            Text('위도: $driverLat'),
            Text('경도: $driverLon'),
            const SizedBox(height: 12),
            if (status == '대기')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: id == 0
                          ? null
                          : () {
                              handleApprove(id);
                            },
                      child: const Text('승인'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: id == 0
                          ? null
                          : () {
                              handleReject(id);
                            },
                      child: const Text('거절'),
                    ),
                  ),
                ],
              ),
            if (status == '승인' && !rideCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: id == 0
                      ? null
                      : () {
                          handleComplete(id);
                        },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('탑승 완료 처리'),
                ),
              ),
            if (rideCompleted)
              const Text(
                '탑승 완료된 신청입니다.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isRecommending ? null : loadPickupRecommendation,
          icon: isRecommending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(isRecommending ? 'AI 추천 계산 중...' : 'AI 픽업 장소 추천'),
        ),
      ),
      const SizedBox(height: 12),
      buildRecommendationCard(),
      ...requests.map(
        (request) => buildRequestCard(request as Map<String, dynamic>),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('탑승 신청자 목록'),
        actions: [
          IconButton(
            onPressed: loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(
                  child: Text(
                    '아직 신청자가 없습니다.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: content,
                ),
    );
  }
}