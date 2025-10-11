import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/activitiy_card.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

/// 콘텐츠 메뉴 화면
class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '메뉴'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(0,16,0,0),
        child: ListView(
          children: [
            ActivityCard(
              icon: Icons.menu_book,
              title: '불안에 대한 교육',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/education'),
            ),
            const SizedBox(height: AppSizes.space),
            ActivityCard(
              icon: Icons.self_improvement,
              title: '이완',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/relaxation_noti'),
            ),
            const SizedBox(height: AppSizes.space),


            ActivityCard(
              icon: Icons.edit_note,
              title: '걱정 일기 목록',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/diary_directory'),
            ),
            const SizedBox(height: AppSizes.space),

            ActivityCard(
              icon: Icons.edit_note,
              title: '걱정 그룹',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/diary_group'),
            ),
            const SizedBox(height: AppSizes.space),

            ActivityCard(
              icon: Icons.edit_note,
              title: '보관함',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/archive'),
            ),

            const SizedBox(height: AppSizes.space),

            ActivityCard(
              icon: Icons.edit_note,
              title: '보관함(바다)',
              enabled: true,
              onTap: () => Navigator.pushNamed(context,'/archive_sea'),
            ),

            // const SizedBox(height: AppSizes.space),
            // ActivityCard(
            //   icon: Icons.edit_note,
            //   title: '캐릭터 삭제',
            //   enabled: true,
            //   onTap: () => Navigator.pushNamed(context,'/battle'),
            // ),
            // const SizedBox(height: AppSizes.space)

          ],
        ),
      ),
    );
  }
}
