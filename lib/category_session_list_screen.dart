// lib/category_session_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'question_screen.dart'; // 문제 풀이 화면 import
import 'models/question.dart'; // Question 모델 import (number 필드 사용)


class CategorySessionListScreen extends StatefulWidget {
  final String categoryName;

  const CategorySessionListScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategorySessionListScreen> createState() => _CategorySessionListScreenState();
}

class _CategorySessionListScreenState extends State<CategorySessionListScreen> {
  bool _isLoading = true;
  // --- ★★★ 데이터 구조 변경 ★★★ ---
  // Map<연도, Map<회차, List<문제번호>>>
  Map<int, Map<int, List<int>>> _groupedData = {};
  // 정렬된 연도 목록
  List<int> _sortedYears = [];
  // ---------------------------------
  @override
  void initState() {
    super.initState();
    _loadSessionDataForCategory();
  }

  Future<void> _loadSessionDataForCategory() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    Map<int, Map<int, List<int>>> tempData = {};
    final List<int> years = List.generate(2024 - 2003 + 1, (index) => 2024 - index);
    final List<int> sessions = [1, 2, 3];

    for (int year in years) {
      List<int> currentYearSessions = List.from(sessions);
      if (year == 2020) { currentYearSessions.add(4); }

      for (int session in currentYearSessions) {
        final String filePath = 'assets/data/${year}_$session.json';
        try {
          final String jsonString = await rootBundle.loadString(filePath);
          final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

          for (final qJson in questionListJson) {
            if (qJson is Map<String, dynamic>) {
              final String? type = qJson['type'] as String?;
              final int? number = qJson['number'] as int?; // 문제 번호 가져오기

              // 카테고리 일치 및 문제 번호 유효성 확인
              if (type == widget.categoryName && number != null) {
                // 연도 키가 없으면 생성
                tempData[year] ??= {};
                // 회차 키가 없으면 생성
                tempData[year]![session] ??= [];
                // 해당 연도-회차 리스트에 문제 번호 추가
                tempData[year]![session]!.add(number);
              }
            }
          }
          // 각 회차별 문제 번호 리스트 정렬
          if (tempData[year] != null && tempData[year]![session] != null) {
            tempData[year]![session]!.sort();
          }

        } catch (e) {
          // 파일 오류는 무시
        }
      }
    }


    // 키 목록을 정렬 (연도 내림차순, 회차 오름차순)
    List<int> sortedYears = tempData.keys.toList()..sort((a, b) => b.compareTo(a));

    if (mounted) {
      setState(() {
        _groupedData = tempData;
        _sortedYears = sortedYears;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("'${widget.categoryName}' 유형 문제 목록"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sortedYears.isEmpty
          ? Center(child: Text("'${widget.categoryName}' 유형의 문제가 포함된 회차가 없습니다."))
          : ListView.builder(
        itemCount: _sortedYears.length,
        itemBuilder: (context, index) {
          final int year = _sortedYears[index];
          final Map<int, List<int>> sessionMap = _groupedData[year] ?? {};
          final List<int> sortedSessions = sessionMap.keys.toList()..sort();

          return ExpansionTile(
            // ★★★ 연도 제목 가운데 정렬 ★★★
            title: Center( // <-- Center 추가
              child: Text(
                '$year 년',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            children: sortedSessions.map((session) {
              final List<int> questionNumbers = sessionMap[session] ?? [];
              // ★★★ 문제 개수 계산 ★★★
              final int count = questionNumbers.length;
              // final String numbersString = questionNumbers.join(', '); // 이 줄 삭제 또는 주석 처리

              return ListTile(
                contentPadding: const EdgeInsets.only(left: 30.0, right: 16.0),
                // ★★★ 회차 및 문제 "개수" 표시 + 가운데 정렬 ★★★
                title: Center( // <-- Center 추가
                  child: Text(
                    // numbersString 대신 count 변수 사용
                    '$session 회차 ($count 문제)',
                    style: const TextStyle(fontSize: 16),
                    // textAlign은 Center 위젯 사용 시 불필요
                  ),
                ),
                // ---------------------------------------------
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () { /* 네비게이션 로직 (기존 유지) */
                  print("선택: $year 년 $session 회차 (${widget.categoryName})");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestionScreen(
                        year: year,
                        sessionNumber: session,
                        categoryFilter: widget.categoryName,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}