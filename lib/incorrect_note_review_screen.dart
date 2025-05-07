import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/incorrect_question_info.dart'; // 경로 확인!
import 'package:sikman/models/question.dart';       // 경로 확인!
import '../services/incorrect_note_service.dart'; // 서비스 import 확인!
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:data_table_2/data_table_2.dart';

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
  // --- 상태 변수 선언 ---
  late int _currentIndex; // 현재 보고 있는 '초기 목록 스냅샷'에서의 인덱스
  Question? _currentFullQuestion; // 현재 표시 중인 문제 전체 데이터
  bool _isLoading = true; // 데이터 로딩 상태
  String _loadingError = ''; // 로딩 에러 메시지
  bool _isAnswerVisible = false; // 답/해설 가시성 상태
  final IncorrectNoteService _noteService = IncorrectNoteService(); // 서비스 객체 생성

  // --- Helper for initState safe setState ---
  void _WidgetsBindingEnsureInitialized() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // initState에서는 초기 목록(widget.initialIncorrectNotes) 사용
    final List<IncorrectQuestionInfo> initialNotes = widget
        .initialIncorrectNotes;
    if (initialNotes.isNotEmpty && _currentIndex >= 0 &&
        _currentIndex < initialNotes.length) {
      _loadFullQuestionData(initialNotes[_currentIndex]);
    } else {
      _WidgetsBindingEnsureInitialized();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingError = '표시할 오답 문제가 없습니다.';
          });
        }
      });
    }
  } // initState 끝

  // --- 데이터 로딩 함수 ---
  Future<void> _loadFullQuestionData(IncorrectQuestionInfo noteInfo) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingError = '';
      _isAnswerVisible = false;
    });
    try {
      final String filePath = 'assets/data/${noteInfo.year}_${noteInfo
          .sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<
          String,
          dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<
          dynamic>? ?? [];
      if (noteInfo.questionIndex >= 0 &&
          noteInfo.questionIndex < questionListJson.length) {
        final questionData = Question.fromJson(
            questionListJson[noteInfo.questionIndex] as Map<String, dynamic>);
        if (mounted) {
          setState(() {
            _currentFullQuestion = questionData;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
            'Invalid question index (${noteInfo.questionIndex}) for ${noteInfo
                .year}-${noteInfo.sessionNumber}.');
      }
    } catch (e, stacktrace) {
      print('Error loading full question data for review: $e\n$stacktrace');
      if (mounted) {
        setState(() {
          _loadingError = '문제 데이터 로딩 오류: $e';
          _isLoading = false;
          _currentFullQuestion = null;
        });
      }
    }
  } // _loadFullQuestionData 끝

  // --- 네비게이션 함수 (초기 목록 기준) ---
  void _navigateToQuestion(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.initialIncorrectNotes
        .length) { // widget.initialIncorrectNotes 사용
      setState(() {
        _currentIndex = newIndex;
      });
      _loadFullQuestionData(widget
          .initialIncorrectNotes[_currentIndex]); // widget.initialIncorrectNotes 사용
    } else {
      print("NavigateToQuestion: Index $newIndex out of bounds.");
      // 목록의 끝/처음에 도달했을 때의 처리 (예: 버튼 비활성화로 이미 처리됨)
    }
  } // _navigateToQuestion 끝

  // --- 삭제 함수 (저장소 직접 로드/수정) ---
  void _deleteCurrentNote() async {
    if (_isLoading) return;
    // 삭제할 대상 정보 (현재 인덱스 기준, 초기 목록 스냅샷에서 가져옴)
    if (_currentIndex < 0 ||
        _currentIndex >= widget.initialIncorrectNotes.length) {
      print("Delete error: Invalid index $_currentIndex.");
      return;
    }
    IncorrectQuestionInfo noteToRemoveFromStorage = widget
        .initialIncorrectNotes[_currentIndex];

    List<IncorrectQuestionInfo> storedNotes = await _noteService
        .loadIncorrectNotes();
    int initialLength = storedNotes.length;
    storedNotes.removeWhere((note) =>
    note == noteToRemoveFromStorage); // == 연산자 사용

    if (storedNotes.length < initialLength) { // 실제로 삭제가 일어났다면
      await _noteService.saveIncorrectNotes(storedNotes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('오답 노트에서 제거되었습니다.'),
            duration: Duration(seconds: 2)),);
        Navigator.pop(context); // 삭제 후 목록 화면으로 돌아감
      }
    } else {
      print("Delete error: Note not found in storage for $_currentIndex.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('삭제 오류: 해당 오답 정보를 찾을 수 없습니다.'),
            duration: Duration(seconds: 2)),);
      }
    }
  } // _deleteCurrentNote 끝

  // --- 빌드 메소드 ---
  @override
  Widget build(BuildContext context) {
    // 초기 목록 스냅샷과 현재 인덱스를 기준으로 정보 가져오기
    final List<IncorrectQuestionInfo> currentDisplayNotes = widget
        .initialIncorrectNotes;
    final int currentReviewNumber = _currentIndex + 1;
    final int totalIncorrectQuestionsInThisReview = currentDisplayNotes.length;
    final IncorrectQuestionInfo? currentNote = (_currentIndex >= 0 &&
        _currentIndex < currentDisplayNotes.length)
        ? currentDisplayNotes[_currentIndex]
        : null;

    // 로딩/에러/Null 처리
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text(
          currentNote != null ? '${currentNote.year}년 ${currentNote
              .sessionNumber}회차' : '오답 복습')),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: AppBar(title: Text(
          currentNote != null ? '${currentNote.year}년 ${currentNote
              .sessionNumber}회차' : '오류')),
          body: Center(child: Padding(padding: const EdgeInsets.all(16.0),
              child: Text(_loadingError, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)))));
    }
    if (currentNote == null) {
      return Scaffold(appBar: AppBar(title: const Text('오류')),
          body: const Center(child: Text('오답 정보를 표시할 수 없습니다.')));
    }
    // _currentFullQuestion null 체크 후 non-nullable 변수 사용
    if (_currentFullQuestion == null) {
      return Scaffold(appBar: AppBar(title: Text(
          '${currentNote.year}년 ${currentNote.sessionNumber}회차 - ${currentNote
              .questionIndex + 1}번')),
          body: const Center(child: Text('문제를 표시할 수 없습니다.')));
    }
    final Question question = _currentFullQuestion!;

    // 메인 화면 반환
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${currentNote.year}년 ${currentNote.sessionNumber}회차 - ${question
                .number}번 복습'),
        actions: [ // 삭제 버튼
          IconButton(icon: const Icon(
              Icons.delete_forever_outlined, color: Colors.white),
            tooltip: '오답 노트에서 삭제',
            onPressed: () {
              showDialog(context: context, builder: (BuildContext ctx) {
                return AlertDialog(title: const Text('삭제 확인'),
                  content: Text('${currentNote.year}년 ${currentNote
                      .sessionNumber}회차 - ${question
                      .number}번 문제를 오답 노트에서 삭제하시겠습니까?'),
                  actions: <Widget>[
                    TextButton(child: const Text('취소'), onPressed: () =>
                        Navigator.of(ctx).pop()),
                    TextButton(child: const Text('삭제', style: TextStyle(
                        color: Colors.red)), onPressed: () {
                      Navigator.of(ctx).pop();
                      _deleteCurrentNote();
                    }),
                  ],);
              });
            },)
        ],
      ),
      body: ListView( // 스크롤 가능 본문
        padding: const EdgeInsets.all(16.0),
        children: [
          // 오답 진행 상태 (초기 목록 기준 총 개수 사용)
          Text('오답 $currentReviewNumber / $totalIncorrectQuestionsInThisReview',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16.0),

          // 문제 표시 영역 (Card 사용)
          Card(elevation: 2.0,
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding(padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildMixedContent(context, question.questionText, Theme
                    .of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.5)),
                if (question.imagePaths?.isNotEmpty ?? false) Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(children: question.imagePaths!
                      .map((path) =>
                      Padding(padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(child: Image.asset(path))))
                      .toList()),),
                if (question.tableImagePath?.isNotEmpty ?? false)
                  Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildTableImage(context, question.tableImagePath)),
                // context 전달
              ],),),),

          // 소문제 표시 영역 (있을 경우)
          if (question.subQuestions.isNotEmpty) ...[
            const Divider(
                height: 32.0, thickness: 1.0, indent: 8.0, endIndent: 8.0),
            ...question.subQuestions.map((sub) {
              return Card(elevation: 1.0,
                margin: const EdgeInsets.only(
                    top: 16.0, left: 12.0, right: 12.0),
                child: Padding(padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildMixedContent(context,
                        '${sub.subNumber} ${sub.questionText}', Theme
                            .of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.4)),
                    const SizedBox(height: 8.0),
                    if (sub.imagePaths?.isNotEmpty ?? false) Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(children: sub.imagePaths!
                          .map((path) =>
                          Padding(padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(child: Image.asset(path))))
                          .toList()),),
                    if (sub.tableImagePath?.isNotEmpty ?? false)
                      Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildTableImage(context, sub.tableImagePath)),
                    if (sub.supplementaryInfo?.isNotEmpty ?? false)
                      Padding(
                        // 소문제의 다른 내용과 간격 주기
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10.0), // 약간 작은 패딩
                          decoration: BoxDecoration(
                            color: Colors.lime.shade50,
                            // 메인 보충 정보와 다른 배경색 (예: 연한 라임색)
                            border: Border.all(color: Colors.lime.shade200),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          // _buildMixedContent 사용하여 내용 표시
                          child: _buildMixedContent(
                              context,
                              sub.supplementaryInfo, // sub 객체의 필드 사용!
                              Theme
                                  .of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                  height: 1.3) // 메인 보충 정보보다 약간 작은 스타일 (예시)
                          ),
                        ),
                      ), // context 전달
                  ],),),);
            }).toList(),
            const Divider(
                height: 32.0, thickness: 1.0, indent: 8.0, endIndent: 8.0),
          ] else
            ...[
              const SizedBox(height: 24.0), // 소문제 없을 때 간격
            ],

          // 답안/해설 보기 버튼
          Center(child: OutlinedButton.icon(icon: Icon(
              _isAnswerVisible ? Icons.visibility_off_outlined : Icons
                  .visibility_outlined),
            label: Text(_isAnswerVisible ? '답안/해설 숨기기' : '답안/해설 보기'),
            onPressed: () {
              setState(() {
                _isAnswerVisible = !_isAnswerVisible;
              });
            },)), // _isAnswerVisible 사용
          const SizedBox(height: 16.0),

          // 답안/해설 표시 영역
          Visibility(
            visible: _isAnswerVisible, // _isAnswerVisible 사용
            child: Card(elevation: 1.0,
              color: Colors.grey.shade50,
              child: Padding(padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Case 1: 소문제 없는 경우 (최상위 답/해설)
                  if (question.subQuestions.isEmpty) ...[
                    if((question.answer?.isNotEmpty ?? false) ||
                        (question.answerImagePaths?.isNotEmpty ??
                            false)) _buildAnswerExplanationSection(
                        context, '모범 답안', question.answer,
                        question.answerImagePaths, Colors.blue.shade50),
                    // context, color 전달
                    if((question.explanation?.isNotEmpty ?? false) ||
                        (question.explanationImagePaths?.isNotEmpty ??
                            false)) Padding(padding: const EdgeInsets.only(
                        top: 16.0),
                        child: _buildAnswerExplanationSection(
                            context, '해설', question.explanation, question
                            .explanationImagePaths, Colors.green.shade50)),
                    // context, color 전달
                  ]
                  // Case 2: 소문제 있는 경우 (각 소문제 + 최상위 답/해설)
                  else
                    ...[
                      ...question.subQuestions.map((sub) {
                        final bool subHasAnswer = (sub.answer?.isNotEmpty ??
                            false) ||
                            (sub.answerImagePaths?.isNotEmpty ?? false);
                        final bool subHasExplanation = (sub.explanation
                            ?.isNotEmpty ?? false) ||
                            (sub.explanationImagePaths?.isNotEmpty ?? false);
                        if (!subHasAnswer && !subHasExplanation)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${sub.subNumber} 답안/해설', style: Theme
                                  .of(context)
                                  .textTheme
                                  .titleSmall),
                              const Divider(height: 8.0),
                              if(subHasAnswer) _buildAnswerExplanationSection(
                                  context, null, sub.answer,
                                  sub.answerImagePaths, Colors.blue.shade50),
                              // context, color 전달
                              if(subHasExplanation) Padding(
                                  padding: EdgeInsets.only(
                                      top: subHasAnswer ? 8.0 : 0),
                                  child: _buildAnswerExplanationSection(
                                      context, null, sub.explanation,
                                      sub.explanationImagePaths,
                                      Colors.green.shade50)),
                              // context, color 전달
                            ],),);
                      }).toList(),
                      // 최상위 답/해설 (존재할 경우)
                      if((question.answer?.isNotEmpty ?? false) ||
                          (question.answerImagePaths?.isNotEmpty ?? false)) ...[
                        const Divider(height: 24.0, thickness: 1.0),
                        _buildAnswerExplanationSection(
                            context, '종합 답안', question.answer,
                            question.answerImagePaths, Colors.blue.shade100),
                      ], // context, color 전달
                      if((question.explanation?.isNotEmpty ?? false) ||
                          (question.explanationImagePaths?.isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 8.0),
                        _buildAnswerExplanationSection(
                            context, '종합 해설', question.explanation,
                            question.explanationImagePaths, Colors.green
                            .shade100),
                      ], // context, color 전달
                    ]
                ],),),),),
          const SizedBox(height: 16.0), // ListView 끝 여백
        ],
      ),
      // 하단 고정 버튼 (이전/다음 버튼 - 초기 목록 기준)
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ElevatedButton( // 이전 버튼
              // 초기 목록 스냅샷 기준 인덱스 사용
              onPressed: _currentIndex > 0 ? () {
                _navigateToQuestion(_currentIndex - 1);
              } : null,
              child: const Text('◀ 이전 오답'),
            ),
            ElevatedButton( // 다음 버튼
              // 초기 목록 스냅샷 기준 인덱스 사용
              onPressed: _currentIndex < totalIncorrectQuestionsInThisReview - 1
                  ? () {
                _navigateToQuestion(_currentIndex + 1);
              }
                  : null,
              child: const Text('다음 오답 ▶'),
            ),
          ],),)
      ],
    ); // Scaffold 끝
  } // build 끝

  // ***** _buildDataTable 함수 정의 전체를 아래 코드로 교체 (두 파일 모두) *****
  // 테이블 생성 헬퍼 (IntrinsicWidth와 IntrinsicColumnWidth 사용)
  // ***** _buildDataTable 함수 정의 전체를 아래 코드로 교체 (두 파일 모두) *****
  // 테이블 생성 헬퍼 (DataTable2 사용)
  // ***** _buildDataTable 함수 정의 전체를 아래 코드로 교체 (두 파일 모두) *****
  // 테이블 생성 헬퍼 (DataTable2 패키지 사용)
  // ***** _buildTableImage 함수 정의 전체를 아래 코드로 교체 (두 파일 모두) *****
  // 테이블 이미지를 표시하는 헬퍼 함수 (Center 위젯 추가)
  // ***** _buildTableImage 함수 정의 전체를 아래 코드로 교체 (두 파일 모두) *****
  // 테이블 이미지를 표시하는 헬퍼 함수 (Center가 Padding을 감싸도록 수정)
  Widget _buildTableImage(BuildContext context, String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const SizedBox.shrink();
    }
    print("--- Building Table Image (Attempting Outer Center Wrap) for path: $imagePath ---");
    try {
      // Center 위젯으로 Padding과 Image를 감싸서 반환
      return Center( // <--- Center가 가장 바깥으로 이동!
        child: Padding( // Center 안쪽에 Padding 배치
          padding: const EdgeInsets.symmetric(vertical: 8.0), // 상하 여백 유지
          child: Image.asset(
            imagePath,
            errorBuilder: (context, error, stackTrace) {
              print("!!! Error loading table image: $imagePath, Error: $error");
              // 오류 발생 시에도 Center 유지
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Text('표 이미지 로딩 오류\n$imagePath', textAlign: TextAlign.center),
                ),
              );
            },
          ),
        ), // Padding 끝
      ); // Center 끝
    } catch (e) {
      print("!!! Exception building table image: $imagePath, Error: $e");
      // 오류 발생 시에도 Center 유지
      return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("표 이미지 표시 오류: $e", style: TextStyle(color: Colors.red)),
          )
      );
    }
    // try-catch 에서 항상 반환하므로 최종 return 불필요
  }
  // *********************************************************************
  // *********************************************************************

  Widget _buildAnswerExplanationSection(BuildContext context, String? title,
      String? text, List<String>? imagePaths, [Color? backgroundColor]) {
    // <-- context 추가!
    bool hasText = text?.isNotEmpty ?? false;
    bool hasImages = imagePaths?.isNotEmpty ?? false;
    if (!hasText && !hasImages) return const SizedBox.shrink();
    final textTheme = Theme
        .of(context)
        .textTheme; // context 사용
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) Padding(padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: textTheme.titleMedium)),
      Container(width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        color: backgroundColor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasText) // _buildMixedContent 사용
            _buildMixedContent(
                context, text, textTheme.bodyMedium?.copyWith(height: 1.4)),
          if (hasText && hasImages) const SizedBox(height: 12.0),
          if (hasImages) Column(children: imagePaths!.map((path) =>
              Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(child: Image.asset(path)))).toList()),
        ],),),
      const SizedBox(height: 8.0),
    ],);
  }

