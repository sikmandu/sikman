// Flutter 및 기본 화면 위젯 가져오기
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // provider 패키지 import
import 'notifiers/recent_study_notifier.dart'; // 방금 만든 Notifier import
// 각 화면 파일들 가져오기
import 'past_exam_screen.dart';
import 'category_screen.dart';
import 'short_answer_screen.dart';
import 'incorrect_note_screen.dart';
import 'mock_exam_screen.dart';

// 앱 시작점
void main() {
  runApp(
    MultiProvider( // 여러 Provider를 사용한다면 MultiProvider
      providers: [
        ChangeNotifierProvider(create: (_) => RecentStudyNotifier()),
        // 다른 Provider들...
      ],
      child: const MyApp(),
    ),
  );
}

// 앱 최상위 위젯
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '전기기사 실기 학습',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 시작 화면 지정
      home: const MainMenuScreen(),
    );
  }
}

// 메인 메뉴 화면 위젯
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  // 버튼 클릭 시 화면 이동 로직을 함수로 분리 (코드 중복 감소)
  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전기기사 실기 학습'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 과년도 문제 학습 버튼
            ElevatedButton(
              onPressed: () {
                print('과년도 문제 학습 버튼 클릭됨');
                _navigateToScreen(context, const PastExamScreen()); // 함수 호출
              },
              child: const Text('과년도 문제 학습'),
            ),
            const SizedBox(height: 16.0),
            // 유형별 문제 학습 버튼
            ElevatedButton(
              onPressed: () {
                print('유형별 문제 학습 버튼 클릭됨');
                _navigateToScreen(context, const CategoryScreen()); // 함수 호출
              },
              child: const Text('유형별 문제 학습'),
            ),
            const SizedBox(height: 16.0),
            // 단답 문제 학습 버튼
            ElevatedButton(
              onPressed: () {
                print('단답 문제 학습 버튼 클릭됨');
                _navigateToScreen(context, const ShortAnswerScreen()); // 함수 호출
              },
              child: const Text('단답 문제 학습'),
            ),
            const SizedBox(height: 16.0),
            // 오답 노트 학습 버튼
            ElevatedButton(
              onPressed: () {
                print('오답 노트 학습 버튼 클릭됨');
                _navigateToScreen(context, const IncorrectNoteScreen()); // 함수 호출
              },
              child: const Text('오답 노트 학습'),
            ),
            const SizedBox(height: 16.0),
            // 모의고사 시작 버튼
            ElevatedButton(
              onPressed: () {
                print('모의고사 시작 버튼 클릭됨');
                _navigateToScreen(context, const MockExamScreen()); // 함수 호출
              },
              child: const Text('모의고사 시작'),
            ),
          ],
        ),
      ),
    );
  }
}