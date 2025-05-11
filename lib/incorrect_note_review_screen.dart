// lib/incorrect_note_review_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart'; // Provider 패키지 import

// 프로젝트 내부 파일 import
import '../models/incorrect_question_info.dart';
import '../models/question.dart';
import '../models/study_context.dart'; // StudyContextType enum
import '../notifiers/recent_study_notifier.dart'; // Notifier import
import '../services/incorrect_note_service.dart';
import '../widgets/question_viewer.dart';

// 오답 노트 복습 화면 위젯
class IncorrectNoteReviewScreen extends StatefulWidget {
  final List<IncorrectQuestionInfo> initialIncorrectNotes; // 생성 시 받는 초기 목록 스냅샷
  final int initialIndex;

  const IncorrectNoteReviewScreen({
    super.key,
    required List<IncorrectQuestionInfo> incorrectNotes, // 생성자 파라미터 이름 사용
    required this.initialIndex,
  }) : initialIncorrectNotes = incorrectNotes; // 전달받은 목록을 초기 상태로 저장

  @override
  State<IncorrectNoteReviewScreen> createState() => _IncorrectNoteReviewScreenState();
} // StatefulWidget 클래스 끝

class _IncorrectNoteReviewScreenState extends State<IncorrectNoteReviewScreen> {
  late List<IncorrectQuestionInfo> _currentNotesInReview; // 현재 화면에서 관리하는 노트 정보 목록
  late int _totalNotesInReview;
  late int _currentIndex;
  Question? _currentFullQuestion; // 현재 표시 중인 로드된 Question 객체
  bool _isLoading = true;
  String _loadingError = '';
  final IncorrectNoteService _noteService = IncorrectNoteService();
  // PageController _pageController; // 제거
  // int _currentPageIndex; // 제거
  // int _totalPages; // 제거 (QuestionViewer가 관리)
  // Map<int, bool> _isAnswerVisibleMap; // 제거 (QuestionViewer가 관리)
  // --------------------------------------
  // --- 초기화 ---


  @override
  void initState() {
    super.initState();
    _currentNotesInReview = List.from(widget.initialIncorrectNotes); // 초기 목록 복사
    _totalNotesInReview = _currentNotesInReview.length;
    _currentIndex = widget.initialIndex;
    if (_currentIndex < 0 || _currentIndex >= _totalNotesInReview) {
      _currentIndex = 0; // 유효하지 않으면 0으로
    }

    if (_totalNotesInReview > 0) {
      _loadFullQuestionData(_currentNotesInReview[_currentIndex]); // 첫 문제 로드
    } else {
      setState(() {
        _isLoading = false;
        _loadingError = '표시할 오답 노트가 없습니다.';
      });
    }
  }


  // --- ★★★ 화면 종료 시 학습 위치 저장 ★★★ ---
  @override
  void dispose() {
    if (mounted) {
      _updateRecentStudyForCurrentReviewedQuestion(isDisposing: true);
    }
    super.dispose();
  }

