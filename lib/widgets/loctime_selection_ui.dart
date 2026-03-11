import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import '../../data/loctime_provider.dart';

class LocTimeSelectionUI extends StatelessWidget {
  final String? label;
  final LocTimeSetting? draftTime;
  final LocTimeSetting? draftLocation;
  final bool noLocTime;
  final RepeatOption repeatOption;
  final Set<int> selectedWeekdays;
  final Duration reminderDuration;
  final VoidCallback onTapTime;
  final VoidCallback onTapLocation;
  final VoidCallback onTapRepeat;
  final VoidCallback onTapReminder;
  final Function(bool) onToggleNone;
  final bool showInlineTimePicker;
  final ValueChanged<TimeOfDay> onInlineTimeChanged;
  final VoidCallback onSave;
  final bool showReminderOption;
  final bool showDisableLocTimeOption;
  final bool showRepeatOption;
  final VoidCallback? onHelp;

  const LocTimeSelectionUI({
    super.key,
    required this.label,
    required this.draftTime,
    required this.draftLocation,
    required this.noLocTime,
    required this.repeatOption,
    required this.selectedWeekdays,
    required this.reminderDuration,
    required this.onTapTime,
    required this.onTapLocation,
    required this.onTapRepeat,
    required this.onTapReminder,
    required this.onToggleNone,
    this.showInlineTimePicker = false,
    required this.onInlineTimeChanged,
    required this.onSave,
    this.showRepeatOption = true,
    this.showReminderOption = true,
    this.showDisableLocTimeOption = true,
    this.onHelp,
  });

  static const Color oceanBlue = Color(0xFF5DADEC);
  static const Color softMint = Color(0xFFEAF3FF);
  static const Color deepNavy = Color(0xFF141F35);
  static const Color subText = Color(0xFF555C66);
  static const Color borderBlue = Color(0xFFCFE0FF);
  static const Color shadowColor = Color(0x19000000);
  static const Color disableGrey = Color(0xFFD5D9E0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (label != null && label!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.label_important_outline,
                            color: oceanBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '불안의 원인/상황',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w500,
                                    color: deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label!,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: subText,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),

                  // 위치 선택 카드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: noLocTime ? disableGrey : borderBlue,
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _rowItem(
                      title: '위치',
                      subtitle: _getLocationText(),
                      icon: Icons.place_outlined,
                      onTap: noLocTime ? null : onTapLocation,
                      isFirst: true,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: JellyfishBanner(
                      message:
                          '위치를 먼저 선택하고,\n하단에서 시간을 설정한 뒤 저장해주세요.',
                      right: -34,
                      bottom: -24,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 하단 스낵바 스타일 영역: 시간 설정 + 저장
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderBlue, width: 1),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: oceanBlue, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      '시간 설정',
                      style: TextStyle(
                        color: deepNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getTimeText(context),
                      style: const TextStyle(
                        color: subText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (showInlineTimePicker)
                  _buildInlineTimeSelector()
                else
                  InkWell(
                    onTap: noLocTime ? null : onTapTime,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: softMint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getTimeText(context),
                        style: const TextStyle(color: subText),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                PrimaryActionButton(
                  text: '저장하기',
                  onPressed: () async {
                    try {
                      onSave();
                    } catch (e) {
                      debugPrint('❌ 저장 실패: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationText() {
    if (draftLocation?.location == null) return '위치를 선택하지 않았습니다';
    return draftLocation!.location ?? '위치 정보 없음';
  }

  String _getTimeText(BuildContext context) {
    final t = draftTime?.time ?? draftLocation?.time;
    return t != null ? t.format(context) : '시간을 선택하지 않았습니다';
  }

  Widget _buildInlineTimeSelector() {
    final current =
        draftTime?.time ??
            draftLocation?.time ??
            const TimeOfDay(hour: 9, minute: 0);

    return SizedBox(
      height: 176,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        use24hFormat: false,
        initialDateTime: DateTime(
          2000,
          1,
          1,
          current.hour,
          current.minute,
        ),
        onDateTimeChanged: (dt) {
          onInlineTimeChanged(TimeOfDay.fromDateTime(dt));
        },
      ),
    );
  }

  Widget _rowItem({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    bool isFirst = false,
  }) {
    final disabled = onTap == null;
    final isPlaceholder =
        subtitle == '시간을 선택하지 않았습니다' ||
            subtitle == '위치를 선택하지 않았습니다';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 14, 12, 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: softMint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: oceanBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: deepNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: (disabled || isPlaceholder)
                          ? Colors.grey
                          : subText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9EA9B8),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
