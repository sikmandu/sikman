import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'category_session_list_screen.dart';
import 'services/recent_study_service.dart';
import 'question_screen.dart'; // ★★★ 이 import 문이 정확히 있는지 확인하세요 ★★★
// import 'notifiers/recent_study_notifier.dart'; // Provider를 사용한다면 이것도 필요합니다.
// import 'package:provider/provider.dart'; // Provider를 사용한다면 이것도 필요합니다.


class CategoryScreen extends StatefulWidget { // StatelessWidget -> StatefulWidget
  const CategoryScreen({super.key});

  // 키 정의 가져오기


  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}
class _CategoryScreenState extends State<CategoryScreen> {
  // 사용자가 제공한 카테고리 목록 + 새로 추가된 카테고리
  // (가나다 순 또는 논리적 순서로 정렬하면 더 보기 좋을 수 있습니다.)
  final List<String> categories = const [
    '감리 관련 문제', // 기존 + 신규 목록 (순서는 임의)
    '논리 회로',
    '년도별 킬러 문제',
    '단락 사고',
    '단답', // 필요시 추가/제외
    '리액터 용량', // <--- 신규
    '부하 설비',
    '불평형률',
    '변류기',     // <--- 신규
    '수변전 설비',
    '시퀀스 제어',
    '역률 개선',
    '전동기',
    '전력 손실',
    '전선 굵기',
    '정전 용량',   // <--- 신규
    '조명 설비',
    '차단 용량',
    '축전지 용량',
    '기타',       // <--- 신규
  ];
// --- ★★★ 상태 변수 추가 ★★★ ---
  bool _isLoading = true;
  Map<String, int> _categoryCounts = {}; // 카테고리 이름: 문제 수
  List<String> _sortedCategories = []; // 정렬된 카테고리 목록
  // --------------------------------
  // --- ★★★ 검색/필터 관련 상태 변수 추가 ★★★ ---
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredCategories = []; // 화면에 표시될 필터링된 목록
  String _searchQuery = ''; // 현재 검색어

