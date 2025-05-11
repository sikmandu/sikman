import 'package:flutter/material.dart';
import 'models/incorrect_question_info.dart'; // Model import 확인
import 'incorrect_note_review_screen.dart'; // 복습 화면 import 확인
import 'services/incorrect_note_service.dart'; // 경로 주의!
import 'package:shared_preferences/shared_preferences.dart'; // Import 추가
import 'dart:convert'; // jsonDecode 사용
import 'widgets/common_app_bar.dart'; // ★★★ 공통 AppBar import ★★★
import 'widgets/recent_activity_tile.dart';
import 'services/recent_study_service.dart'; // ★ 추가: 최근 학습 서비스

const String prefKeyRecentIncorrectNote = 'recent_incorrect_note_v1';

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

  final RecentStudyService _recentStudyService = RecentStudyService();
  Map<String, dynamic>? _lastViewedIncorrectNoteDetail; // 로드된 오답노트 최근 학습 정보

  @override
  void initState() {
    super.initState();
    _fetchAndPrepareAllNotesData(); // 오답 목록과 최근 학습 정보 모두 로드
  }


  Future<void> _fetchAndPrepareAllNotesData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    // 1. 오답 목록 로드 및 그룹화 (기존 로직)
    _notes = await _noteService.loadIncorrectNotes();
    // questionNumber 기준으로 정렬 (또는 year, session, questionNumber 순)
    _notes.sort((a, b) {
      int yearCompare = a.year.compareTo(b.year);
      if (yearCompare != 0) return yearCompare;
      int sessionCompare = a.sessionNumber.compareTo(b.sessionNumber);
      if (sessionCompare != 0) return sessionCompare;
      return a.questionNumber.compareTo(b.questionNumber);
    });
    _displayItems = [];
    String? currentType;
    for (var note in _notes) {
      if (note.questionType != currentType) {
        currentType = note.questionType;
        _displayItems.add(currentType);
      }
      _displayItems.add(note);
    }

    // ★★★ 2. 오답노트 전용 "최근 학습" 정보 로드 ★★★
    final data = await _recentStudyService.loadLastViewedIncorrectNoteDetail();
    if (mounted) {
      setState(() {
        _lastViewedIncorrectNoteDetail = data;
        _isLoading = false;
      });
      if (data != null) {
        print("IncorrectNoteScreen: 로드된 최근 오답 정보: ${data.toString()}");
      } else {
        print("IncorrectNoteScreen: 로드된 최근 오답 정보 없음.");
      }
    }
  }
  void _navigateToRecentIncorrectNoteReview() {
    if (_lastViewedIncorrectNoteDetail != null) {
      final year = _lastViewedIncorrectNoteDetail!['year'] as int?;
      final session = _lastViewedIncorrectNoteDetail!['session'] as int?;
      final qNum = _lastViewedIncorrectNoteDetail!['q_num'] as int?;
      // final category = _lastViewedIncorrectNoteDetail!['category'] as String?; // 필요시 사용
      // final originalJsonIndex = _lastViewedIncorrectNoteDetail!['originalJsonIndex'] as int?; // 필요시 사용

      if (year != null && session != null && qNum != null) {
        // 오답 목록(_notes)에서 해당 문제의 인덱스(오답 목록 내에서의 순번)를 찾아야 함
        int reviewScreenInitialIndex = _notes.indexWhere((note) =>
        note.year == year &&
            note.sessionNumber == session &&
            note.questionNumber == qNum); // 타입도 비교하려면 note.questionType == category 추가

        if (reviewScreenInitialIndex != -1) {
          print('IncorrectNoteScreen: 최근 학습 오답 이동 - Y:$year, S:$session, QN:$qNum (리뷰 화면 인덱스: $reviewScreenInitialIndex)');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncorrectNoteReviewScreen(
                incorrectNotes: List.from(_notes), // 현재 오답 목록 전체 전달
                initialIndex: reviewScreenInitialIndex, // 오답 목록에서의 인덱스
              ),
            ),
          ).then((dataChanged) { // IncorrectNoteReviewScreen에서 돌아왔을 때
            print("IncorrectNoteScreen: IncorrectNoteReviewScreen에서 돌아옴. 데이터 갱신 시도.");
            _fetchAndPrepareAllNotesData(); // 오답 목록 및 최근 학습 정보 다시 로드
            // dataChanged가 true이면 (예: 삭제됨) 추가적인 UI 피드백 가능
          });
        } else {
          print('IncorrectNoteScreen: 최근 학습 오답 정보를 현재 오답 목록에서 찾을 수 없습니다. 정보: $_lastViewedIncorrectNoteDetail');
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('최근에 본 오답이 현재 목록에 없거나 정보가 정확하지 않습니다.')));
        }
      } else {
        print('IncorrectNoteScreen: 최근 학습 오답 정보의 일부 필드가 null입니다.');
      }
    } else {
      print('IncorrectNoteScreen: 최근 학습 오답 정보 자체가 null입니다.');
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
      await _fetchAndPrepareAllNotesData(); // ★★★ 목록 다시 로드 및 그룹화 (내부에 setState 포함) ★★★

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
      await _fetchAndPrepareAllNotesData();
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
      await _fetchAndPrepareAllNotesData(); // 목록 새로고침

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
    // --- 선택 모드에 따른 기존 actions 버튼 목록 ---
    List<Widget> currentActions = _isSelectionMode
        ? [ /* 선택 모드 버튼들 (전체선택, 선택삭제, 취소) */
      IconButton(icon: Icon(_selectedNotes.length == _notes.length && _notes.isNotEmpty ? Icons.deselect : Icons.select_all), tooltip: '전체 선택/해제', onPressed: _notes.isEmpty ? null : _toggleSelectAll,),
      IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: '선택 삭제', onPressed: _selectedNotes.isEmpty ? null : _deleteSelectedNotes,),
      IconButton(icon: const Icon(Icons.close), tooltip: '취소', onPressed: () { setState(() { _isSelectionMode = false; _selectedNotes.clear(); }); },),
    ]
        : [ /* 일반 모드 버튼들 (새로고침, 선택) */
      IconButton(icon: const Icon(Icons.refresh), tooltip: '새로고침', onPressed: _fetchAndPrepareAllNotesData,),
      TextButton(child: const Text('선택', style: TextStyle(color: Colors.white)), onPressed: () { setState(() { _isSelectionMode = true; _selectedNotes.clear(); }); },),
    ];
    return Scaffold(
      // --- ★★★ AppBar 수정: 'actions' -> 'otherActions' ★★★ ---
      appBar: buildCommonAppBar(
        context: context, // context 전달
        title: _isSelectionMode ? '${_selectedNotes.length}개 선택됨' : '오답 노트 (${_notes.length}개)',
        otherActions: currentActions, // ★★★ 파라미터 이름을 otherActions로 변경 ★★★
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? const Center(child: Text('오답 노트가 비어있습니다...', /* ... */))
          : Column( // ★★★ Column으로 감싸서 최근 학습 정보 표시 공간 마련 ★★★
        children: [
          // ★★★ 오답노트의 "최근 학습" 정보 표시 ★★★
          if (_lastViewedIncorrectNoteDetail != null &&
              _lastViewedIncorrectNoteDetail!['year'] != null &&
              _lastViewedIncorrectNoteDetail!['session'] != null &&
              _lastViewedIncorrectNoteDetail!['q_num'] != null &&
              _lastViewedIncorrectNoteDetail!['category'] != null ) // category도 확인
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Card(
                elevation: 2,
                color: Colors.orange.shade50, // 오답노트용 색상
                child: ListTile(
                  leading: Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 28),
                  title: Text(
                    '최근 본 오답: ${_lastViewedIncorrectNoteDetail!['year']}년 ${_lastViewedIncorrectNoteDetail!['session']}회차 ${_lastViewedIncorrectNoteDetail!['q_num']}번 (${_lastViewedIncorrectNoteDetail!['category']})',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: _navigateToRecentIncorrectNoteReview, // ★★★ 클릭 시 이동 함수 호출 ★★★
                ),
              ),
            ),
          if (_notes.isEmpty && _lastViewedIncorrectNoteDetail != null) // 최근 학습만 있고 오답 목록은 빌 경우
            const Expanded(child: Center(child: Text("오답 노트 목록은 비어있습니다."))),
          if (_notes.isNotEmpty) // 오답 목록이 있을 경우에만 ListView 표시
          Expanded(
            child: ListView.builder(
              itemCount: _displayItems.length,
              itemBuilder: (context, index) {
                final item = _displayItems[index];
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
            child: Text('${note.year}년 ${note.sessionNumber}회차 - ${note.questionNumber}번 문제 (${note.questionType})'), // 유형 함께 표시
          ),
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
                    }else {
                      // 오답노트 목록에서 항목 클릭 시 IncorrectNoteReviewScreen으로 이동
                      // ★★★ _notes에서 현재 note의 실제 인덱스를 찾아 전달 ★★★
                      int originalListIndex = _notes.indexWhere((n) =>
                      n.year == note.year &&
                          n.sessionNumber == note.sessionNumber &&
                          n.questionNumber == note.questionNumber &&
                          n.questionType == note.questionType);

                      if (originalListIndex != -1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IncorrectNoteReviewScreen(
                              incorrectNotes: List.from(_notes), // 오염 방지를 위해 복사본 전달
                              initialIndex: originalListIndex, // _notes 리스트에서의 실제 인덱스
                            ),
                          ),
                        ).then((value) { // ★ IncorrectNoteReviewScreen에서 돌아왔을 때
                          print("IncorrectNoteScreen: IncorrectNoteReviewScreen에서 돌아옴. 데이터 갱신.");
                          _fetchAndPrepareAllNotesData(); // 오답 목록 및 최근 학습 정보 다시 로드
                          if (value == true) { // 만약 삭제 등의 변경이 있었다면
                            // 추가적인 UI 처리 가능
                          }
                        });
                      } else {
                        print("IncorrectNoteScreen: 클릭된 오답노트 항목의 인덱스를 찾을 수 없음");
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('선택한 오답 정보를 찾을 수 없습니다.')));
                      } 
                    }
                  },
                ),
            );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}