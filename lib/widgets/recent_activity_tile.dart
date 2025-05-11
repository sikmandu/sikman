// lib/widgets/recent_activity_tile.dart
import 'package:flutter/material.dart';
import 'package:sikman/question_screen.dart'; // QuestionScreen 경로 확인
import 'package:sikman/incorrect_note_review_screen.dart'; // IncorrectNoteReviewScreen 경로 확인
import 'package:sikman/models/incorrect_question_info.dart'; // IncorrectQuestionInfo 경로 확인 (오답노트용)

enum RecentActivityType { pastExam, categoryExam, incorrectNote }

class RecentActivityTile extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic>? data; // 저장된 최근 학습 데이터
  final RecentActivityType type;   // 최근 학습의 종류
  final List<IncorrectQuestionInfo>? allIncorrectNotes; // 오답노트 최근 학습 시 전체 목록 전달 (선택적)
  final VoidCallback onReturnFromScreen; // 문제 화면에서 돌아왔을 때 호출될 콜백
  final List<IncorrectQuestionInfo>? allIncorrectNotesForLookup;

  const RecentActivityTile({
    super.key,
    required this.isLoading,
    this.data,
    required this.type,
    this.allIncorrectNotes, // 오답노트용
    required this.onReturnFromScreen,
    this.allIncorrectNotesForLookup, // 생성자에도 반영
  });

  String _getTitle() {
    if (data == null) return '';
    switch (type) {
      case RecentActivityType.pastExam:
        return '최근 학습: ${data!['year']}년 ${data!['session']}회차';
      case RecentActivityType.categoryExam:
        return '최근 학습: ${data!['category']}';
      case RecentActivityType.incorrectNote:
        return '최근 학습: ${data!['year']}년 ${data!['session']}회차';
      default:
        return '최근 학습';
    }
  }

  String _getSubtitle() {
    if (data == null) return '';
    switch (type) {
      case RecentActivityType.pastExam:
      case RecentActivityType.categoryExam:
        return '문제: ${data!['number']}번 (${data!['type']})';
      case RecentActivityType.incorrectNote:
        return '문제: ${data!['number']}번 (${data!['type']})';
      default:
        return '';
    }
  }

  IconData _getIcon() {
    // 타입별로 다른 아이콘 반환 가능
    return Icons.history;
  }

  Color _getIconColor() {
    switch (type) {
      case RecentActivityType.pastExam:
        return Colors.blueAccent;
      case RecentActivityType.categoryExam:
        return Colors.deepPurpleAccent;
      case RecentActivityType.incorrectNote:
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  Color _getTileColor() {
    switch (type) {
      case RecentActivityType.pastExam:
        return Colors.blue.shade50;
      case RecentActivityType.categoryExam:
        return Colors.deepPurple.shade50;
      case RecentActivityType.incorrectNote:
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  void _navigateToScreen(BuildContext context) {
    if (data == null) return;

    Widget screenToNavigate;

    switch (type) {
      case RecentActivityType.pastExam:
        screenToNavigate = QuestionScreen(
          year: data!['year'] as int,
          sessionNumber: data!['session'] as int,
          initialIndex: data!['index'] as int,
        );
        break;
      case RecentActivityType.categoryExam:
        screenToNavigate = QuestionScreen(
          year: data!['year'] as int,
          sessionNumber: data!['session'] as int,
          initialIndex: data!['index'] as int,
          categoryFilter: data!['category'] as String,
        );
        break;
      case RecentActivityType.incorrectNote:
      // --- ★★★ allIncorrectNotesForLookup null 또는 empty 체크 강화 ★★★ ---
        if (allIncorrectNotesForLookup == null || allIncorrectNotesForLookup!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오답 노트 목록을 찾을 수 없습니다. 목록을 먼저 확인해주세요.'), duration: Duration(seconds: 2)));
          return; // 네비게이션 중단
        }
        int targetIndex = allIncorrectNotes!.indexWhere((note) =>
        note.year == data!['year'] &&
            note.sessionNumber == data!['session'] &&
            note.questionIndex == data!['originalIndex']);

        if (targetIndex != -1) {
          screenToNavigate = IncorrectNoteReviewScreen(
            incorrectNotes: List.from(allIncorrectNotes!),
            initialIndex: targetIndex,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최근 학습 오답 항목을 찾을 수 없습니다.'), duration: Duration(seconds: 2)),
          );
          return;
        }
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screenToNavigate))
        .then((_) => onReturnFromScreen()); // 부모에게 전달받은 콜백 호출
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (data == null) {
      return const SizedBox.shrink(); // 데이터 없으면 아무것도 표시 안 함
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0), // 기본 여백
      child: ListTile(
        dense: true,
        tileColor: _getTileColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        leading: Icon(_getIcon(), color: _getIconColor()),
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _getSubtitle(),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.play_arrow),
        onTap: () => _navigateToScreen(context),
      ),
    );
  }
}