  // ★ 최근 학습 정보를 Notifier를 통해 업데이트하는 함수
  Future<void> _updateRecentStudyForCurrentReviewedQuestion({bool isDisposing = false}) async {
    if (!mounted || _isLoading || _loadingError.isNotEmpty || _currentFullQuestion == null) {
      if (isDisposing) print("IncorrectNoteReviewScreen: dispose 중 최근 학습 업데이트 건너뜀 (상태 유효하지 않음)");
      else print("IncorrectNoteReviewScreen: 최근 학습 업데이트 건너뜀 (상태 유효하지 않음)");
      return;
    }
    if (_currentIndex < 0 || _currentIndex >= _currentNotesInReview.length) return;

    final Question questionToUpdate = _currentFullQuestion!;
    final IncorrectQuestionInfo noteInfo = _currentNotesInReview[_currentIndex];
    final recentStudyNotifier = Provider.of<RecentStudyNotifier>(context, listen: false);

    int originalIndexToSave = questionToUpdate.originalIndex ?? noteInfo.questionIndex; // IncorrectQuestionInfo의 questionIndex는 원본 인덱스여야 함
    print("IncorrectNoteReviewScreen: _updateRecentStudyForCurrentReviewedQuestion 호출됨 - Q#${questionToUpdate.number}, originalIndex: $originalIndexToSave, Category: ${noteInfo.questionType}");

    if (questionToUpdate.year != null && questionToUpdate.sessionNumber != null) {
      // ★★★ originalIndex 전달 ★★★
      await recentStudyNotifier.updateRecentIncorrectNoteView(
          questionToUpdate.year!,
          questionToUpdate.sessionNumber!,
          questionToUpdate.number,
          noteInfo.questionType, // 카테고리로 사용될 원본 문제 유형
          originalIndexToSave
      );
      // 2. 원본 과년도의 최근 학습 업데이트
      await recentStudyNotifier.updateRecentPastExam(
          questionToUpdate.year!,
          questionToUpdate.sessionNumber!,
          questionToUpdate.number,
          originalIndexToSave
      );
      // 3. (선택적) 오답노트 자체의 최근 학습 아이템 업데이트 (Notifier에 해당 로직이 있다면)
      // await recentStudyNotifier.updateActualRecentIncorrectNoteItem(...);
    } else {
      print("IncorrectNoteReviewScreen 경고: 최근 학습 저장 시 Question 객체에 year 또는 sessionNumber 정보가 없습니다.");
    }
  }



