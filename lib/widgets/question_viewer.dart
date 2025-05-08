// lib/widgets/question_viewer.dart
import 'package:flutter/material.dart';
import 'package:sikman/models/question.dart'; // 경로 확인
import 'package:flutter_math_fork/flutter_math.dart'; // 경로 확인
// import 'package:sikman/widgets/question_display_helpers.dart'; // 만약 헬퍼를 분리했다면 import

// --- 공통 헬퍼 함수들 (원래 각 Screen State에 있던 것들) ---
// 이 함수들을 QuestionViewer 위젯 외부 또는 별도 파일에 두어도 됩니다.
// 여기서는 편의상 같은 파일에 둡니다.

// 텍스트/수식 혼합 렌더링 헬퍼
Widget buildMixedContent(BuildContext context, String? inputText, TextStyle? textStyle, {TextAlign textAlign = TextAlign.start}) {
  if (inputText == null || inputText.isEmpty) return const SizedBox.shrink();
  List<InlineSpan> spans = [];
  final RegExp regex = RegExp(r'(\$.*?\$)');
  inputText.splitMapJoin(regex, onMatch: (Match match) { String mathContent = match.group(0) ?? ''; if (mathContent.length >= 2) mathContent = mathContent.substring(1, mathContent.length - 1); if (mathContent.isNotEmpty) { spans.add(WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: Math.tex(mathContent, textStyle: textStyle, mathStyle: MathStyle.text, onErrorFallback: (FlutterMathException e) { print("Math Error: ${e.message} in TeX: $mathContent"); return Text(match.group(0)!, style: textStyle?.copyWith(color: Colors.red)); },),)); } return ''; }, onNonMatch: (String nonMatch) { if (nonMatch.isNotEmpty) spans.add(TextSpan(text: nonMatch, style: textStyle)); return ''; },);
  if (spans.isEmpty) { print("Warning: _buildMixedContent resulted in empty spans for input: $inputText"); return const SizedBox.shrink(); }
  return RichText( textAlign: textAlign, text: TextSpan(style: textStyle, children: spans,),);
}

// 답/해설 섹션 생성 헬퍼
Widget buildAnswerExplanationSection(BuildContext context, String? title, String? text, List<String>? imagePaths, [Color? backgroundColor]) {
  bool hasText = text?.isNotEmpty ?? false;
  bool hasImages = imagePaths?.isNotEmpty ?? false;
  if (!hasText && !hasImages) return const SizedBox.shrink();
  final textTheme = Theme.of(context).textTheme;
  final bodyTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4);

  // --- ★★★ 제목 스타일 정의 (굵게, 크게, 색상 적용) ★★★ ---
  Color titleColor = Colors.black87; // 기본 색상
  if (title != null) {
    // 제목 내용에 따라 색상 구분
    if (title.contains('답안')) { // '모범 답안', '종합 답안' 등
      titleColor = Colors.blue.shade800; // 진한 파란색 계열
    } else if (title.contains('해설')) { // '해설', '종합 해설' 등
      titleColor = Colors.green.shade800; // 진한 녹색 계열
    }
  }

  // titleMedium 스타일을 기반으로 수정 (null 처리 포함)
  final titleStyle = (textTheme.titleMedium ?? const TextStyle(fontSize: 16.0)).copyWith(
    fontWeight: FontWeight.bold, // 볼드체
    fontSize: (textTheme.titleMedium?.fontSize ?? 16.0) * 1.1, // 기존보다 10% 크게 (조절 가능)
    color: titleColor, // 위에서 결정된 색상 적용
  );
  // ---------------------------------------------------

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // --- ★★★ 수정된 스타일 적용 ★★★ ---
      if (title != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 10.0, top: 4.0), // 패딩 조절
            child: Text(
                title,
                style: titleStyle, // 수정된 스타일 적용
                textAlign: TextAlign.center
            )
        ),
      // ----------------------------
      Container( // 내용 컨테이너 (기존 유지)
        width: double.infinity,
        padding: const EdgeInsets.all(12.0), // 내용 패딩 약간 증가
        color: backgroundColor ?? Colors.transparent, // 배경색은 투명하게
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasText) buildMixedContent(context, text, bodyTextStyle, textAlign: TextAlign.center),
            if (hasText && hasImages) const SizedBox(height: 12.0),
            if (hasImages) Column(children: imagePaths!.map((path) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Center(child: Image.asset(path)))).toList()),
          ],
        ),
      ),
      const SizedBox(height: 8.0), // 섹션 하단 여백
    ],
  );
}
// ---------------------------------------------------------

class QuestionViewer extends StatefulWidget {
  final Question question; // 현재 표시할 문제
  final Key? key; // 상태 유지를 위한 Key (부모에서 ValueKey 전달 권장)

  const QuestionViewer({
    this.key, // key 파라미터 추가
    required this.question,
  }) : super(key: key); // super.key 전달

  @override
  State<QuestionViewer> createState() => _QuestionViewerState();
}

class _QuestionViewerState extends State<QuestionViewer> {
  late PageController _pageController;
  late int _totalPages;
  int _currentPageIndex = 0; // 페이지 인덱스는 내부에서 관리
  Map<int, bool> _isAnswerVisibleMap = {}; // 답안 표시 상태도 내부에서 관리

  @override
  void initState() {
    super.initState();
    _initializePageData();
  }

