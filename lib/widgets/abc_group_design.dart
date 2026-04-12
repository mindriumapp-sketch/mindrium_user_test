import 'dart:ui';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/utils/server_datetime.dart';
import 'custom_appbar.dart';
import '../features/2nd_treatment/abc_group_add_screen.dart';

/// 🪸 Mindrium 수족관 스타일 걱정 그룹 목록 (withOpacity 제거 버전)
class AbcGroupListView extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final Map<String, List<Map<String, dynamic>>> diariesByGroup;
  final String uid;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(
    BuildContext,
    Map<String, dynamic>,
  )
  onEdit;

  const AbcGroupListView({
    super.key,
    required this.groups,
    required this.diariesByGroup,
    required this.uid,
    required this.selectedIndex,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          /// 🌊 배경 (eduhome + 수심 그라데이션)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF004C73),
                  Color(0xFF78D5F5),
                  Color(0xFFAEE6FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Image.asset(
            'assets/image/eduhome.png',
            fit: BoxFit.cover,
            color: const Color.fromRGBO(255, 255, 255, 0.35),
            colorBlendMode: BlendMode.srcOver,
          ),

          /// ✨ 상단 빛기둥 효과
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(255, 255, 255, 0.25),
                      Color.fromRGBO(255, 255, 255, 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          /// 콘텐츠
          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: '걱정 그룹 목록'),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.25),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.4),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(173, 216, 230, 0.25),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: groups.length + 1,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
                            itemBuilder: (ctx, i) {
                              if (i == 0) return const AddGroupCard();
                              final data = groups[i - 1];
                              final groupId =
                                  (data['group_id'] ??
                                      data['groupId'] ??
                                      '').toString();
                              final diaries = diariesByGroup[groupId] ?? [];
                              return GroupCard(
                                group: data,
                                index: i,
                                isSelected: selectedIndex == i,
                                diaryCount: diaries.length,
                                onSelect: () => onSelect(i),
                                onEdit: (ctx, g) => onEdit(ctx, g),
                              );
                            },
                          ),
                        ),
                      ),
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
}

/// 🫧 그룹 추가 카드 (파스텔 방울형 버튼)
class AddGroupCard extends StatelessWidget {
  const AddGroupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AbcGroupAddScreen()),
          ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8FDFFF), Color(0xFFC4F5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(173, 216, 230, 0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: Color(0xFF0E4569),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                '걱정 그룹 추가',
                style: TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0E4569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🐚 그룹 카드 (유리 느낌 + 선택 시 하이라이트)
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final int index;
  final bool isSelected;
  final int diaryCount;
  final VoidCallback onSelect;
  final void Function(
    BuildContext,
    Map<String, dynamic>,
  )
  onEdit;

  const GroupCard({
    super.key,
    required this.group,
    required this.index,
    required this.isSelected,
    required this.diaryCount,
    required this.onSelect,
    required this.onEdit,
  });

  DateTime _parseDate(dynamic raw) {
    final parsedServerTime = parseServerDateTime(raw);
    if (parsedServerTime != null) return parsedServerTime;
    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = (group['group_id'] ?? group['groupId'] ?? '').toString();
    final title = (group['group_title'] ?? '').toString();
    final contents = (group['group_contents'] ?? '').toString();
    final createdAt = _parseDate(group['created_at'] ?? group['createdAt']);
    final createdStr = DateFormat('yyyy.MM.dd').format(createdAt);
    final bool isDefaultGroup =
        groupId == '1' || groupId == 'group_example';

    final Color highlightColor = const Color(0xFF007BA7);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [Color(0xFFD0F2FF), Color(0xFFB9E8FF)]
                    : [
                      Color.fromRGBO(255, 255, 255, 0.6),
                      Color.fromRGBO(255, 255, 255, 0.4),
                    ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected
                    ? highlightColor
                    : const Color.fromRGBO(255, 255, 255, 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? const Color.fromRGBO(0, 123, 167, 0.4)
                      : const Color.fromRGBO(0, 0, 0, 0.1),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color.fromRGBO(255, 255, 255, 0.6),
              child: ClipOval(
                child: Image.asset(
                  'assets/image/character$groupId.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => const Icon(
                        Icons.folder,
                        size: 30,
                        color: Colors.grey,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : '제목 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color:
                          isSelected ? highlightColor : const Color(0xFF103050),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contents.isNotEmpty ? contents : '내용 없음',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 14,
                      color: Color(0xFF102030),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '작성일: $createdStr',
                    style: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 12,
                      color: Color(0xAA102030),
                    ),
                  ),
                ],
              ),
            ),
            if (!isDefaultGroup)
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 22,
                  color: isSelected ? highlightColor : const Color(0xFF004C73),
                ),
                onPressed: () => onEdit(context, group),
              ),
          ],
        ),
      ),
    );
  }
}

/// ✨ 그룹 수정 바텀시트 (하늘빛 팝업)
class EditGroupBottomSheet extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentsController;
  final VoidCallback onSave;

  const EditGroupBottomSheet({
    super.key,
    required this.titleController,
    required this.contentsController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9F8FF), Color(0xFFBFEAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(173, 216, 230, 0.3),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '그룹 편집',
            style: TextStyle(
              fontFamily: 'Noto Sans KR',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF003A64),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: '제목',
              labelStyle: const TextStyle(color: Color(0xFF004C73)),
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '설명',
              labelStyle: const TextStyle(color: Color(0xFF004C73)),
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: const Text('수정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BA7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🫧 Mindrium 하늘빛 로딩 화면
class AbcGroupLoading extends StatelessWidget {
  const AbcGroupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          /// 🌊 수심 그라데이션 + eduhome 배경
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF004C73),
                  Color(0xFF78D5F5),
                  Color(0xFFAEE6FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Image.asset(
            'assets/image/eduhome.png',
            fit: BoxFit.cover,
            color: const Color.fromRGBO(255, 255, 255, 0.35),
            colorBlendMode: BlendMode.srcOver,
          ),

          /// ✨ 상단 빛기둥 효과
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(255, 255, 255, 0.25),
                      Color.fromRGBO(255, 255, 255, 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          /// 로딩 내용
          const SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: '걱정 그룹 목록'),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: Color(0xFF007BA7),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '데이터를 불러오는 중이에요...',
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF003A64),
                          ),
                        ),
                      ],
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
}
