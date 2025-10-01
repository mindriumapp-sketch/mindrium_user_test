import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'week4_alternative_thoughts_display_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week4AlternativeThoughtsScreen extends StatefulWidget {
  final List<String> previousChips;
  final int? beforeSud;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String>? existingAlternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final String? abcId;
  final int loopCount;

  const Week4AlternativeThoughtsScreen({
    super.key,
    required this.previousChips,
    this.beforeSud,
    required this.remainingBList,
    required this.allBList,
    this.existingAlternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4AlternativeThoughtsScreen> createState() =>
      _Week4AlternativeThoughtsScreenState();
}

class _Week4AlternativeThoughtsScreenState
    extends State<Week4AlternativeThoughtsScreen> {
  final List<String> _chips = [];

  @override
  void initState() {
    super.initState();
    // 사용자에게는 현재 작성하는 내용만 보여주기 위해 기존 대체 생각들은 표시하지 않음
    // 하지만 데이터는 계속 누적되어야 함
  }

  Future<void> _saveAlternativeThoughtsToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ 저장 실패: 사용자가 로그인하지 않았습니다.');
        return;
      }

      debugPrint('✅ 저장 시작 - User ID: ${user.uid}');
      debugPrint('✅ 현재 chips: $_chips');
      debugPrint('✅ 기존 thoughts: ${widget.existingAlternativeThoughts}');

      // 기존 대체 생각들과 새로 추가한 대체 생각들을 합침
      final allAlternativeThoughts = [
        ...?widget.existingAlternativeThoughts,
        ..._chips,
      ];

      debugPrint('✅ 저장할 전체 thoughts: $allAlternativeThoughts');

      String targetAbcId;

      // abcId가 없으면 최신 ABC 모델 문서를 찾아서 사용
      if (widget.abcId == null || widget.abcId!.isEmpty) {
        debugPrint('⚠️ abcId가 없습니다. 최신 ABC 모델을 찾습니다...');

        final snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('abc_models')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();

        if (snapshot.docs.isEmpty) {
          debugPrint('❌ ABC 모델이 없습니다. 저장을 중단합니다.');
          return;
        }

        targetAbcId = snapshot.docs.first.id;
        debugPrint('✅ 최신 ABC 모델을 찾았습니다: $targetAbcId');
      } else {
        targetAbcId = widget.abcId!;
        debugPrint('✅ 전달받은 ABC ID 사용: $targetAbcId');
      }

      // ABC 모델 문서 업데이트 (set with merge: true를 사용하여 문서가 없어도 생성)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('abc_models')
          .doc(targetAbcId)
          .set({
            'alternative_thoughts': allAlternativeThoughts,
            'week4_completed': true,
            'week4_completed_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('✅ 도움이 되는 생각이 Firebase에 저장되었습니다!');
      debugPrint('   경로: users/${user.uid}/abc_models/$targetAbcId');
      debugPrint('   필드: alternative_thoughts');
      debugPrint('   내용: $allAlternativeThoughts');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase 저장 오류: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  void _showInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFFE8EAF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '불안한 생각을 도움이 되는 생각으로 바꿔볼까요?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.indigo,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 80,
                              maxWidth: 200,
                            ),
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: '예: 긍정적으로 생각해요',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(이)라는',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '생각을 해보았습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) {
                        setState(() {
                          _chips.add(value);
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[alt_thought] abcId: ${widget.abcId}');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
                        child: Text(
                          '도움이 되는 생각을 찾아보는 시간',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: Image.asset(
                            'assets/image/alternative thoughts.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 하단 카드 (새 구조)
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '다르게 생각해보기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _chips.isEmpty
                              ? '도움이 되는 생각을 찾아볼까요?'
                              : '혹시 또 다른 도움이 되는 생각이 있다면 입력해주시고, 없으시다면 다음을 눌러주세요.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF2F3F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                _chips.isEmpty
                                    ? Center(
                                      child: Text(
                                        '여기에 입력한 내용이 표시됩니다',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15,
                                        ),
                                      ),
                                    )
                                    : SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            _chips
                                                .asMap()
                                                .entries
                                                .map(
                                                  (entry) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF6F8FF,
                                                      ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFCED4DA,
                                                        ),
                                                        width: 1.2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            entry.value,
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF2962F6,
                                                                  ),
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _chips.removeAt(
                                                                entry.key,
                                                              );
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 20,
                                                            height: 20,
                                                            decoration:
                                                                const BoxDecoration(
                                                                  color: Color(
                                                                    0xFFCED4DA,
                                                                  ),
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                            child: const Icon(
                                                              Icons.close,
                                                              size: 14,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _showInputDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2962F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '입력하기',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext:
                  _chips.isNotEmpty
                      ? () async {
                        // Firebase에 저장
                        await _saveAlternativeThoughtsToFirebase();

                        // 항상 현재 B(생각)을 명확히 전달
                        final bToShow =
                            widget.previousChips.isNotEmpty
                                ? widget.previousChips.last
                                : (widget.remainingBList.isNotEmpty
                                    ? widget.remainingBList.first
                                    : '');

                        if (widget.abcId != null && widget.abcId!.isNotEmpty) {
                          Navigator.pushNamed(
                            context,
                            '/alt_thought',
                            arguments: {
                              'abcId': widget.abcId,
                              'loopCount': widget.loopCount,
                            },
                          );
                        } else {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) =>
                                      Week4AlternativeThoughtsDisplayScreen(
                                        alternativeThoughts: _chips,
                                        previousB: bToShow,
                                        beforeSud: widget.beforeSud ?? 0,
                                        remainingBList: widget.remainingBList,
                                        allBList: widget.allBList,
                                        existingAlternativeThoughts:
                                            widget.existingAlternativeThoughts,
                                        isFromAnxietyScreen:
                                            widget.isFromAnxietyScreen,
                                        originalBList: widget.originalBList,
                                        abcId: widget.abcId,
                                        loopCount: widget.loopCount,
                                      ),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        }
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
