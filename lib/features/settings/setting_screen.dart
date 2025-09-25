import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/internal_action_button.dart';


/// 설정 화면
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTaskReminderOn = true;
  bool _isHomeworkReminderOn = true;
  bool _isReportReminderOn = true;

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  void _sendInquiry() {
    final subject = _subjectController.text;
    final message = _messageController.text;
    if (subject.isNotEmpty && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의가 접수되었습니다.')),
      );
      _subjectController.clear();
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '설정'),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: ListView(
          children: [
            CardContainer(
              title: '알림 설정',
              child: Column(
                children: [
                  _buildSwitchTile('치료 일정 알림', _isTaskReminderOn, (value) => setState(() => _isTaskReminderOn = value)),
                  _buildSwitchTile('숙제 제출 알림', _isHomeworkReminderOn, (value) => setState(() => _isHomeworkReminderOn = value)),
                  _buildSwitchTile('리포트 생성 알림', _isReportReminderOn, (value) => setState(() => _isReportReminderOn = value)),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space),
            CardContainer(
              title: '고객센터 문의',
              child: Column(
                children: [
                  InputTextField(label: '문의 제목', controller: _subjectController),
                  const SizedBox(height: AppSizes.space),
                  InputTextField(label: '문의 내용',controller:  _messageController, maxLines: 4),
                  const SizedBox(height: AppSizes.space),
                  const SizedBox(height: AppSizes.space),
                  Center(
                    child: InternalActionButton(onPressed: _sendInquiry, text: '전송하기')
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.fromLTRB(16,4,4,4),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
