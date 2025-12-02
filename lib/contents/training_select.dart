// // 🔹 Mindrium: 훈련 선택 화면 (TrainingSelect)
// // 사용자가 ‘일기 작성’ 또는 ‘이완 활동’ 중 어떤 훈련을 진행할지 선택하는 초기 분기 화면
// // InnerBtnCardScreen 위젯을 이용해 ApplyDesign 스타일과 통일된 카드형 버튼 UI 구성
// // 연결 흐름:
// //   홈(/home) 또는 이전 단계 → TrainingSelect
// //     ├─ “일기 작성” → /abc (ABC 걱정 일기 작성 화면, origin='training')
// //     └─ “이완 활동” → /relaxation_education (이완 교육/훈련 시작 화면)
// // import 목록:
// //   dart:math                        → 이미지 크기 제한용 math.min()
// //   flutter/material.dart            → 기본 Flutter 위젯
// //   gad_app_team/widgets/custom_appbar.dart → 상단 공용 CustomAppBar (앱바용)
// //   gad_app_team/widgets/inner_btn_card.dart → 카드형 2버튼 UI 위젯 (InnerBtnCardScreen)

// import 'dart:math' as math;
// import 'package:gad_app_team/utils/text_line_material.dart';
// import 'package:gad_app_team/widgets/inner_btn_card.dart'; // ← 네가 만든 위젯 import

// class TrainingSelect extends StatelessWidget {
//   const TrainingSelect({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return InnerBtnCardScreen(
//       appBarTitle: '훈련 선택',
//       title: '어떤 활동을 진행하시겠어요?',
//       // 카드 안에 들어갈 본문
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const SizedBox(height: 4),
//           Image.asset(
//             'assets/image/pink3.png',
//             height: math.min(180, MediaQuery.of(context).size.width * 0.38),
//             fit: BoxFit.contain,
//           ),
//           // const SizedBox(height: 12),
//           // const Text(
//           //   '걱정 일기를 작성하거나\n몸과 마음을 풀어주는 이완 활동을 선택할 수 있어요.',
//           //   textAlign: TextAlign.center,
//           // ),
//         ],
//       ),
//       primaryText: '일기 작성',
//       onPrimary: () {
//         Navigator.pushNamed(context, '/abc', arguments: {'origin': 'training'});
//       },
//       secondaryText: '이완 활동',
//       onSecondary: () {
//         Navigator.pushNamed(
//           context,
//           '/relaxation_education',
//           arguments: {'abcId': null},
//         );
//       },
//       // 스타일은 기존 ApplyDesign 계열이랑 맞추기
//       backgroundAsset: 'assets/image/eduhome.png',
//       // button_height: 56,
//     );
//   }
// }
