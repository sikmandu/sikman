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

  List<dynamic> _displayItems = []; // 헤더(String) 또는 노트(IncorrectQuestionInfo) 저장

  bool _isSelectionMode = false;
  Set<IncorrectQuestionInfo> _selectedNotes = {}; // 선택된 노트들을 저장 (Set 사용)

  @override
  void initState() {
    super.initState();
    _fetchAndPrepareNotes(); // 데이터 로드 및 준비 함수 호출
  }

  // 노트를 저장소에서 불러오는 비동기 함수
  Future<void> _fetchAndPrepareNotes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    _notes = await _noteService.loadIncorrectNotes();
    _notes.sort((a, b) {
      // 1. 유형(Type) 기준으로 오름차순 정렬
      int typeCompare = a.questionType.compareTo(b.questionType);
      if (typeCompare != 0) return typeCompare;
      // 2. 연도(Year) 기준으로 내림차순 정렬
      int yearCompare = b.year.compareTo(a.year);
      if (yearCompare != 0) return yearCompare;
      // 3. 회차(Session) 기준으로 오름차순 정렬
      int sessionCompare = a.sessionNumber.compareTo(b.sessionNumber);
      if (sessionCompare != 0) return sessionCompare;
      // 4. 문제 인덱스(Index) 기준으로 오름차순 정렬
      return a.questionIndex.compareTo(b.questionIndex);
    });
    _displayItems = [];
    String? currentType;
    for (var note in _notes) {
      if (note.questionType != currentType) {
        currentType = note.questionType;
        _displayItems.add(currentType); // 유형 헤더 추가 (문자열)
      }
      _displayItems.add(note); // 오답 노트 정보 추가 (객체)
    }// 저장된 노트 로드
    if (mounted) {
      setState(() { _isLoading = false; }); // 로딩 완료
    }
  }

  // 목록 화면에서 직접 노트를 삭제하고 저장하는 함수
  // --- 노트 삭제 함수 ---
  Future<void> _removeIncorrectNote(IncorrectQuestionInfo noteToRemove) async {

    // 삭제 진행
    List<IncorrectQuestionInfo> currentNotes = await _noteService.loadIncorrectNotes();
    int initialLength = currentNotes.length;
    currentNotes.removeWhere((note) => note == noteToRemove); // Use == operator

    if (currentNotes.length < initialLength) { // 삭제가 실제로 일어났는지 확인
      await _noteService.saveIncorrectNotes(currentNotes); // 변경된 목록 저장
      await _fetchAndPrepareNotes(); // ★★★ 목록 다시 로드 및 그룹화 (내부에 setState 포함) ★★★

      // ★★★ 추가: UI 갱신을 확실히 하기 위해 setState 한 번 더 호출 ★★★
      if (mounted) {
        setState(() {}); // 비어있더라도 호출하여 리빌드 유도
      }
      // ★★★---------------------------------------------------★★★

      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar( content: Text('오답 노트에서 제거되었습니다.'), duration: Duration(seconds: 2), ),
        );
      }
    } else {
      print("Note not found for deletion in list screen.");
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar( content: Text('이미 삭제되었거나 찾을 수 없는 노트입니다.'), duration: Duration(seconds: 2), ),
        );
      }
      // 삭제할 노트가 없어도 목록은 한번 갱신
      await _fetchAndPrepareNotes();
      if (mounted) {
        setState(() {});
      }
    }
  }
  Future<void> _deleteSelectedNotes() async {
    if (_selectedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제할 오답 노트를 선택하세요.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('선택 항목 삭제 확인'),
            content: Text('${_selectedNotes.length}개의 오답 노트를 삭제하시겠습니까?'),
            actions: <Widget>[
              TextButton(
                child: const Text('취소'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        }
    );

    if (confirmed == true) {
      List<IncorrectQuestionInfo> currentNotes = await _noteService.loadIncorrectNotes();
      // 선택된 항목들 제거
      currentNotes.removeWhere((note) => _selectedNotes.contains(note));
      await _noteService.saveIncorrectNotes(currentNotes);

      // 상태 업데이트 및 모드 종료
      setState(() {
        _isSelectionMode = false;
        _selectedNotes.clear();
        _isLoading = true; // 로딩 표시기 잠시 보여주기
      });
      await _fetchAndPrepareNotes(); // 목록 새로고침

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedNotes.length}개의 오답 노트가 삭제되었습니다.'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }
  // ------------------------------------

  // --- ★★★ 전체 선택/해제 함수 ★★★ ---
  void _toggleSelectAll() {
    setState(() {
      if (_selectedNotes.length == _notes.length) {
        // 이미 전체 선택 상태면 전체 해제
        _selectedNotes.clear();
      } else {
        // 아니면 전체 선택
        _selectedNotes = Set.from(_notes);
      }
    });
  }
  // -----------------------------------

  // --- 수정: 삭제 함수는 ReviewScreen에서 처리하므로 여기선 불필요 ---
  // void _removeIncorrectNote(IncorrectQuestionInfo noteToRemove) { ... }
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- ★★★ AppBar 동적 변경 ★★★ ---
        title: Text(
            _isSelectionMode ? '${_selectedNotes.length}개 선택됨' : '오답 노트 (${_notes.length}개)'
        ), // _notes.length 사용
    actions: _isSelectionMode
    ? [ // 선택 모드일 때의 버튼들
    // 전체 선택 버튼 (선택적)
    IconButton(
    icon: Icon(
    _selectedNotes.length == _notes.length && _notes.isNotEmpty
    ? Icons.deselect
        : Icons.select_all
    ),
    tooltip: '전체 선택/해제',
    onPressed: _notes.isEmpty ? null : _toggleSelectAll, // 노트 없으면 비활성화
    ),
    // 선택 항목 삭제 버튼
    IconButton(
    icon: const Icon(Icons.delete_sweep_outlined),
    tooltip: '선택 삭제',
    onPressed: _selectedNotes.isEmpty ? null : _deleteSelectedNotes, // 선택된게 없으면 비활성화
    ),
    // 취소 버튼
    IconButton(
    icon: const Icon(Icons.close),
    tooltip: '취소',
    onPressed: () {
    setState(() {
    _isSelectionMode = false;
    _selectedNotes.clear();
    });
    },
    ),
    ]
        : [ // 일반 모드일 때의 버튼들
    // 새로고침 버튼 (기존 유지)
    IconButton(
    icon: const Icon(Icons.refresh),
    tooltip: '새로고침',
    onPressed: _fetchAndPrepareNotes,
    ),
    // 선택 모드 진입 버튼
    TextButton(
    child: const Text('선택', style: TextStyle(color: Colors.white)),
    onPressed: () {
    setState(() {
    _isSelectionMode = true;
    _selectedNotes.clear(); // 선택 모드 진입 시 선택 초기화
    });
    },
    ),
    ],
      ),
      body: _isLoading // 로딩 상태 표시
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty // 로딩 완료 후 목록 상태에 따라 표시
          ? const Center( child: Text( '오답 노트가 비어있습니다...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey), ), )
          : ListView.builder(
        itemCount: _displayItems.length, // 그룹화된 목록 개수 사용
        itemBuilder: (context, index) {
          final item = _displayItems[index];

          // --- 아이템 타입에 따라 위젯 분기 ---
          if (item is String) {
            // 유형 헤더 표시 (기존 유지 - 이미 가운데 정렬됨)
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Colors.grey.shade200,
              child: Text(
                item,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, // Container가 stretch되므로 필요
              ),
            );
          } else if (item is IncorrectQuestionInfo) {
            // 오답 노트 ListTile 표시
            final note = item;
            final bool isSelected = _selectedNotes.contains(note);
            return Container( // 선택 시 배경색 변경 효과를 위해 Container 사용
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                // 선택 모드일 때만 체크박스 표시 (leading 사용)
                leading: _isSelectionMode
                ? Checkbox(
                value: isSelected,
                onChanged: (bool? selected) {
              setState(() {
                if (selected == true) {
                  _selectedNotes.add(note);
                } else {
                  _selectedNotes.remove(note);
                }
              });
            },
          )
              : null, // 일반 모드에서는 leading 없음
          title: Center( // 제목 가운데 정렬
          child: Text(
          '${note.year}년 ${note.sessionNumber}회차 - ${note.questionNumber}번 문제',
          ),
          ),
          subtitle: null, // 부제목 제거됨
          // 선택 모드일 때는 개별 삭제 버튼 숨김
                  trailing: null,
                  onTap: () {
                    if (_isSelectionMode) {
                      // 선택 모드에서는 탭으로 선택/해제
                      setState(() {
                        if (isSelected) {
                          _selectedNotes.remove(note);
                        } else {
                          _selectedNotes.add(note);
                        }
                      });
                    } else {
                      // 일반 모드에서는 복습 화면으로 이동 (기존 로직)
                      int originalIndex = _notes.indexWhere((n) => n == note);
                      if (originalIndex != -1) { Navigator.push( context, MaterialPageRoute( builder: (context) => IncorrectNoteReviewScreen(
                        // 전체 오답 목록(_notes)과 해당 노트의 인덱스를 전달
                        incorrectNotes: List.from(_notes),
                        initialIndex: originalIndex, // _notes에서의 인덱스
                      ),),).then((_) { _fetchAndPrepareNotes(); });
                      } else { print("Error: Could not find original index."); }
                    }
                  },
                  // 선택 상태 시각적 표시 (ListTile 자체 속성)
                  // selected: isSelected,
                  // selectedTileColor: Colors.blue.shade50, // Container로 대체됨
                ),
            );
            // --------------------------------------------
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}