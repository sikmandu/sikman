// lib/category_session_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'question_screen.dart';
// import 'models/question.dart'; // 직접 사용하지 않으므로 주석 처리 또는 삭제 가능
import 'services/recent_study_service.dart'; // RecentStudyService import

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
// ★★★ 해당 카테고리의 최근 학습 정보를 저장할 변수 ★★★
  final RecentStudyService _recentStudyService = RecentStudyService();
  Map<String, dynamic>? _recentCategoryExamData;


  @override
  void initState() {
    super.initState();
    _loadAllData(); // 세션 데이터와 최근 학습 정보 동시 로드
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    Map<int, Map<int, List<int>>> tempData = {};
    final List<int> years = List.generate(2024 - 2003 + 1, (index) => 2024 - index);
    final List<int> sessions = [1, 2, 3, 4]; // 2020년 4회차 포함 가정

    for (int year in years) {
      List<int> currentYearSessions = (year == 2020) ? [1,2,3,4] : [1,2,3];
      for (int session in currentYearSessions) {
        final String filePath = 'assets/data/${year}_$session.json';
        try {
          final String jsonString = await rootBundle.loadString(filePath);
          final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

          for (final qJson in questionListJson) {
            if (qJson is Map<String, dynamic>) {
              final String? type = qJson['type'] as String?;
              final int? number = qJson['number'] as int?;
              if (type == widget.categoryName && number != null) {
                tempData[year] ??= {};
                tempData[year]![session] ??= [];
                tempData[year]![session]!.add(number);
              }
            }
          }
          if (tempData[year] != null && tempData[year]![session] != null) {
            tempData[year]![session]!.sort();
          }
        } catch (e) {
          // 파일 오류는 무시
        }
      }
    }
    List<int> sortedYears = tempData.keys.toList()..sort((a, b) => b.compareTo(a));

    // ★★★ 해당 카테고리의 최근 학습 정보 로드 ★★★
    final recentData = await _recentStudyService.loadRecentCategoryExam(widget.categoryName);

    if (mounted) {
      setState(() {
        _groupedData = tempData;
        _sortedYears = sortedYears;
        _recentCategoryExamData = recentData; // 로드된 정보 저장
        _isLoading = false;
      });
    }
  }

  void _navigateToQuestionFromRecent(BuildContext context, int year, int session, int questionNumber) {
    print('CategorySessionListScreen: 최근 학습 이동 - ${widget.categoryName} - $year년 $session회 $questionNumber번');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionScreen(
          year: year,
          sessionNumber: session,
          categoryFilter: widget.categoryName,
          initialQuestionNumber: questionNumber, // 실제 문제 번호 전달
          initialIndex: 0, // fallback
        ),
      ),
    ).then((_){
      print("CategorySessionListScreen: QuestionScreen에서 돌아옴. 최근 학습 정보 다시 로드.");
      _loadAllData(); // ★ 함수 이름 일치 확인
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("'${widget.categoryName}' 유형 문제 목록"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column( // ★★★ Column으로 감싸서 최근 학습 정보 표시 공간 마련 ★★★
        children: [
          // ★★★ 해당 카테고리의 최근 학습 정보 표시 및 클릭 로직 ★★★
          if (_recentCategoryExamData != null &&
              _recentCategoryExamData!['year'] != null &&
              _recentCategoryExamData!['session'] != null &&
              _recentCategoryExamData!['q_num'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Card(
                elevation: 2,
                color: Colors.green.shade50, // 다른 색상으로 구분
                child: ListTile(
                  leading: Icon(Icons.label_important_outline, color: Colors.green.shade700, size: 28),
                  title: Text(
                    '최근 학습 (${widget.categoryName}): ${_recentCategoryExamData!['year']}년 ${_recentCategoryExamData!['session']}회차 ${_recentCategoryExamData!['q_num']}번',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    final year = _recentCategoryExamData!['year'] as int?;
                    final session = _recentCategoryExamData!['session'] as int?;
                    final qNum = _recentCategoryExamData!['q_num'] as int?;
                    if (year != null && session != null && qNum != null) {
                      _navigateToQuestionFromRecent(context, year, session, qNum);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: _sortedYears.isEmpty
                ? Center(child: Text("'${widget.categoryName}' 유형의 문제가 포함된 회차가 없습니다."))
                : ListView.builder(
              padding: _recentCategoryExamData == null ? const EdgeInsets.only(top:8.0) : EdgeInsets.zero,
              itemCount: _sortedYears.length,
              itemBuilder: (context, index) {
                final int year = _sortedYears[index];
                final Map<int, List<int>> sessionMap = _groupedData[year] ?? {};
                final List<int> sortedSessions = sessionMap.keys.toList()..sort();

                return ExpansionTile(
                  key: PageStorageKey<String>('$year-${widget.categoryName}'), // 고유 키
                  title: Center(
                    child: Text('$year 년', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  children: sortedSessions.map((session) {
                    final List<int> questionNumbers = sessionMap[session] ?? [];
                    final int count = questionNumbers.length;

                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 30.0, right: 16.0),
                      title: Center(
                        child: Text('$session 회차 ($count 문제)', style: const TextStyle(fontSize: 16)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        print("세션 선택: $year 년 $session 회차 (${widget.categoryName})");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestionScreen(
                              year: year,
                              sessionNumber: session,
                              categoryFilter: widget.categoryName,
                              initialIndex: 0, // 세션 선택 시 항상 첫 문제부터
                            ),
                          ),
                        ).then((_){
                          print("CategorySessionListScreen: QuestionScreen에서 돌아옴 (세션 선택), 최근 학습 정보 다시 로드");
                          _loadAllData(); // 문제 풀고 돌아오면 최근 학습 정보 갱신
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}