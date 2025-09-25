// File: archive_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('보관함 목록')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }
    final uid = user.uid;

    // 1) 먼저 모든 일기를 스트림으로 가져와 group_id 별로 분류
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .snapshots(),
      builder: (ctxAll, allSnap) {
        if (allSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('보관함 목록')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (allSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('보관함 목록')),
            body: const Center(child: Text('일기 로드 중 오류가 발생했습니다.')),
          );
        }

        // group_id 있는 일기만
        final diaryDocs = allSnap.data!.docs
            .where((d) => (d.data()['group_id'] as String?)?.isNotEmpty == true)
            .toList();

        // group_id 별로 리스트
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> diariesByGroup = {};
        for (var d in diaryDocs) {
          final gid = d.data()['group_id'] as String;
          diariesByGroup.putIfAbsent(gid, () => []).add(d);
        }

        // 2) 보관함(archived==true) 그룹 문서 스트림
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('abc_group')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (ctxGrp, grpSnap) {
            if (grpSnap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: const Text('보관함 목록')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (grpSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('보관함 목록')),
                body: const Center(child: Text('보관함 로드 중 오류가 발생했습니다.')),
              );
            }

            // archived == true 인 문서만
            final archivedDocs = grpSnap.data!.docs
                .where((d) => d.data()['archived'] == true)
                .toList();

            if (archivedDocs.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('보관함 목록')),
                body: const Center(child: Text('보관된 그룹이 없습니다.')),
              );
            }

            // 보관일시 내림차순
            archivedDocs.sort((a, b) {
              final aTs = (a.data()['archived_at'] as Timestamp?)?.toDate() ?? DateTime(0);
              final bTs = (b.data()['archived_at'] as Timestamp?)?.toDate() ?? DateTime(0);
              return bTs.compareTo(aTs);
            });

            return Scaffold(
              appBar: AppBar(title: const Text('보관함 목록')),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: ListView.separated(
                  itemCount: archivedDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = archivedDocs[index];
                    final data = doc.data();
                    final groupId = data['group_id']?.toString() ?? '';
                    final title = data['group_title']?.toString() ?? '';
                    final contents = data['group_contents']?.toString() ?? '';
                    final timestamp = data['archived_at'] as Timestamp?;
                    final archivedAt = timestamp?.toDate() ?? DateTime.now();
                    final archivedStr = DateFormat('yyyy.MM.dd HH:mm').format(archivedAt);

                    // 3) 실제 일기 개수: diariesByGroup 에서 가져오기
                    final count = diariesByGroup[groupId]?.length ?? 0;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade200,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/image/character$groupId.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 32, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    contents,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '보관함 이동 일시: $archivedStr',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/diary_directory',
                                        arguments: {'groupId': groupId},
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '일기 $count개',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
