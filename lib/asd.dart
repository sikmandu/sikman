import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // 올바른 import
import 'package:sikman/models/question.dart'; // Model import 확인
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
  // --- 페이지 관련 상태 변수 추가 ---
  PageController _pageController = PageController(); // 페이지 뷰 컨트롤러
  int _currentPageIndex = 0; // 현재 보고 있는 *페이지* 인덱스 (0부터 시작)
  int _totalPages = 1; // 현재 문제의 총 페이지 수 (문제 로드 후 계산)
  // ------------------------------
  // ... initState, _loadQuestionData 등 ...
  // --- 초기화 ---

  @override
  void initState() {
    super.initState();
    // 위젯의 초기 인덱스로 현재 인덱스 설정 (유효성 검사는 로딩 후 수행)
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: 0); // PageController 초기화
    _currentPageIndex = 0;
    // 데이터 로딩 함수 호출
    _loadQuestionData();
  }
  void _goToQuestion(int newIndex) {
    if (!mounted || newIndex < 0 || newIndex >= _totalQuestionsInSession) return;
    print("Navigating to question index: $newIndex");
    // 페이지 컨트롤러 리셋 (페이지 0으로)
    if (_pageController.hasClients && _pageController.page != 0) { _pageController.jumpToPage(0); }

    setState(() {
      _currentIndex = newIndex;         // 문제 인덱스 변경
      _assessmentStatus = null;         // 평가 상태 초기화
      _isAnswerVisible = false;        // 답/해설 숨김
      _isLoading = true;              // 새 문제 로딩 시작 표시
      _currentPageIndex = 0;          // 현재 '페이지' 인덱스도 0으로 리셋
    });
    _loadQuestionData(); // 새 문제 데이터 로드 시작 (이 안에서 isLoading=false, totalPages 계산됨)
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
          _isLoading = false;
          if (_loadedQuestions.isNotEmpty && _currentIndex < _loadedQuestions.length) {
            // 현재 유효한 문제를 기준으로 페이지 수 계산
            final Question currentQ = _loadedQuestions[_currentIndex];
            _totalPages = 1 + currentQ.subQuestions.length; // 페이지 수 = 메인 문제 1 + 소문제 개수
          } else {
            _totalPages = 1; // 문제가 없거나 잘못된 경우 기본값 1
          }
          _currentPageIndex = 0; // 페이지 인덱스 초기화// 로딩 완료!
          // 페이지 컨트롤러 초기화 (필요시)
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0); // 첫 페이지로 이동
          }
          print("Data loaded for Q.${_currentIndex + 1}, Total Pages: $_totalPages"); // 디버깅 로그
        }
        );
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
  @override
  void dispose() {
    print("Disposing QuestionScreen State and PageController"); // 디버깅 로그 (선택 사항)
    _pageController.dispose(); // PageController 리소스 해제! (필수)
    super.dispose(); // State 클래스의 기본 dispose 호출 (필수)
    print("QuestionScreen disposed."); // 디버깅 로그 (선택 사항)
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
    print("--- Build Method: Checking supplementaryInfo before returning Scaffold ---");
    print("Value: ${question.supplementaryInfo}");
    final bool shouldShowSuppInfo = question.supplementaryInfo?.isNotEmpty ?? false;
    print("Condition result (should show box?): $shouldShowSuppInfo");
    print("-------------------------------------------------------------------");
    // ************************************
    // 4. 메인 문제 풀이 화면 구성
    return Scaffold(
      appBar: AppBar(title: Text('${widget.year}년 ${widget.sessionNumber}회차 문제 풀이 ($currentQuestionNumber / $_totalQuestionsInSession)')),
      body: Column( // 스크롤 가능한 본문
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_totalPages > 1) // 페이지가 1개 초과일 때만 표시
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '페이지 ${_currentPageIndex + 1} / $_totalPages',
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ),
          // 문제 번호 표시
          Expanded(
            child: PageView.builder(
              controller: _pageController, // 컨트롤러 연결
              itemCount: _totalPages,     // 총 페이지 수
              onPageChanged: (index) {    // 페이지 스와이프 시 호출됨
                setState(() {
                  _currentPageIndex = index; // 현재 페이지 상태 업데이트
                });
              },
              itemBuilder: (context, pageIndex) { // 각 페이지 생성
                // 위에서 만든 헬퍼 함수 호출
                return _buildPageContent(context, question, pageIndex);
              },
            ),
          ),

          Padding( // 버튼과 위아래 간격
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: OutlinedButton.icon(
              icon: Icon(_isAnswerVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              label: Text(_isAnswerVisible ? '답안/해설 숨기기' : '답안/해설 보기'),
              onPressed: () { setState(() { _isAnswerVisible = !_isAnswerVisible; }); },)),
          ),

          // 문제 내용 표시 영역 (텍스트, 이미지, 테이블) - Card 사용 및 Null 처리
          Card(
            color: Colors.white,
            elevation: 2.0, margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding( padding: const EdgeInsets.all(16.0),
              child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Math.tex 사용 (TeX + Text 렌더링)
                _buildMixedContent(context, question.questionText, Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                // 메인 이미지 리스트 (Null 및 Empty 체크)
                if (question.imagePaths?.isNotEmpty ?? false)
                  Padding( padding: const EdgeInsets.only(top: 16.0),
                    child: Column(children: question.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Container(child: Image.asset(path)))).toList()),),
                // 메인 테이블 (Null 및 Empty 체크)
                if (question.tableData?.isNotEmpty ?? false)
                  Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildDataTable(context, question.tableData!)), // context 전달 확인
              ],),),
          ),
          // --- 추가: 보충 정보 박스 (올바른 위치) ---
          if (question.supplementaryInfo?.isNotEmpty ?? false) // <--- if 블록 안 print 추가!
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration( color: Colors.blueGrey.shade50, border: Border.all(color: Colors.blueGrey.shade200), borderRadius: BorderRadius.circular(8.0),),
                child: _buildMixedContent(context, question.supplementaryInfo, Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)), // _buildMixedContent 사용
              ),
            ),
          // ------------------------------------

          // 소문제 표시 영역
          if (question.subQuestions.isNotEmpty) ...[
            const Divider(height: 32.0, thickness: 1.0, indent: 8.0, endIndent: 8.0),
            // 각 소문제를 Card 안에 표시
            ...question.subQuestions.map((sub) {
              return Card( elevation: 1.0, margin: const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Padding( padding: const EdgeInsets.all(16.0),
                  child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildMixedContent(context, '${sub.subNumber} ${sub.questionText}', Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)), // _buildMixedContent 사용
                    const SizedBox(height: 8.0),
                    if (sub.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 8.0), child: Column(children: sub.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Container(child: Image.asset(path)))).toList()),),
                    if (sub.tableData?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildDataTable(context, sub.tableData!)),
                    if (sub.supplementaryInfo?.isNotEmpty ?? false)
                      Padding(
                        // 소문제의 다른 내용과 간격 주기
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10.0), // 약간 작은 패딩
                          decoration: BoxDecoration(
                            color: Colors.lime.shade50, // 메인 보충 정보와 다른 배경색 (예: 연한 라임색)
                            border: Border.all(color: Colors.lime.shade200),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          // _buildMixedContent 사용하여 내용 표시
                          child: _buildMixedContent(
                              context,
                              sub.supplementaryInfo, // sub 객체의 필드 사용!
                              Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3) // 메인 보충 정보보다 약간 작은 스타일 (예시)
                          ),
                        ),
                      ),// context 전달 확인
                  ],),),);
            }).toList(),
            const Divider(height: 32.0, thickness: 1.0, indent: 8.0, endIndent: 8.0),
          ] else ...[
            // 소문제 없을 때, 정보 박스와 보기 버튼 사이 간격 조정
            if (question.supplementaryInfo?.isNotEmpty ?? false) const SizedBox(height: 8.0) else const SizedBox(height: 24.0),
          ],


          // 답안/해설 보기 버튼


          // 답안/해설 표시 영역
          Visibility(
            visible: _isAnswerVisible,
            child: Card( // Card 구조 사용
                elevation: 1.0,
                color: Colors.grey.shade50,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),// 배경색
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3, // 예시: 화면 높이의 30%
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column( // 내용 세로 배치
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Case 1: 소문제 없는 경우
                        if (question.subQuestions.isEmpty) ...[
                          // _buildAnswerExplanationSection 호출 (4개 인자 전달)
                          if((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false))
                            _buildAnswerExplanationSection(context, '모범 답안', question.answer, question.answerImagePaths, Colors.blue.shade50),
                          if((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false))
                            Padding( padding: const EdgeInsets.only(top: 16.0), child: _buildAnswerExplanationSection(context, '해설', question.explanation, question.explanationImagePaths, Colors.green.shade50)),
                        ]
                        // Case 2: 소문제 있는 경우
                        else ...[
                          // 각 소문제 답/해설
                          ...question.subQuestions.map((sub) {
                            final bool subHasAnswer = (sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false);
                            final bool subHasExplanation = (sub.explanation?.isNotEmpty ?? false) || (sub.explanationImagePaths?.isNotEmpty ?? false);
                            if (!subHasAnswer && !subHasExplanation) return const SizedBox.shrink(); // 내용 없으면 빈 위젯 반환
                            // 내용 있으면 Column 반환
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${sub.subNumber} 답안/해설', style: Theme.of(context).textTheme.titleSmall), const Divider(height: 8.0),
                                  // _buildAnswerExplanationSection 호출 (4개 인자 전달)
                                  if(subHasAnswer) _buildAnswerExplanationSection(context, null, sub.answer, sub.answerImagePaths, Colors.blue.shade50),
                                  if(subHasExplanation) Padding(padding: EdgeInsets.only(top: subHasAnswer ? 8.0 : 0), child: _buildAnswerExplanationSection(context, null, sub.explanation, sub.explanationImagePaths, Colors.green.shade50)),
                                ],
                              ),
                            );
                          }).toList(), // map 끝


                          // 최상위 답/해설 (존재할 경우)
                          if((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false)) ...[
                            const Divider(height: 24.0, thickness: 1.0),
                            _buildAnswerExplanationSection(context, '종합 답안', question.answer, question.answerImagePaths, Colors.blue.shade100), // 4개 인자 전달
                          ],
                          if((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 8.0),
                            _buildAnswerExplanationSection(context, '종합 해설', question.explanation, question.explanationImagePaths, Colors.green.shade100), // 4개 인자 전달
                          ],
                        ]
                      ],
                    ),
                  ),
                )
            ),
          ), // Visibility 끝
          const SizedBox(height: 16.0), // ListView 끝 여백
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
              ElevatedButton(
                  onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
                  child: const Text('◀ 이전 문제')
              ),
              // 다음 문제 버튼: _goToQuestion 호출
              ElevatedButton(
                  onPressed: _currentIndex < _totalQuestionsInSession - 1 ? () => _goToQuestion(_currentIndex + 1) : null,
                  child: const Text('다음 문제 ▶')
              ),]),
          ],),)
      ],
    );
  }

  // --- Helper Widgets ---
  // 테이블 생성 헬퍼
  Widget _buildDataTable(BuildContext context, List<Map<String, dynamic>> tableData) {
    if (tableData.isEmpty) return const SizedBox.shrink(); // 데이터 없으면 빈 위젯 반환
    try {
      // 컬럼 헤더 생성
      final columns = tableData.first.keys.map((key) => DataColumn(label: Expanded(child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)))).toList();
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0), // 상하 여백 8.0 적용
                          child: _buildMixedContent( // _buildMixedContent 호출 확인
                              context,
                              cellValue?.toString(),
                              Theme.of(context).textTheme.bodyMedium // bodyMedium 적용 확인
                          )
                      )
                  )
              );
            }
          } return const DataCell(Text('')); // 키 오류 시
        }).toList();
        // 컬럼 수 일치 확인 등
        if (cells.length != columns.length) { print("Warning: Row data length mismatch..."); }
        return DataRow(cells: cells);
      }).toList();
      // DataTable 위젯 반환
      return DataTable( columnSpacing: 16.0, border: TableBorder.all(color: Colors.grey.shade400, width: 1), headingRowColor: MaterialStateProperty.all(Colors.grey.shade200), columns: columns, rows: rows );
    } catch (e) {
      print("Error building table: $e");
      return Text("테이블 표시 오류", style: TextStyle(color: Colors.red)); // 오류 시 Text 위젯 반환
    }
    // ***** 모든 코드 경로에서 Widget 반환 보장 *****
    return const SizedBox.shrink();
    // ***********************************************
  }
