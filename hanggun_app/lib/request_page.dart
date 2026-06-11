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

  int getIntValue(Map<String, dynamic> data, String key, int defaultValue) {
    final value = data[key];

    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;

    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
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
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final r = requests[index] as Map<String, dynamic>;

                    final id = getIntValue(r, 'id', 0);
                    final name = r['rider_name']?.toString() ?? '이름 없음';
                    final phone = r['rider_phone']?.toString() ?? '전화번호 없음';
                    final status = r['status']?.toString() ?? '대기';

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
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}