  // Question 객체가 변경될 때마다 페이지 관련 상태 초기화
  @override
  void didUpdateWidget(covariant QuestionViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.question != oldWidget.question) {
      print("QuestionViewer: Question changed, re-initializing."); // 디버그 로그
      _initializePageData();
      // 페이지 컨트롤러가 이미 생성되었고 클라이언트가 연결된 경우 0페이지로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  void _initializePageData() {
    _pageController = PageController(initialPage: 0);
    _totalPages = 1 + widget.question.subQuestions.length;
    _currentPageIndex = 0;
    _isAnswerVisibleMap = {}; // 답안 표시 상태 초기화
    // 초기화 후 위젯이 빌드되도록 setState 호출 (필요한 경우)
    // initState에서는 보통 필요 없지만 didUpdateWidget에서는 필요할 수 있음
    setState(() {});
  }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- 페이지별 답안/해설 토글 및 내용 위젯 생성 헬퍼 ---
  // (State 내부로 이동하고 내부 상태(_isAnswerVisibleMap) 사용)
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
          // 내부 상태 변경
          setState(() {
            _isAnswerVisibleMap[pageIndex] = !isVisible;
          });
        },
      ),),),
      Visibility( visible: isVisible, child: Container( margin: const EdgeInsets.only(top: 8.0), padding: const EdgeInsets.all(12.0), decoration: BoxDecoration( color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4), ), child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isMainQuestionPage) ...[ if ((question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false)) buildAnswerExplanationSection(context, '답안', question.answer, question.answerImagePaths, Colors.transparent), if ((question.explanation?.isNotEmpty ?? false) || (question.explanationImagePaths?.isNotEmpty ?? false)) Padding( padding: EdgeInsets.only(top: (question.answer?.isNotEmpty ?? false) || (question.answerImagePaths?.isNotEmpty ?? false) ? 16.0 : 0), child: buildAnswerExplanationSection(context, '해설', question.explanation, question.explanationImagePaths, Colors.transparent), ), ]
        else if (sub != null) ...[ if ((sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false)) buildAnswerExplanationSection(context, '답안', sub.answer, sub.answerImagePaths, Colors.transparent), if ((sub.explanation?.isNotEmpty ?? false) || (sub.explanationImagePaths?.isNotEmpty ?? false)) Padding( padding: EdgeInsets.only(top: (sub.answer?.isNotEmpty ?? false) || (sub.answerImagePaths?.isNotEmpty ?? false) ? 16.0 : 0), child: buildAnswerExplanationSection(context, '해설', sub.explanation, sub.explanationImagePaths, Colors.transparent), ), ]
      ],),),),
    ],
    );
  }
  // ---------------------------------------------------------

  // --- 페이지 내용 생성 헬퍼 ---
  Widget _buildPageContent(BuildContext context, Question question, int pageIndex) {
    final pageKey = PageStorageKey('q${question.hashCode}_p$pageIndex');
    final textTheme = Theme.of(context).textTheme;
    final mainTextStyle = textTheme.bodyLarge?.copyWith(height: 1.5, fontWeight: FontWeight.w600, color: Colors.black) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black, height: 1.5);
    final subTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w600, color: Colors.black) ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black, height: 1.4);
    final suppTextStyle = textTheme.bodyMedium?.copyWith(height: 1.4);
    final subSuppTextStyle = textTheme.bodySmall?.copyWith(height: 1.3);

    bool isMainQuestionPage = (pageIndex == 0);
    SubQuestion? sub = (isMainQuestionPage || pageIndex - 1 >= question.subQuestions.length) ? null : question.subQuestions[pageIndex - 1];

    return SingleChildScrollView(
      key: pageKey,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 문제 내용 ---
          if (isMainQuestionPage) ...[
            Center( child: buildMixedContent(context, question.questionText, mainTextStyle),),
            if (question.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(top: 16.0), child: Column( children: question.imagePaths!.map((path) { if (path.isEmpty) return const SizedBox.shrink(); return Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Center( child: Image.asset( path, errorBuilder: (context, error, stackTrace) { return Text('이미지 오류'); }, ) ) ); }).toList() ), ),
            // tableImagePath 관련 코드 없음
            const SizedBox(height: 16.0),
            if (question.supplementaryInfo?.isNotEmpty ?? false) Container( width: double.infinity, padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: Colors.blueGrey.shade50, border: Border.all(color: Colors.blueGrey.shade200), borderRadius: BorderRadius.circular(8.0),), child: buildMixedContent(context, question.supplementaryInfo, suppTextStyle), ),
          ] else if (sub != null) ...[
            Center( child: buildMixedContent(context, '${sub.subNumber} ${sub.questionText}', subTextStyle),),
            const SizedBox(height: 16.0),
            if (sub.imagePaths?.isNotEmpty ?? false) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Column( children: sub.imagePaths!.map((path) { if (path.isEmpty) return const SizedBox.shrink(); return Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Center( child: Image.asset( path, errorBuilder: (context, error, stackTrace) { return Text('이미지 오류'); }, ) ) ); }).toList() ), ),
            // tableImagePath 관련 코드 없음
            if (sub.supplementaryInfo?.isNotEmpty ?? false) Container( width: double.infinity, margin: const EdgeInsets.only(bottom: 16.0), padding: const EdgeInsets.all(10.0), decoration: BoxDecoration(color: Colors.lime.shade50, border: Border.all(color: Colors.lime.shade200), borderRadius: BorderRadius.circular(6.0),), child: buildMixedContent(context, sub.supplementaryInfo, subSuppTextStyle), ),
          ],
          // --- 페이지별 답안/해설 토글 및 내용 (헬퍼 호출) ---
          _buildAnswerToggleAndContent(context, question, pageIndex),
          // ------------------------------------------
          const SizedBox(height: 16.0), // 페이지 하단 여백
        ],
      ),
    );
  }
  // ---------------------------------------------------------

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