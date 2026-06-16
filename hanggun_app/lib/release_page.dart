import 'package:flutter/material.dart';
import 'api_service.dart';

class ReleasePage extends StatefulWidget {
  const ReleasePage({super.key});

  @override
  State<ReleasePage> createState() => _ReleasePageState();
}

class _ReleasePageState extends State<ReleasePage> {
  final centerController = TextEditingController();
  final releaseTimeController = TextEditingController();

  String trainingType = '학생예비군';
  String reserveYear = '학생';
  String weather = '맑음';

  bool isSubmitting = false;
  bool isPredicting = false;

  Map<String, dynamic>? prediction;

  final trainingTypes = const [
    '학생예비군',
    '기본훈련',
    '작계훈련',
    '동미참',
    '동원훈련',
  ];

  final reserveYears = const [
    '학생',
    '1년차',
    '2년차',
    '3년차',
    '4년차',
    '5년차',
    '6년차',
  ];

  final weathers = const [
    '맑음',
    '흐림',
    '비',
    '눈',
  ];

  Future<void> submitReport() async {
    final center = centerController.text.trim();
    final releaseTime = releaseTimeController.text.trim();

    if (center.isEmpty || releaseTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('훈련장과 퇴소시간을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await ApiService.submitReleaseReport(
        trainingCenter: center,
        trainingType: trainingType,
        reserveYear: reserveYear,
        weather: weather,
        releaseTime: releaseTime,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퇴소시간 제보가 저장되었습니다.')),
      );

      releaseTimeController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제보 실패: $e')),
      );
    }

    if (!mounted) return;

    setState(() {
      isSubmitting = false;
    });
  }

  Future<void> getPrediction() async {
    final center = centerController.text.trim();

    if (center.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('훈련장을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      isPredicting = true;
      prediction = null;
    });

    try {
      final data = await ApiService.getReleasePrediction(
        trainingCenter: center,
        trainingType: trainingType,
      );

      if (!mounted) return;

      setState(() {
        prediction = data;
        isPredicting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isPredicting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예측 실패: $e')),
      );
    }
  }

  Widget buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget buildPredictionCard() {
    if (prediction == null) {
      return const SizedBox.shrink();
    }

    final predictedTime =
        prediction!['predicted_release_time']?.toString() ?? '-';
    final dataCount = prediction!['data_count']?.toString() ?? '0';
    final explanation =
        prediction!['explanation']?.toString() ?? '설명 없음';

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'AI 퇴소시간 예측',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '예상 퇴소시간: $predictedTime',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('기반 데이터 수: $dataCount건'),
            const SizedBox(height: 10),
            Text('예측 설명: $explanation'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    centerController.dispose();
    releaseTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.schedule, size: 64),
            const SizedBox(height: 12),
            const Text(
              '퇴소시간 제보 / 예측',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: centerController,
              decoration: const InputDecoration(
                labelText: '훈련장명',
                hintText: '예: 춘천과학화예비군훈련장',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            buildDropdown(
              label: '훈련종류',
              value: trainingType,
              items: trainingTypes,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  trainingType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            buildDropdown(
              label: '연차',
              value: reserveYear,
              items: reserveYears,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  reserveYear = value;
                });
              },
            ),
            const SizedBox(height: 12),
            buildDropdown(
              label: '날씨',
              value: weather,
              items: weathers,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  weather = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: releaseTimeController,
              decoration: const InputDecoration(
                labelText: '퇴소시간',
                hintText: '예: 16:40',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitReport,
                icon: const Icon(Icons.upload),
                label: Text(isSubmitting ? '저장 중...' : '퇴소시간 제보하기'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isPredicting ? null : getPrediction,
                icon: isPredicting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(isPredicting ? '예측 중...' : 'AI 퇴소시간 예측하기'),
              ),
            ),
            const SizedBox(height: 18),
            buildPredictionCard(),
          ],
        ),
      ),
    );
  }
}