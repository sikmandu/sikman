import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/incorrect_question_info.dart'; // 경로 확인!
import 'package:sikman/models/question.dart';       // 경로 확인!
import '../services/incorrect_note_service.dart';
import 'widgets/question_viewer.dart';// 서비스 import 확인!
import 'package:flutter_math_fork/flutter_math.dart';

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

  // --- 데이터 로딩 함수 ---
  Future<void> _loadFullQuestionData(IncorrectQuestionInfo noteInfo) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadingError = ''; _currentFullQuestion = null; }); // 로딩 시작 시 현재 문제 null 처리

    try {
      final String filePath = 'assets/data/${noteInfo.year}_${noteInfo.sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];

      if (noteInfo.questionIndex >= 0 && noteInfo.questionIndex < questionListJson.length) {
        final qJson = questionListJson[noteInfo.questionIndex] as Map<String, dynamic>;
        final questionData = Question.fromJson(qJson);

        // ★★★ 로드된 Question 객체에 컨텍스트 정보 추가 (오답노트 저장을 위해 필요할 수 있음) ★★★
        // (Question 모델에 year, sessionNumber, originalIndex 필드가 있다고 가정)
        final contextualQuestion = questionData.copyWithContext(
            year: noteInfo.year,
            sessionNumber: noteInfo.sessionNumber,
            originalIndex: noteInfo.questionIndex
        );
        // ------------------------------------------------------------------

        if (mounted) {
          setState(() {
            _currentFullQuestion = contextualQuestion; // 로드된 Question 객체 저장
            _isLoading = false;
          });
        }
      } else { throw Exception('Invalid question index (${noteInfo.questionIndex}) in JSON for ${noteInfo.year}-${noteInfo.sessionNumber}.'); }
    } catch (e, stacktrace) {
      print('Error loading full question data for review: $e\n$stacktrace');
      if (mounted) { setState(() { _loadingError = '문제 데이터 로딩 오류: $e'; _isLoading = false; }); }
    }
  }// _loadFullQuestionData 끝

  void _navigateToQuestion(int newIndex) {
    if (!mounted || newIndex < 0 || newIndex >= _totalNotesInReview) return;
    setState(() {
      _currentIndex = newIndex;
      _isLoading = true; // 새 문제 로딩 시작 표시
    });
    _loadFullQuestionData(_currentNotesInReview[newIndex]); // 새 인덱스의 노트 정보로 문제 로드
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
        // 목록이 비었으면 이전 화면으로 돌아감
        print("All notes deleted, popping back.");
        Navigator.pop(context);
      } else {
        // 다음 표시할 인덱스 결정 (삭제된 위치 또는 그 이전)
        int nextIndexToShow = (indexToDelete >= newTotal) ? newTotal - 1 : indexToDelete;

        // --- ★★★ setState 호출하여 인덱스 및 목록 상태 업데이트 후, 새 데이터 로드 ★★★ ---
        setState(() {
          _currentNotesInReview = updatedNotes; // 업데이트된 리스트 반영
          _totalNotesInReview = newTotal;      // 업데이트된 총 개수 반영
          _currentIndex = nextIndexToShow;     // 다음 인덱스로 설정
          _isLoading = true;                   // 새 문제 로딩 시작 표시
        });
        // 업데이트된 인덱스의 노트 정보로 다음 문제 로드
        _loadFullQuestionData(_currentNotesInReview[nextIndexToShow]);
        // ------------------------------------------------------------
      }
    } else if (mounted && !deletionSuccessful) {
      // 삭제 실패 처리
      print("Delete error: Note not found in storage for index $indexToDelete.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('삭제 오류: 해당 오답 정보를 찾을 수 없거나 이미 삭제되었습니다.'), duration: Duration(seconds: 2)),);
      Navigator.pop(context); // 실패 시에도 이전 화면으로
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
    final Question question = _currentFullQuestion!;
    final int currentReviewNumber = _currentIndex + 1; // 인덱스는 0부터 시작

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentNoteInfo.year}년 ${currentNoteInfo.sessionNumber}회차 - ${question.number}번 복습'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.white),
            tooltip: '오답 노트에서 삭제',
            onPressed: () async {
              // --- ★★★ 삭제 확인 Dialog (AppBar에서 호출) ★★★ ---
              bool? confirmed = await showDialog<bool>(context: context, builder: (BuildContext ctx) {
                return AlertDialog(title: const Text('삭제 확인'), content: Text('${currentNoteInfo.year}년 ${currentNoteInfo.sessionNumber}회차 - ${question.number}번 문제를 오답 노트에서 삭제하시겠습니까?'),
                  actions: <Widget>[
                    TextButton(child: const Text('취소'), onPressed: () => Navigator.of(ctx).pop(false)),
                    TextButton(child: const Text('삭제', style: TextStyle(color: Colors.red)), onPressed: () { Navigator.of(ctx).pop(true); }),
                  ],);
              });
              if (confirmed == true) {
                _deleteCurrentNote(); // 확인 시 삭제 함수 호출
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
      padding: const EdgeInsets.symmetric(vertical: 8.0), // 위아래 여백
      child: Text(
        // currentNoteInfo에서 year/session, question에서 number 가져오기
        '${currentNoteInfo.year}년 ${currentNoteInfo.sessionNumber}회차 ${question.number}번',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    ),
            Expanded(
              child: QuestionViewer(
                // ValueKey는 currentIndex와 노트 자체의 고유성을 조합하는 것이 더 안전할 수 있음
                key: ValueKey('${currentNoteInfo.year}_${currentNoteInfo.sessionNumber}_${currentNoteInfo.questionIndex}'),
                question: question,
              ),
            ),
            // --------------------
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
    );
  }
} // _IncorrectNoteReviewScreenState 끝