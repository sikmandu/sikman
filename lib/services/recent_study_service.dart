// lib/services/recent_study_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class RecentStudyService {
  static const String _keyPrefix = 'recent_study_';

  // 과년도 최근 학습 정보 저장
  Future<void> saveRecentPastExam(int year, int session, int questionNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_keyPrefix}past_exam_year', year);
    await prefs.setInt('${_keyPrefix}past_exam_session', session);
    await prefs.setInt('${_keyPrefix}past_exam_q_num', questionNumber);
    print('최근 학습 저장 (과년도): $year년 $session회차 $questionNumber번');
  }

  Future<Map<String, int?>?> loadRecentPastExam() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('${_keyPrefix}past_exam_year')) return null;
    return {
      'year': prefs.getInt('${_keyPrefix}past_exam_year'),
      'session': prefs.getInt('${_keyPrefix}past_exam_session'),
      'q_num': prefs.getInt('${_keyPrefix}past_exam_q_num'),
    };
  }

  // 유형별 최근 학습 정보 저장
  Future<void> saveRecentCategoryExam(String category, int year, int session, int questionNumber) async {
    final prefs = await SharedPreferences.getInstance();
    String safeCategoryKey = category.replaceAll(' ', '_').replaceAll('/', '_');
    await prefs.setInt('${_keyPrefix}cat_${safeCategoryKey}_year', year);
    await prefs.setInt('${_keyPrefix}cat_${safeCategoryKey}_session', session);
    await prefs.setInt('${_keyPrefix}cat_${safeCategoryKey}_q_num', questionNumber);
    print('최근 학습 저장 (유형별 - $category): $year년 $session회차 $questionNumber번');
  }

  // 유형별 최근 학습 정보 로드
  Future<Map<String, dynamic>?> loadRecentCategoryExam(String category) async {
    final prefs = await SharedPreferences.getInstance();
    String safeCategoryKey = category.replaceAll(' ', '_').replaceAll('/', '_');
    if (!prefs.containsKey('${_keyPrefix}cat_${safeCategoryKey}_year')) return null;
    return {
      'category': category,
      'year': prefs.getInt('${_keyPrefix}cat_${safeCategoryKey}_year'),
      'session': prefs.getInt('${_keyPrefix}cat_${safeCategoryKey}_session'),
      'q_num': prefs.getInt('${_keyPrefix}cat_${safeCategoryKey}_q_num'),
    };
  }
  Future<void> saveLastViewedIncorrectNoteDetail({
    required int year,
    required int session,
    required int questionNumber,
    required String category,
    required int originalIndex, // 원본 JSON에서의 인덱스
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_keyPrefix}incorrect_note_year', year);
    await prefs.setInt('${_keyPrefix}incorrect_note_session', session);
    await prefs.setInt('${_keyPrefix}incorrect_note_q_num', questionNumber);
    await prefs.setString('${_keyPrefix}incorrect_note_category', category);
    await prefs.setInt('${_keyPrefix}incorrect_note_orig_idx', originalIndex);
    print('최근 학습 저장 (오답노트 상세): $year년 $session회 $questionNumber번 (유형:$category, 원본idx:$originalIndex)');
  }

  // 오답노트 최근 학습 정보 로드 (상세 정보 로드)
  Future<Map<String, dynamic>?> loadLastViewedIncorrectNoteDetail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('${_keyPrefix}incorrect_note_year')) {
      print("RecentStudyService: 저장된 오답노트 최근 학습 정보 없음");
      return null;
    }
    return {
      'year': prefs.getInt('${_keyPrefix}incorrect_note_year'),
      'session': prefs.getInt('${_keyPrefix}incorrect_note_session'),
      'q_num': prefs.getInt('${_keyPrefix}incorrect_note_q_num'),
      'category': prefs.getString('${_keyPrefix}incorrect_note_category'),
      'originalJsonIndex': prefs.getInt('${_keyPrefix}incorrect_note_orig_idx'), // 원본 JSON 인덱스 로드
    };
  }
}
