import 'dart:convert'; // jsonDecode 사용
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // rootBundle 사용
import 'category_question_screen.dart';
import 'models/question.dart';
import 'category_session_list_screen.dart';
// 유형별 문제 학습 화면 위젯 (새 카테고리 추가 및 정렬)
class CategoryScreen extends StatefulWidget { // StatelessWidget -> StatefulWidget
  const CategoryScreen({super.key});

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
  // ------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadCategoryCounts();

    // --- ★★★ 검색 컨트롤러 리스너 추가 ★★★ ---
    _searchController.addListener(() {
      // 검색어가 변경될 때마다 필터링 함수 호출
      _filterCategories(_searchController.text);
    });
    // --------------------------------------// 위젯 초기화 시 문제 수 계산 시작
  }
  @override
  void dispose() {
    _searchController.dispose(); // 컨트롤러 리소스 해제
    super.dispose();
  }

  Future<void> _loadCategoryCounts() async {
    if (!mounted) return;

    Map<String, int> counts = {};
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
              // type 필드만 빠르게 읽어오기 (Question 객체 전체 생성 불필요)
              final String? type = qJson['type'] as String?;
              if (type != null && type.isNotEmpty) {
                counts[type] = (counts[type] ?? 0) + 1;
              }
            }
          }
        } catch (e) {
          // 파일 로드/파싱 오류는 무시하거나 로그 출력
          print("카테고리 수 계산 중 오류 ($filePath): $e");
        }
      }
    }

    // categories 리스트를 가나다 순으로 정렬 (표시 순서 결정)
    // 실제 데이터에 존재하는 카테고리만 포함하도록 필터링할 수도 있음
    final List<String> sorted = List.from(categories)..sort();

    if (mounted) {
      setState(() {
        _categoryCounts = counts;
        _sortedCategories = sorted;
        _filteredCategories = sorted; // ★★★ 초기 필터 목록은 전체 목록 ★★★
        _isLoading = false;
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

    setState(() {
      _searchQuery = query; // 현재 검색어 상태 업데이트
      _filteredCategories = filtered; // 필터링된 목록 업데이트
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('유형별 문제 학습'),
      ),
      // --- ★★★ body 구조 변경 (Column > 검색창 + Expanded(GridView)) ★★★ ---
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
    Expanded( // 검색창 아래 남은 공간을 차지
    child: _isLoading
    ? const Center(child: CircularProgressIndicator())
        : _filteredCategories.isEmpty // ★★★ 필터링된 목록 기준 ★★★
    ? Center(child: Text(_searchQuery.isEmpty ? '표시할 카테고리가 없습니다.' : '검색 결과가 없습니다.'))
        : GridView.builder(
    padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0), // 검색창 아래부터 패딩
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 180,
    childAspectRatio: 1 / 1.1,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    ),
    // ★★★ 필터링된 목록 사용 ★★★
    itemCount: _filteredCategories.length,
    itemBuilder: (BuildContext context, int index) {
    final String categoryName = _filteredCategories[index];
    final int count = _categoryCounts[categoryName] ?? 0;
          // --- ★★★ 카드 디자인 적용 ★★★ ---
          return Card(
            elevation: 2.0, // 약간의 그림자
            shape: RoundedRectangleBorder( // 부드러운 모서리
              borderRadius: BorderRadius.circular(8.0),
            ),
            clipBehavior: Clip.antiAlias, // InkWell 효과가 Card 영역을 벗어나지 않도록
            child: InkWell( // 탭 효과 및 onTap 콜백
              onTap: () {
                print('카테고리 선택됨: $categoryName');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ★★★ CategorySessionListScreen으로 이동 ★★★
                    builder: (context) => CategorySessionListScreen(
                      categoryName: categoryName,
                    ),
                  ),
                );
              },
              child: Padding( // 카드 내부 여백
                padding: const EdgeInsets.all(8.0),
                child: Column( // 내용을 세로로 배치
                  mainAxisAlignment: MainAxisAlignment.center, // 수직 가운데 정렬
                  crossAxisAlignment: CrossAxisAlignment.center, // 수평 가운데 정렬
                  children: [
                    // 카테고리 이름 (최대 2줄, 넘으면 ... 표시)
                    Text(
                      categoryName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600), // 약간 굵게
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6), // 이름과 카운트 사이 간격
                    // 문제 수 (작고 연한 글씨)
                    Text(
                      '($count 문제)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54), // 색상 조절
                      textAlign: TextAlign.center,
                    ),
                  ],),),),);
    },
    ),
    ),
            // -----------------------
          ],
      ),
      // -------------------------------------------------------------
    );
  }
}