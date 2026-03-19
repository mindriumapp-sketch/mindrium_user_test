import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 하단 네비게이션 바 커스텀 위젯 (위쪽 둥근 모서리 적용)
class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CustomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItemData(icon: Icons.home, label: '홈'),
      _NavItemData(icon: Icons.school, label: '교육'),
      _NavItemData(icon: Icons.water, label: '마인드리움'),
      _NavItemData(icon: Icons.insert_chart_outlined_rounded, label: '리포트'),
      _NavItemData(icon: Icons.person_outline, label: '마이페이지'),
    ];

    return SizedBox(
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 기본 바 영역
          Positioned.fill(
            top: 22,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
            ),
          ),

          // 탭 아이템들
          Positioned.fill(
            top: 22,
            bottom: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                final isCenter = index == 2;
                return Expanded(
                  child: _NavBarItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    isCenter: isCenter,
                    onTap: () => onDestinationSelected(index),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCenter;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCenter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isCenter) {
      final centerLabelColor = isSelected ? AppColors.indigo : Colors.black87;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.asset(
                        'assets/image/popup1.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: centerLabelColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final color = isSelected ? AppColors.indigo : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
