// import 'package:flutter/material.dart';
// import 'package:gad_app_team/common/constants.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class MindriumScreen extends StatelessWidget {
//   const MindriumScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     return Scaffold(
//       backgroundColor: AppColors.grey100,
//       body: ListView(
//         children: [
//           // 제목 영역
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Mindrium Plus',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   '매일 걱정 일기를 작성하고 이완 훈련을 진행하고,\n실제 불안이 발생할 때 적용해요.',
//                   style: TextStyle(
//                     fontSize: AppSizes.fontSize,
//                     color: Colors.grey,
//                   ),
//                 ),
//                 const SizedBox(height: AppSizes.space),
                
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     InkWell(
//                       onTap: () {
//                         debugPrint('[MINDRIUM] push /abc  origin=training');
//                         Navigator.pushNamed(
//                           context, '/training'
//                         );
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(AppSizes.padding),
//                         decoration: BoxDecoration(
//                           color: AppColors.white,
//                           borderRadius: BorderRadius.circular(AppSizes.borderRadius),
//                           boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 8)],
//                         ),
//                         child: SizedBox(
//                           width: double.infinity,
//                           height: screenHeight * 0.32, // 45% of screen width
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(
//                                 '훈련하기',
//                                 style: TextStyle(
//                                     fontSize: 24, fontWeight: FontWeight.bold),
//                               ),
//                               SizedBox(height: 8),
//                               Text(
//                                 '매주 교육에서 배운 내용을 바탕으로 훈련해봐요.'
//                               )
//                             ]
//                           ),
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: AppSizes.space),

//                     FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//                       future: FirebaseFirestore.instance
//                           .collection('users')
//                           .doc(FirebaseAuth.instance.currentUser?.uid)
//                           .get(),
//                       builder: (context, snap) {
//                         final enabled =
//                             (snap.data?.data()?['completed_education'] ?? 0) >= 3;

//                         final bgColor =
//                             enabled ? AppColors.white : Colors.grey.shade300;
//                         final txtColor =
//                             enabled ? Colors.black : Colors.grey.shade500;

//                         return InkWell(
//                           onTap: enabled
//                               ? () {
//                                   debugPrint(
//                                       '[MINDRIUM] push /diary_yes_or_no  origin=apply');
//                                   Navigator.pushNamed(
//                                     context,
//                                     '/diary_yes_or_no',
//                                     arguments: {
//                                       'origin': 'apply',
//                                       'diary': 'new'
//                                     },
//                                   );
//                                 }
//                               : null,
//                           child: Container(
//                             padding: const EdgeInsets.all(AppSizes.padding),
//                             decoration: BoxDecoration(
//                               color: bgColor, // 활성/비활성 배경색
//                               borderRadius:
//                                   BorderRadius.circular(AppSizes.borderRadius),
//                               boxShadow: const [
//                                 BoxShadow(
//                                     color: AppColors.black12, blurRadius: 8)
//                               ],
//                             ),
//                             child: SizedBox(
//                               width: double.infinity,
//                               height: screenHeight * 0.32,
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     '적용하기',
//                                     style: TextStyle(
//                                         fontSize: 24,
//                                         fontWeight: FontWeight.bold,
//                                         color: txtColor),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     '훈련한 내용을 바탕으로 실제 불안이 발생할 때 적용해봐요.',
//                                     style: TextStyle(color: txtColor),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
