import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// --- 올바른 Import 경로 확인 ---
import 'models/question.dart';
import 'models/incorrect_question_info.dart';
import 'services/incorrect_note_service.dart';
import 'package:flutter_math_fork/flutter_math.dart';
// ---------------------------

class QuestionScreen extends StatefulWidget {
  final int year;
  final int sessionNumber;
  final int initialIndex;

  const QuestionScreen({
    super.key,
    required this.year,
    required this.sessionNumber,
    this.initialIndex = 0,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // --- 상태 변수 ---
  List<Question> _loadedQuestions = [];
  bool _isLoading = true;
  String _loadingError = '';
  int _totalQuestionsInSession = 0;
  int _currentIndex = 0; // 현재 *문제* 인덱스
  String? _assessmentStatus;
  bool _isAnswerVisible = false;
  final IncorrectNoteService _noteService = IncorrectNoteService();
  PageController _pageController = PageController(); // 페이지 뷰 컨트롤러
  int _currentPageIndex = 0; // 현재 *페이지* 인덱스
  int _totalPages = 1; // 현재 문제의 총 페이지 수

  // --- 초기화 ---
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: 0); // PageController 초기화
    _currentPageIndex = 0;
    _loadQuestionData();
  }

  // --- 리소스 해제 ---
  @override
  void dispose() {
    _pageController.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  // --- 데이터 로딩 ---
  Future<void> _loadQuestionData() async {
    if (!mounted) return;
    // 로딩 시작 시 페이지 관련 상태도 초기화 고려
    setState(() {
      _isLoading = true;
      _loadingError = '';
      _isAnswerVisible = false;
      _currentPageIndex = 0;
    });
    try {
      final String filePath = 'assets/data/${widget.year}_${widget
          .sessionNumber}.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<
          String,
          dynamic>;
      final List<dynamic> questionListJson = jsonData['questions'] as List<
          dynamic>? ?? [];
      final List<Question> questions = questionListJson.map((q) =>
          Question.fromJson(q)).whereType<Question>().toList();

      int validInitialIndex = widget.initialIndex;
      if (validInitialIndex >= questions.length || validInitialIndex < 0) {
        validInitialIndex = 0;
      }

      int calculatedTotalPages = 1; // 기본 페이지 수
      if (questions.isNotEmpty && validInitialIndex < questions.length) {
        calculatedTotalPages =
            1 + questions[validInitialIndex].subQuestions.length;
      }

      if (mounted) {
        setState(() {
          _loadedQuestions = questions;
          _totalQuestionsInSession = questions.length;
          _currentIndex = validInitialIndex;
          _totalPages = calculatedTotalPages; // 계산된 총 페이지 수 적용
          _isLoading = false; // 로딩 완료
          // 페이지 컨트롤러가 준비되었는지 확인 후 첫 페이지로 이동
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
          print("Data loaded for Q.${_currentIndex +
              1}, Total Pages: $_totalPages");
        });
      }
    } catch (e, stacktrace) {
      print('Error loading question data: $e\n$stacktrace');
      final String errorFilePath = 'assets/data/${widget.year}_${widget
          .sessionNumber}.json';
      if (mounted) {
        setState(() {
          _loadingError = '문제 로딩 오류 ($errorFilePath)\n$e';
          _isLoading = false;
          _loadedQuestions = [];
          _totalQuestionsInSession = 0;
          _totalPages = 1;
          _currentPageIndex = 0;
        });
      }
    }
  }

  // --- 문제 이동 함수 ---
  void _goToQuestion(int newIndex) {
    if (!mounted || newIndex < 0 || newIndex >= _totalQuestionsInSession)
      return;
    print("Navigating to question index: $newIndex");
    // 페이지 컨트롤러 리셋
    if (_pageController.hasClients && _pageController.page != 0) {
      _pageController.jumpToPage(0);
    }
    setState(() {
      _currentIndex = newIndex;
      _assessmentStatus = null;
      _isAnswerVisible = false;
      _isLoading = true;
      _currentPageIndex = 0;
    }); // 로딩 시작 표시
    _loadQuestionData(); // 새 문제 로드
  }

  // --- 화면 빌드 ---
  @override
  Widget build(BuildContext context) {
    // 로딩/에러 처리
    if (_isLoading) {
      return Scaffold(appBar: AppBar(
          title: Text('${widget.year}년 ${widget.sessionNumber}회차')),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError.isNotEmpty) {
      return Scaffold(appBar: AppBar(
          title: Text('${widget.year}년 ${widget.sessionNumber}회차')),
          body: Center(child: Padding(padding: const EdgeInsets.all(16.0),
              child: Text(_loadingError, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)))));
    }
    final Question? currentQuestionNullable = (_loadedQuestions.isNotEmpty &&
        _currentIndex < _loadedQuestions.length)
        ? _loadedQuestions[_currentIndex]
        : null;
    if (currentQuestionNullable == null) {
      return Scaffold(appBar: AppBar(
          title: Text('${widget.year}년 ${widget.sessionNumber}회차')),
          body: const Center(child: Text('표시할 문제가 없습니다.')));
    }
    final Question question = currentQuestionNullable;
    final int currentQuestionNumber = _currentIndex + 1;

    // 메인 Scaffold
    return Scaffold(
      appBar: AppBar(title: Text('${widget.year}년 ${widget
          .sessionNumber}회차 문제 풀이 ($currentQuestionNumber / $_totalQuestionsInSession)')),

      // ***** body 구조: Column > [문제번호/페이지정보?, Expanded(PageView), 하단 컨트롤] *****
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 문제 번호 및 페이지 정보 (선택적 표시)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '문제 $currentQuestionNumber / $_totalQuestionsInSession' +
                  (_totalPages > 1 ? '  |  페이지 ${_currentPageIndex +
                      1} / $_totalPages (좌우 스와이프)' : ''), // 페이지 정보 추가
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
              textAlign: TextAlign.center,
            ),
          ),

          // PageView 영역
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              itemBuilder: (context, pageIndex) {
                // 각 페이지 내용 빌드
                return _buildPageContent(context, question, pageIndex);
              },
            ),
          ), // Expanded 끝

          // --- 답안/해설 보기 버튼 및 영역 (PageView 아래) ---
          Padding( // 버튼 위 간격
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Center(child: OutlinedButton.icon(icon: Icon(
                _isAnswerVisible ? Icons.visibility_off_outlined : Icons
                    .visibility_outlined),
              label: Text(_isAnswerVisible ? '답안/해설 숨기기' : '답안/해설 보기'),
              onPressed: () {
                setState(() {
                  _isAnswerVisible = !_isAnswerVisible;
                });
              },)),
          ),
          Visibility(
            visible: _isAnswerVisible,
            child: Card( // Card 구조 사용
              elevation: 1.0,
              color: Colors.grey.shade50,
              margin: const EdgeInsets.symmetric(horizontal: 16.0), // 배경색
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery
                      .of(context)
                      .size
                      .height * 0.3, // 예시: 화면 높이의 30%
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column( // 내용 세로 배치
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Case 1: 소문제 없는 경우
                      if (question.subQuestions.isEmpty) ...[
                        // _buildAnswerExplanationSection 호출 (4개 인자 전달)
                        if((question.answer?.isNotEmpty ?? false) || (question
                            .answerImagePaths?.isNotEmpty ?? false))
                          _buildAnswerExplanationSection(
                              context, '모범 답안', question.answer, question
                              .answerImagePaths, Colors.blue.shade50),
                        if((question.explanation?.isNotEmpty ?? false) ||
                            (question.explanationImagePaths?.isNotEmpty ??
                                false))
                          Padding(padding: const EdgeInsets.only(top: 16.0),
                              child: _buildAnswerExplanationSection(
                                  context, '해설', question.explanation,
                                  question.explanationImagePaths,
                                  Colors.green.shade50)),
                      ]
                      // Case 2: 소문제 있는 경우
                      else
                        ...[
                          // 각 소문제 답/해설
                          ...question.subQuestions.map((sub) {
                            final bool subHasAnswer = (sub.answer?.isNotEmpty ??
                                false) ||
                                (sub.answerImagePaths?.isNotEmpty ?? false);
                            final bool subHasExplanation = (sub.explanation
                                ?.isNotEmpty ?? false) ||
                                (sub.explanationImagePaths?.isNotEmpty ??
                                    false);
                            if (!subHasAnswer && !subHasExplanation)
                              return const SizedBox.shrink(); // 내용 없으면 빈 위젯 반환
                            // 내용 있으면 Column 반환
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
                                  // _buildAnswerExplanationSection 호출 (4개 인자 전달)
                                  if(subHasAnswer) _buildAnswerExplanationSection(
                                      context, null, sub.answer,
                                      sub.answerImagePaths,
                                      Colors.blue.shade50),
                                  if(subHasExplanation) Padding(
                                      padding: EdgeInsets.only(
                                          top: subHasAnswer ? 8.0 : 0),
                                      child: _buildAnswerExplanationSection(
                                          context, null, sub.explanation,
                                          sub.explanationImagePaths,
                                          Colors.green.shade50)),
                                ],
                              ),
                            );
                          }).toList(), // map 끝


                          // 최상위 답/해설 (존재할 경우)
                          if((question.answer?.isNotEmpty ?? false) || (question
                              .answerImagePaths?.isNotEmpty ?? false)) ...[
                            const Divider(height: 24.0, thickness: 1.0),
                            _buildAnswerExplanationSection(
                                context, '종합 답안', question.answer,
                                question.answerImagePaths,
                                Colors.blue.shade100), // 4개 인자 전달
                          ],
                          if((question.explanation?.isNotEmpty ?? false) ||
                              (question.explanationImagePaths?.isNotEmpty ??
                                  false)) ...[
                            const SizedBox(height: 8.0),
                            _buildAnswerExplanationSection(
                                context, '종합 해설', question.explanation,
                                question.explanationImagePaths,
                                Colors.green.shade100), // 4개 인자 전달
                          ],
                        ]
                    ],),),),),),
          const SizedBox(height: 8.0), // 하단 버튼과의 간격
          // ----------------------------------------------------
        ],
      ),
      // **************************************************

      // 하단 고정 버튼
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [ // 평가 버튼
                  ElevatedButton(onPressed: () {
                    setState(() {
                      _assessmentStatus = '맞음';
                    });
                  },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _assessmentStatus == '맞음' ? Colors
                              .green : null),
                      child: const Text('맞음')),
                  ElevatedButton(onPressed: () {
                    setState(() {
                      _assessmentStatus = '보류';
                    });
                  },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _assessmentStatus == '보류' ? Colors
                              .orange : null),
                      child: const Text('보류')),
                  ElevatedButton( // 틀림 버튼
                      onPressed: () async { // async 확인!
                        // question 변수가 이 스코프에서 non-null 임을 확인 (build 메소드 상단에서 처리됨)
                        final incorrectInfo = IncorrectQuestionInfo(
                          year: widget.year,
                          sessionNumber: widget.sessionNumber,
                          questionIndex: _currentIndex,
                          questionTextSnippet: question.questionText.substring(
                              0, (question.questionText.length > 50
                              ? 50
                              : question.questionText.length)),
                        );

                        // 1. 현재 노트 로드
                        print("Loading current notes before adding...");
                        List<
                            IncorrectQuestionInfo> currentNotes = await _noteService
                            .loadIncorrectNotes();
                        print("Loaded ${currentNotes.length} notes.");

                        // 2. 중복 체크
                        bool alreadyExists = currentNotes.any((note) =>
                        note == incorrectInfo);

                        // 3. 추가 또는 메시지 표시
                        if (!alreadyExists) {
                          currentNotes.add(incorrectInfo); // 리스트에 추가
                          await _noteService.saveIncorrectNotes(
                              currentNotes); // 저장!
                          print("Saved ${currentNotes.length} notes.");
                          // 저장 후 SnackBar 표시 (mounted 확인 필수)
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${widget.year}년 ${widget
                                    .sessionNumber}회차 ${incorrectInfo
                                    .questionIndex + 1}번 오답 추가'),
                                    duration: const Duration(seconds: 2))
                            );
                          }
                        } else {
                          // 이미 존재할 경우 SnackBar 표시 (mounted 확인 필수)
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                    '이미 오답 노트에 있는 문제입니다.'),
                                    duration: const Duration(seconds: 2))
                            );
                          }
                        }

                        // 4. UI 상태 업데이트 (버튼 색상 변경 등)
                        if (mounted) {
                          setState(() {
                            _assessmentStatus = '틀림';
                          });
                        }
                      }, // onPressed 끝
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _assessmentStatus == '틀림' ? Colors
                              .red : null), child: const Text('틀림')
                  ),
                ]),
          ],),)
      ],
    ); // Scaffold 끝
  } // build 메소드 끝

  // --- Helper Widgets (정의는 한 번씩만!) ---

  // 페이지 내용 생성 헬퍼
  Widget _buildPageContent(BuildContext context, Question question,
      int pageIndex) {
    return SingleChildScrollView( // 각 페이지 내용 스크롤 가능하도록
      key: PageStorageKey('page_$pageIndex'), // 페이지 상태 유지 (선택 사항)
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 페이지 0: 메인 문제 + 보충 정보
        if (pageIndex == 0) ...[
          Card(
            elevation: 2.0,
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildMixedContent(context, question.questionText, Theme
                  .of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.5)),
              if (question.imagePaths?.isNotEmpty ?? false) Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(children: question.imagePaths!.map((path) =>
                    Padding(padding: const EdgeInsets.only(bottom: 8.0),
                        child: Image.asset(path))).toList()),),
              if (question.tableData?.isNotEmpty ?? false) Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildDataTable(context, question.tableData!)),
            ],),),),
          if (question.supplementaryInfo?.isNotEmpty ?? false) Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                border: Border.all(color: Colors.blueGrey.shade200),
                borderRadius: BorderRadius.circular(8.0),),
              child: _buildMixedContent(
                  context, question.supplementaryInfo, Theme
                  .of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.4)),),),
          const SizedBox(height: 16.0),
        ]
        // 페이지 1 이상: 소문제 내용
        else
          if (pageIndex > 0 &&
              pageIndex - 1 < question.subQuestions.length) ...[
            Builder(builder: (context) {
              final sub = question.subQuestions[pageIndex - 1];
              return Card(elevation: 1.0,
                margin: const EdgeInsets.only(bottom: 16.0),
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
                      child: Column(children: sub.imagePaths!.map((path) =>
                          Padding(padding: const EdgeInsets.only(bottom: 8.0),
                              child: Image.asset(path))).toList()),),
                    if (sub.tableData?.isNotEmpty ?? false) Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildDataTable(context, sub.tableData!)),
                    if (sub.supplementaryInfo?.isNotEmpty ?? false) Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(width: double.infinity,
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(color: Colors.lime.shade50,
                          border: Border.all(color: Colors.lime.shade200),
                          borderRadius: BorderRadius.circular(6.0),),
                        child: _buildMixedContent(
                            context, sub.supplementaryInfo, Theme
                            .of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.3)),),),
                  ],),),);
            }),
            const SizedBox(height: 16.0),
          ] else
            ...[ const Center(child: Text('잘못된 페이지입니다.'))],
      ],),);
  }

  // 테이블 생성 헬퍼 (최종 수정본 - context 인자, 최종 return 포함)
  Widget _buildDataTable(BuildContext context,
      List<Map<String, dynamic>> tableData) {
    if (tableData.isEmpty) return const SizedBox.shrink(); // 데이터 없으면 빈 위젯 반환
    try {
      // 컬럼 헤더 생성
      final columns = tableData.first.keys.map((key) =>
          DataColumn(
          label: Expanded(child: Text(
              key, style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center)))).toList();
      // 각 행 생성
      final rows = tableData.map((rowMap) {
        // 각 셀 생성
        final cells = columns.map((column) {
          final labelWidget = column.label;
          if (labelWidget is Expanded && labelWidget.child is Text) {
            final key = (labelWidget.child as Text).data;
            if (key != null) {
              final cellValue = rowMap[key];
              // DataCell 내용물 _buildMixedContent로 변경 및 정렬/패딩 적용
              return DataCell(
                  Align( // Align 위젯 사용
                      alignment: Alignment.center,
                      child: Padding( // Padding 추가
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          // 상하 여백 8.0 적용
                          child: _buildMixedContent( // _buildMixedContent 호출 확인
                              context,
                              cellValue?.toString(),
                              Theme
                                  .of(context)
                                  .textTheme
                                  .bodyMedium // bodyMedium 적용 확인
                          )
                      )
                  )
              );
            }
          }
          return const DataCell(Text('')); // 키 오류 시
        }).toList();
        // 컬럼 수 일치 확인 등
        if (cells.length != columns.length) {
          print("Warning: Row data length mismatch...");
        }
        return DataRow(cells: cells);
      }).toList();
      // DataTable 위젯 반환
      return DataTable(columnSpacing: 16.0,
          border: TableBorder.all(color: Colors.grey.shade400, width: 1),
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: columns,
          rows: rows);
    } catch (e) {
      print("Error building table: $e");
      return Text(
          "테이블 표시 오류", style: TextStyle(color: Colors.red)); // 오류 시 Text 위젯 반환
    }
    // ***** 모든 코드 경로에서 Widget 반환 보장 *****
    return const SizedBox.shrink();
    // ***********************************************
  }

  // 답/해설 섹션 생성 헬퍼 (최종 수정본 - context 인자, _buildMixedContent 사용)
  Widget _buildAnswerExplanationSection(BuildContext context, String? title,
      String? text, List<String>? imagePaths, [Color? backgroundColor]) {
    bool hasText = text?.isNotEmpty ?? false;
    bool hasImages = imagePaths?.isNotEmpty ?? false;
    if (!hasText && !hasImages) return const SizedBox.shrink();
    final textTheme = Theme
        .of(context)
        .textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) Padding(padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: textTheme.titleMedium)),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        color: backgroundColor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasText) _buildMixedContent(
              context, text, textTheme.bodyMedium?.copyWith(height: 1.4)),
          // TeX+Text
          if (hasText && hasImages) const SizedBox(height: 12.0),
          if (hasImages) Column(children: imagePaths!.map((path) =>
              Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.asset(path))).toList()),
        ],),),
      const SizedBox(height: 8.0),
    ],);
  }

  // 텍스트/수식 혼합 렌더링 헬퍼 (최종 수정본 - RichText 사용)
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
}// _QuestionScreenState 끝



























