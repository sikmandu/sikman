import 'package:flutter/foundation.dart';
import 'package:sikman/services/recent_study_service.dart'; // 실제 경로로 수정하세요.

class RecentStudyInfo {
  final int year;
  final int session;
  final int questionNumber;
  final String? category;
  final int? originalIndex; // 이 필드는 UI 네비게이션 등에 사용

  RecentStudyInfo({
    required this.year,
    required this.session,
    required this.questionNumber,
    this.category,
    this.originalIndex,
  });

  @override
  String toString() {
    String mainInfo = '$year년 $session회차 $questionNumber번';
    if (category != null && category!.isNotEmpty) {
      return '$category - $mainInfo';
    }
    return mainInfo;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RecentStudyInfo &&
              runtimeType == other.runtimeType &&
              year == other.year &&
              session == other.session &&
              questionNumber == other.questionNumber &&
              category == other.category &&
              originalIndex == other.originalIndex;

  @override
  int get hashCode =>
      year.hashCode ^
      session.hashCode ^
      questionNumber.hashCode ^
      category.hashCode ^
      originalIndex.hashCode;
}

class RecentStudyNotifier with ChangeNotifier {
  final RecentStudyService _service = RecentStudyService();

  RecentStudyInfo? _recentPastExam;
  Map<String, RecentStudyInfo?> _recentCategoryExams = {};
  RecentStudyInfo? _recentIncorrectNoteItem;

  RecentStudyInfo? get recentPastExam => _recentPastExam;
  RecentStudyInfo? getRecentStudyForCategory(String category) => _recentCategoryExams[category];
  RecentStudyInfo? get recentIncorrectNoteItem => _recentIncorrectNoteItem;

  RecentStudyNotifier() {
    print("RecentStudyNotifier: 생성됨, 모든 초기 데이터 로드 시작");
    loadInitialAllData();
  }

  Future<void> loadInitialAllData() async {
    await _loadInitialPastExamData();
    await _loadInitialIncorrectNoteData();
    // 유형별 카테고리 데이터는 CategoryScreen에서 화면에 필요한 카테고리에 대해
    // loadRecentStudyForCategoryIfNotLoaded를 호출하여 로드하는 것이 효율적입니다.
    print("RecentStudyNotifier: 초기 데이터 로드 완료 후 notifyListeners 호출");
    notifyListeners(); // 모든 초기 로드 후 한 번만 호출
  }

  Future<void> _loadInitialPastExamData() async {
    final data = await _service.loadRecentPastExam(); // 서비스는 year, session, q_num만 반환
    if (data != null && data['year'] != null && data['session'] != null && data['q_num'] != null) {
      _recentPastExam = RecentStudyInfo(
        year: data['year']!,
        session: data['session']!,
        questionNumber: data['q_num']!,
        originalIndex: data['q_num']! -1, // q_num (문제번호) 기준으로 originalIndex 계산
      );
      print("RecentStudyNotifier: 과년도 초기 데이터 로드 - ${_recentPastExam.toString()}");
    } else {
      _recentPastExam = null;
      print("RecentStudyNotifier: 과년도 초기 데이터 없음");
    }
    // notifyListeners(); // loadInitialAllData에서 한 번만 호출
  }

  Future<void> loadRecentStudyForCategoryIfNotLoaded(String category) async {
    if (!_recentCategoryExams.containsKey(category) || _recentCategoryExams[category] == null) {
      print("RecentStudyNotifier: 카테고리 '$category' 최근 학습 정보 로드 시도");
      final data = await _service.loadRecentCategoryExam(category); // 서비스는 category, year, session, q_num 반환
      if (data != null && data['year'] != null && data['session'] != null && data['q_num'] != null) {
        _recentCategoryExams[category] = RecentStudyInfo(
          category: category,
          year: data['year']! as int, // 타입 캐스팅 명시
          session: data['session']! as int, // 타입 캐스팅 명시
          questionNumber: data['q_num']! as int, // 타입 캐스팅 명시
          originalIndex: (data['q_num']! as int) -1, // q_num (문제번호) 기준으로 originalIndex 계산
        );
        print("RecentStudyNotifier: 카테고리 '$category' 데이터 로드 - ${_recentCategoryExams[category].toString()}");
      } else {
        _recentCategoryExams[category] = null;
        print("RecentStudyNotifier: 카테고리 '$category' 데이터 없음");
      }
      notifyListeners();
    }
  }


  Future<void> _loadInitialIncorrectNoteData() async {
    // RecentStudyService에 오답노트용 최근 학습 로드/저장 함수가 정의되어 있어야 합니다.
    // (현재 RecentStudyService에는 이 기능이 없습니다. 필요하다면 추가해야 합니다.)
    // 예시: final data = await _service.loadRecentIncorrectNote();
    // if (data != null) { ... }
    _recentIncorrectNoteItem = null; // 우선 null로 초기화
    print("RecentStudyNotifier: 오답노트 초기 데이터 로드 (현재 기능 미구현 상태)");
    // notifyListeners(); // loadInitialAllData에서 한 번만 호출
  }



