import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'question_screen.dart'; // QuestionScreen import
import 'services/recent_study_service.dart'; // RecentStudyService import


// 과년도 문제 학습 화면 위젯 (최종 버전)
class PastExamScreen extends StatefulWidget {
  const PastExamScreen({super.key});

  @override
  State<PastExamScreen> createState() => _PastExamScreenState();
}

class _PastExamScreenState extends State<PastExamScreen> {
  // 합격률 데이터 (제공해주신 데이터를 Map 형태로 변환)
  final Map<int, List<double>> passRatesData = const {
    2003: [65.54, 20.10, 8.50],
    2004: [10.36, 59.41, 72.58],
    2005: [37.68, 15.53, 53.20],
    2006: [37.77, 27.95, 42.98],
    2007: [19.92, 23.18, 18.53],
    2008: [15.23, 3.40, 40.33],
    2009: [10.33, 6.39, 2.82],
    2010: [8.51, 10.44, 10.29],
    2011: [56.91, 38.49, 41.46],
    2012: [24.40, 21.18, 1.65],
    2013: [24.62, 13.77, 7.15],
    2014: [19.42, 37.33, 6.45],
    2015: [27.36, 21.04, 1.41],
    2016: [15.02, 32.61, 10.60],
    2017: [22.78, 61.94, 24.15],
    2018: [3.21, 10.73, 25.97],
    2019: [58.94, 16.82, 36.77],
    2020: [8.18, 14.96, 9.52, 32.99], // 2020년 4회차 데이터 포함
    2021: [41.99, 29.10, 12.10],
    2022: [13.10, 47.41, 66.73],
    2023: [17.34, 23.47, 65.67],
    2024: [42.62, 21.20, 47.29],
  };
  final RecentStudyService _recentStudyService = RecentStudyService();
  Map<String, int?>? _recentPastExamData; // 로드된 최근 학습 정보 저장

  @override
  void initState() {
    super.initState();
    _loadRecentPastExamData(); // 화면 시작 시 최근 학습 정보 로드
  }

  Future<void> _loadRecentPastExamData() async {
    final data = await _recentStudyService.loadRecentPastExam();
    if (mounted) { // 위젯이 여전히 마운트된 상태인지 확인
      setState(() {
        _recentPastExamData = data;
      });
    }
  }
  Color _getPassRateColor(double rate) {
    if (rate < 20.0) return Colors.red;
    if (rate > 30.0) return Colors.blue;
    return Colors.black87; // 기본값 또는 Theme.of(context).textTheme.bodyLarge?.color
  }
  void _navigateToQuestionScreen(BuildContext context, int year, int session, int questionNumber) {
    // questionNumber는 1부터 시작하는 문제 번호라고 가정
    // initialIndex는 0부터 시작하는 인덱스
    int initialIndex = questionNumber > 0 ? questionNumber - 1 : 0;

    print('과년도 최근 학습 이동 시도: $year년 $session회 $questionNumber번 (initialIndex: $initialIndex)');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionScreen(
          year: year,
          sessionNumber: session,
          initialIndex: initialIndex, // 계산된 initialIndex 전달
        ),
      ),
    ).then((_) {
      // QuestionScreen에서 돌아왔을 때 최근 학습 정보를 다시 로드하여 UI 갱신
      print("PastExamScreen: QuestionScreen에서 돌아옴, 최근 학습 정보 다시 로드");
      _loadRecentPastExamData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<int> years = passRatesData.keys.toList()..sort((a, b) => b.compareTo(a));
    final NumberFormat percentFormat = NumberFormat("0.00'%'");

    return Scaffold(
      appBar: AppBar(
        title: const Text('과년도 문제 학습'),
      ),
      body: Column(
        children: [
          // ★★★ 최근 학습 정보 표시 및 클릭 로직 ★★★
          if (_recentPastExamData != null &&
              _recentPastExamData!['year'] != null &&
              _recentPastExamData!['session'] != null &&
              _recentPastExamData!['q_num'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Card(
                elevation: 2,
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: Icon(Icons.history_edu_outlined, color: Colors.blue.shade700, size: 28),
                  title: Text(
                    '최근 학습: ${_recentPastExamData!['year']}년 ${_recentPastExamData!['session']}회차 ${_recentPastExamData!['q_num']}번',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    // null 체크 후 안전하게 사용
                    final year = _recentPastExamData!['year'];
                    final session = _recentPastExamData!['session'];
                    final qNum = _recentPastExamData!['q_num'];

                    if (year != null && session != null && qNum != null) {
                      _navigateToQuestionScreen(context, year, session, qNum);
                    } else {
                      print("최근 학습 정보에 null 값이 포함되어 이동할 수 없습니다.");
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('최근 학습 정보가 올바르지 않습니다.'))
                      );
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: _recentPastExamData == null ? const EdgeInsets.only(top: 8.0) : EdgeInsets.zero,
              itemCount: years.length,
              itemBuilder: (BuildContext context, int yearIndex) {
                final int year = years[yearIndex];
                final List<double> ratesForYear = passRatesData[year] ?? []; // null 체크 추가

                // ★★★ ExpansionTile이 회차를 표시하지 못하는 문제 점검 ★★★
                // ratesForYear가 비어있거나, List.generate 로직 확인
                if (ratesForYear.isEmpty) {
                  // 해당 연도에 회차 정보가 없는 경우 (데이터 문제일 수 있음)
                  return ExpansionTile(
                    key: PageStorageKey<int>(year),
                    title: Center(child: Text('$year 년', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    children: const [ListTile(title: Center(child: Text("해당 연도의 회차 정보가 없습니다.")))],
                  );
                }

                return ExpansionTile(
                  key: PageStorageKey<int>(year),
                  title: Center(
                    child: Text(
                      '$year 년',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  children: List.generate(ratesForYear.length, (sessionIndex) {
                    final int sessionNumber = sessionIndex + 1;
                    final double passRate = ratesForYear[sessionIndex];
                    final Color textColor = _getPassRateColor(passRate);

                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 30.0, right: 16.0),
                      title: Center(
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                            children: <TextSpan>[
                              TextSpan(text: '$sessionNumber회차 '),
                              TextSpan(
                                text: '(${percentFormat.format(passRate)})',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // 각 회차 클릭 시, 해당 회차의 첫 문제로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestionScreen(
                              year: year,
                              sessionNumber: sessionNumber,
                              initialIndex: 0, // 항상 첫 문제부터 시작
                            ),
                          ),
                        ).then((_) {
                          print("PastExamScreen: QuestionScreen에서 돌아옴 (회차 선택), 최근 학습 정보 다시 로드");
                          _loadRecentPastExamData(); // 문제 풀고 돌아오면 최근 학습 정보 갱신
                        });
                      },
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}