// lib/ui/chat_bubble.dart (final patched)
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isAi,
    this.label,
    this.profileWidget,   // 상담사 프로필 위젯 (감정별 아바타 전달)
    this.isNotice = false, // 검토/요약 등 공지성 메시지
  });

  final String text;
  final bool isAi;
  final String? label;
  final Widget? profileWidget;
  final bool isNotice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 🎨 배경색 구분 강화
    final Color bg = isNotice
        ? scheme.surfaceVariant
        : (isAi ? scheme.surfaceVariant : scheme.primaryContainer.withOpacity(0.9));

    // 헤더 제거 로직 가드: 해당 문자열로 "시작하는 경우"에만 제거
    final String displayText = text.startsWith('--- 세션 요약 ---')
        ? text.replaceFirst('--- 세션 요약 ---\n', '')
        : (text.startsWith('① 입력 검토 결과:')
            ? text.replaceFirst('① 입력 검토 결과:', '').trim()
            : text);

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                protectKoreanWords(label!),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            protectKoreanWords(displayText),
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    // 🤖 AI(상담사) 메시지: 왼쪽 정렬 + 프로필
    if (isAi) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profileWidget != null && !isNotice)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: profileWidget!,
              ),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    // 👤 사용자 메시지: 오른쪽 정렬
    return Align(
      alignment: Alignment.centerRight,
      child: bubble,
    );
  }
}
