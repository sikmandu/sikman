// lib/category_question_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart'; // Provider 패키지 import

// 프로젝트 내부 파일 import
import 'models/question.dart';
import 'models/incorrect_question_info.dart';
import 'models/study_context.dart'; // StudyContextType enum
import 'notifiers/recent_study_notifier.dart'; // Notifier import
import 'services/incorrect_note_service.dart';
import 'widgets/question_viewer.dart';

class CategoryQuestionScreen extends StatefulWidget {
  final String categoryName; // 선택된 카테고리 이름

  const CategoryQuestionScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryQuestionScreen> createState() => _CategoryQuestionScreenState();
}

class _CategoryQuestionScreenState extends State<CategoryQuestionScreen> {
  // --- 상태 변수 ---
  List<Question> _categoryQuestions = []; // 카테고리에 맞는 문제 목록
  int _totalQuestionsInCategory = 0;    // 카테고리 내 총 문제 수
  int _currentIndex = 0;                // 현재 보고 있는 문제 인덱스
  bool _isLoading = true;
  String _loadingError = '';
  String? _assessmentStatus; // 맞음/보류/틀림 상태
  final IncorrectNoteService _noteService = IncorrectNoteService();
  // PageController, currentPageIndex, totalPages, isAnswerVisibleMap 등은 제거됨
  // -----------------
  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    _loadCategoryQuestionData(); // 데이터 로딩 시작
  }
  @override
  void dispose() {
    if (mounted) {
      _updateRecentStudyForCurrentCategoryQuestion(isDisposing: true);
    }
    super.dispose();
  }

  Future<void> _updateRecentStudyForCurrentCategoryQuestion({bool isDisposing = false}) async {
    if (!mounted || _isLoading || _loadingError.isNotEmpty || _categoryQuestions.isEmpty || _currentIndex < 0 || _currentIndex >= _categoryQuestions.length) {
      if (isDisposing) print("CategoryQuestionScreen: dispose 중 최근 학습 업데이트 건너뜀 (상태 유효하지 않음)");
      else print("CategoryQuestionScreen: 최근 학습 업데이트 건너뜀 (상태 유효하지 않음)");
      return;
    }
    final Question currentQuestion = _categoryQuestions[_currentIndex];
    final recentStudyNotifier = Provider.of<RecentStudyNotifier>(context, listen: false);

    int originalIndexToSave = currentQuestion.originalIndex ?? _currentIndex;
    print("CategoryQuestionScreen: _updateRecentStudyForCurrentCategoryQuestion 호출됨 - Q#${currentQuestion.number}, originalIndex: $originalIndexToSave");

    if (currentQuestion.year != null && currentQuestion.sessionNumber != null) {
      // ★★★ originalIndex 전달 ★★★
      await recentStudyNotifier.updateRecentCategoryExam(
          widget.categoryName,
          currentQuestion.year!,
          currentQuestion.sessionNumber!,
          currentQuestion.number,
          originalIndexToSave
      );
    } else {
      print("CategoryQuestionScreen 경고: 최근 학습 저장 시 Question 객체에 year 또는 sessionNumber 정보가 없습니다.");
    }
  }
  // --- 데이터 로딩 함수 ---
  Future<void> _loadCategoryQuestionData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadingError = ''; });

    List<Question> allQuestions = [];
    final List<int> years = List.generate(2024 - 2003 + 1, (index) => 2024 - index);
    final List<int> sessions = [1, 2, 3, 4]; // 2020년 4회차 포함 가정 (필요시 조정)

    for (int year in years) {
      List<int> currentYearSessions = (year == 2020) ? [1, 2, 3, 4] : [1, 2, 3];
      for (int session in currentYearSessions) {
        final String filePath = 'assets/data/${year}_$session.json';
        try {
          final String jsonString = await rootBundle.loadString(filePath);
          final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

          for (int i = 0; i < questionListJson.length; i++) { // questionListJson 루프 내에서 인덱스 사용
            final qJson = questionListJson[i];
            if (qJson is Map<String, dynamic>) {
              final Question originalQ = Question.fromJson(qJson);
              allQuestions.add(originalQ.copyWithContext(
                year: year, // 현재 읽고 있는 파일의 연도
                sessionNumber: session, // 현재 읽고 있는 파일의 회차
                originalIndex: i, // 현재 파일 내에서의 인덱스
              ));
            }
          }
        } catch (e) {
          // 파일 로드 오류는 개발 중에는 print, 배포 시에는 무시 또는 로깅
          print("CategoryQuestionScreen: $filePath 로드/파싱 오류 - $e");
        }
      }
    }

    // 선택된 카테고리와 일치하는 문제 필터링
    final filteredQuestions = allQuestions.where((q) => q.type == widget.categoryName).toList();
    print("Total questions loaded: ${allQuestions.length}, Filtered for '${widget.categoryName}': ${filteredQuestions.length}");

    if (mounted) {
      setState(() {
        _categoryQuestions = filteredQuestions;
        _totalQuestionsInCategory = filteredQuestions.length;
        _isLoading = false;
        _currentIndex = 0; // 필터링 후 첫 문제로
        _assessmentStatus = null; // 상태 초기화
        if (_categoryQuestions.isEmpty) {
          _loadingError = "'${widget.categoryName}' 유형의 문제를 찾을 수 없습니다.";
        }
      });
      await _updateRecentStudyForCurrentCategoryQuestion();
    }
  }
  // --- 문제 이동 함수 (카테고리 내에서) ---
  void _goToQuestion(int newIndex) async { // async 추가
    if (!mounted || newIndex < 0 || newIndex >= _totalQuestionsInCategory) return;
    print("CategoryQuestionScreen: Navigating to index $newIndex");

    setState(() { // 먼저 UI 상태 업데이트
      _currentIndex = newIndex;
      _assessmentStatus = null;
    });
    // ★ 다음 문제로 이동 후, "최근 학습" 정보 업데이트
    await _updateRecentStudyForCurrentCategoryQuestion();
  }
  // --- 빌드 메소드 ---
  @override
  Widget build(BuildContext context) {
    // --- 1단계: 로딩 상태 확인 ---
    if (_isLoading) {
      print(">>> Build: isLoading is true, showing loading indicator.");
      return Scaffold(
          appBar: AppBar(title: Text('${widget.categoryName} 문제')),
          body: const Center(child: CircularProgressIndicator()));
    }

    // --- 2단계: 로딩 오류 확인 ---
    if (_loadingError.isNotEmpty) {
      print(">>> Build: loadingError is not empty, showing error: $_loadingError");
      return Scaffold(
          appBar: AppBar(title: Text('${widget.categoryName} 문제')),
          body: Center(child: Padding(padding: const EdgeInsets.all(16.0),
              child: Text(_loadingError, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)))));
    }

    // --- 3단계: 데이터 및 인덱스 유효성 확인 ---
    if (_categoryQuestions.isEmpty || _currentIndex < 0 || _currentIndex >= _categoryQuestions.length) {
      print(">>> Build: No questions available or invalid index. Count: ${_categoryQuestions.length}, Index: $_currentIndex");
      final message = _categoryQuestions.isEmpty ? "'${widget.categoryName}' 유형의 문제가 없습니다." : '문제 인덱스 오류입니다.';
      return Scaffold(
          appBar: AppBar(title: Text('${widget.categoryName} 문제')),
          body: Center(child: Text(message)));
    }

    // --- 4단계: 유효한 데이터로 UI 구성 ---
    // 이 시점에서는 _isLoading=false, _loadingError 비어있음, _categoryQuestions 비어있지 않음, _currentIndex 유효함
    final Question currentQuestion = _categoryQuestions[_currentIndex];
    final int currentQuestionNumber = _currentIndex + 1;

    // --- ★★★ 디버깅용 Print: 데이터 확인 ★★★ ---
    // 이 print 문이 실행되는지, 값은 올바른지 확인하세요.
    print("### Build: Rendering UI for Question - "
        "Y=${currentQuestion.year}, S=${currentQuestion.sessionNumber}, "
        "No=${currentQuestion.number}, Idx=${currentQuestion.originalIndex}, "
        "Type=${currentQuestion.type}");

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} ($currentQuestionNumber / $_totalQuestionsInCategory)'),
      ),
      body: Column( // 메인 Column
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- ★★★ 문제 출처 정보 표시 Text ★★★ ---
          // 이 Padding 위젯이 Column의 첫 번째 자식으로 있는지 확인하세요.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '${currentQuestion.year ?? '?'}년 ${currentQuestion.sessionNumber ?? '?'}회차 ${currentQuestion.number}번',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: QuestionViewer(
              key: ValueKey(currentQuestion.hashCode), // 문제 객체 변경 시 위젯 갱신
              question: currentQuestion,
              contextType: StudyContextType.categoryExam,
              categoryName: widget.categoryName,
              // displayYear, displaySessionNumber는 QuestionViewer 내부에서 question.year/sessionNumber를 사용
            ),
          ),
        ],
      ),
      // -----------------------------------------
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
                          // --- ★★★ 오답 저장 시 currentQuestion의 컨텍스트 정보 사용 ★★★ ---
                          if (_currentIndex < 0 || _currentIndex >= _categoryQuestions.length) return;
                          final Question questionForNote = _categoryQuestions[_currentIndex];

                          // Question 객체에 저장된 year, sessionNumber, originalIndex 사용 (Null 체크!)
                          if (questionForNote.year == null || questionForNote.sessionNumber == null || questionForNote.originalIndex == null) {
                            print("Error saving incorrect note: Missing context in Question object.");
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('오류: 문제 정보를 찾을 수 없어 오답노트에 추가할 수 없습니다.')));
                            return;
                          }

                          final incorrectInfo = IncorrectQuestionInfo(
                            year: questionForNote.year!,
                            sessionNumber: questionForNote.sessionNumber!,
                            questionIndex: questionForNote.originalIndex!,
                            questionNumber: questionForNote.number,// 원본 인덱스 사용
                            questionType: questionForNote.type,
                            questionTextSnippet: questionForNote.questionText.substring(0, (questionForNote.questionText.length > 50 ? 50 : questionForNote.questionText.length)),
                          );
                          // -------------------------------------------------------------

                          List<IncorrectQuestionInfo> currentNotes = await _noteService.loadIncorrectNotes();
                          bool alreadyExists = currentNotes.any((note) => note == incorrectInfo);

                          if (!alreadyExists) {
                            currentNotes.add(incorrectInfo);
                            await _noteService.saveIncorrectNotes(currentNotes);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                        // --- ★★★ SnackBar 메시지 수정 ★★★ ---
                                        // originalIndex 대신 questionNumber 사용
                                          '${questionForNote.year}년 ${questionForNote.sessionNumber}회차 ${questionForNote.number}번 오답 추가 (${questionForNote.type})'
                                        // ---------------------------------
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
                    ElevatedButton(
                        onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
                        child: const Text('◀ 이전 문제')
                    ),
                    ElevatedButton(
                        onPressed: _currentIndex < _totalQuestionsInCategory - 1 ? () => _goToQuestion(_currentIndex + 1) : null,
                        child: const Text('다음 문제 ▶')
                    ),
                  ]
              ),
            ],
          ),
        )
      ],
    );
  }
} // _CategoryQuestionScreenState 끝