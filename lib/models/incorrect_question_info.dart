// lib/models/incorrect_question_info.dart
class IncorrectQuestionInfo {
  final int year;
  final int sessionNumber;
  final int questionIndex; // 문제 목록에서의 0 기반 인덱스
  final String questionTextSnippet; // 오답 노트 목록에 보여줄 문제 내용 일부

  IncorrectQuestionInfo({
    required this.year,
    required this.sessionNumber,
    required this.questionIndex,
    required this.questionTextSnippet,
  });

  // 리스트 내 중복 확인 등을 위한 비교 로직 (같은 시험의 같은 문제인지 확인)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is IncorrectQuestionInfo &&
              runtimeType == other.runtimeType &&
              year == other.year &&
              sessionNumber == other.sessionNumber &&
              questionIndex == other.questionIndex;

  @override
  int get hashCode =>
      year.hashCode ^ sessionNumber.hashCode ^ questionIndex.hashCode;
}