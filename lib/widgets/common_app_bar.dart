// lib/widgets/common_app_bar.dart
import 'package:flutter/material.dart';
// MainMenuScreen이 있는 파일의 정확한 경로로 수정하세요.
import 'package:sikman/main.dart'; // 예시: 프로젝트 이름이 sikman이고 lib/main.dart에 MainMenuScreen이 있는 경우

AppBar buildCommonAppBar({
  required BuildContext context,
  required String title,
  List<Widget>? otherActions, // ★★★ 이 파라미터가 있는지 확인하세요 ★★★
}) {
  List<Widget> allActions = [];

  // otherActions가 null이 아니고 비어있지 않다면 먼저 추가
  if (otherActions != null && otherActions.isNotEmpty) {
    allActions.addAll(otherActions);
  }

  // 홈 버튼 추가
  allActions.add(
    IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: '메인 메뉴로 이동',
      onPressed: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainMenuScreen()),
              (Route<dynamic> route) => false,
        );
      },
    ),
  );

  return AppBar(
    title: Text(title),
    actions: allActions,
  );
}