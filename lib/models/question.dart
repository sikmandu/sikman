
// 소문제 정보를 담는 클래스


class SubQuestion {
  final String subNumber;
  final String questionText;
  final List<String>? imagePaths; // 여러 이미지 경로 허용
  final String? answer;
  final String? explanation;
  final String? supplementaryInfo;
  final List<String>? answerImagePaths;
  final List<String>? explanationImagePaths;
  //final String? tableImagePath; // <-- 추가 (String? 타입)

  SubQuestion({
    required this.subNumber,
    required this.questionText,
    this.imagePaths,
    this.answer,
    this.explanation,
    this.answerImagePaths,
    this.explanationImagePaths,
    //this.tableImagePath, // <-- 생성자에 추가
    this.supplementaryInfo,
  });

  factory SubQuestion.fromJson(Map<String, dynamic> json) {
    // 이미지 경로 리스트 파싱 (null 또는 List<String> 반환)
    List<String>? parseImagePaths(dynamic data) {
      if (data is List) {
        // JSON 배열의 각 요소가 문자열인지 확인하고 리스트 생성
        return data.map((item) => item.toString()).toList();
      }
      return null;
    }
    // 테이블 데이터 파싱 (null 또는 List<Map<String, dynamic>> 반환)
    List<Map<String, dynamic>>? parseTableData(dynamic data) {
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return null;
    }

    return SubQuestion(
      subNumber: json['subNumber'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      imagePaths: parseImagePaths(json['imagePaths']),
      answer: json['answer'] as String?, // null 허용
      explanation: json['explanation'] as String?, // null 허용
      answerImagePaths: parseImagePaths(json['answerImagePaths']),
      explanationImagePaths: parseImagePaths(json['explanationImagePaths']),
      //tableImagePath: json['tableImagePath'] as String?,
      supplementaryInfo: json['supplementaryInfo'] as String?,
    );
  }
}

// 메인 문제 정보를 담는 클래스
class Question {
  final int number;
  final String type;
  final String questionText; // 메인 질문 또는 전체 질문
  final List<String>? imagePaths; // 메인 질문 이미지 경로 리스트
  final String? supplementaryInfo; // String? 타입으로 추가
  final List<SubQuestion> subQuestions; // 소문제 리스트 (없으면 빈 리스트)
  final String? answer; // 전체 답안 (요약 또는 null)
  final String? explanation; // 전체 해설 (요약 또는 null)
  final List<String>? answerImagePaths; // 전체 답안 이미지 경로 리스트
  final List<String>? explanationImagePaths; // 전체 해설 이미지 경로 리스트
  final String? tableImagePath; // <-- 추가
  final bool isKillerProblem;
  final int? year;          // 원래 문제의 연도 (Nullable)
  final int? sessionNumber; // 원래 문제의 회차 (Nullable)
  final int? originalIndex; // 원래 JSON 파일에서의 인덱스 (Nullable)

  Question({
    required this.number,
    required this.type,
    required this.questionText,
    this.imagePaths,
    this.supplementaryInfo, // <--- 생성자에 추가
    required this.subQuestions, // 필수로 빈 리스트라도 받도록 함
    this.answer,
    this.explanation,
    this.answerImagePaths,
    this.explanationImagePaths,
    this.tableImagePath, // <-- 생성자에 추가
    required this.isKillerProblem,
    this.year,
    this.sessionNumber,
    this.originalIndex,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    List<String>? parseImagePaths(dynamic data) {
      if (data is List) {
        return data.map((item) => item.toString()).toList();
      }
      return null;
    }


    // subQuestions 파싱
    List<SubQuestion> subs = [];
    if (json['subQuestions'] is List) {
      subs = (json['subQuestions'] as List)
          .map((subJson) => SubQuestion.fromJson(subJson as Map<String, dynamic>))
          .toList();
    }

    return Question(
      number: json['number'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      imagePaths: parseImagePaths(json['imagePaths']),
      supplementaryInfo: json['supplementaryInfo'] as String?, // <--- 필드 파싱 추가 (String? 타입)
      subQuestions: subs, // 파싱된 소문제 리스트 또는 빈 리스트
      answer: json['answer'] as String?,
      explanation: json['explanation'] as String?,
      answerImagePaths: parseImagePaths(json['answerImagePaths']),
      explanationImagePaths: parseImagePaths(json['explanationImagePaths']),
      tableImagePath: json['tableImagePath'] as String?,
      isKillerProblem: json['isKillerProblem'] as bool? ?? false,
    );
  }
  Question copyWithContext({required int year, required int sessionNumber, required int originalIndex}) {
    return Question(
      number: this.number,
      type: this.type,
      questionText: this.questionText,
      imagePaths: this.imagePaths,
      supplementaryInfo: this.supplementaryInfo,
      subQuestions: this.subQuestions,
      answer: this.answer,
      explanation: this.explanation,
      answerImagePaths: this.answerImagePaths,
      explanationImagePaths: this.explanationImagePaths,
      isKillerProblem: this.isKillerProblem,
      year: year,
      sessionNumber: sessionNumber,
      originalIndex: originalIndex,
    );
  }
}