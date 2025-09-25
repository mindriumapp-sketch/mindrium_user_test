// File: abc_group.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../widgets/custom_appbar.dart';
import 'abc_group_add_screen.dart';

class AbcGroupScreen extends StatefulWidget {
  final String? label;
  final String? abcId;
  final String? origin;

  const AbcGroupScreen({super.key, this.label, this.abcId, this.origin});

  @override
  _AbcGroupScreenState createState() => _AbcGroupScreenState();
}

class _AbcGroupScreenState extends State<AbcGroupScreen> {
  int _selectedIndex = -1;

  void _showEditDialog(
      BuildContext context,
      Map<String, dynamic> group,
      DocumentReference<Map<String, dynamic>> docRef,
      ) {
    final titleCtrl =
    TextEditingController(text: (group['group_title'] ?? '').toString());
    final contentsCtrl =
    TextEditingController(text: (group['group_contents'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '그룹 편집',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentsCtrl,
              decoration: const InputDecoration(labelText: '설명'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('삭제'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await docRef.delete();
                    if (mounted) Navigator.pop(context);
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('수정'),
                  onPressed: () async {
                    await docRef.update({
                      'group_title': titleCtrl.text,
                      'group_contents': contentsCtrl.text,
                    });
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AbcGroupAddScreen1()),
        ),
        child: const SizedBox(
          height: 40,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20, color: Colors.blue),
                SizedBox(width: 6),
                Text(
                  '그룹 추가',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }
    final uid = user.uid;

    // 모든 일기 구독 → 그룹별로 묶기(평균 SUD 계산에 사용)
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .snapshots(),
      builder: (ctxAll, allSnap) {
        if (allSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: CustomAppBar(title: '걱정 그룹 목록'),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allDocs = allSnap.data?.docs ?? [];
        final diaryDocs = allDocs
            .where((d) => ((d.data()['group_id'] ?? '').toString()).isNotEmpty)
            .toList();

        // 그룹별로 일기 리스트 구성
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        diariesByGroup = {};
        for (var d in diaryDocs) {
          final gid = (d.data()['group_id'] ?? '').toString();
          if (gid.isEmpty) continue;
          diariesByGroup.putIfAbsent(gid, () => []).add(d);
        }

        // 그룹 목록 구독
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('abc_group')
              .snapshots(),
          builder: (ctxGrp, grpSnap) {
            if (grpSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                appBar: CustomAppBar(title: '걱정 그룹 목록'),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // archived == true 만 제외 (null/없음 포함)
            final docs = (grpSnap.data?.docs ?? [])
                .where((d) => d.data()['archived'] != true)
                .toList();

            // ✅ 정렬: group_id == '1' 최상단, 나머지는 createdAt 내림차순
            docs.sort((a, b) {
              final aId = (a.data()['group_id'] ?? '').toString();
              final bId = (b.data()['group_id'] ?? '').toString();

              if (aId == '1' && bId != '1') return -1;
              if (bId == '1' && aId != '1') return 1;

              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];
              final aTs = (aTime is Timestamp) ? aTime : null;
              final bTs = (bTime is Timestamp) ? bTime : null;

              if (aTs != null && bTs != null) {
                return bTs.compareTo(aTs); // 최신 먼저
              } else if (aTs == null && bTs != null) {
                return 1; // createdAt 없는 것은 뒤로
              } else if (aTs != null && bTs == null) {
                return -1;
              }
              return 0;
            });

            return Scaffold(
              appBar: const CustomAppBar(title: '걱정 그룹 목록'),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: ListView.separated(
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    if (i == 0) return _buildAddCard();

                    final doc = docs[i - 1];
                    final data = doc.data();

                    final groupId = (data['group_id'] ?? '').toString();
                    final diaries = diariesByGroup[groupId] ?? [];
                    final diaryIds = diaries.map((d) => d.id).toList();
                    final count = diaries.length;

                    return _GroupCard(
                      uid: uid,
                      group: data,
                      index: i,
                      docRef: doc.reference,
                      isSelected: _selectedIndex == i,
                      onSelect: () => setState(() => _selectedIndex = i),
                      diaryCount: count,
                      diaryIds: diaryIds,
                      showEditDialog: _showEditDialog,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> group;
  final int index;
  final DocumentReference<Map<String, dynamic>> docRef;
  final bool isSelected;
  final VoidCallback onSelect;
  final int diaryCount;
  final List<String> diaryIds;
  final void Function(
      BuildContext,
      Map<String, dynamic>,
      DocumentReference<Map<String, dynamic>>,
      ) showEditDialog;

  const _GroupCard({
    required this.uid,
    required this.group,
    required this.index,
    required this.docRef,
    required this.isSelected,
    required this.onSelect,
    required this.diaryCount,
    required this.diaryIds,
    required this.showEditDialog,
  });

  /// ✅ 그룹 평균 after_sud 계산 (하위 컬렉션 sud_score의 after_sud 필드만)
  Future<double> _computeGroupAvgAfterSud() async {
    if (diaryIds.isEmpty) return 0.0;

    final firestore = FirebaseFirestore.instance;
    int sum = 0;
    int n = 0;

    for (final abcId in diaryIds) {
      final colRef = firestore
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .doc(abcId)
          .collection('sud_score');

      try {
        final qs = await colRef.get(); // 정렬 조건 없이 전체 조회
        if (qs.docs.isEmpty) continue;

        int? picked;
        for (final d in qs.docs) {
          final data = d.data();
          final v = data['after_sud'];
          if (v != null) {
            if (v is int) picked = v;
            else if (v is num) picked = v.toInt();
          }
          if (picked != null) break; // after_sud가 있는 첫 문서만 사용
        }

        if (picked != null) {
          sum += picked.clamp(0, 10);
          n++;
        }
      } catch (_) {
        // 한 일기에서 실패해도 전체는 계속
      }
    }

    if (n == 0) return 0.0;
    return sum / n;
  }

  @override
  Widget build(BuildContext context) {
    final groupId = (group['group_id'] ?? '').toString();
    final ts = group['createdAt'];
    final createdAt = (ts is Timestamp) ? ts.toDate() : null;
    final createdStr = DateFormat('yyyy.MM.dd').format(createdAt ?? DateTime.now());

    final title = (group['group_title'] ?? '').toString();
    final contents = (group['group_contents'] ?? '').toString();

    return Column(
      children: [
        Card(
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/image/character$groupId.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.folder,
                          size: 32,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.indigo : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contents,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (groupId != '1')
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      padding: const EdgeInsets.all(4),
                      onPressed: () =>
                          showEditDialog(context, group, docRef),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (isSelected) ...[
          FutureBuilder<double>(
            future: _computeGroupAvgAfterSud(),
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final avg = (snap.data ?? 0.0).clamp(0.0, 10.0);
              final ratio = avg / 10.0;
              final barColor =
                  Color.lerp(Colors.green, Colors.red, ratio) ?? Colors.red;
              final canDeleteAnxiety = (!loading && avg <= 2.0 && groupId != '1');

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '주관적 불안점수 (2점 이하 시 삭제 가능)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: loading ? null : ratio,
                              minHeight: 8,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loading ? '.../10' : '${avg.toStringAsFixed(1)}/10',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '생성일: $createdStr',
                          style: const TextStyle(fontSize: 14),
                        ),
                        InkWell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/diary_directory',
                            arguments: {'groupId': groupId},
                          ),
                          child: Row(
                            children: [
                              Text(
                                '일기 $diaryCount개',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (canDeleteAnxiety) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('정말 "$title" 그룹을 삭제하시겠습니까?'),
                              content: const Text('삭제된 그룹은 보관함에서 확인 가능합니다.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await docRef.update({
                                      'archived': true,
                                      'archived_at': FieldValue.serverTimestamp(),
                                    });
                                    if (context.mounted) {
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('"$title" 그룹이 삭제되었습니다.')),
                                      );
                                    }
                                  },
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('불안 삭제'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
