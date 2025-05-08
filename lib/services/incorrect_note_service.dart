// lib/services/incorrect_note_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incorrect_question_info.dart'; // 경로 주의!

class IncorrectNoteService {
  // ★★★ 키 이름 변경 권장 (데이터 구조 변경) ★★★
  static const _key = 'incorrectNotes_v3';

  // 오답 노트 목록을 기기에 저장하는 함수
  Future<void> saveIncorrectNotes(List<IncorrectQuestionInfo> notes) async {
    final prefs = await SharedPreferences.getInstance();
    // 모델의 encodeToString 사용 (이미 수정됨)
    final List<String> encodedNotes = notes.map((note) => note.encodeToString()).toList();
    await prefs.setStringList(_key, encodedNotes);
    print("오답 노트 저장 완료 (v3): ${encodedNotes.length}개");
  }

  // 기기에서 오답 노트 목록을 불러오는 함수
  Future<List<IncorrectQuestionInfo>> loadIncorrectNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ★★★ 새 키 또는 이전 키 + 새 키 모두 로드 고려 ★★★
      final List<String> encodedNotes = prefs.getStringList(_key) ?? [];
      // 이전 버전 키 로드 (선택적)
      // final List<String> oldNotesV2 = prefs.getStringList('incorrectNotes_v2') ?? [];
      // encodedNotes.addAll(oldNotesV2); // 마이그레이션 필요한 경우 병합

      print("오답 노트 로드 시도 (v3): ${encodedNotes.length}개 문자열 발견");
      // 모델의 decodeFromString 사용 (이미 수정됨)
      final List<IncorrectQuestionInfo> notes = encodedNotes
          .map(IncorrectQuestionInfo.decodeFromString)
          .whereType<IncorrectQuestionInfo>()
          .toList();
      print("오답 노트 로드 완료 (v3): ${notes.length}개 객체 변환 성공");

      // 마이그레이션: 만약 이전 버전 데이터를 로드했다면, 변환 후 새 키로 저장하고 이전 키 삭제
      // if (oldNotesV2.isNotEmpty) {
      //   await saveIncorrectNotes(notes); // 변환된 전체 노트를 새 키로 저장
      //   await prefs.remove('incorrectNotes_v2'); // 이전 키 삭제
      //   print("Migrated v2 notes to v3.");
      // }

      return notes;
    } catch (e) {
      print("Error loading incorrect notes (v3): $e");
      return [];
    }
  }
}