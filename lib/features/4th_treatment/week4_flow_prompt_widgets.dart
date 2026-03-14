import 'package:gad_app_team/utils/text_line_material.dart';

class Week4SituationFocusBody extends StatelessWidget {
  final String title;
  final String helperText;
  final String situationText;
  final String footerText;
  final String imageAsset;
  final int? secondsLeft;
  final String waitingText;
  final bool isLoading;

  const Week4SituationFocusBody({
    super.key,
    required this.title,
    required this.helperText,
    required this.situationText,
    required this.footerText,
    this.imageAsset = 'assets/image/think_blue.png',
    this.secondsLeft,
    this.waitingText = '',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(imageAsset, height: 148, filterQuality: FilterQuality.high),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD8E7F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: Color(0xFF2E6EA5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF274968),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                helperText,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF6D8194),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE1ECF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '작성한 상황',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6E86A0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      situationText,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF355676),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                footerText,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF6B7D90),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (secondsLeft != null) ...[
          const SizedBox(height: 18),
          Text(
            waitingText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8A99AA),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class Week4FlowPromptBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final String situationText;
  final String? thoughtText;
  final String footerText;
  final String? badgeText;
  final String imageAsset;
  final int? secondsLeft;
  final String waitingText;
  final bool isLoading;

  const Week4FlowPromptBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.situationText,
    this.thoughtText,
    required this.footerText,
    this.badgeText,
    this.imageAsset = 'assets/image/think_blue.png',
    this.secondsLeft,
    this.waitingText = '',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(imageAsset, height: 152, filterQuality: FilterQuality.high),
        const SizedBox(height: 18),
        _Week4PromptCard(
          title: title,
          subtitle: subtitle,
          situationText: situationText,
          thoughtText: thoughtText,
          footerText: footerText,
          badgeText: badgeText,
        ),
        if (secondsLeft != null) ...[
          const SizedBox(height: 18),
          Text(
            waitingText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8A99AA),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Week4PromptCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String situationText;
  final String? thoughtText;
  final String footerText;
  final String? badgeText;

  const _Week4PromptCard({
    required this.title,
    required this.subtitle,
    required this.situationText,
    this.thoughtText,
    required this.footerText,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final hasThought = thoughtText != null && thoughtText!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Color(0xFF2E6EA5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF274968),
                  ),
                ),
              ),
              if (badgeText != null && badgeText!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD8E7F3)),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF57748F),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF6D8194),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _Week4PromptLine(label: '상황', value: situationText),
          if (hasThought) ...[
            const SizedBox(height: 10),
            _Week4PromptLine(label: '생각', value: thoughtText!, emphasize: true),
          ],
          const SizedBox(height: 12),
          Text(
            footerText,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF6B7D90),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Week4PromptLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _Week4PromptLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6E86A0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 15,
            height: 1.55,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color:
                emphasize ? const Color(0xFF263C69) : const Color(0xFF395B7F),
          ),
        ),
      ],
    );
  }
}
