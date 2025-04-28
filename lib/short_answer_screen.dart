import 'package:flutter/material.dart';

// 단답 문제 학습 화면 위젯
class ShortAnswerScreen extends StatelessWidget {
  const ShortAnswerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단답 문제 학습'), // 화면 제목
      ),
      body: const Center(
        child: Text(
          '단답 문제 학습 화면입니다.\n(여기에 내용이 들어갈 예정)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}