// ***** 아래 함수 정의 전체로 교체하세요 (두 파일 모두) *****
// 최종 버전: RichText를 사용하여 인라인 수학식 및 자동 줄바꿈 처리
  Widget _buildMixedContent(BuildContext context, String? inputText,
      TextStyle? textStyle) {
    if (inputText == null || inputText.isEmpty) {
      return const SizedBox.shrink(); // 입력 없으면 빈 위젯
    }

    List<InlineSpan> spans = []; // TextSpan 또는 WidgetSpan을 담을 리스트
    // --- 수정: $...$ 만 찾는 단순화된 정규식 ---
    final RegExp regex = RegExp(r'(\$.*?\$)'); // $로 시작하고 $로 끝나는 가장 짧은 문자열 찾기
    // --------------------------------------

    // 이전과 동일하게 splitMapJoin 사용
    inputText.splitMapJoin(
      regex,
      onMatch: (Match match) { // $...$ 수학식 부분 처리
        String mathContent = match.group(0) ?? '';
        // 앞뒤 $ 제거
        if (mathContent.length >= 2) {
          mathContent = mathContent.substring(1, mathContent.length - 1);
        }
        if (mathContent.isNotEmpty) {
          // WidgetSpan으로 Math.tex 추가
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline, // 기준선 정렬
            baseline: TextBaseline.alphabetic, // 알파벳 기준선 사용
            child: Math.tex( // Math.tex 위젯
              // JSON의 \\가 Dart에서 \가 되므로 추가 처리 불필요할 수 있음
              // 만약 \alpha 등이 그대로 보이면 아래 주석 해제 시도
              // mathContent.replaceAll(r'\\', r'\'),
              mathContent,
              textStyle: textStyle, // 기본 텍스트 스타일 적용
              mathStyle: MathStyle.text, // 인라인 스타일 고정
              onErrorFallback: (FlutterMathException e) { // 오류 발생 시
                print("Math Error: ${e.message} in TeX: $mathContent");
                // 오류 발생 시 원래 $...$ 텍스트를 빨간색으로 표시
                return Text(match.group(0)!,
                    style: textStyle?.copyWith(color: Colors.red));
              },
            ),
          ));
        }
        return ''; // 처리 완료 문자열 반환 (splitMapJoin 요구사항)
      },
      onNonMatch: (String nonMatch) { // $...$ 가 아닌 일반 텍스트 부분 처리
        if (nonMatch.isNotEmpty) {
          // TextSpan으로 일반 텍스트 추가
          spans.add(TextSpan(text: nonMatch, style: textStyle));
        }
        return ''; // 처리 완료 문자열 반환
      },
    );
    if (spans.isEmpty) {
      // 입력은 있었지만 파싱 결과 내용이 없으면 빈 위젯 반환
      print(
          "Warning: _buildMixedContent resulted in empty spans for input: $inputText");
      return const SizedBox.shrink();
    }
    // 생성된 Span들로 RichText 위젯 생성하여 반환
    return RichText(
      text: TextSpan(
        // RichText 전체에 기본 스타일 적용 (children에서 개별 스타일 지정 가능)
        style: textStyle,
        children: spans,
      ),
    );
  }
}
// --- State 클래스 끝 ---
// _IncorrectNoteReviewScreenState 끝 (추가 괄호 없음 확인!)