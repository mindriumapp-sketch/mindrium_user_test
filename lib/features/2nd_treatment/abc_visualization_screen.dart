/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/navigation_button.dart';
import '../../models/grid_item.dart';
import 'abc_real_start_screen.dart';

class AbcVisualizationScreen extends StatefulWidget {
  final List<GridItem> activatingEventChips;
  final List<GridItem> beliefChips;
  final List<GridItem> resultChips;
  final List<GridItem> feedbackEmotionChips;
  final bool isExampleMode;

  const AbcVisualizationScreen({
    super.key,
    required this.activatingEventChips,
    required this.beliefChips,
    required this.resultChips,
    required this.feedbackEmotionChips,
    this.isExampleMode = false,
  });

  @override
  State<AbcVisualizationScreen> createState() => _AbcVisualizationScreenState();
}

class _AbcVisualizationScreenState extends State<AbcVisualizationScreen> {
  void _handleComplete() async {
    if (widget.isExampleMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AbcRealStartScreen()),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final tempDoc = await userDoc.collection('temp').doc('abc_model').get();

      if (tempDoc.exists) {
        await userDoc.collection('abc_models').add(tempDoc.data()!);
        await tempDoc.reference.delete();
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isExampleMode ? '예시 시각화' : '2주차 - ABC 모델 시각화',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('A. 상황', widget.activatingEventChips),
                    const SizedBox(height: 24),
                    _buildSection('B. 생각', widget.beliefChips),
                    const SizedBox(height: 24),
                    _buildSection('C. 결과', widget.resultChips),
                    const SizedBox(height: 24),
                    _buildSection('피드백 감정', widget.feedbackEmotionChips),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: NavigationButtons(
                leftLabel: '이전',
                rightLabel: '완료',
                onBack: () => Navigator.pop(context),
                onNext: _handleComplete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<GridItem> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) => _buildChip(chip)).toList(),
        ),
      ],
    );
  }

  Widget _buildChip(GridItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 16, color: Colors.indigo.shade700),
          const SizedBox(width: 4),
          Text(
            item.label,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
*/