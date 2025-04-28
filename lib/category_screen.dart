import 'package:flutter/material.dart';

// 유형별 문제 학습 화면 위젯 (새 카테고리 추가 및 정렬)
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  // 사용자가 제공한 카테고리 목록 + 새로 추가된 카테고리
  // (가나다 순 또는 논리적 순서로 정렬하면 더 보기 좋을 수 있습니다.)
  final List<String> categories = const [
    '감리 관련 문제', // 기존 + 신규 목록 (순서는 임의)
    '논리회로',
    '년도별 킬러문제',
    '단락사고',
    '단답', // 필요시 추가/제외
    '리액터 용량', // <--- 신규
    '부하 설비',
    '불평형률',
    '변류기',     // <--- 신규
    '수변전 설비',
    '시퀀스 제어',
    '역률 개선',
    '전동기',
    '전력손실',
    '전선 굵기',
    '정전용량',   // <--- 신규
    '조명 설비',
    '차단 용량',
    '축전지 용량',
    '기타',       // <--- 신규
  ];

  @override
  Widget build(BuildContext context) {
    // 카테고리 목록을 가나다 순으로 정렬해서 보여주기 (선택 사항)
    // final List<String> sortedCategories = List.from(categories)..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('유형별 문제 학습'),
      ),
      body: ListView.builder(
        // itemCount: sortedCategories.length, // 정렬된 목록 사용 시
        itemCount: categories.length, // 원본 목록 사용 시
        itemBuilder: (BuildContext context, int index) {
          // final String categoryName = sortedCategories[index]; // 정렬된 목록 사용 시
          final String categoryName = categories[index]; // 원본 목록 사용 시

          return ListTile(
            title: Center(
              child: Text(
                categoryName,
                style: const TextStyle(fontSize: 17),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              print('카테고리 선택됨: $categoryName');
              // TODO: 해당 카테고리의 문제 풀이 화면으로 이동
            },
          );
        },
      ),
    );
  }
}