import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/2nd_treatment/notification_selection_screen.dart';

/// Firestore의 `abc_models` 문서를 화면용 모델로 매핑
class AbcModel {
  final String id;
  final String activatingEvent;
  final String belief;
  final String consequence;
  final String groupId;
  final String? diaryDetail;
  final int? sudScore; // (이제 사용 안하지만 호환 위해 유지)
  final Timestamp createdAt;

  AbcModel({
    required this.id,
    required this.activatingEvent,
    required this.belief,
    required this.consequence,
    required this.groupId,
    this.diaryDetail,
    this.sudScore,
    required this.createdAt,
  });

  factory AbcModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AbcModel(
      id: doc.id,
      activatingEvent: data['activatingEvent'] as String? ?? '-',
      belief: data['belief'] as String? ?? '-',
      consequence: data['consequence'] as String? ?? '-',
      groupId: data['group_id'] as String? ?? '',
      diaryDetail: data['diaryDetail'] as String?,
      sudScore: data['sud_score'] as int?, // (미사용)
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}

/// ✅ SUD 점수 표시 위젯: sud_score 컬렉션에서 after_sud만 찾아 표시
class _SudScoreBar extends StatelessWidget {
  final String uid;
  final String modelId;

  const _SudScoreBar({required this.uid, required this.modelId});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('abc_models')
        .doc(modelId)
        .collection('sud_score');

    // 👉 정렬/조건 없이 그대로 구독
    return StreamBuilder<QuerySnapshot>(
      stream: col.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 8);
        }

        int after = 0;

        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          // after_sud가 있는 첫 문서에서만 값 추출
          for (final d in snap.data!.docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            if (data.containsKey('after_sud') && data['after_sud'] != null) {
              final v = data['after_sud'];
              if (v is int) after = v;
              else if (v is num) after = v.toInt();
              break;
            }
          }
        }

        // 0~10 범위 제한
        after = after.clamp(0, 10);
        final ratio = after / 10.0;
        final color = Color.lerp(Colors.green, Colors.red, ratio) ?? Colors.red;

        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: ratio,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$after/10',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }
}



/// 일기 목록 + 클릭 시 알림/일기 세부 보기
class AbcStreamList extends StatelessWidget {
  final String uid;
  final String? selectedGroupId;