  // --- 데이터 로딩 함수 ---
  Future<void> _loadFullQuestionData(IncorrectQuestionInfo noteInfo) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadingError = ''; _currentFullQuestion = null; });

    try {
      final String filePath = 'assets/data/${noteInfo.year}_${noteInfo.sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

      // noteInfo.questionIndex가 원본 JSON 파일 내에서의 0부터 시작하는 인덱스여야 함.
      int targetOriginalJsonIndex = noteInfo.questionIndex;
      Question? loadedQuestionData;

      if (targetOriginalJsonIndex >= 0 && targetOriginalJsonIndex < questionListJson.length) {
        final qJson = questionListJson[targetOriginalJsonIndex] as Map<String, dynamic>;
        // 추가 검증: 로드한 문제의 번호와 타입이 noteInfo와 일치하는지
        if (Question.fromJson(qJson).number == noteInfo.questionNumber &&
            Question.fromJson(qJson).type == noteInfo.questionType) {
          loadedQuestionData = Question.fromJson(qJson);
        }
      }
      // 만약 위에서 못찾았거나, 문제번호로 다시 한번 찾아보는 로직
      if (loadedQuestionData == null) {
        var foundEntry = questionListJson
            .asMap().entries // 인덱스와 함께 순회
            .firstWhere(
              (entry) {
            final q = Question.fromJson(entry.value as Map<String, dynamic>);
            return q.number == noteInfo.questionNumber && q.type == noteInfo.questionType;
          },
          orElse: () => const MapEntry(-1, null), // const로 빈 MapEntry 반환
        );
        if (foundEntry.key != -1 && foundEntry.value != null) {
          loadedQuestionData = Question.fromJson(foundEntry.value as Map<String, dynamic>);
          targetOriginalJsonIndex = foundEntry.key; // 찾은 실제 인덱스로 업데이트
          print("IncorrectNoteReviewScreen: 문제 번호로 검색하여 원본 인덱스 ${targetOriginalJsonIndex} 찾음.");
        }
      }


      if (loadedQuestionData != null) {
        // ★★★ Question 객체에 원본 출처 정보(year, session, originalIndex)를 확실히 주입 ★★★
        final contextualQuestion = loadedQuestionData.copyWithContext(
            year: noteInfo.year,                 // 오답 정보에 있는 원본 연도
            sessionNumber: noteInfo.sessionNumber, // 오답 정보에 있는 원본 회차
            originalIndex: targetOriginalJsonIndex  // 사용된/찾은 원본 JSON 인덱스
        );
        // ------------------------------------------------------------------

        if (mounted) {
          setState(() {
            _currentFullQuestion = contextualQuestion;
            _isLoading = false;
          });
          // ★ QuestionViewer가 initState 또는 didUpdateWidget에서 _saveRecentStudy를 호출하여 최근 학습 저장
        }
      } else {
        throw Exception('오답노트 정보에 해당하는 문제(번호: ${noteInfo.questionNumber}, 유형: ${noteInfo.questionType})를 JSON 파일(${filePath})에서 찾을 수 없습니다.');
      }
    } catch (e, stacktrace) {
      print('오답노트 복습 문제 로딩 오류: $e\n$stacktrace');
      if (mounted) { setState(() { _loadingError = '문제 데이터 로딩 오류:\n$e'; _isLoading = false; }); }
    }
  }

  static final Question null_question_object = Question(number: -1, type: '', questionText: '', subQuestions: [], isKillerProblem: false);


  void _navigateToQuestion(int newIndex) {
    if (!mounted || newIndex < 0 || newIndex >= _totalNotesInReview) return;

    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
        _isLoading = true; // 새 문제 로딩 시작
        _loadingError = '';
        _currentFullQuestion = null;
      });
    }
    _loadFullQuestionData(_currentNotesInReview[newIndex]);
  }

  // --- ★★★ 삭제 로직 수정 ★★★ ---
  Future<void> _deleteCurrentNote() async {
    if (_isLoading) return; // 로딩 중 삭제 방지
    if (_currentIndex < 0 || _currentIndex >= _totalNotesInReview) {
      print("Delete error: Invalid current index $_currentIndex.");
      return;
    }

    // 1. 삭제할 노트 정보 (현재 상태 목록 기준)
    IncorrectQuestionInfo noteToDelete = _currentNotesInReview[_currentIndex];
    int indexToDelete = _currentIndex;

    // 2. 저장소에서 삭제 시도
    List<IncorrectQuestionInfo> storedNotes = await _noteService.loadIncorrectNotes();
    int initialStorageLength = storedNotes.length;
    storedNotes.removeWhere((note) => note == noteToDelete); // Use == operator

    bool deletionSuccessful = false;
    if (storedNotes.length < initialStorageLength) {
      await _noteService.saveIncorrectNotes(storedNotes);
      deletionSuccessful = true;
    }

    // 3. 삭제 성공 시 상태 업데이트 및 네비게이션
    if (mounted && deletionSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('오답 노트에서 제거되었습니다.'), duration: Duration(seconds: 2)),);

      // --- 로컬 상태 업데이트 ---
      List<IncorrectQuestionInfo> updatedNotes = List.from(_currentNotesInReview);
      updatedNotes.removeAt(indexToDelete); // 현재 화면의 목록에서도 제거
      int newTotal = updatedNotes.length;
      // ------------------------

      if (newTotal == 0) {
        Navigator.pop(context, true); // ★ 변경 사항이 있음을 알림
      } else {
        int nextIndexToShow = (indexToDelete >= newTotal) ? newTotal - 1 : indexToDelete;
        // setState(() { // _navigateToQuestion이 setState를 포함하므로 중복 호출 방지
        //   _currentNotesInReview = updatedNotes;
        //   _totalNotesInReview = newTotal;
        //   // _currentIndex = nextIndexToShow; // _navigateToQuestion에서 설정
        // });
        _navigateToQuestion(nextIndexToShow); // 다음 문제로 이동 (이동 후 최근 학습 자동 업데이트)
      }
    } else if (mounted && !deletionSuccessful) {
      print("Delete error: Note not found in storage for index $indexToDelete.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('삭제 오류: 해당 오답 정보를 찾을 수 없거나 이미 삭제되었습니다.'), duration: Duration(seconds: 2)),);
      // Navigator.pop(context); // 실패 시 바로 닫지 않고 현재 화면 유지 고려
    }
  }

  // --- 빌드 메소드 ---
  @override
  Widget build(BuildContext context) {
    // 로딩/에러/데이터 없음 처리
    if (_isLoading && _currentFullQuestion == null) { // _currentFullQuestion 로드 여부 확인
      return Scaffold(appBar: AppBar(title: const Text('오답 복습')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('오류')), body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_loadingError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)))));
    }
    if (_currentNotesInReview.isEmpty || _currentIndex >= _currentNotesInReview.length) {
      // 로딩 끝났는데 노트가 없는 경우
      return Scaffold(appBar: AppBar(title: const Text('오답 노트')), body: const Center(child: Text('표시할 오답 노트가 없습니다.')));
    }
    if (_currentFullQuestion == null) {
      // 데이터 로딩 중이거나 실패하여 Question 객체가 없는 경우 (오류 또는 로딩 재시도 UI)
      return Scaffold(appBar: AppBar(title: const Text('오답 복습')), body: Center(child: _isLoading ? CircularProgressIndicator() : Text('문제를 불러오지 못했습니다.')));
    }

    // 현재 표시할 노트 정보와 Question 객체
    final IncorrectQuestionInfo currentNoteInfo = _currentNotesInReview[_currentIndex];