Widget _buildPageContent(BuildContext context, Question question,
    int pageIndex) {
  return SingleChildScrollView( // 각 페이지 내용 스크롤 가능하도록
    key: PageStorageKey('page_$pageIndex'), // 페이지 상태 유지 (선택 사항)
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 페이지 0: 메인 문제 + 보충 정보
      if (pageIndex == 0) ...[
        Card(
          elevation: 2.0,
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildMixedContent(context, question.questionText, Theme
                .of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.5)),
            if (question.imagePaths?.isNotEmpty ?? false) Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(children: question.imagePaths!.map((path) =>
                  Padding(padding: const EdgeInsets.only(bottom: 8.0),
                      child: Image.asset(path))).toList()),),
            if (question.tableData?.isNotEmpty ?? false) Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildDataTable(context, question.tableData!)),
          ],),),),
        if (question.supplementaryInfo?.isNotEmpty ?? false) Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              border: Border.all(color: Colors.blueGrey.shade200),
              borderRadius: BorderRadius.circular(8.0),),
            child: _buildMixedContent(
                context, question.supplementaryInfo, Theme
                .of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.4)),),),
        const SizedBox(height: 16.0),
      ]
      // 페이지 1 이상: 소문제 내용
      else
        if (pageIndex > 0 &&
            pageIndex - 1 < question.subQuestions.length) ...[
          Builder(builder: (context) {
            final sub = question.subQuestions[pageIndex - 1];
            return Card(elevation: 1.0,
              margin: const EdgeInsets.only(bottom: 16.0),
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
                    child: Column(children: sub.imagePaths!.map((path) =>
                        Padding(padding: const EdgeInsets.only(bottom: 8.0),
                            child: Image.asset(path))).toList()),),
                  if (sub.tableData?.isNotEmpty ?? false) Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildDataTable(context, sub.tableData!)),
                  if (sub.supplementaryInfo?.isNotEmpty ?? false) Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(width: double.infinity,
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(color: Colors.lime.shade50,
                        border: Border.all(color: Colors.lime.shade200),
                        borderRadius: BorderRadius.circular(6.0),),
                      child: _buildMixedContent(
                          context, sub.supplementaryInfo, Theme
                          .of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.3)),),),
                ],),),);
          }),
          const SizedBox(height: 16.0),
        ] else
          ...[ const Center(child: Text('잘못된 페이지입니다.'))],
    ],),);
}


























