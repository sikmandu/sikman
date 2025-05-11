// lib/widgets/question_viewer.dart
import 'package:flutter/material.dart';
import 'package:sikman/models/question.dart';
import 'package:sikman/services/recent_study_service.dart'; // 실제 경로로
import 'package:sikman/models/study_context.dart';   // 실제 경로로
import 'package:flutter_math_fork/flutter_math.dart'; // 추가된 부분

// --- 공통 헬퍼 함수들 (buildMixedContent, buildAnswerExplanationSection) ---
// 이 함수들은 QuestionViewer 클래스 외부에 있거나, 별도의 헬퍼 파일에 있을 수 있습니다.
// 여기서는 QuestionViewer 파일 내에 있다고 가정합니다. (이전 제공된 코드와 동일)

// 텍스트/수식 혼합 렌더링 헬퍼
Widget buildMixedContent(BuildContext context, String? inputText, TextStyle? textStyle, {TextAlign textAlign = TextAlign.start}) {
  if (inputText == null || inputText.isEmpty) return const SizedBox.shrink();
  List<InlineSpan> spans = [];
  final RegExp regex = RegExp(r'(\$.*?\$)'); // $...$ 형식의 LaTeX 수식 찾기
  inputText.splitMapJoin(
    regex,
    onMatch: (Match match) {
      String mathContent = match.group(0) ?? '';
      if (mathContent.length >= 2) { // 앞뒤 $ 제거
        mathContent = mathContent.substring(1, mathContent.length - 1);
      }
      if (mathContent.isNotEmpty) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Math.tex(
            mathContent.replaceAll(r'\\', r'\'), // LaTeX에서 \\를 \로 변경
            textStyle: textStyle,
            mathStyle: MathStyle.text,
            onErrorFallback: (FlutterMathException e) {
              print("Math Error: ${e.message} in TeX: $mathContent");
              return Text(match.group(0)!, style: textStyle?.copyWith(color: Colors.red));
            },
          ),
        ));
      }
      return '';
    },
    onNonMatch: (String nonMatch) {
      if (nonMatch.isNotEmpty) {
        spans.add(TextSpan(text: nonMatch, style: textStyle));
      }
      return '';
    },
  );
  if (spans.isEmpty && inputText.isNotEmpty) { // 입력은 있지만 span이 없는 경우 (예: "$$"만 있는 경우)
    return Text(inputText, style: textStyle); // 원본 텍스트라도 보여주도록
  }
  if (spans.isEmpty) return const SizedBox.shrink();
  return RichText(
    textAlign: textAlign,
    text: TextSpan(
      style: DefaultTextStyle.of(context).style.merge(textStyle), // 기본 스타일과 병합
      children: spans,
    ),
  );
}Widget buildAnswerExplanationSection(BuildContext context, String? title, String? text, List<String>? imagePaths, [Color? backgroundColor]) {
  bool hasText = text?.isNotEmpty ?? false;
  bool hasImages = imagePaths?.isNotEmpty ?? false;
  if (!hasText && !hasImages) return const SizedBox.shrink();
  final textTheme = Theme.of(context).textTheme;
  final bodyTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4);
  Color titleColor = Theme.of(context).textTheme.titleMedium?.color ?? Colors.black87;
  if (title != null) {
    if (title.contains('답안')) { titleColor = Colors.blue.shade800; }
    else if (title.contains('해설')) { titleColor = Colors.green.shade800; }
  }
  final titleStyle = (textTheme.titleMedium ?? const TextStyle(fontSize: 16.0)).copyWith(
    fontWeight: FontWeight.bold,
    fontSize: (textTheme.titleMedium?.fontSize ?? 16.0) * 1.1,
    color: titleColor,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null) Padding(padding: const EdgeInsets.only(bottom: 10.0, top: 4.0), child: Text(title, style: titleStyle, textAlign: TextAlign.center)),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12.0), color: backgroundColor ?? Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasText) buildMixedContent(context, text, bodyTextStyle, textAlign: TextAlign.center),
            if (hasText && hasImages) const SizedBox(height: 12.0),
            if (hasImages) Column(children: imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Center(child: Image.asset(path, errorBuilder: (ctx, err, st) => Text('이미지 로드 오류: $path'))))).toList()),
          ],
        ),
      ),
      const SizedBox(height: 8.0),
    ],
  );
}// ------------------------------------------------------------------------

class QuestionViewer extends StatefulWidget {
  final Question question;
  final Key? key; // 부모로부터 전달받는 Key

