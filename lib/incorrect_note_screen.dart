import 'package:flutter/material.dart';
import 'models/incorrect_question_info.dart'; // Model import 확인
import 'incorrect_note_review_screen.dart'; // 복습 화면 import 확인
import 'services/incorrect_note_service.dart'; // 경로 주의!

class IncorrectNoteScreen extends StatefulWidget {
  const IncorrectNoteScreen({super.key});
  @override State<IncorrectNoteScreen> createState() => _IncorrectNoteScreenState();
}

class _IncorrectNoteScreenState extends State<IncorrectNoteScreen> {
  // --- 상태 변수 ---
  List<IncorrectQuestionInfo> _notes = []; // 화면에 표시될 로드된 노트 목록
  bool _isLoading = true; // 로딩 상태
  final IncorrectNoteService _noteService = IncorrectNoteService(); // 서비스 객체

  @override
  void initState() {
    super.initState();
    _fetchNotes(); // 화면 시작 시 노트 불러오기
  }

  // 노트를 저장소에서 불러오는 비동기 함수
  Future<void> _fetchNotes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; }); // 로딩 시작
    _notes = await _noteService.loadIncorrectNotes(); // 저장된 노트 로드
    if (mounted) {
      setState(() { _isLoading = false; }); // 로딩 완료
    }
  }

  // 목록 화면에서 직접 노트를 삭제하고 저장하는 함수
  Future<void> _removeIncorrectNote(IncorrectQuestionInfo noteToRemove) async {
    List<IncorrectQuestionInfo> currentNotes = List.from(_notes); // 현재 목록 복사
    currentNotes.remove(noteToRemove); // 리스트에서 제거

    // 변경된 목록을 저장소에 저장
    await _noteService.saveIncorrectNotes(currentNotes);

    // 화면 상태 업데이트 및 피드백
    if(mounted){
      setState(() {
        _notes = currentNotes; // 화면 목록 업데이트
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오답 노트에서 제거되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  // -----------------------------------

  // --- 수정: 삭제 함수는 ReviewScreen에서 처리하므로 여기선 불필요 ---
  // void _removeIncorrectNote(IncorrectQuestionInfo noteToRemove) { ... }
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('오답 노트 (${_notes.length}개)'), // _notes.length 사용
        actions: [ // 새로고침 버튼 추가
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _fetchNotes, // 버튼 누르면 노트 다시 로드
          )
        ],
      ),
      body: _isLoading // 로딩 상태 표시
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty // 로딩 완료 후 목록 상태에 따라 표시
          ? const Center( child: Text( '오답 노트가 비어있습니다...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey), ), )
          : ListView.builder(
        itemCount: _notes.length, // _notes 사용
        itemBuilder: (context, index) {
          final note = _notes[index]; // _notes 사용
          return ListTile(
            title: Text('${note.year}년 ${note.sessionNumber}회차 - ${note.questionIndex + 1}번 문제'),
            subtitle: Text(note.questionTextSnippet, maxLines: 2, overflow: TextOverflow.ellipsis),
            // --- 삭제 버튼 로직 수정 ---
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: '오답 노트에서 삭제',
              onPressed: () {
                // 삭제 확인 다이얼로그
                showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog( /* ... 이전과 동일 ... */
                        title: const Text('삭제 확인'),
                        content: Text('${note.year}년 ${note.sessionNumber}회차 - ${note.questionIndex + 1}번 문제를 오답 노트에서 삭제하시겠습니까?'),
                        actions: <Widget>[
                          TextButton(child: const Text('취소'), onPressed: () => Navigator.of(dialogContext).pop()),
                          TextButton(child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _removeIncorrectNote(note); // 수정된 삭제 함수 호출
                            },
                          ),
                        ],
                      );
                    }
                );
              },
            ),
            // ----------------------------------------------------
            // 항목 본문 탭: 복습 화면으로 이동 (이전과 동일)
            onTap: () {
              Navigator.push( context, MaterialPageRoute( builder: (context) => IncorrectNoteReviewScreen( incorrectNotes: List.from(_notes), initialIndex: index,),),
              ).then((_) {
                print('Returned from ReviewScreen, refreshing list.');
                _fetchNotes(); // 저장소에서 다시 로드
              });
            },
          );
        },
      ),
    );
  }
}