Widget _buildPageContent(BuildContext context, Question question,
    int pageIndex) {
  return SingleChildScrollView( // 각 페이지 내용 스크롤 가능하도록
    key: PageStorageKey('page_$pageIndex'), // 페이지 상태 유지 (선택 사항)
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 페이지 0: 메인 문제 + 보충 정보
      if (pageIndex == 0) ...[
        Card(
          elevation: 2.0,
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildMixedContent(context, question.questionText, Theme
                .of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.5)),
            if (question.imagePaths?.isNotEmpty ?? false) Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(children: question.imagePaths!.map((path) =>
                  Padding(padding: const EdgeInsets.only(bottom: 8.0),
                      child: Image.asset(path))).toList()),),
            if (question.tableData?.isNotEmpty ?? false) Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildDataTable(context, question.tableData!)),
          ],),),),
        if (question.supplementaryInfo?.isNotEmpty ?? false) Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              border: Border.all(color: Colors.blueGrey.shade200),
              borderRadius: BorderRadius.circular(8.0),),
            child: _buildMixedContent(
                context, question.supplementaryInfo, Theme
                .of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.4)),),),
        const SizedBox(height: 16.0),
      ]
      // 페이지 1 이상: 소문제 내용
      else
        if (pageIndex > 0 &&
            pageIndex - 1 < question.subQuestions.length) ...[
          Builder(builder: (context) {
            final sub = question.subQuestions[pageIndex - 1];
            return Card(elevation: 1.0,
              margin: const EdgeInsets.only(bottom: 16.0),
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
                    child: Column(children: sub.imagePaths!.map((path) =>
                        Padding(padding: const EdgeInsets.only(bottom: 8.0),
                            child: Image.asset(path))).toList()),),
                  if (sub.tableData?.isNotEmpty ?? false) Padding(
                      padding: const EdgeInsets.only(top: 8.0),

                      child: _buildDataTable(context, sub.tableData!)),
                  if (sub.supplementaryInfo?.isNotEmpty ?? false) Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(width: double.infinity,
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(color: Colors.lime.shade50,
                        border: Border.all(color: Colors.lime.shade200),
                        borderRadius: BorderRadius.circular(6.0),),
                      child: _buildMixedContent(
                          context, sub.supplementaryInfo, Theme
                          .of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.3)),),),
                ],),),);
          }),
          const SizedBox(height: 16.0),
        ] else
          ...[ const Center(child: Text('잘못된 페이지입니다.'))],
    ],),);
}