  // ★★★ 유형별 최근 학습 정보를 저장할 Map ★★★
  final RecentStudyService _recentStudyService = RecentStudyService();
  Map<String, Map<String, dynamic>?> _recentCategoryData = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryCountsAndRecentStudies(); // 카운트와 최근 학습 정보 동시 로드
    _searchController.addListener(() {
      _filterCategories(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _loadCategoryCountsAndRecentStudies() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    Map<String, int> counts = {};
    // ... (기존 _loadCategoryCounts 로직은 거의 동일하게 유지) ...
    // 단, 루프 안에서 각 카테고리 발견 시 _loadRecentDataForCategory 호출
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
              if (type != null && type.isNotEmpty) {
                counts[type] = (counts[type] ?? 0) + 1;
              }
            }
          }
        } catch (e) {
          print("카테고리 수 계산 중 오류 ($filePath): $e");
        }
      }
    }


    final List<String> sorted = List.from(categories)..sort();
    _sortedCategories = sorted; // 전체 카테고리 목록 우선 설정
    _filteredCategories = sorted; // 초기 필터 목록

    Map<String, Map<String, dynamic>?> tempRecentData = {};
    for (String categoryName in _sortedCategories) {
      tempRecentData[categoryName] = await _recentStudyService.loadRecentCategoryExam(categoryName);
    }

    if (mounted) {
      setState(() {
        _categoryCounts = counts;
        _recentCategoryData = tempRecentData; // 로드된 최근 학습 정보 저장
        _isLoading = false;
      });
    }
  }
  Future<void> _refreshRecentStudyForCategory(String categoryName) async {
    final data = await _recentStudyService.loadRecentCategoryExam(categoryName);
    if(mounted){
      setState(() {
        _recentCategoryData[categoryName] = data;
      });
    }
  }

  void _filterCategories(String query) {
    final lowerQuery = query.toLowerCase();
    // 원본 정렬 목록(_sortedCategories)을 기준으로 필터링
    final filtered = _sortedCategories.where((category) {
      final lowerCategory = category.toLowerCase();
      // 카테고리 이름에 검색어가 포함되어 있는지 확인
      return lowerCategory.contains(lowerQuery);
    }).toList();

    if(mounted){
      setState(() {
        _searchQuery = query;
        _filteredCategories = filtered;
      });
    }
  }
  void _navigateToCategoryQuestionScreen(BuildContext context, String category, int year, int session, int questionNumber) {
    // questionNumber는 1부터 시작하는 실제 문제 번호
    // QuestionScreen은 initialQuestionNumber를 받도록 수정되었어야 함
    print('CategoryScreen: 유형별 최근 학습 이동 시도: $category - $year년 $session회 $questionNumber번');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionScreen( // ★ QuestionScreen import 필요
          year: year,
          sessionNumber: session,
          categoryFilter: category,
          initialQuestionNumber: questionNumber, // 실제 문제 번호 전달
          initialIndex: 0, // fallback, initialQuestionNumber가 우선
        ),
      ),
    ).then((_){
      print("CategoryScreen: QuestionScreen에서 돌아옴 (유형별 최근 학습 클릭). 카테고리 '$category' 최근 학습 정보 다시 로드.");
      _refreshRecentStudyForCategory(category); // UI 갱신
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('유형별 문제 학습'),
      ),
      // -----------------------------
      body: Column(
          children: [
      // --- 검색창 ---
      Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
            hintText: '카테고리 검색...',
            prefixIcon: const Icon(Icons.search),
            // 검색어 지우기 버튼 (선택 사항)
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear(); // 컨트롤러 내용 지우기 (리스너가 필터링 함수 호출)
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12.0) // 내부 패딩 조절
        ),
        // onChanged: _filterCategories, // 리스너를 사용하므로 여기서 호출 안해도 됨
      ),
    ),
    // -------------
    // --- 로딩 및 결과 표시 영역 ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCategories.isEmpty
                  ? Center(child: Text(_searchQuery.isEmpty ? '표시할 카테고리가 없습니다.' : '검색 결과가 없습니다.'))
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180, // 너비에 따라 조절
                  childAspectRatio: 0.85, // 높이 조절 (기존 1/1.1 보다 약간 길게)
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _filteredCategories.length,
                itemBuilder: (BuildContext context, int index) {
                  final String categoryName = _filteredCategories[index];
                  final int count = _categoryCounts[categoryName] ?? 0;
                  // ★★★ 해당 카테고리의 최근 학습 정보 가져오기 ★★★
                  final Map<String, dynamic>? recentData = _recentCategoryData[categoryName];
          // --- ★★★ 카드 디자인 적용 ★★★ ---
                  return Card(
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        print('카테고리 선택됨: $categoryName');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategorySessionListScreen( // 세션 목록 화면으로 이동
                              categoryName: categoryName,
                            ),
                          ),
                        ).then((_){
                          // CategorySessionListScreen 또는 그 안의 QuestionScreen에서 돌아왔을 때
                          print("CategoryScreen: CategorySessionListScreen에서 돌아옴, 카테고리 '$categoryName' 최근 학습 정보 다시 로드");
                          _refreshRecentStudyForCategory(categoryName);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0), // 내부 패딩 조정
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              categoryName,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '($count 문제)',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                            // ★★★ 최근 학습 정보 표시 및 클릭 로직 (Card 내부) ★★★
                            if (recentData != null &&
                                recentData['year'] != null &&
                                recentData['session'] != null &&
                                recentData['q_num'] != null)
                              Expanded( // 남은 공간을 채우도록 Expanded 추가
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end, // 아래쪽에 배치
                                  children: [
                                    const Divider(height: 12, thickness: 0.5),
                                    InkWell( // 최근 학습 텍스트도 클릭 가능하게
                                      onTap: () {
                                        final year = recentData['year'] as int?;
                                        final session = recentData['session'] as int?;
                                        final qNum = recentData['q_num'] as int?;
                                        if (year != null && session != null && qNum != null) {
                                          _navigateToCategoryQuestionScreen(context, categoryName, year, session, qNum);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '최근: ${recentData['year']}년 ${recentData['session']}회 ${recentData['q_num']}번',
                                          style: TextStyle(fontSize: 11, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
      ),
    );
  }
}