  // 과년도 최근 학습 정보 업데이트
  // originalIndexIfAvailable 파라미터는 RecentStudyInfo 객체 생성에만 사용하고,
  // _service.saveRecentPastExam 호출 시에는 전달하지 않습니다.
  Future<void> updateRecentPastExam(int year, int session, int questionNumber, [int? originalIndexIfAvailable]) async {
    final newInfo = RecentStudyInfo(
        year: year, session: session, questionNumber: questionNumber, originalIndex: originalIndexIfAvailable ?? (questionNumber -1)
    );
    if (_recentPastExam != newInfo) {
      _recentPastExam = newInfo;
      print("RecentStudyNotifier: 과년도 최근 학습 업데이트됨 - ${_recentPastExam.toString()}");
      notifyListeners();
      // ★★★ _service.saveRecentPastExam는 3개의 인자(year, session, questionNumber)만 받습니다. ★★★
      await _service.saveRecentPastExam(year, session, questionNumber);
    }
  }

  // 유형별 최근 학습 정보 업데이트
  // originalIndexIfAvailable 파라미터는 RecentStudyInfo 객체 생성에만 사용하고,
  // _service.saveRecentCategoryExam 호출 시에는 전달하지 않습니다.
  Future<void> updateRecentCategoryExam(String category, int year, int session, int questionNumber, [int? originalIndexIfAvailable]) async {
    final newInfo = RecentStudyInfo(
        category: category, year: year, session: session, questionNumber: questionNumber, originalIndex: originalIndexIfAvailable ?? (questionNumber-1)
    );
    if (_recentCategoryExams[category] != newInfo) {
      _recentCategoryExams[category] = newInfo;
      print("RecentStudyNotifier: 유형별($category) 최근 학습 업데이트됨 - ${_recentCategoryExams[category]?.toString()}");
      notifyListeners();
      // ★★★ _service.saveRecentCategoryExam는 4개의 인자(category, year, session, questionNumber)만 받습니다. ★★★
      await _service.saveRecentCategoryExam(category, year, session, questionNumber);
    }
  }

  // 오답노트에서 문제를 봤을 때 호출될 함수
  // ★★★ updateRecentIncorrectNoteView 메소드 시그니처 변경 (originalIndexIfAvailable 추가) ★★★
  // category 인자는 필수입니다 (오답노트 문제의 원본 유형)
  Future<void> updateRecentIncorrectNoteView(int year, int session, int questionNumber, String category, [int? originalIndexIfAvailable]) async {
    print("RecentStudyNotifier: updateRecentIncorrectNoteView 호출됨 - $year년 $session회 $questionNumber번, Cat:$category, Index:$originalIndexIfAvailable");

    int effectiveOriginalIndex = originalIndexIfAvailable ?? (questionNumber > 0 ? questionNumber - 1 : 0);

    // 1. 오답노트 자체의 "최근 본 문제" 상태 업데이트 (선택적)
    final newIncorrectInfo = RecentStudyInfo(
        year: year, session: session, questionNumber: questionNumber, originalIndex: effectiveOriginalIndex, category: category
    );
    if (_recentIncorrectNoteItem != newIncorrectInfo) {
      _recentIncorrectNoteItem = newIncorrectInfo;
      print("RecentStudyNotifier: 오답노트 최근 학습 내부 상태 업데이트됨 - ${_recentIncorrectNoteItem.toString()}");
      // 오답노트 "최근 학습"을 SharedPreferences에 별도로 저장하고 싶다면,
      // RecentStudyService에 saveRecentIncorrectNoteItem(RecentStudyInfo info) 같은 함수를 만들고 호출합니다.
      // 예: await _service.saveRecentIncorrectNoteItem(newIncorrectInfo);
    }

    // 2. 이 문제가 원래 속했던 과년도 최근 학습 정보 업데이트
    //    originalIndex는 updateRecentPastExam의 옵셔널 파라미터로 전달
    await updateRecentPastExam(year, session, questionNumber, effectiveOriginalIndex);

    // 3. 이 문제가 원래 속했던 유형(카테고리) 최근 학습 정보 업데이트
    //    originalIndex는 updateRecentCategoryExam의 옵셔널 파라미터로 전달
    if (category.isNotEmpty) {
      await updateRecentCategoryExam(category, year, session, questionNumber, effectiveOriginalIndex);
    }
    // notifyListeners(); // 각 update... 메소드에서 이미 호출하므로, 여기서 중복 호출하면 여러번 화면이 갱신될 수 있음.
    // 또는, 모든 작업이 끝난 후 여기서 한번만 호출하는 것을 고려할 수 있으나,
    // 각 update 메소드가 실제로 상태를 변경했을 때만 notify하는 것이 더 효율적.
    // 현재는 각 update 메소드에서 notifyListeners()를 호출합니다.
  }
}