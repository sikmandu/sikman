import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // 올바른 import
import 'models/question.dart'; // Model import 확인
import 'models/incorrect_question_info.dart'; // Model import 확인
import 'services/incorrect_note_service.dart'; // 경로 주의!
import 'package:flutter_math_fork/flutter_math.dart';

class QuestionScreen extends StatefulWidget {
  final int year;
  final int sessionNumber;
  final int initialIndex;

  // 생성자
  const QuestionScreen({
    super.key,
    required this.year,
    required this.sessionNumber,
    this.initialIndex = 0,
  });

  // createState 메소드 (필수)
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // --- 상태 변수 선언 ---
  List<Question> _loadedQuestions = [];
  bool _isLoading = true;
  String _loadingError = '';
  int _totalQuestionsInSession = 0;
  int _currentIndex = 0;
  String? _assessmentStatus;
  bool _isAnswerVisible = false;
  final IncorrectNoteService _noteService = IncorrectNoteService(); // 서비스 객체 추가
  // ... initState, _loadQuestionData 등 ...
  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    // 위젯의 초기 인덱스로 현재 인덱스 설정 (유효성 검사는 로딩 후 수행)
    _currentIndex = widget.initialIndex;
    // 데이터 로딩 함수 호출
    _loadQuestionData();
  }

  // --- 데이터 로딩 함수 ---
  Future<void> _loadQuestionData() async {
    if (!mounted) return; // 비동기 작업 전 위젯 마운트 상태 확인
    setState(() { _isLoading = true; _loadingError = ''; }); // 로딩 시작 상태 설정

    try {
      final String filePath = 'assets/data/${widget.year}_${widget.sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath); // rootBundle 사용 확인
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<dynamic>? ?? [];
      final List<Question> questions = questionListJson
          .map((questionJson) {
        if (questionJson is Map<String, dynamic>) {
          return Question.fromJson(questionJson);
        } else {
          print("Warning: Invalid item found in questions list: $questionJson");
          return null; // 잘못된 항목은 null 반환
        }
      })
          .whereType<Question>() // null이 아닌 Question 객체만 필터링
          .toList();

      // 시작 인덱스 유효성 검사
      int validInitialIndex = widget.initialIndex;
      // 로드된 questions 리스트 기준으로 인덱스 범위 재확인
      if (validInitialIndex >= questions.length || validInitialIndex < 0) {
        validInitialIndex = 0; // 유효하지 않으면 0으로
      }

      if (mounted) { // 상태 업데이트 전 위젯 존재 확인
        setState(() {
          _loadedQuestions = questions;
          _totalQuestionsInSession = questions.length; // 실제 로드된 문제 수
          _currentIndex = validInitialIndex; // 유효한 시작 인덱스 설정
          _isLoading = false; // 로딩 완료!
        });
      }
    } catch (e, stacktrace) { // 에러 발생 시
      print('!!! _loadQuestionData 에러 발생 !!!');
      final String errorFilePath = 'assets/data/${widget.year}_${widget.sessionNumber}.json';
      print('파일 경로: $errorFilePath');
      print('에러 종류: ${e.runtimeType}');
      print('에러 메시지: $e');
      print('스택 트레이스:\n$stacktrace');
      if (mounted) { // 에러 처리 전 위젯 존재 확인
        setState(() {
          // 사용자에게 보여줄 에러 메시지 설정
          _loadingError = '문제 데이터를 불러오는 중 오류가 발생했습니다.\n파일 경로($errorFilePath) 및 JSON 형식을 확인하세요.\n오류: $e';
          _isLoading = false; // 로딩 상태는 끝났다고 표시
          _loadedQuestions = []; // 빈 리스트로 초기화
          _totalQuestionsInSession = 0;
        });
      }
    }
  }

  // --- 화면 구성 (Build Method) ---
  @override
  Widget build(BuildContext context) {
    // 1. 로딩 중 화면 처리
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: const Center(child: CircularProgressIndicator()));
    }

    // 2. 로딩 에러 화면 처리
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_loadingError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)))));
    }

    // 3. 로드된 데이터 유효성 확인 (이 시점에서 _currentIndex는 유효함)
    final Question? currentQuestionNullable = (_loadedQuestions.isNotEmpty && _currentIndex < _loadedQuestions.length)
        ? _loadedQuestions[_currentIndex]
        : null;

    if (currentQuestionNullable == null) {
      // 이 경우는 로딩은 성공했으나 questions 리스트가 비어있거나 인덱스 문제 발생 시
      return Scaffold(appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차')), body: const Center(child: Text('표시할 문제가 없습니다.')));
    }
    // --- 이 시점 이후로는 currentQuestionNullable이 null이 아님 ---
    final Question question = currentQuestionNullable; // Non-nullable 변수 사용
    final int currentQuestionNumber = _currentIndex + 1;

    // 4. 메인 문제 풀이 화면 구성
    return Scaffold(
      appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차 문제 풀이')),
      body: ListView( // 스크롤 가능한 본문
        padding: const EdgeInsets.all(16.0), // 전체 여백
        children: [
          // 문제 번호 표시
          Text('문제 $currentQuestionNumber / $_totalQuestionsInSession', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16.0),

          // 문제 내용 표시 영역 (텍스트, 이미지, 테이블) - Card 사용 및 Null 처리
          Card(
            elevation: 2.0, margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding( padding: const EdgeInsets.all(16.0),
              child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildMixedContent(context, question.questionText, Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                // 메인 이미지 리스트 (Null 및 Empty 체크)
                if (question.imagePaths?.isNotEmpty ?? false)
                  Padding( padding: const EdgeInsets.only(top: 16.0),
                    child: Column(children: question.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),),
                // 메인 테이블 (Null 및 Empty 체크)
                if (question.tableData?.isNotEmpty ?? false)
                  Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildDataTable(context, question.tableData!)),
              ],),),
          ),

          // 소문제 표시 영역 (Null 및 Empty 체크)
          if (question.subQuestions.isNotEmpty) ...[ // subQuestions는 non-nullable List (fromJson에서 []로 초기화)
            const Divider(height: 32.0, thickness: 1.0), // 구분선
            ...question.subQuestions.map((sub) {
              return Card( elevation: 1.0, margin: const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Padding( padding: const EdgeInsets.all(16.0),
                  child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildMixedContent(context, '${sub.subNumber} ${sub.questionText}', Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                    // 소문제 이미지 (Null 및 Empty 체크)
                    if (sub.imagePaths?.isNotEmpty ?? false)
                      Padding( padding: const EdgeInsets.only(top: 12.0),
                        child: Column(children: sub.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),),
                    // 소문제 테이블 (Null 및 Empty 체크)
                    if (sub.tableData?.isNotEmpty ?? false)
                      Padding(padding: const EdgeInsets.only(top: 12.0), child: _buildDataTable(context, sub.tableData!)),
                  ],),),);
            }).toList(),
            const Divider(height: 32.0, thickness: 1.0),
          ] else ...[
            const SizedBox(height: 24.0), // 소문제 없을 때 간격
          ],

          // 답안/해설 보기 버튼
          Center(child: OutlinedButton.icon(
            icon: Icon(_isAnswerVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_isAnswerVisible ? '답안/해설 숨기기' : '답안/해설 보기'),
            onPressed: () { setState(() { _isAnswerVisible = !_isAnswerVisible; }); }, // _isAnswerVisible 사용
          )),
          const SizedBox(height: 16.0),

          // 답안/해설 표시 영역
          // ***** Visibility 위젯 전체를 아래 내용으로 교체하세요 *****
          Visibility(
            visible: _isAnswerVisible, // _isAnswerVisible 사용
            child: Card( // Card 구조 사용
              elevation: 1.0,
              color: Colors.grey.shade50, // 카드 배경색
              child: Padding(
                padding: const EdgeInsets.all(16.0), // 카드 내부 여백
                child: Column( // 답/해설 내용을 세로로 배치
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Case 1: 소문제 없는 경우
                    if (question.subQuestions.isEmpty) ...[
                      // _buildAnswerExplanationSection 호출 시 인자 순서 확인! (context, title, text, imagePaths, color)
                      if((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false))
                        _buildAnswerExplanationSection(context, '모범 답안', question.answer, question.answerImagePaths, Colors.blue.shade50), // 순서 확인!
                      if((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false))
                        Padding( padding: const EdgeInsets.only(top: 16.0), child: _buildAnswerExplanationSection(context, '해설', question.explanation, question.explanationImagePaths, Colors.green.shade50)), // 순서 확인!
                    ]
                    // Case 2: 소문제 있는 경우
                    else ...[
                      // 각 소문제 답/해설
                      ...question.subQuestions.map((sub) {
                        final bool subHasAnswer = (sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false);
                        final bool subHasExplanation = (sub.explanation?.isNotEmpty ?? false) || (sub.explanationImagePaths?.isNotEmpty ?? false);
                        if (!subHasAnswer && !subHasExplanation) return const SizedBox.shrink(); // 내용 없으면 표시 안 함
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${sub.subNumber} 답안/해설', style: Theme.of(context).textTheme.titleSmall), const Divider(height: 8.0),
                              // _buildAnswerExplanationSection 호출 시 인자 순서 확인! (context, title, text, imagePaths, color)
                              if(subHasAnswer) _buildAnswerExplanationSection(context, null, sub.answer, sub.answerImagePaths, Colors.blue.shade50), // 순서 확인!
                              if(subHasExplanation) Padding(padding: EdgeInsets.only(top: subHasAnswer ? 8.0 : 0), child: _buildAnswerExplanationSection(context, null, sub.explanation, sub.explanationImagePaths, Colors.green.shade50)), // 순서 확인!
                            ],
                          ),
                        );
                      }).toList(), // map 끝

                      // 최상위 답/해설 (존재할 경우)
                      // _buildAnswerExplanationSection 호출 시 인자 순서 확인!
                      if((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false)) ...[
                        const Divider(height: 24.0, thickness: 1.0),
                        _buildAnswerExplanationSection(context, '종합 답안', question.answer, question.answerImagePaths, Colors.blue.shade100), // 순서 확인!
                      ],
                      if((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 8.0),
                        _buildAnswerExplanationSection(context, '종합 해설', question.explanation, question.explanationImagePaths, Colors.green.shade100), // 순서 확인!
                      ],
                    ]
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
      // 하단 고정 버튼
      persistentFooterButtons: [
        Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column( mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ // 평가 버튼
              ElevatedButton(onPressed: () { setState(() { _assessmentStatus = '맞음'; }); }, style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '맞음' ? Colors.green : null), child: const Text('맞음')),
              ElevatedButton(onPressed: () { setState(() { _assessmentStatus = '보류'; }); }, style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '보류' ? Colors.orange : null), child: const Text('보류')),
              ElevatedButton( // 틀림 버튼
                  onPressed: () async { // async 확인!
                    // question 변수가 이 스코프에서 non-null 임을 확인 (build 메소드 상단에서 처리됨)
                    final incorrectInfo = IncorrectQuestionInfo(
                      year: widget.year,
                      sessionNumber: widget.sessionNumber,
                      questionIndex: _currentIndex,
                      questionTextSnippet: question.questionText.substring(0, (question.questionText.length > 50 ? 50 : question.questionText.length)),
                    );

                    // 1. 현재 노트 로드
                    print("Loading current notes before adding...");
                    List<IncorrectQuestionInfo> currentNotes = await _noteService.loadIncorrectNotes();
                    print("Loaded ${currentNotes.length} notes.");

                    // 2. 중복 체크
                    bool alreadyExists = currentNotes.any((note) => note == incorrectInfo);

                    // 3. 추가 또는 메시지 표시
                    if (!alreadyExists) {
                      currentNotes.add(incorrectInfo); // 리스트에 추가
                      await _noteService.saveIncorrectNotes(currentNotes); // 저장!
                      print("Saved ${currentNotes.length} notes.");
                      // 저장 후 SnackBar 표시 (mounted 확인 필수)
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${widget.year}년 ${widget.sessionNumber}회차 ${incorrectInfo.questionIndex + 1}번 오답 추가'), duration: const Duration(seconds: 2))
                        );
                      }
                    } else {
                      // 이미 존재할 경우 SnackBar 표시 (mounted 확인 필수)
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이미 오답 노트에 있는 문제입니다.'), duration: const Duration(seconds: 2))
                        );
                      }
                    }

                    // 4. UI 상태 업데이트 (버튼 색상 변경 등)
                    if(mounted) {
                      setState(() {
                        _assessmentStatus = '틀림';
                      });
                    }
                  }, // onPressed 끝
                  style: ElevatedButton.styleFrom(backgroundColor: _assessmentStatus == '틀림' ? Colors.red : null), child: const Text('틀림')
              ),
            ]),
            const SizedBox(height: 8.0),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ // 이전/다음 버튼
              ElevatedButton(onPressed: _currentIndex > 0 ? () { setState(() { _currentIndex--; _assessmentStatus = null; _isAnswerVisible = false; }); } : null, child: const Text('◀ 이전 문제')),
              ElevatedButton(onPressed: _currentIndex < _totalQuestionsInSession - 1 ? () { setState(() { _currentIndex++; _assessmentStatus = null; _isAnswerVisible = false; }); } : null, child: const Text('다음 문제 ▶')),
            ]),
          ],),)
      ],
    );
  }

  // --- Helper Widgets ---
  // 테이블 생성 헬퍼
  Widget _buildDataTable(BuildContext context, List<Map<String, dynamic>> tableData) { // <--- context 추가!
    if (tableData.isEmpty) return const SizedBox.shrink();
    try {
      // 첫 번째 행의 키들을 사용하여 컬럼 헤더 생성
      final columns = tableData.first.keys.map((key) => DataColumn(label: Expanded(child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)))).toList();
      // 각 행 데이터를 DataRow로 변환
      final rows = tableData.map((rowMap) {
        final cells = columns.map((column) {
          final labelWidget = column.label;
          if (labelWidget is Expanded && labelWidget.child is Text) {
            final key = (labelWidget.child as Text).data;
            if (key != null) {
              final cellValue = rowMap[key];
              return DataCell(Center(child: Text(cellValue?.toString() ?? '')));
            }
          }
          return const DataCell(Text('')); // 키 추출 실패 시
        }).toList();
        // 컬럼 수 일치 확인 (선택적)
        if (cells.length != columns.length) { print("Warning: Row data length mismatch..."); }
        return DataRow(cells: cells);
      }).toList();
      // DataTable 위젯 반환
      return DataTable( columnSpacing: 16.0, border: TableBorder.all(color: Colors.grey.shade400, width: 1), headingRowColor: MaterialStateProperty.all(Colors.grey.shade200), columns: columns, rows: rows );
    } catch (e) {
      print("Error building table: $e");
      return Text("테이블 표시 오류", style: TextStyle(color: Colors.red));
    }
    // ***** 추가: 모든 코드 경로에서 Widget 반환 보장 *****
    return const SizedBox.shrink();
    // ***********************************************
  }

  // 답/해설 섹션 생성 헬퍼
  Widget _buildAnswerExplanationSection(BuildContext context, String? title, String? text, List<String>? imagePaths, [Color? backgroundColor]) { // <--- context 추가!
    bool hasText = text?.isNotEmpty ?? false;
    bool hasImages = imagePaths?.isNotEmpty ?? false;
    if (!hasText && !hasImages) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme; // context 사용 가능

    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: textTheme.titleMedium)),
      Container( width: double.infinity, padding: const EdgeInsets.all(8.0), color: backgroundColor,
        child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasText)
            _buildMixedContent(context, text, textTheme.bodyMedium?.copyWith(height: 1.4)),
          if (hasText && hasImages) const SizedBox(height: 12.0),
          if (hasImages) Column(children: imagePaths!.map((path) => Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),
        ],),),
      const SizedBox(height: 8.0),
    ],);
    // 이 함수는 마지막 return 불필요
  }
  Widget _buildMixedContent(BuildContext context, String? inputText, TextStyle? textStyle) {
    if (inputText == null || inputText.isEmpty) {
      return const SizedBox.shrink(); // 입력 없으면 빈 위젯
    }

    List<Widget> children = []; // 생성될 위젯들을 담을 리스트
    // $...$ 패턴 또는 $가 나오기 전까지의 일반 텍스트 패턴으로 문자열 분리
    // (주의: 복잡한 중첩 $는 처리 못할 수 있음)
    final RegExp regex = RegExp(r'(\$.*?\$)'); // $로 감싸진 부분 찾기

    inputText.splitMapJoin(
      regex,
      onMatch: (Match match) { // $...$ 부분 (수학식) 처리
        String mathContent = match.group(0) ?? '';
        // 앞뒤 $ 제거
        if (mathContent.length >= 2) {
          mathContent = mathContent.substring(1, mathContent.length - 1);
        }
        if (mathContent.isNotEmpty) {
          children.add(
              Padding( // 수식 위젯 좌우에 약간의 공백 추가 (선택 사항)
                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                child: Math.tex(
                  mathContent, // $ 제거된 TeX 코드 전달
                  textStyle: textStyle,
                  mathStyle: MathStyle.text, // 기본적으로 인라인 스타일 사용
                  onErrorFallback: (FlutterMathException e) {
                    print("Math Error: ${e.message} in TeX: $mathContent");
                    // 오류 발생 시 원본 텍스트 (빨간색) 표시
                    return Text(match.group(0)!, style: textStyle?.copyWith(color: Colors.red));
                  },
                ),
              )
          );
        }
        return ''; // 처리 완료
      },
      onNonMatch: (String nonMatch) { // $...$ 가 아닌 부분 (일반 텍스트) 처리
        if (nonMatch.isNotEmpty) {
          // Text 위젯 사용 (자동 줄바꿈 및 띄어쓰기 적용됨)
          children.add(Text(nonMatch, style: textStyle));
        }
        return ''; // 처리 완료
      },
    );

    // 생성된 Text/Math.tex 위젯들을 Wrap 위젯으로 감싸서 반환
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center, // 세로 정렬 (텍스트 기준선)
      alignment: WrapAlignment.start, // 가로 정렬
      spacing: 4.0, // 위젯 사이의 가로 간격 (선택 사항)
      runSpacing: 0.0, // 줄 사이의 세로 간격 (선택 사항)
      children: children, // 생성된 위젯 리스트
    );
  }
// --- State 클래스 끝 ---
}