  // --- ↓↓↓ 컨텍스트 정보를 위한 파라미터 추가 ↓↓↓ ---
  final StudyContextType contextType;         // '과년도'인지 '유형별'인지 구분
  final int? displayYear;                   // '과년도' 학습 시 해당 연도 (QuestionScreen에서 전달)
  final int? displaySessionNumber;          // '과년도' 학습 시 해당 회차 (QuestionScreen에서 전달)
  final String? categoryName;               // '유형별' 학습 시 카테고리 이름 (CategoryQuestionScreen에서 전달)
  // --- ↑↑↑ ----------------------------------- ↑↑↑ ---

  const QuestionViewer({
    this.key, // super.key로 전달하기 위해 this.key 사용
    required this.question,
    // --- ↓↓↓ 생성자 파라미터 추가 ↓↓↓ ---
    required this.contextType,
    this.displayYear,
    this.displaySessionNumber,
    this.categoryName,
    // --- ↑↑↑ ---------------------- ↑↑↑ ---
  }) : super(key: key); // super.key에 전달

  @override
  State<QuestionViewer> createState() => _QuestionViewerState();
}

class _QuestionViewerState extends State<QuestionViewer> {
  late PageController _pageController;
  int _totalPages = 1;
  int _currentPageIndex = 0;
  Map<int, bool> _isAnswerVisibleMap = {};
  final RecentStudyService _recentStudyService = RecentStudyService();


  @override
  void initState() {
    super.initState();
    print("QuestionViewer initState: Q#${widget.question.number}, Hash: ${widget.question.hashCode}");
    _pageController = PageController(initialPage: 0); // PageController는 여기서 한번만 생성
    _updatePageData();    // ★ 페이지 상태 초기화 (setState 포함)
    _saveRecentStudy();   // 최근 학습 정보 저장
  }
  @override
  void didUpdateWidget(covariant QuestionViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("QuestionViewer didUpdateWidget: Old Q#${oldWidget.question.number} (Hash: ${oldWidget.question.hashCode}), New Q#${widget.question.number} (Hash: ${widget.question.hashCode})");

    // Question 객체 자체가 변경되었을 때만 페이지 상태를 리셋하고 최근 학습 저장
    if (widget.question != oldWidget.question) {
      print("  -> 문제 객체 변경됨. 페이지 데이터 리셋 및 저장.");
      _updatePageData(); // ★ 페이지 상태 업데이트 및 setState 호출
      _saveRecentStudy();  // 새 문제에 대한 최근 학습 저장

      // PageView를 첫 페이지로 이동
      // _updatePageData에서 _currentPageIndex가 0으로 설정되고 setState가 호출되면,
      // 다음 build 시점에 PageView는 _pageController의 initialPage (항상 0) 또는
      // controller가 마지막으로 알고 있던 페이지를 기준으로 그려짐.
      // 문제가 바뀌었으므로 명시적으로 0번 페이지로 보내는 것이 안전.
      if (_pageController.hasClients) {
        // 이미 0페이지라면 jumpToPage 불필요
        if (_pageController.page?.round() != 0) {
          _pageController.jumpToPage(0);
          print("    QuestionViewer didUpdateWidget: jumpToPage(0) 호출됨.");
        }
      }
    }
    // 컨텍스트 정보만 변경된 경우 (문제 객체는 동일) -> 최근 학습 정보만 업데이트
    else if (widget.contextType != oldWidget.contextType ||
        widget.displayYear != oldWidget.displayYear ||
        widget.displaySessionNumber != oldWidget.displaySessionNumber ||
        widget.categoryName != oldWidget.categoryName) {
      print("  -> 컨텍스트 정보만 변경됨. 최근 학습만 다시 저장.");
      _saveRecentStudy();
    }
  }
// 페이지 관련 상태(_totalPages, _currentPageIndex)를 업데이트하는 함수
  void _updatePageData() {
    final newTotalPages = 1 + widget.question.subQuestions.length;
    final newCurrentPageIndex = 0; // 문제가 바뀌면 항상 첫 페이지(메인 문제)부터

    // setState는 실제 상태 값이 변경되었을 때만 호출하는 것이 좋지만,
    // 문제가 바뀌면 항상 UI 갱신이 필요하다고 판단하여 호출.
    if (mounted) { // 위젯이 트리에 마운트된 상태인지 확인
      setState(() {
        _totalPages = newTotalPages;
        _currentPageIndex = newCurrentPageIndex;
        _isAnswerVisibleMap = {}; // 답안 표시 상태 초기화
        print("  QuestionViewer _updatePageData: setState 호출됨. TotalPages: $_totalPages, CurrentPageIndex: $_currentPageIndex");
      });
    } else {
      // initState에서 호출될 경우 mounted가 false일 수 있으므로 직접 할당
      _totalPages = newTotalPages;
      _currentPageIndex = newCurrentPageIndex;
      _isAnswerVisibleMap = {};
      print("  QuestionViewer _updatePageData: (not mounted) 직접 할당됨. TotalPages: $_totalPages, CurrentPageIndex: $_currentPageIndex");
    }
  }

