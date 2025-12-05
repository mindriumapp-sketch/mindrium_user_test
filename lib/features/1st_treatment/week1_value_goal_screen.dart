import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/menu/education/education_screen.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';

class Week1ValueGoalScreen extends StatefulWidget {
  final String? sessionId;
  const Week1ValueGoalScreen({super.key, required this.sessionId});

  @override
  State<Week1ValueGoalScreen> createState() => _Week1ValueGoalScreenState();
}

class _Week1ValueGoalScreenState extends State<Week1ValueGoalScreen> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _saveUserData() async {
    // ✅ formState null 방어 + validate
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final valueText = _controller.text.trim();
    setState(() => _isLoading = true);

    // ✅ BuildContext에 의존하는 것들은 await 전에 뽑아서 보관
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 🔹 서버에 value_goal 업데이트
      final tokens = TokenStorage();
      final client = ApiClient(tokens: tokens);
      final userDataApi = UserDataApi(client);
      await userDataApi.updateValueGoal(valueText);

      if (!mounted) return;

      // 🔹 UserProvider 캐시도 같이 맞춰주기
      userProvider.setValueGoalLocally(valueText);

      // 🔹 1주차 교육 화면으로 바로 진입
      navigator.push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => EducationScreen(isRelax: true, sessionId: widget.sessionId),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('저장에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final name = (user.userName).isNotEmpty ? user.userName : '사용자';

    return ApplyDesign(
      appBarTitle: '1주차 - 시작하기',
      cardTitle: 'Mindrium에 오신 것을\n환영합니다 🌊',
      onBack: () => Navigator.pop(context),
      onNext: _isLoading ? null : _saveUserData,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              protectKoreanWords(
                '이 프로그램을 통해 불안을 관리하고 \n더 나은 삶을 만들어가시길 바랍니다.',
              ),
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF333333),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              protectKoreanWords(
                '$name님, 삶에서 가장 중요하게\n생각하는 가치는 무엇인가요?',
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF224C78),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '예: 가족, 건강, 성장, 자유, 사랑, 평화 등',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFBFD9FA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF7CB9FF),
                    width: 2,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '가치를 입력해주세요';
                if (v.trim().length < 2) return '가치를 더 자세히 적어주세요';
                return null;
              },
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