// ★★★ final Question questionToView = _currentFullQuestion!; 이 라인이 확실히 있는지 확인 ★★★
    final Question questionToView = _currentFullQuestion!;

    return WillPopScope( // 뒤로가기 버튼 처리
        onWillPop: () async {
      Navigator.pop(context, true); // 변경사항이 있었을 수 있음을 알림
      return true;
    },
    child: Scaffold(
    appBar: AppBar(
        title: Text('${currentNoteInfo.year}년 ${currentNoteInfo.sessionNumber}회차 - ${questionToView.number}번 복습'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.white),
            tooltip: '오답 노트에서 삭제',
            onPressed: () async {
              bool? confirmed = await showDialog<bool>(
                  context: context, // ★★★ 여기 context도 확인 ★★★
                  // builder 파라미터는 함수를 받습니다.
                  builder: (BuildContext dialogContext) { // ★★★ builder의 context 이름 변경 (선택적이지만 명확성 위해) ★★★
                    return AlertDialog(
                      title: const Text('삭제 확인'),
                      content: Text('${currentNoteInfo.year}년 ${currentNoteInfo.sessionNumber}회차 - ${questionToView.number}번 문제를 오답 노트에서 삭제하시겠습니까?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('취소'),
                          onPressed: () => Navigator.of(dialogContext).pop(false), // dialogContext 사용
                        ),
                        TextButton(
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true); // dialogContext 사용
                          },
                        ),
                      ],
                    );
                  }
              );
              if (confirmed == true) {
                _deleteCurrentNote();
              }
            },
          )
        ],
      ),
      // --- ★★★ body에 QuestionViewer 사용 ★★★ ---
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
      // --- 문제 출처 정보 표시 Text ---
          Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Text(
    // questionToView는 copyWithContext를 통해 원본 year, sessionNumber를 가짐
    '출처: ${questionToView.year ?? '?'}년 ${questionToView.sessionNumber ?? '?'}회차 ${questionToView.number}번 (유형: ${currentNoteInfo.questionType})',
    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
    textAlign: TextAlign.center,
    ),
    ),
    Expanded(
    child: QuestionViewer(
    // ValueKey에 문제 객체의 hashCode를 포함하여 객체가 변경될 때 위젯이 갱신되도록 함
    key: ValueKey('incorrect_${currentNoteInfo.year}_${currentNoteInfo.sessionNumber}_${currentNoteInfo.questionIndex}_${questionToView.hashCode}'),
    question: questionToView,
    // ★★★ QuestionViewer에 정확한 컨텍스트 정보 전달 ★★★
    contextType: StudyContextType.incorrectNoteReview,
    displayYear: questionToView.year, // Question 객체에 저장된 원본 연도
    displaySessionNumber: questionToView.sessionNumber, // Question 객체에 저장된 원본 회차
    categoryName: currentNoteInfo.questionType, // 오답 정보에 있는 원본 유형(카테고리)
    ),
    ),
    ],
    ),
      // -----------------------------------------
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                // ★★★ 상태 변수 _totalNotesInReview 사용 ★★★
                onPressed: _currentIndex > 0 ? () => _navigateToQuestion(_currentIndex - 1) : null,
                child: const Text('◀ 이전 오답'),
              ),
              ElevatedButton(
                // ★★★ 상태 변수 _totalNotesInReview 사용 ★★★
                onPressed: _currentIndex < _totalNotesInReview - 1 ? () => _navigateToQuestion(_currentIndex + 1) : null,
                child: const Text('다음 오답 ▶'),
              ),
            ],
          ),
        )
      ],
    ),
    );
  }
} // _IncorrectNoteReviewScreenState 끝