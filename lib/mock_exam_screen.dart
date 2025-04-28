import 'package:flutter/material.dart';
// import 'question_screen.dart'; // 나중에 필요
// import 'dart:math';

// 모의고사 시작 화면 위젯 (StatefulWidget으로 변경)
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  // --- 상태 변수 ---
  int? _selectedYear; // 사용자가 선택한 연도를 저장 (초기값 null)

  // 선택 가능한 연도 목록 생성 (2024 ~ 2003)
  final List<int> _availableYears = List.generate(
      2024 - 2003 + 1, (index) => 2024 - index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모의고사 설정'), // 제목 변경
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 안내 문구
              const Text(
                '모의고사를 진행할 연도를 선택하세요.\n\n선택한 연도의 문제들을 바탕으로\n(나중에 설정할 비율에 따라)\n18문제가 출제됩니다.',
                style: TextStyle(fontSize: 17, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),

              // --- 연도 선택 드롭다운 버튼 ---
              DropdownButtonFormField<int>(
                value: _selectedYear, // 현재 선택된 값 표시
                hint: const Text('연도 선택'), // 아무것도 선택 안했을 때 안내 문구
                // 드롭다운 메뉴 스타일링 (선택 사항)
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                // 선택 가능한 연도 목록 설정
                items: _availableYears.map((int year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text('$year 년'),
                  );
                }).toList(),
                // 사용자가 새 연도를 선택했을 때 호출될 함수
                onChanged: (int? newValue) {
                  // setState를 호출하여 화면을 갱신하고 _selectedYear 값을 변경
                  setState(() {
                    _selectedYear = newValue;
                  });
                },
              ),
              // -----------------------------

              const SizedBox(height: 40.0),

              // 모의고사 시작 버튼
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: const TextStyle(fontSize: 20),
                  // 연도가 선택되지 않으면 버튼 비활성화 (색 흐리게)
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                // _selectedYear가 null (선택 안됨) 이면 onPressed에 null을 전달하여 비활성화
                onPressed: _selectedYear == null ? null : () {
                  // 연도가 선택되었을 때만 동작
                  print('$_selectedYear 년 모의고사 시작 버튼 클릭됨 (실제 시작 로직 준비중)');
                  // TODO: 다음 단계 - 선택된 연도 정보와 함께 QuestionScreen으로 이동
                  // 비율 설정 등 추가 UI가 필요할 수 있음
                  // 실제 문제 필터링 및 랜덤 추출 로직 구현 필요
                },
                child: const Text('모의고사 시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}