  const AbcStreamList({
    super.key,
    required this.uid,
    this.selectedGroupId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        final items = docs
            .map(AbcModel.fromDoc)
            .where((m) => selectedGroupId == null || m.groupId == selectedGroupId)
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final model = items[i];
            final assetPath = 'assets/image/character${model.groupId}.png';

            return Card(
              color: Colors.grey.shade200,
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage(assetPath),
                  // (원 코드와 동일한 동작 가정)
                ),
                tilePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                childrenPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이벤트 + 생성일자(시:분까지)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.activatingEvent,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy.MM.dd HH:mm')
                              .format(model.createdAt.toDate().toLocal()),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // belief
                    Text(
                      model.belief,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 안내 텍스트
                    const Text(
                      '주관적 불안점수',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    // ✅ SUD 점수 바(최신 after_score)
                    _SudScoreBar(uid: uid, modelId: model.id),
                  ],
                ),
                children: [
                  // 알림 펼쳐보기
                  ExpansionTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text(
                      '알림 펼쳐보기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('abc_models')
                            .doc(model.id)
                            .collection('notification_settings')
                            .snapshots(),
                        builder: (context, notifSnap) {
                          if (notifSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            );
                          }
                          final notifs = notifSnap.data?.docs ?? [];
                          if (notifs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('설정된 알림이 없습니다.'),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: notifs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (c, idx) {
                              final data = notifs[idx].data() as Map<String, dynamic>;
                              final location = data['location'] as String? ?? '-';
                              final notifyEnter = (data['notifyEnter'] as bool?) ?? false;
                              final notifyExit  = (data['notifyExit'] as bool?) ?? false;
                              final condition = notifyEnter && notifyExit
                                  ? '입장/퇴장'
                                  : notifyEnter
                                  ? '입장 시'
                                  : notifyExit
                                  ? '퇴장 시'
                                  : '매일 반복';
                              final time = data['time'] as String? ?? '-';

                              int? reminderMinutes;
                              final rm = data['reminderMinutes'];
                              if (rm is int) reminderMinutes = rm;
                              if (rm is num) reminderMinutes = rm.toInt();

                              final reminderText = (reminderMinutes == null)
                                  ? '반복시간 없음'
                                  : '반복 ($reminderMinutes분)';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('위치: $location'),
                                  Text('조건: $condition'),
                                  Text('시간: $time'),
                                  Text(reminderText),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('수정'),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => NotificationSelectionScreen(
                                              origin: 'edit',
                                              abcId: model.id,
                                              label: model.activatingEvent,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  // 일기 펼쳐보기
                  if (model.diaryDetail != null)
                    ExpansionTile(
                      leading: const Icon(Icons.book),
                      title: const Text(
                        '일기 펼쳐보기',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(model.diaryDetail!),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 일기 목록 + 풀 너비 그룹 필터 드롭다운 + 전체/필터링 카운트
class NotificationDirectoryScreen extends StatefulWidget {
  const NotificationDirectoryScreen({super.key});

  @override
  State<NotificationDirectoryScreen> createState() =>
      _NotificationDirectoryScreenState();
}

class _NotificationDirectoryScreenState
    extends State<NotificationDirectoryScreen> {
  String _selectedGroupId = ''; // '' == 전체

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: const CustomAppBar(
        title: '걱정일기 (ABC 모델)',
        showHome: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('abc_group')
            .snapshots(),
        builder: (context, grpSnap) {
          if (grpSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1) group_id 없는 문서 제외, 2) 정렬
          final groups = grpSnap.data!.docs
              .map((d) {
            final data = d.data()! as Map<String, dynamic>;
            final gid = data['group_id'] as String?;
            final title = data['group_title'] as String?;
            if (gid == null || gid.isEmpty) return null;
            return {'id': gid, 'title': title ?? gid};
          })
              .where((e) => e != null)
              .cast<Map<String, String>>()
              .toList()
            ..sort((a, b) => a['title']!.compareTo(b['title']!));

          // '전체 그룹' 메뉴 항목 생성
          final dropdownItems = <DropdownMenuItem<String>>[];
          dropdownItems.add(
            DropdownMenuItem(
              value: '',
              child: Row(
                children: const [
                  CircleAvatar(radius: 12, child: Icon(Icons.group)),
                  SizedBox(width: 8),
                  Text('전체 그룹', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
          dropdownItems.addAll(
            groups.map((g) {
              return DropdownMenuItem(
                value: g['id']!,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage:
                      AssetImage('assets/image/character${g['id']}.png'),
                      radius: 12,
                    ),
                    const SizedBox(width: 8),
                    Text(g['title']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
          );

          return Column(
            children: [
              // ─── 그룹 필터 드롭다운 ─────────────────────────
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedGroupId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                    ),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_drop_down),
                    ),
                    dropdownColor: Colors.white,
                    items: dropdownItems,
                    onChanged: (val) => setState(() => _selectedGroupId = val ?? ''),
                  ),
                ),
              ),

              // ─── 전체/필터링 카운트 ─────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('abc_models')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }
                  final all = snap.data!.docs;
                  final filtered = all.where((d) =>
                  _selectedGroupId.isEmpty ||
                      (d['group_id'] as String) == _selectedGroupId).length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '일기 $filtered / ${all.length} 개',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              ),

              // ─── 일기 목록 ────────────────────────────────
              Expanded(
                child: AbcStreamList(
                  uid: uid,
                  selectedGroupId: _selectedGroupId.isEmpty ? null : _selectedGroupId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