// ***********************************************
}

Widget _buildPageContent(BuildContext context, Question question, int pageIndex) {
  return SingleChildScrollView( // 각 페이지 내용 스크롤 가능하도록
    key: PageStorageKey('page_$pageIndex'), // 페이지 상태 유지 (선택 사항)
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 페이지 0: 메인 문제 + 보충 정보
      if (pageIndex == 0) ...[
        Card( elevation: 2.0, margin: const EdgeInsets.only(bottom: 8.0), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildMixedContent(context, question.questionText, Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (question.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 16.0), child: Column(children: question.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),),
          if (question.tableData?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildDataTable(context, question.tableData!)),
        ],),),),
        if (question.supplementaryInfo?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Container( width: double.infinity, padding: const EdgeInsets.all(12.0), decoration: BoxDecoration( color: Colors.blueGrey.shade50, border: Border.all(color: Colors.blueGrey.shade200), borderRadius: BorderRadius.circular(8.0),),
          child: _buildMixedContent(context, question.supplementaryInfo, Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),),),
        const SizedBox(height: 16.0),
      ]
      // 페이지 1 이상: 소문제 내용
      else if (pageIndex > 0 && pageIndex - 1 < question.subQuestions.length) ...[
        Builder(builder: (context) {
          final sub = question.subQuestions[pageIndex - 1];
          return Card( elevation: 1.0, margin: const EdgeInsets.only(bottom: 16.0), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildMixedContent(context, '${sub.subNumber} ${sub.questionText}', Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 8.0),
            if (sub.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 8.0), child: Column(children: sub.imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),),
            if (sub.tableData?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildDataTable(context, sub.tableData!)),
            if (sub.supplementaryInfo?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 12.0), child: Container( width: double.infinity, padding: const EdgeInsets.all(10.0), decoration: BoxDecoration( color: Colors.lime.shade50, border: Border.all(color: Colors.lime.shade200), borderRadius: BorderRadius.circular(6.0),),
              child: _buildMixedContent(context, sub.supplementaryInfo, Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3)),),),
          ],),),);
        }),
        const SizedBox(height: 16.0),
      ] else ...[ const Center(child: Text('잘못된 페이지입니다.')) ],
    ],),);
}

