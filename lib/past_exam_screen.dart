import 'package:flutter/material.dart';
// intl 패키지와 QuestionScreen 파일을 import 합니다.
import 'package:intl/intl.dart';
import 'question_screen.dart'; // 이 파일이 lib 폴더 안에 있어야 합니다!

// 과년도 문제 학습 화면 위젯 (최종 버전)
class PastExamScreen extends StatelessWidget {
  const PastExamScreen({super.key});

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

  // 합격률에 따라 텍스트 색상을 반환하는 함수
  Color _getPassRateColor(double rate) {
    if (rate < 20.0) {
      return Colors.red; // 20% 미만: 빨간색
    } else if (rate > 30.0) {
      return Colors.blue; // 30% 초과: 파란색
    } else {
      // 20% ~ 30% 사이: 기본 색상
      return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 표시할 연도 목록 생성 (데이터가 있는 연도만, 내림차순 정렬)
    final List<int> years = passRatesData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // 합격률 숫자 포맷터 (소수점 두 자리 + %)
    final NumberFormat percentFormat = NumberFormat("0.00'%'");

    return Scaffold(
      appBar: AppBar(
        title: const Text('과년도 문제 학습 (연도/회차 선택)'),
      ),
      body: ListView.builder(
        itemCount: years.length, // 데이터에 있는 연도 수만큼 아이템 생성
        itemBuilder: (BuildContext context, int index) {
          final int year = years[index];
          // 해당 연도의 합격률 리스트 (데이터 없으면 빈 리스트)
          final List<double> ratesForYear = passRatesData[year] ?? [];

          // 연도별 펼치기 타일
          return ExpansionTile(
            // 제목: 연도 (가운데 정렬)
            title: Center(
              child: Text(
                '$year 년',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // 자식: 회차 목록 (동적으로 생성)
            children: List.generate(ratesForYear.length, (sessionIndex) {
              final int sessionNumber = sessionIndex + 1; // 회차 (1, 2, 3 또는 1, 2, 3, 4)
              final double passRate = ratesForYear[sessionIndex]; // 해당 회차 합격률
              final Color textColor = _getPassRateColor(passRate); // 합격률 기반 색상

              // 각 회차를 나타내는 리스트 타일
              return ListTile(
                contentPadding: const EdgeInsets.only(left: 30.0, right: 16.0), // 들여쓰기
                // 제목: 회차 번호와 합격률 (가운데 정렬, 조건부 색상)
                title: Center(
                  child: RichText(
                    text: TextSpan(
                      // 앱의 기본 텍스트 스타일 상속 및 크기 지정
                      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                      children: <TextSpan>[
                        TextSpan(text: '$sessionNumber회차 '), // 회차 번호
                        TextSpan(
                          text: '(${percentFormat.format(passRate)})', // 합격률 (포맷팅)
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w500), // 색상 및 두께
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center, // 텍스트 가운데 정렬
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16,), // 오른쪽 화살표 아이콘
                // 탭했을 때의 동작: QuestionScreen으로 이동 (연도, 회차 정보 전달)
                onTap: () {
                  print('$year 년 $sessionNumber회차 선택됨 -> 문제 풀이 화면으로 이동');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestionScreen( // QuestionScreen 호출
                        year: year,
                        sessionNumber: sessionNumber,
                      ),
                    ),
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }
}