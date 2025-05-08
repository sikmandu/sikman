// lib/models/incorrect_question_info.dart
class IncorrectQuestionInfo {
  final int year;
  final int sessionNumber;
  final int questionIndex; // 원본 JSON에서의 인덱스
  final int questionNumber; // ★★★ 실제 문제 번호 필드 추가 ★★★
  final String questionType;
  final String questionTextSnippet;

  IncorrectQuestionInfo({
    required this.year,
    required this.sessionNumber,
    required this.questionIndex,
    required this.questionNumber, // ★★★ 생성자에 추가 ★★★
    required this.questionType,
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
  String encodeToString() {
    final safeType = questionType.replaceAll('|', '');
    final safeSnippet = questionTextSnippet.replaceAll('|', '');
    // year|session|index|number|type|snippet 순서로 저장
    return '$year|$sessionNumber|$questionIndex|$questionNumber|$safeType|$safeSnippet';
  }


  static IncorrectQuestionInfo? decodeFromString(String encoded) {
    try {
      final parts = encoded.split('|');
      // 필드 개수 6개 확인
      if (parts.length == 6) {
        return IncorrectQuestionInfo(
          year: int.parse(parts[0]),
          sessionNumber: int.parse(parts[1]),
          questionIndex: int.parse(parts[2]),
          questionNumber: int.parse(parts[3]), // number 파싱
          questionType: parts[4],
          questionTextSnippet: parts[5],
        );
      } else if (parts.length == 5) { // 이전 버전 호환성 (선택적)
        print("Decoding old format (v2)");
        // 이전 버전 데이터는 questionNumber를 index+1로 임시 설정하거나,
        // 기본값(예: 0)을 사용하고 표시 시 조정할 수 있음
        return IncorrectQuestionInfo(
          year: int.parse(parts[0]),
          sessionNumber: int.parse(parts[1]),
          questionIndex: int.parse(parts[2]),
          questionNumber: int.parse(parts[2]) + 1, // 임시로 index + 1 사용
          questionType: parts[3],
          questionTextSnippet: parts[4],
        );
      }
    } catch (e) {
      print("Error decoding IncorrectQuestionInfo: $encoded, Error: $e");
    }
    return null;
  }
// ----------------------------
}