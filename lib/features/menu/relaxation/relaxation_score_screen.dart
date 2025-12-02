// ─────────────────────────  FLUTTER  ─────────────────────────
import 'package:dio/dio.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

// ───────────────────────────  LOCAL  ────────────────────────
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/icon_label.dart';

/// SUD(0‒10)을 입력받아 저장하고, 점수에 따라 후속 행동을 안내하는 화면
class RelaxationScoreScreen extends StatefulWidget {

  const RelaxationScoreScreen({super.key});

  @override
  State<RelaxationScoreScreen> createState() => _RelaxationScoreScreenState();
}

class _RelaxationScoreScreenState extends State<RelaxationScoreScreen> {
  int _relax = 10; // 슬라이더 값 (1‒10)
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final UserDataApi _userDataApi = UserDataApi(_apiClient);
  late final RelaxationApi _relaxationApi = RelaxationApi(_apiClient);


  // ────────────────────── Mongo 저장 ──────────────────────
  Future<void> _saveRelax() async {
    final route = ModalRoute.of(context);
    final Object? rawArgs = route?.settings.arguments;

    if (rawArgs is! Map) {
      debugPrint('[relaxation_score] arguments is not a Map: $rawArgs');
      return;
    }

    final args = rawArgs;
    final relaxId = args['relaxId'] as String?;

    if (relaxId == null || relaxId.isEmpty) {
      debugPrint('[relaxation_score] relaxId is null or empty, skip save');
      return;
    }

    await _relaxationApi.updateRelaxationScore(
      relaxId: relaxId,
      relaxationScore: _relax.toDouble(),
    );
  }

  // ────────────────────────── UI ──────────────────────────
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId   = args['abcId'] as String?;

    final trackColor = _relax <= 3
        ? Colors.red
        : _relax >= 7
            ? Colors.green
              : Colors.amber;

    return Scaffold(
      appBar: const CustomAppBar(title: '이완 점수'),
      backgroundColor: Colors.grey.shade100,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.padding, vertical: 8),
          child: NavigationButtons(
              leftLabel: '이전',
              rightLabel: '저장',
              onBack: () => Navigator.pop(context),
              onNext: () async {
                // 1) 점수 저장
                await _saveRelax();

                if (!context.mounted) return;
                // 2) 사용자 completed_education 읽기
                Map<String, dynamic> progress;
                try {
                  progress = await _userDataApi.getProgress();
                } on DioException catch (e) {
                  debugPrint('[relaxation_score] getProgress Dio error: $e');
                  // 실패하면 0으로 보고 그냥 기존(초기) 플로우 태우기
                  progress = const {};
                } catch (e) {
                  debugPrint('[relaxation_score] getProgress error: $e');
                  progress = const {};
                }

                final completed =
                    (progress['last_completed_week'] as int?) ?? 0;

                // 3) completed_education >= 4 → 대체생각, else after_sud
                if (!context.mounted) return;
                if (args['origin'] == 'apply') {
                  if (completed >= 4) {
                    Navigator.pushNamed(
                      context,
                      '/apply_alt_thought',
                      arguments: {
                        'abcId': abcId,
                        'diary': args['diary'],
                      },
                    );
                  } else {
                    Navigator.pushNamed(
                      context,
                      '/after_sud',
                      arguments: {
                        'abcId': abcId,
                        'diary': args['diary'],
                      },
                    );
                  }
                  return;
                } 
                if (args['origin'] == 'solve') {
                  Navigator.pushNamed(
                    context,
                    '/alt_yes_or_no',
                    arguments: {
                      'abcId': abcId,
                      'diary': args['diary'],
                    },
                  );
                  return;
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                }
              }),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '지금 느껴지는 몸의 이완 정도를 슬라이드로 선택해 주세요.',
                  style:TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // ── 현재 점수 (숫자) ──
                Center(
                  child: Text(
                    '$_relax',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: trackColor,
                    ),
                  ),
                ),

                // ── 큰 이모티콘 ──
                Icon(
                  _relax <= 3
                      ? Icons.sentiment_very_dissatisfied_sharp
                      : _relax >= 7
                          ? Icons.sentiment_very_satisfied
                            : Icons.sentiment_neutral,
                  size: 160,
                  color: trackColor,
                ),

                // ── 슬라이더 + 아이콘 설명 (가로 배치) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── 세로 슬라이더 ──
                    SizedBox(
                      height: 352,
                      child: Column(
                        children: [
                          const Text('10',
                              style: TextStyle(fontSize: 20, color: Colors.black54)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: trackColor,
                                  thumbColor: trackColor,
                                ),
                                child: Slider(
                                  value: _relax.toDouble(),
                                  min: 0,
                                  max: 10,
                                  divisions: 10,
                                  label: '$_relax',
                                  onChanged: (v) =>
                                      setState(() => _relax = v.round()),
                                ),
                              ),
                            ),
                          ),
                          const Text('0',
                              style: TextStyle(fontSize: 20, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // ── 아이콘 + 캡션 세트 ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconLabel(
                          icon: Icons.sentiment_very_satisfied,
                          color: Colors.green,
                          label: '이완',
                        ),
                        SizedBox(height: 60),
                        IconLabel(
                          icon: Icons.sentiment_neutral,
                          color: Colors.amber,
                          label: '보통',
                        ),
                        SizedBox(height: 60),
                        IconLabel(
                          icon: Icons.sentiment_very_dissatisfied_sharp,
                          color: Colors.red,
                          label: '긴장',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}