// 답/해설 섹션 생성 헬퍼
Widget _buildAnswerExplanationSection(BuildContext context, String? title, String? text, List<String>? imagePaths, [Color? backgroundColor]) {
  bool hasText = text?.isNotEmpty ?? false;
  bool hasImages = imagePaths?.isNotEmpty ?? false;
  if (!hasText && !hasImages) return const SizedBox.shrink();
  final textTheme = Theme.of(context).textTheme;
  return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (title != null) Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: textTheme.titleMedium)),
    Container( width: double.infinity, padding: const EdgeInsets.all(8.0), color: backgroundColor,
      child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasText) _buildMixedContent(context, text, textTheme.bodyMedium?.copyWith(height: 1.4)), // TeX+Text
        if (hasText && hasImages) const SizedBox(height: 12.0),
        if (hasImages) Column(children: imagePaths!.map((path) => Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Image.asset(path))).toList()),
      ],),),
    const SizedBox(height: 8.0),
  ],);
}
Widget _buildMixedContent(BuildContext context, String? inputText, TextStyle? textStyle) {
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
          baseline: TextBaseline.alphabetic,      // 알파벳 기준선 사용
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
              return Text(match.group(0)!, style: textStyle?.copyWith(color: Colors.red));
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
    print("Warning: _buildMixedContent resulted in empty spans for input: $inputText");
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
// --- State 클래스 끝 ---