  void _saveRecentStudy() async {
    final Question currentQ = widget.question;
    print("QuestionViewer: _saveRecentStudy 호출됨. Q#${currentQ.number}, Context: ${widget.contextType}");
    // int originalIndexToSave = currentQ.originalIndex ?? (currentQ.number > 0 ? currentQ.number - 1 : 0);

    switch (widget.contextType) {
      case StudyContextType.pastExam:
        if (widget.displayYear != null && widget.displaySessionNumber != null) {
          await _recentStudyService.saveRecentPastExam(
              widget.displayYear!, widget.displaySessionNumber!, currentQ.number);
        }
        break;
      case StudyContextType.categoryExam:
        if (widget.categoryName != null && currentQ.year != null && currentQ.sessionNumber != null) {
          await _recentStudyService.saveRecentCategoryExam(
              widget.categoryName!, currentQ.year!, currentQ.sessionNumber!, currentQ.number);
        }
        break;
      case StudyContextType.incorrectNoteReview:
        if (widget.displayYear != null && widget.displaySessionNumber != null &&
            widget.categoryName != null && widget.categoryName!.isNotEmpty &&
            currentQ.originalIndex != null) {
          await _recentStudyService.saveLastViewedIncorrectNoteDetail(
            year: widget.displayYear!,
            session: widget.displaySessionNumber!,
            questionNumber: currentQ.number,
            category: widget.categoryName!,
            originalIndex: currentQ.originalIndex!,
          );
        } else {
          print("  QuestionViewer (오답노트 리뷰): 최근 학습 저장 위한 정보 부족.");
          print("    displayYear: ${widget.displayYear}, displaySessionNumber: ${widget.displaySessionNumber}, categoryName: ${widget.categoryName}, currentQ.originalIndex: ${currentQ.originalIndex}");
        }
        break;
    }
  }
  @override
  void dispose() {
    _pageController.dispose(); // PageController는 항상 dispose
    super.dispose();
  }

