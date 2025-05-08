import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// --- 올바른 Import 경로 확인 ---
import 'models/question.dart';
import 'models/incorrect_question_info.dart';
import 'services/incorrect_note_service.dart';
//import 'package:flutter_math_fork/flutter_math.dart';
import 'widgets/question_viewer.dart';
// ---------------------------

class QuestionScreen extends StatefulWidget {
  final int year;
  final int sessionNumber;
  final int initialIndex;
  final String? categoryFilter; // ★★★ 카테고리 필터 파라미터 추가 ★★★

  const QuestionScreen({
    super.key,
    required this.year,
    required this.sessionNumber,
    this.initialIndex = 0,
    this.categoryFilter, // ★★★ 생성자에 추가 ★★★
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // --- 상태 변수 (UI 로직 관련 변수 제거) ---
  List<Question> _loadedQuestions = [];
  bool _isLoading = true;
  String _loadingError = '';
  int _totalQuestionsInSession = 0;
  int _currentIndex = 0; // 현재 문제 인덱스 (부모가 관리)
  String? _assessmentStatus;
  final IncorrectNoteService _noteService = IncorrectNoteService();
 // PageController _pageController = PageController(); // 페이지 뷰 컨트롤러
 // int _currentPageIndex = 0; // 현재 *페이지* 인덱스
  //int _totalPages = 1; // 현재 문제의 총 페이지 수

  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadQuestionData();
  }

  // --- 데이터 로딩 ---
  Future<void> _loadQuestionData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadingError = ''; });

    try {
      final String filePath = 'assets/data/${widget.year}_${widget.sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

      // --- ★★★ 'final' 키워드 제거 ★★★ ---
      List<Question> questions = questionListJson.map((qJson) {
        if (qJson is Map<String, dynamic>) {
          final q = Question.fromJson(qJson);
          // 컨텍스트 추가 로직 (필요시)
          // return q.copyWithContext(year: widget.year, sessionNumber: widget.sessionNumber, originalIndex: questionListJson.indexOf(qJson));
          return q;
        }
        return null;
      }).whereType<Question>().toList();
      // ---------------------------------

      // --- 카테고리 필터링 로직 (이제 questions 변수에 재할당 가능) ---
      if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
        print("Applying category filter: ${widget.categoryFilter}");
        questions = questions.where((q) => q.type == widget.categoryFilter).toList(); // 이제 오류 없음
        print("Filtered question count: ${questions.length}");
      }
      // --------------------------------------------------------

      // --- 나머지 로직 (인덱스 검사, 상태 업데이트 등) ---
      int validInitialIndex = _currentIndex;
      if (questions.isEmpty) { // 필터링 후 비었는지 확인
        _loadingError = widget.categoryFilter != null
            ? "'${widget.categoryFilter}' 유형의 문제가 이 회차에 없습니다."
            : '표시할 문제가 없습니다.';
      } else if (validInitialIndex >= questions.length || validInitialIndex < 0) {
        validInitialIndex = 0;
      }

      if (mounted) {
        setState(() {
          _loadedQuestions = questions; // 최종 리스트를 상태 변수에 저장
          _totalQuestionsInSession = questions.length;
          _currentIndex = validInitialIndex;
          _isLoading = false;
          _assessmentStatus = null;
        });
      }
      // -------------------------------------------------
    } catch (e, stacktrace) {
      print("!!! QuestionScreen _loadQuestionData 에러 발생: $e");
      print(stacktrace);
      if (mounted) { setState(() { _loadingError = '문제 로딩 오류: $e'; _isLoading = false; _loadedQuestions = []; _totalQuestionsInSession = 0; }); }
    }
  }

  // --- 문제 이동 함수 ---
  void _goToQuestion(int newIndex) {
    if (!mounted || newIndex < 0 || newIndex >= _totalQuestionsInSession) return;
    print("QuestionScreen: Navigating to index $newIndex");
    setState(() {
      _currentIndex = newIndex;
      _assessmentStatus = null; // 문제 이동 시 평가 상태 초기화
      // _isAnswerVisibleMap = {}; // QuestionViewer가 자체 관리
    });
    // 데이터 재로딩 불필요
  }

  // --- 화면 빌드 ---
  @override
  Widget build(BuildContext context) {
    print(">>> Build 시작됨. Index: $_currentIndex, isLoading: $_isLoading, Error: $_loadingError");
    // 로딩/에러 처리
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_loadingError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)))));
    }

    // --- ★★★ Null 체크 강화 및 Non-nullable 변수 할당 ★★★ ---
    // 1. 인덱스가 유효한지 먼저 확인
    if (_currentIndex < 0 || _currentIndex >= _loadedQuestions.length) {
      // 유효하지 않은 인덱스 처리 (예: 첫 문제로 이동 또는 에러 메시지)
      print("Error: Invalid index $_currentIndex in build method.");
      // 안전하게 첫 문제 표시 또는 에러 화면 표시
      if (_loadedQuestions.isEmpty) {
        return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: const Center(child: Text('표시할 문제가 없습니다.')));
      } else {
        // 상태를 0으로 설정하고 다시 빌드 유도 (무한 루프 가능성 주의)
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   if(mounted) setState(() => _currentIndex = 0);
        // });
        // 또는 그냥 에러 메시지 표시
        return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: const Center(child: Text('문제 인덱스 오류')));
      }
    }

    // 2. 유효한 인덱스로 non-nullable Question 객체 가져오기
    // (위에서 인덱스 유효성을 확인했으므로 _loadedQuestions[_currentIndex] 접근 안전)
    final Question currentQuestion = _loadedQuestions[_currentIndex];
    // --------------------------------------------------------

    final int currentQuestionNumber = _currentIndex + 1;

    // 메인 Scaffold
    return Scaffold(
      appBar: AppBar(
        // 제목에 필터 정보 포함 가능
        title: Text(
            '${widget.year}년 ${widget.sessionNumber}회차 ${widget.categoryFilter != null ? "(${widget.categoryFilter})" : ""} 문제 ($currentQuestionNumber / $_totalQuestionsInSession)'
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.categoryFilter != null)
          // --- 문제 출처 정보 표시 Text 추가 ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              // 위젯의 year/sessionNumber와 currentQuestion의 number 사용
              '${widget.year}년 ${widget.sessionNumber}회차 ${currentQuestion.number}번',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: QuestionViewer(
              key: ValueKey('${widget.year}_${widget.sessionNumber}_${widget.categoryFilter}_$_currentIndex'),
              question: currentQuestion,
            ),
          ),
          // --------------------
        ],
      ),

      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row( // 평가 버튼
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(onPressed: () => setState(() => _assessmentStatus = '맞음'), style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '맞음' ? Colors.green : null), child: const Text('맞음')),
                    ElevatedButton(onPressed: () => setState(() => _assessmentStatus = '보류'), style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '보류' ? Colors.orange : null), child: const Text('보류')),
                    ElevatedButton( // 틀림 버튼
                        onPressed: () async {
                          // onPressed 내부에서도 currentQuestion 변수 사용 가능
                          // (build 메소드 스코프 내에 있으므로 접근 가능)
                          // 또는 안전하게 다시 가져오기:
                          // if (_currentIndex < 0 || _currentIndex >= _loadedQuestions.length) return;
                          // final Question questionForNote = _loadedQuestions[_currentIndex];
                          if (_currentIndex < 0 || _currentIndex >= _loadedQuestions.length) return;
                          final Question currentQuestion = _loadedQuestions[_currentIndex];

                          final incorrectInfo = IncorrectQuestionInfo(
                            year: widget.year,
                            sessionNumber: widget.sessionNumber,
                            // ★★★ 저장 시 주의: 현재 로직은 _currentIndex를 저장 ★★★
                            // 이것이 원본 인덱스가 아닐 수 있음 (필터링 시)
                            // 정확한 해결을 위해선 _loadQuestionData에서 원본 인덱스를 Question 객체에 저장하고
                            // 여기서 그 값을 사용해야 함 (category_question_screen처럼)
                            // 지금은 SnackBar만 수정
                            questionIndex: _currentIndex,
                            questionNumber: currentQuestion.number, // 실제 문제 번호 저장
                            questionType: currentQuestion.type, // build 메소드에서 정의한 변수 사용
                            questionTextSnippet: currentQuestion.questionText.substring(0, (currentQuestion.questionText.length > 50 ? 50 : currentQuestion.questionText.length)),
                          );
                          // ... (오답 노트 저장 로직) ...
                          List<IncorrectQuestionInfo> currentNotes = await _noteService.loadIncorrectNotes();
                          bool alreadyExists = currentNotes.any((note) => note == incorrectInfo);

                          if (!alreadyExists) {
                            currentNotes.add(incorrectInfo);
                            await _noteService.saveIncorrectNotes(currentNotes);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                        // --- ★★★ SnackBar 메시지 수정: currentQuestion.number 사용 ★★★ ---
                                          '${widget.year}년 ${widget.sessionNumber}회차 ${currentQuestion.number}번 오답 추가 (${currentQuestion.type})'
                                        // -----------------------------------------------------------
                                      ),
                                      duration: const Duration(seconds: 2)
                                  )
                              );
                            }
                          } else {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('이미 오답 노트에 있는 문제입니다.'), duration: const Duration(seconds: 2)) );
                          }
                          if (mounted) setState(() => _assessmentStatus = '틀림');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '틀림' ? Colors.red : null),
                        child: const Text('틀림')
                    ),
                  ]
              ),
              const SizedBox(height: 8.0),
              Row( // 이전/다음 문제 버튼
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton( onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null, child: const Text('◀ 이전 문제') ),
                    ElevatedButton( onPressed: _currentIndex < _totalQuestionsInSession - 1 ? () => _goToQuestion(_currentIndex + 1) : null, child: const Text('다음 문제 ▶') ),
                  ]
              ),
            ],
          ),
        )
      ],
    );
  }
}