else
if (pageIndex > 0 &&
pageIndex - 1 < question.subQuestions.length) ...[
Builder(builder: (context) {
final sub = question.subQuestions[pageIndex - 1];
print(">>> Building content for Sub-Question Page: ${pageIndex} (Sub# ${sub.subNumber}) - TEXT ONLY TEST");



return Card(
elevation: 1.0,
margin: const EdgeInsets.only(bottom: 16.0),
child: Padding(padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start, children: [

Text(
'DEBUG: Sub-Question ${sub.subNumber} Simple Text Placeholder.\n이 텍스트가 보이면 Card 구조는 문제 없습니다.',
style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
),
//_buildMixedContent(context,
//'${sub.subNumber} ${sub.questionText}', Theme
//.of(context)
//.textTheme
//.bodyMedium
//?.copyWith(height: 1.4)),

const SizedBox(height: 8.0),
if (sub.imagePaths?.isNotEmpty ?? false) Padding(
padding: const EdgeInsets.only(top: 8.0),
child: Column(children: sub.imagePaths!.map((path) =>
Padding(padding: const EdgeInsets.only(bottom: 8.0),
child: Image.asset(path))).toList()),),
if (sub.tableData?.isNotEmpty ?? false) Padding(
padding: const EdgeInsets.only(top: 8.0),

child: _buildDataTable(context, sub.tableData!)),
if (sub.supplementaryInfo?.isNotEmpty ?? false) Padding(
padding: const EdgeInsets.only(top: 12.0),
child: Container(width: double.infinity,
padding: const EdgeInsets.all(10.0),
decoration: BoxDecoration(color: Colors.lime.shade50,
border: Border.all(color: Colors.lime.shade200),
borderRadius: BorderRadius.circular(6.0),),
child: _buildMixedContent(
context, sub.supplementaryInfo, Theme
    .of(context)
    .textTheme
    .bodySmall
    ?.copyWith(height: 1.3)),),),
],),),);
}),
const SizedBox(height: 16.0),
] else
...[ const Center(child: Text('잘못된 페이지입니다.'))],
],),);
}