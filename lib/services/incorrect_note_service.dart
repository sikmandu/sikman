// lib/services/incorrect_note_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incorrect_question_info.dart'; // 경로 주의!

class IncorrectNoteService {
  static const _key = 'incorrectNotes'; // 데이터를 저장할 키 이름

  // IncorrectQuestionInfo 객체를 저장 가능한 문자열로 변환
  // 형식: "year|sessionNumber|questionIndex|snippet"
  // 주의: snippet에 | 문자가 포함되면 문제가 생길 수 있음 (Base64 인코딩 등으로 개선 가능)
  String _encodeNote(IncorrectQuestionInfo note) {
    // snippet에서 | 문자 임시 제거 (간단 처리)
    final safeSnippet = note.questionTextSnippet.replaceAll('|', '');
    return '${note.year}|${note.sessionNumber}|${note.questionIndex}|$safeSnippet';
  }

  // 저장된 문자열을 IncorrectQuestionInfo 객체로 변환
  IncorrectQuestionInfo? _decodeNote(String encodedNote) {
    try {
      final parts = encodedNote.split('|');
      if (parts.length == 4) {
        return IncorrectQuestionInfo(
          year: int.parse(parts[0]),
          sessionNumber: int.parse(parts[1]),
          questionIndex: int.parse(parts[2]),
          questionTextSnippet: parts[3],
        );
      }
    } catch (e) {
      print("Error decoding note: $encodedNote, Error: $e");
    }
    return null; // 변환 실패 시 null 반환
  }

  // 오답 노트 목록을 기기에 저장하는 함수
  Future<void> saveIncorrectNotes(List<IncorrectQuestionInfo> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedNotes = notes.map(_encodeNote).toList();
    await prefs.setStringList(_key, encodedNotes);
    print("오답 노트 저장 완료: ${encodedNotes.length}개");
  }

  // 기기에서 오답 노트 목록을 불러오는 함수
  Future<List<IncorrectQuestionInfo>> loadIncorrectNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> encodedNotes = prefs.getStringList(_key) ?? [];
      print("오답 노트 로드 시도: ${encodedNotes.length}개 문자열 발견");
      final List<IncorrectQuestionInfo> notes = encodedNotes
          .map(_decodeNote) // 각 문자열을 객체로 변환 시도
          .whereType<IncorrectQuestionInfo>() // null이 아닌 객체만 필터링
          .toList();
      print("오답 노트 로드 완료: ${notes.length}개 객체 변환 성공");
      return notes;
    } catch (e) {
      print("Error loading incorrect notes: $e");
      return []; // 에러 발생 시 빈 리스트 반환
    }
  }
}