  // --- 페이지별 답안/해설 토글 및 내용 위젯 생성 헬퍼 ---
  // (이전과 동일)
  Widget _buildAnswerToggleAndContent(BuildContext context, Question question, int pageIndex) {
    bool isVisible = _isAnswerVisibleMap[pageIndex] ?? false;
    bool isMainQuestionPage = (pageIndex == 0);
    SubQuestion? sub = (isMainQuestionPage || pageIndex - 1 >= question.subQuestions.length)
        ? null
        : question.subQuestions[pageIndex - 1];
    bool hasContentToShow = false;
    if (isMainQuestionPage) { hasContentToShow = (question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false) || (question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false);
    } else if (sub != null) { hasContentToShow = (sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false) || (sub.explanation?.isNotEmpty ?? false) || (sub.explanationImagePaths?.isNotEmpty ?? false); }
    if (!hasContentToShow) return const SizedBox.shrink();

    return Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding( padding: const EdgeInsets.only(top: 24.0, bottom: 8.0), child: Center( child: OutlinedButton.icon(
        icon: Icon(isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        label: Text(isVisible ? '답안/해설 숨기기' : '답안/해설 보기'),
        onPressed: () {
          if (mounted) { setState(() { _isAnswerVisibleMap[pageIndex] = !isVisible; }); }
        },
      ),),),
      Visibility( visible: isVisible, child: Container( margin: const EdgeInsets.only(top: 8.0), padding: const EdgeInsets.all(12.0), decoration: BoxDecoration( color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4), ), child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isMainQuestionPage) ...[ if ((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false)) buildAnswerExplanationSection(context, '답안', question.answer, question.answerImagePaths, Colors.transparent), if ((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false)) Padding( padding: EdgeInsets.only(top: (question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false) ? 16.0 : 0), child: buildAnswerExplanationSection(context, '해설', question.explanation, question.explanationImagePaths, Colors.transparent), ), ]
        else if (sub != null) ...[ if ((sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false)) buildAnswerExplanationSection(context, '답안', sub.answer, sub.answerImagePaths, Colors.transparent), if ((sub.explanation?.isNotEmpty ?? false) || (sub.explanationImagePaths?.isNotEmpty ?? false)) Padding( padding: EdgeInsets.only(top: (sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false) ? 16.0 : 0), child: buildAnswerExplanationSection(context, '해설', sub.explanation, sub.explanationImagePaths, Colors.transparent), ), ]
      ],),),),
    ],);
  }

  // --- 페이지 내용 생성 헬퍼 ---
  // (이전과 동일)
  Widget _buildPageContent(BuildContext context, Question question, int pageIndex) {
    final pageKey = PageStorageKey('q${question.hashCode}_p$pageIndex'); // question.hashCode 대신 고유 ID 사용 고려
    final textTheme = Theme.of(context).textTheme;
    final mainTextStyle = textTheme.bodyLarge?.copyWith(height: 1.5, fontWeight: FontWeight.w600, color: Colors.black) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black, height: 1.5);
    final subTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w600, color: Colors.black) ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black, height: 1.4);
    final suppTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4);
    final subSuppTextStyle = textTheme.bodySmall?.copyWith(height: 1.3);

    bool isMainQuestionPage = (pageIndex == 0);
    SubQuestion? sub = (isMainQuestionPage || pageIndex - 1 >= question.subQuestions.length) ? null : question.subQuestions[pageIndex - 1];

    if (isMainQuestionPage) {
      return SingleChildScrollView(
        key: pageKey, padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center( child: buildMixedContent(context, question.questionText, mainTextStyle)),
          if (question.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 16.0), child: Column( children: question.imagePaths!.map((path) => Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Center( child: Image.asset(path, errorBuilder: (ctx,e,st) => Text('이미지 오류:$path'))))).toList())),
          const SizedBox(height: 16.0),
          if (question.supplementaryInfo?.isNotEmpty ?? false) Container( width: double.infinity, padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: Colors.blueGrey.shade50, border: Border.all(color: Colors.blueGrey.shade200), borderRadius: BorderRadius.circular(8.0)), child: buildMixedContent(context, question.supplementaryInfo, suppTextStyle)),
          _buildAnswerToggleAndContent(context, question, pageIndex), // 각 페이지에 답/해설 버튼 포함
          const SizedBox(height: 16.0),
        ]),
      );
    } else if (sub != null)  {
      return SingleChildScrollView(
        key: pageKey, padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center( child: buildMixedContent(context, '${sub.subNumber} ${sub.questionText}', subTextStyle)),
          const SizedBox(height: 16.0),
          if (sub.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Column( children: sub.imagePaths!.map((path) => Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Center( child: Image.asset(path, errorBuilder: (ctx,e,st) => Text('이미지 오류:$path'))))).toList())),
          if (sub.supplementaryInfo?.isNotEmpty ?? false) Container( width: double.infinity, margin: const EdgeInsets.only(bottom: 16.0), padding: const EdgeInsets.all(10.0), decoration: BoxDecoration(color: Colors.lime.shade50, border: Border.all(color: Colors.lime.shade200), borderRadius: BorderRadius.circular(6.0)), child: buildMixedContent(context, sub.supplementaryInfo, subSuppTextStyle)),
          _buildAnswerToggleAndContent(context, question, pageIndex), // 각 페이지에 답/해설 버튼 포함
          const SizedBox(height: 16.0),
        ]),
      );
    }
    return Center(child: Text("페이지 내용을 표시할 수 없습니다. (페이지 인덱스: $pageIndex)"));
  }


  @override
  Widget build(BuildContext context) {
    print("Building QuestionViewer - Total Pages: $_totalPages"); // 디버그 로그
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 페이지 정보 및 네비게이션 버튼
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios), iconSize: 20.0,
                  tooltip: '이전 페이지',
                  onPressed: (_currentPageIndex > 0)
                      ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
                      : null,
                ),
                Text(
                  '페이지 ${_currentPageIndex + 1} / $_totalPages',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios), iconSize: 20.0,
                  tooltip: '다음 페이지',
                  onPressed: (_currentPageIndex < _totalPages - 1)
                      ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
                      : null,
                ),
              ],
            ),
          ),
        // PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (index) {
              // 내부 페이지 인덱스 상태 업데이트
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, pageIndex) {
              // 페이지 내용 빌드
              return _buildPageContent(context, widget.question, pageIndex);
            },
          ),
        ),
      ],
    );
  }
}