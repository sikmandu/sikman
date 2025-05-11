// lib/question_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart'; // Provider import

import 'constants.dart'; // 사용한다면 유지
import 'models/question.dart';
import 'models/incorrect_question_info.dart';
import 'models/study_context.dart';
import 'notifiers/recent_study_notifier.dart'; // Notifier import
import 'services/incorrect_note_service.dart';
import 'widgets/question_viewer.dart';
import 'widgets/common_app_bar.dart'; // 사용한다면 유지
// ---------------------------

class QuestionScreen extends StatefulWidget {
  final int year;
  final int sessionNumber;
  // final int initialIndex; // 이 대신 아래 initialQuestionNumber 사용 또는 둘 다 사용
  final String? categoryFilter;
  final int? initialQuestionNumber; // ★★★ 실제 문제 번호 (1부터 시작)를 받을 수 있도록 추가 ★★★
  final int initialIndex; // 기존 initialIndex는 fallback 또는 기본값으로 유지 가능

  const QuestionScreen({
    super.key,
    required this.year,
    required this.sessionNumber,
    this.initialIndex = 0, // 기본값은 0번 인덱스
    this.categoryFilter,
    this.initialQuestionNumber, // 생성자에 추가
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<Question> _loadedQuestions = [];
  bool _isLoading = true;
  String _loadingError = '';
  int _totalQuestionsInSession = 0;
  int _currentIndex = 0;
  String? _assessmentStatus;
  final IncorrectNoteService _noteService = IncorrectNoteService();

  // ★★★ RecentStudyNotifier 인스턴스를 저장할 멤버 변수 ★★★
  RecentStudyNotifier? _recentStudyNotifierInstance;
  bool _isNotifierInitialized = false;


  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    // initState에서는 Provider.of를 사용한 초기화가 불안정할 수 있으므로
    // _loadQuestionData 호출 후, 또는 didChangeDependencies에서 Notifier를 가져옵니다.
    _loadQuestionData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 위젯의 의존성이 변경될 때 호출되며, context를 안전하게 사용할 수 있는 시점입니다.
    if (!_isNotifierInitialized) {
      _recentStudyNotifierInstance = Provider.of<RecentStudyNotifier>(context, listen: false);
      _isNotifierInitialized = true;
      print("QuestionScreen: RecentStudyNotifier 인스턴스 초기화됨 in didChangeDependencies");

      // Notifier가 준비된 후, 데이터 로드가 이미 완료되었고 유효한 문제가 있다면 첫 문제에 대한 최근 학습 업데이트
      if (!_isLoading && _loadedQuestions.isNotEmpty && _currentIndex >=0 && _currentIndex < _loadedQuestions.length) {
        _updateRecentStudyForCurrentQuestion(isFromDidChangeDependencies: true);
      }
    }
  }

  @override
  void dispose() {
    print("QuestionScreen: dispose 호출됨");
    if (_isNotifierInitialized) { // Notifier가 성공적으로 초기화되었을 경우에만 호출
      _updateRecentStudyForCurrentQuestion(isDisposing: true);
    }
    super.dispose();
  }

  Future<void> _updateRecentStudyForCurrentQuestion({bool isDisposing = false, bool isFromDidChangeDependencies = false}) async {
    // isDisposing이 true가 아닐 때만 mounted를 체크합니다. dispose 중에는 mounted가 false일 수 있습니다.
    if (!isDisposing && !mounted) {
      print("QuestionScreen: _updateRecentStudyForCurrentQuestion - mounted false (and not disposing), 업데이트 건너뜀");
      return;
    }

    if (_isLoading || _loadingError.isNotEmpty || _loadedQuestions.isEmpty || _currentIndex < 0 || _currentIndex >= _loadedQuestions.length) {
      print("QuestionScreen: 최근 학습 업데이트 건너뜀 (상태 유효하지 않음 - isLoading:$_isLoading, error:$_loadingError, count:${_loadedQuestions.length}, index:$_currentIndex)");
      return;
    }

    final Question currentQuestion = _loadedQuestions[_currentIndex];
    final notifier = _recentStudyNotifierInstance; // initState 또는 didChangeDependencies에서 할당된 인스턴스 사용

    if (notifier == null) {
      // 이 경우는 didChangeDependencies가 아직 호출되지 않았거나 실패한 경우
      // dispose 중이 아니라면 Provider.of를 시도해볼 수 있으나, _isNotifierInitialized 플래그로 관리하는 것이 더 안전
      if (!isDisposing && mounted) { // dispose 중이 아닐때만 context를 사용한 Provider.of 시도
        print("QuestionScreen: _recentStudyNotifierInstance is null, attempting Provider.of again.");
        final tempNotifier = Provider.of<RecentStudyNotifier>(context, listen: false);
        await _performUpdateLogic(tempNotifier, currentQuestion);
      } else {
        print("QuestionScreen: _recentStudyNotifierInstance is null and (isDisposing or not mounted). Cannot update.");
      }
      return;
    }

    if (isDisposing) print("QuestionScreen: dispose 중 최근 학습 저장 시도 - ${currentQuestion.number}번");
    else print("QuestionScreen: _updateRecentStudyForCurrentQuestion 호출됨 - Q#${currentQuestion.number}");

    await _performUpdateLogic(notifier, currentQuestion);
  }
  Future<void> _performUpdateLogic(RecentStudyNotifier notifier, Question currentQuestion) async {
    int originalIndexToSave = currentQuestion.originalIndex ?? _currentIndex; // fallback
    if (widget.categoryFilter == null || widget.categoryFilter!.isEmpty) {
      await notifier.updateRecentPastExam(
          widget.year,
          widget.sessionNumber,
          currentQuestion.number,
          originalIndexToSave
      );
    } else {
      await notifier.updateRecentCategoryExam(
          widget.categoryFilter!,
          currentQuestion.year ?? widget.year,
          currentQuestion.sessionNumber ?? widget.sessionNumber,
          currentQuestion.number,
          originalIndexToSave
      );
    }
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

      List<Question> questions = questionListJson.map((qJson) {
        if (qJson is Map<String, dynamic>) {
          final q = Question.fromJson(qJson);
          return q.copyWithContext(
              year: widget.year,
              sessionNumber: widget.sessionNumber,
              originalIndex: questionListJson.indexOf(qJson)
          );
        }
        return null;
      }).whereType<Question>().toList();

      if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
        questions = questions.where((q) => q.type == widget.categoryFilter).toList();
      }

      int determinedInitialIndex = widget.initialIndex;
      if (widget.initialQuestionNumber != null && questions.isNotEmpty) {
        int foundIndex = questions.indexWhere((q) => q.number == widget.initialQuestionNumber);
        if (foundIndex != -1) {
          determinedInitialIndex = foundIndex;
        } else {
          determinedInitialIndex = questions.isNotEmpty ? 0 : -1;
        }
      } else if (questions.isNotEmpty && widget.initialIndex >= questions.length) {
        determinedInitialIndex = 0;
      } else if (questions.isEmpty) {
        determinedInitialIndex = -1;
      }

      if (mounted) {
        setState(() {
          _loadedQuestions = questions;
          _totalQuestionsInSession = questions.length;
          _currentIndex = determinedInitialIndex;
          _isLoading = false;
          _assessmentStatus = null;
          if (questions.isEmpty && _loadingError.isEmpty) {
            _loadingError = widget.categoryFilter != null
                ? "'${widget.categoryFilter}' 유형의 문제가 이 회차에 없습니다."
                : '표시할 문제가 없습니다.';
          }
        });
        // 데이터 로드 완료 후, 첫 문제에 대한 "최근 학습" 정보 업데이트
        // Notifier 인스턴스가 didChangeDependencies에서 설정된 후 안전하게 호출
        if (_isNotifierInitialized && _currentIndex != -1) {
          await _updateRecentStudyForCurrentQuestion();
        }
      }
    } catch (e, stacktrace) {
      print("!!! QuestionScreen _loadQuestionData 에러 발생: $e\n$stacktrace");
      if (mounted) { setState(() { _loadingError = '문제 로딩 오류: $e'; _isLoading = false; _loadedQuestions = []; _totalQuestionsInSession = 0; }); }
    }
  }

  // --- 문제 이동 함수 ---
  void _goToQuestion(int newIndex) async {
    if (!mounted || newIndex < 0 || newIndex >= _totalQuestionsInSession) return;
    print("QuestionScreen: Navigating to index $newIndex");

    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
        _assessmentStatus = null;
      });
    }
    // 다음 문제로 이동 후, "최근 학습" 정보 업데이트
    await _updateRecentStudyForCurrentQuestion();
  }

  // --- 화면 빌드 ---
  @override
  Widget build(BuildContext context) {
    // Notifier가 초기화되었는지 또는 로딩 중인지 먼저 확인
    if (!_isNotifierInitialized && !_isLoading) {
      // 이 경우는 didChangeDependencies가 아직 호출되지 않았거나, Provider 설정에 문제가 있을 수 있음.
      // 안전하게 로딩 화면을 보여주거나, WidgetsBinding으로 다음 프레임에 재시도할 수 있음.
      // 지금은 로딩을 표시.
      print("QuestionScreen build: Notifier 아직 초기화 안됨, 로딩 표시");
      return Scaffold(appBar: AppBar(title: Text("초기화 중...")), body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
      return Scaffold(appBar: buildCommonAppBar(context: context,title: '${widget.year}년 ${widget.sessionNumber}회차'), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: buildCommonAppBar(context: context,title: '${widget.year}년 ${widget.sessionNumber}회차'), body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_loadingError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)))));
    }
    if (_currentIndex == -1 || _loadedQuestions.isEmpty || _currentIndex >= _loadedQuestions.length) {
      return Scaffold(
          appBar: buildCommonAppBar(context: context,title: '${widget.year}년 ${widget.sessionNumber}회차'),
          body: Center(child: Text(_loadingError.isNotEmpty ? _loadingError : '표시할 문제가 없습니다.'))
      );
    }

    final Question currentQuestion = _loadedQuestions[_currentIndex];
    final int currentQuestionDisplayNumber = _currentIndex + 1;
    // 메인 Scaffold
    return Scaffold(
      appBar: buildCommonAppBar(
          context: context,
          title: '${widget.year}년 ${widget.sessionNumber}회차 ${widget.categoryFilter != null ? "(${widget.categoryFilter})" : ""} 문제 ($currentQuestionDisplayNumber / $_totalQuestionsInSession)'
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.categoryFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '${currentQuestion.year ?? widget.year}년 ${currentQuestion.sessionNumber ?? widget.sessionNumber}회차 ${currentQuestion.number}번',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: QuestionViewer(
              key: ValueKey(currentQuestion.hashCode), // 문제 객체가 바뀔 때마다 키가 바뀌도록
              question: currentQuestion,
              contextType: (widget.categoryFilter == null || widget.categoryFilter!.isEmpty)
                  ? StudyContextType.pastExam
                  : StudyContextType.categoryExam,
              displayYear: widget.year,
              displaySessionNumber: widget.sessionNumber,
              categoryName: widget.categoryFilter,
            ),
          ),
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