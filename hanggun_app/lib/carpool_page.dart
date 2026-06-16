import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';
import 'create_carpool_page.dart';
import 'request_page.dart';
import 'profile_page.dart';
import 'user_profile.dart';

class CarpoolPage extends StatefulWidget {
  const CarpoolPage({super.key});

  @override
  State<CarpoolPage> createState() => _CarpoolPageState();
}

class _CarpoolPageState extends State<CarpoolPage> {
  List<dynamic> carpools = [];
  bool isLoading = true;
  String myPhone = '';

  @override
  void initState() {
    super.initState();
    loadProfile();
    loadCarpools();
  }

  Future<void> loadProfile() async {
    final profile = await UserProfile.getProfile();

    if (!mounted) return;

    setState(() {
      myPhone = profile['phone'] ?? '';
    });
  }

  Future<void> loadCarpools() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getCarpools();

      if (!mounted) return;

      setState(() {
        carpools = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카풀 목록 불러오기 실패: $e')),
      );
    }
  }

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('위치 서비스가 꺼져 있습니다. 휴대폰 위치 기능을 켜주세요.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('위치 권한이 거부되었습니다.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  int getIntValue(Map<String, dynamic> data, String key, int defaultValue) {
    final value = data[key];

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;

    return defaultValue;
  }

  double getDoubleValue(
    Map<String, dynamic> data,
    String key,
    double defaultValue,
  ) {
    final value = data[key];

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;

    return defaultValue;
  }

  Future<void> showJoinDialog(int carpoolId) async {
    final profile = await UserProfile.getProfile();

    if (!mounted) return;

    final nameController = TextEditingController(
      text: profile['name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: profile['phone'] ?? '',
    );

    bool useCurrentLocation = true;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('탑승 신청'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '예: 홍길동',
                    ),
                  ),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '전화번호',
                      hintText: '예: 01012345678',
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useCurrentLocation,
                    title: const Text('현재 위치를 승차 위치로 보내기'),
                    subtitle: const Text('운전자가 신청자 목록에서 위치를 확인할 수 있습니다.'),
                    onChanged: isSubmitting
                        ? null
                        : (value) {
                            setDialogState(() {
                              useCurrentLocation = value ?? true;
                            });
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();

                          if (name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이름과 전화번호를 입력해주세요.'),
                              ),
                            );
                            return;
                          }

                          double? pickupLat;
                          double? pickupLon;
                          String? pickupLocation;

                          try {
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            if (useCurrentLocation) {
                              final position = await getCurrentPosition();

                              pickupLat = position.latitude;
                              pickupLon = position.longitude;
                              pickupLocation = '현재 위치';
                            }

                            await ApiService.joinCarpool(
                              carpoolId: carpoolId,
                              riderName: name,
                              riderPhone: phone,
                              pickupLocation: pickupLocation,
                              pickupLat: pickupLat,
                              pickupLon: pickupLon,
                            );

                            if (!mounted) return;

                            Navigator.of(dialogContext).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('탑승 신청이 접수되었습니다.'),
                              ),
                            );

                            await loadCarpools();
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              isSubmitting = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('탑승 신청 실패: $e')),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('신청'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 카풀 추천'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(),
                ),
              );

              await loadProfile();
              await loadCarpools();
            },
            icon: const Icon(Icons.person),
          ),
          IconButton(
            onPressed: loadCarpools,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateCarpoolPage(),
            ),
          );

          if (result == true) {
            loadCarpools();
          }
        },
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : carpools.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 카풀이 없습니다.',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: carpools.length,
                  itemBuilder: (context, index) {
                    final c = carpools[index] as Map<String, dynamic>;

                    final id = getIntValue(c, 'id', 0);
                    final departure = c['departure']?.toString() ?? '출발지 미정';
                    final destination =
                        c['destination']?.toString() ?? '목적지 미정';
                    final time = c['time']?.toString() ?? '시간 미정';

                    final maxSeats = getIntValue(c, 'maxSeats', 4);
                    final currentSeats = getIntValue(c, 'currentSeats', 1);
                    final minutes = getIntValue(c, 'minutes', 45);
                    final distanceKm = getDoubleValue(c, 'distanceKm', 0.0);
                    final fare = getIntValue(c, 'fare', 5000);
                    final match = getIntValue(c, 'match', 90);
                    final driverPhone = c['driver_phone']?.toString() ?? '';

                    final leftSeats = maxSeats - currentSeats;
                    final isFull = leftSeats <= 0;
                    final isDriver =
                        myPhone.isNotEmpty && myPhone == driverPhone;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
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
                            const SizedBox(height: 10),
                            Text('출발 시간: $time'),
                            Text('탑승 현황: $currentSeats / $maxSeats명'),
                            Text('남은 자리: ${isFull ? "만석" : "$leftSeats석"}'),
                            Text('예상 이동시간: $minutes분'),
                            Text('예상 거리: $distanceKm km'),
                            Text('예상 요금: $fare원'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'AI 매칭률 $match%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isFull || id == 0
                                    ? null
                                    : () {
                                        showJoinDialog(id);
                                      },
                                child: Text(isFull ? '만석' : '탑승 신청'),
                              ),
                            ),
                            if (isDriver)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: id == 0
                                        ? null
                                        : () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RequestPage(
                                                  carpoolId: id,
                                                ),
                                              ),
                                            );

                                            loadCarpools();
                                          },
                                    child: const Text('신청자 보기'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}