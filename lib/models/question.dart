// lib/models/question.dart

// 소문제 정보를 담는 클래스
class SubQuestion {
  final String subNumber;
  final String questionText;
  final List<String>? imagePaths; // 여러 이미지 경로 허용
  final String? answer;
  final String? explanation;
  final List<String>? answerImagePaths;
  final List<String>? explanationImagePaths;
  final List<Map<String, dynamic>>? tableData; // 테이블 데이터 (List<Map<String, String>> 이 더 정확할 수 있음)

  SubQuestion({
    required this.subNumber,
    required this.questionText,
    this.imagePaths,
    this.answer,
    this.explanation,
    this.answerImagePaths,
    this.explanationImagePaths,
    this.tableData,
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
      tableData: parseTableData(json['tableData']),
    );
  }
}

// 메인 문제 정보를 담는 클래스
class Question {
  final int number;
  final String type;
  final String questionText; // 메인 질문 또는 전체 질문
  final List<String>? imagePaths; // 메인 질문 이미지 경로 리스트
  final List<SubQuestion> subQuestions; // 소문제 리스트 (없으면 빈 리스트)
  final String? answer; // 전체 답안 (요약 또는 null)
  final String? explanation; // 전체 해설 (요약 또는 null)
  final List<String>? answerImagePaths; // 전체 답안 이미지 경로 리스트
  final List<String>? explanationImagePaths; // 전체 해설 이미지 경로 리스트
  final List<Map<String, dynamic>>? tableData; // 메인 질문 테이블 데이터
  final bool isKillerProblem;

  Question({
    required this.number,
    required this.type,
    required this.questionText,
    this.imagePaths,
    required this.subQuestions, // 필수로 빈 리스트라도 받도록 함
    this.answer,
    this.explanation,
    this.answerImagePaths,
    this.explanationImagePaths,
    this.tableData,
    required this.isKillerProblem,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    List<String>? parseImagePaths(dynamic data) {
      if (data is List) {
        return data.map((item) => item.toString()).toList();
      }
      return null;
    }
    List<Map<String, dynamic>>? parseTableData(dynamic data) {
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
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
      subQuestions: subs, // 파싱된 소문제 리스트 또는 빈 리스트
      answer: json['answer'] as String?,
      explanation: json['explanation'] as String?,
      answerImagePaths: parseImagePaths(json['answerImagePaths']),
      explanationImagePaths: parseImagePaths(json['explanationImagePaths']),
      tableData: parseTableData(json['tableData']),
      isKillerProblem: json['isKillerProblem'] as bool? ?? false,
    );
  }
}