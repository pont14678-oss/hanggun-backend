import 'package:flutter/material.dart';
import 'api_service.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final questionController = TextEditingController();

  String answer = '안녕하세요. 행군 AI 도우미입니다.\n예비군 정보나 카풀 추천을 물어보세요.';
  bool isLoading = false;

  Future<void> askAi() async {
    final q = questionController.text.trim();

    if (q.isEmpty) return;

    setState(() {
      isLoading = true;
      answer = 'AI가 답변을 생성 중입니다...';
    });

    try {
      final result = await ApiService.askAi(q);

      if (!mounted) return;

      setState(() {
        answer = result;
        isLoading = false;
      });

      questionController.clear();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        answer = 'AI 응답 실패: $e';
        isLoading = false;
      });
    }
  }

  void setQuickQuestion(String text) {
    questionController.text = text;
    askAi();
  }

  @override
  void dispose() {
    questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 도우미'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.smart_toy, size: 70),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('준비물 알려줘'),
                  onPressed:
                      isLoading ? null : () => setQuickQuestion('예비군 준비물 알려줘'),
                ),
                ActionChip(
                  label: const Text('빠른 카풀'),
                  onPressed:
                      isLoading ? null : () => setQuickQuestion('가장 빨리 도착하는 카풀 알려줘'),
                ),
                ActionChip(
                  label: const Text('카풀 추천'),
                  onPressed:
                      isLoading ? null : () => setQuickQuestion('카풀 추천해줘'),
                ),
                ActionChip(
                  label: const Text('남은 자리'),
                  onPressed:
                      isLoading ? null : () => setQuickQuestion('남은 자리 있는 차량 알려줘'),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    answer,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: questionController,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: 'AI에게 질문하기',
                border: const OutlineInputBorder(),
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: askAi,
                      ),
              ),
              onSubmitted: (_) {
                if (!isLoading) {
                  askAi();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}