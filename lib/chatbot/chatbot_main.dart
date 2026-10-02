// lib/chatbot/chatbot_main.dart
//
// NPC 상담 화면. UI / STT / TTS / 스크롤 / 아바타만 담당하고,
// 상담 판단은 전부 CounselingProvider -> CounselingHarness 로 넘긴다.
//
// 이 파일에 있으면 안 되는 것:
//   프롬프트 생성, 검색, CBT 상태 결정, 환자 기록 선택, 모델 호출, 응답 검증
import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.html) 'utils/file_stub.dart'
    show Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/internal_account_allowlist.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/local_realization_telemetry_sink.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/counseling_benchmark.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/chatbot/services/chat_transcript_log.dart';
import 'package:gad_app_team/data/api/counseling_classify_api.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/features/counseling/perception/shadow_perception.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/llm_service.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'affective/affect_signal.dart';
import 'affective/affect_signal_detector.dart';
import 'affective/affective_adapter.dart';
import 'affective/avatar_asset_resolver.dart';
import 'affective/avatar_selector.dart';
import 'services/speech_output_service.dart';
import 'ui/chat_bubble.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const ChatApp());
// }

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const ChatPage();
  }
}

class ChatPage extends StatefulWidget {
  /// 테스트나 다른 런타임을 끼우기 위한 주입점. 생략하면 앱 기본 구성을 쓴다.
  final CbtKnowledgeRepository? knowledgeRepository;

  /// MindRium 앱 사용법 지식(Phase 6). 생략하면 기본 자산(`rootBundle`)에서
  /// 읽는다 — `knowledgeRepository`와 같은 주입 패턴이다.
  final AppGuideRepository? appGuideRepository;
  final LlmService? llm;
  final MindriumDataSource? dataSource;
  final SpeechOutputService? speechOutput;

  /// 생략하면 UserProvider 의 현재 주차를 쓴다.
  final int? currentWeek;

  const ChatPage({
    super.key,
    this.knowledgeRepository,
    this.appGuideRepository,
    this.llm,
    this.dataSource,
    this.speechOutput,
    this.currentWeek,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  /// TurnPlan 초안을 GPT(backend `/counseling/realize`)로 다듬는 경로.
  /// 기본값 false — 온/오프 스위치는 이 define과 backend kill switch 둘 다에
  /// 있어야 한다(docs/counseling/chatbot_system.md 9절).
  static const bool _remoteRealizerEnabled = bool.fromEnvironment(
    'COUNSELING_REMOTE_REALIZER',
    defaultValue: false,
  );

  /// Phase 10.6C — Stage 1 (internalOnly) canary rollout.
  ///
  /// 이 플래그가 켜져 있어도(위 `_remoteRealizerEnabled`) 실제로 Remote
  /// realization을 받는 건 `internalAccountEmailAllowlist`에 등록된 계정
  /// 뿐이다 — `RolloutConfig(stage: internalOnly)`가 그 밖의 모든 계정을
  /// deterministic으로 되돌린다. 이 빌드/환경 자체를 즉시 꺼야 할 때 앱을
  /// 재빌드하지 않고 값을 바꿀 원격 설정은 아직 없다(Phase 10.6B 문서의
  /// 알려진 한계) — 지금은 이 컴파일타임 플래그가 유일한 kill switch다.
  static const bool _rolloutKillSwitch = bool.fromEnvironment(
    'COUNSELING_REMOTE_REALIZER_KILL_SWITCH',
    defaultValue: false,
  );

  /// Phase 14.2A-4: 의미 분류기 그림자 관찰. 켜도 결과는 기록만 하고 상담
  /// 결정에 쓰지 않는다. 사용자 발화가 백엔드를 거쳐 외부 모델로 가므로 내부
  /// 계정 허용 목록에 있는 계정에서만 동작한다. 기본값 false.
  static const bool _shadowClassifierEnabled = bool.fromEnvironment(
    'COUNSELING_SHADOW_CLASSIFIER',
    defaultValue: false,
  );

  /// Phase 14.2B: 분류기의 두 신호(질문 중단, 챗봇 말을 못 알아들음)를 guard 뒤에서
  /// 정책 입력으로 쓴다(규칙 OR 모델). 내부 계정에서만, 기본값 false. 켜면 그림자
  /// 관찰도 함께 켜진 것으로 본다.
  static const bool _semanticRepairEnabled = bool.fromEnvironment(
    'COUNSELING_SEMANTIC_REPAIR',
    defaultValue: false,
  );

  /// Phase 14.X: Bounded LLM-led 경로(시제품). 내부 계정에서만, 기본값 false.
  /// docs/counseling/phase14x_bounded_llm_led.md.
  static const bool _llmLedEnabled = bool.fromEnvironment(
    'COUNSELING_LLM_LED_PATH',
    defaultValue: false,
  );

  /// Phase 14.X E3: LLM-led 경로를 세션마다 번갈아 쓴다(화면에 표시하지 않음).
  static const bool _llmLedAlternate = bool.fromEnvironment(
    'COUNSELING_LLM_LED_AB',
    defaultValue: false,
  );

  // ===== Affect =====
  // 표정 결정은 전부 affective/ 로 옮겼다. 화면은 결과를 그리기만 한다.
  static const AffectSignalDetector _detector = AffectSignalDetector();
  static const AffectiveAdapter _adapter = AffectiveAdapter();
  final AvatarSelector _avatarSelector = AvatarSelector();

  AffectSignal? _lastSignal;

  // ===== Services =====
  late final CounselingProvider _provider;
  late final SpeechOutputService _speechOutput;

  /// 이미 음성으로 읽은 assistant 메시지. 같은 문장을 두 번 읽지 않기 위해 쓴다.
  final Set<String> _spokenMessageIds = {};
  final Map<String, String> _messageAvatars = {};

  // ===== Chat State =====
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatTranscriptLog? _transcriptLog;
  final bool _autoSend = true;

  /// 화면에 띄우는 안내 문구(에러/도움말). 상담 메시지가 아니라 UI 전용이다.
  final List<String> _notices = [];

  /// closing 안내는 세션당 한 번만 띄운다. closing 상태는 여러 턴 유지될 수
  /// 있어 매 턴 검사하면 같은 안내가 반복된다.
  bool _closingHintShown = false;

  // ===== STT/TTS =====
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _recognized = '';

  bool _ttsEnabled = true;
  bool _isTtsSpeaking = false;

  DateTime? _sttGuardUntil;
  final Duration _sttCooldown = const Duration(
    seconds: 3,
  ); // 1031 수정 (기존; milliseconds:800)
  bool _userGestured = false;
  bool get _canStartListening {
    if (_isTtsSpeaking) return false;
    if (_sttGuardUntil != null && DateTime.now().isBefore(_sttGuardUntil!)) {
      return false;
    }
    if (!_sessionOpen) return false;
    return true;
  }

  bool _sessionOpen = true;

  // ===== Emotion Avatars =====
  late String _currentAvatar = _avatarSelector.asset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speechOutput = widget.speechOutput ?? FlutterTtsSpeechOutputService();
    _speechOutput.onSpeakingChanged = _handleSpeakingChanged;
    _provider = _createProvider();
    _provider.addListener(_handleProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_provider.finalizeIfIncomplete());
    }
  }

  /// 상담 엔진 구성. 여기서 정하는 것은 "어떤 구현을 쓸지"뿐이고,
  /// 상담 판단은 전부 harness 안에서 일어난다.
  CounselingProvider _createProvider() {
    final repository =
        widget.knowledgeRepository ?? LocalCbtKnowledgeRepository();
    final appGuideRepository =
        widget.appGuideRepository ?? LocalAppGuideRepository();

    final week =
        widget.currentWeek ??
        context.read<UserProvider>().currentWeek.clamp(1, 8);

    CounselingSessionsApi? sessionsApi;
    MindriumContextBuilder? contextBuilder;
    final injected = widget.dataSource;
    if (injected != null) {
      contextBuilder = MindriumContextBuilder(dataSource: injected);
    } else {
      // 서버 구성이 없는 환경에서는 개인화 없이 동작한다.
      try {
        final client = ApiClient(tokens: TokenStorage());
        sessionsApi = CounselingSessionsApi(client);
        contextBuilder = MindriumContextBuilder(
          dataSource: ApiMindriumDataSource(
            diariesApi: DiariesApi(client),
            worryGroupsApi: WorryGroupsApi(client),
            relaxationApi: RelaxationApi(client),
          ),
        );
      } catch (e) {
        debugPrint('[ChatPage] 컨텍스트 빌더 구성 실패: $e');
      }
    }

    final injectedLlm = widget.llm;
    final useRemoteRealizer = injectedLlm == null && _remoteRealizerEnabled;
    final effectiveLlm = injectedLlm ?? MockLlmService();

    // Phase 10.6C: Stage 1 rollout config. `stage: internalOnly` means
    // only `internalAccountEmailAllowlist`에 실제로 등록된 이메일만
    // Remote를 받는다 — 그 목록이 비어 있으면(현재 기본값) 아무도 받지
    // 않는다, Phase 10.6B 기준선과 동일하게 안전하다.
    final rolloutConfig =
        useRemoteRealizer
            ? RolloutConfig(
              enabled: true,
              stage: RolloutStage.internalOnly,
              killSwitch: _rolloutKillSwitch,
            )
            : null;
    final userEmail =
        useRemoteRealizer ? context.read<UserProvider>().userEmail : null;
    final isInternalAccount = isInternalAccountEmail(userEmail);

    final harness =
        useRemoteRealizer
            // TurnPlan은 여전히 결정론이 정하고, GPT는 그 초안을 자연스러운
            // 한국어로 다듬기만 한다. 검증 실패·네트워크 오류는 항상
            // deterministic draft로 되돌아간다.
            ? CounselingHarness.remoteGpt(
              llm: effectiveLlm,
              safetyGate: const KeywordSafetyGate(),
              knowledgeRepository: repository,
              responseRealizer: RemoteLlmRealizer(
                api: DioCounselingRealizeApi(ApiClient(tokens: TokenStorage())),
              ),
              rolloutConfig: rolloutConfig,
              isInternalAccount: isInternalAccount,
              telemetrySink: logRealizationTelemetryLocally,
            )
            // GPT 경로가 꺼져 있으면 안전한 결정론적 경로를 유지한다.
            : CounselingHarness.deterministic(
              llm: effectiveLlm,
              safetyGate: const KeywordSafetyGate(),
              knowledgeRepository: repository,
            );

    return CounselingProvider(
      knowledgeRepository: repository,
      appGuideRepository: appGuideRepository,
      currentWeek: week,
      contextBuilder: contextBuilder,
      sessionsApi: sessionsApi,
      shadowPerception: _shadowPerception(),
      causalPerception: _semanticRepairEnabled && _shadowPerception() != null,
      llmLedApi: _llmLedApi(),
      llmLedAlternate: _llmLedAlternate,
      // Phase 10.6C-DOGFOOD: disabled per real-device feedback — showing
      // this deterministic placeholder bubble ahead of the real answer
      // made every Remote-eligible turn render as two disconnected
      // messages, which the Phase 10.5 review artifacts (one reply per
      // scenario) never showed reviewers. `instantEmpathy` itself stays a
      // supported CounselingProvider feature (see counseling_provider_test.dart),
      // just not wired to true at this real call site anymore.
      instantEmpathy: false,
      harness: harness,
    );
  }

  /// Phase 14.X E3: rate the session that just ended. The path (A/B) is not
  /// shown; it is logged with the session pseudonym (`LLM_LED_RATING`).
  Future<void> _askSessionRating() async {
    const items = {
      'natural': '실제 대화처럼 자연스럽게 이어졌나요?',
      'context': '방금 한 말을 제대로 이해하고 반응했나요?',
      'flexible': '앱 질문, 새 주제, 불만에 적절히 대응했나요?',
      'progress': '빙빙 돌지 않고 적절히 진행됐나요?',
    };
    final scores = <String, int>{};
    int? again;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이번 상담 평가 (1~5)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final e in items.entries) ...[
                  Text(e.value),
                  Wrap(spacing: 6, children: [
                    for (var v = 1; v <= 5; v++)
                      ChoiceChip(
                        label: Text('$v'),
                        selected: scores[e.key] == v,
                        onSelected: (_) => setSheet(() => scores[e.key] = v),
                      ),
                  ]),
                  const SizedBox(height: 8),
                ],
                const Text('실제로 이 챗봇과 상담을 계속하고 싶다고 느꼈나요?'),
                Wrap(spacing: 6, children: [
                  for (var v = 1; v <= 5; v++)
                    ChoiceChip(label: Text('$v'), selected: again == v, onSelected: (_) => setSheet(() => again = v)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: scores.length == items.length && again != null
                        ? () => Navigator.of(ctx).pop(true)
                        : null,
                    child: const Text('제출'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    debugPrint('LLM_LED_RATING ${jsonEncode({
      'session': _provider.sessionPseudonym,
      'path': _provider.experimentPath,
      ...scores,
      'continue_wish': again,
    })}');
  }

  CounselingRespondApi? _llmLedApi() {
    if (!_llmLedEnabled || widget.llm != null) return null;
    if (!isInternalAccountEmail(context.read<UserProvider>().userEmail)) return null;
    return DioCounselingRespondApi(ApiClient(tokens: TokenStorage()));
  }

  ShadowPerception? _shadowPerception() {
    if (!(_shadowClassifierEnabled || _semanticRepairEnabled) || widget.llm != null) {
      return null;
    }
    final email = context.read<UserProvider>().userEmail;
    if (!isInternalAccountEmail(email)) return null;
    return ShadowPerception(
      api: DioCounselingClassifyApi(ApiClient(tokens: TokenStorage())),
    );
  }

  void _handleProviderChanged() {
    if (!mounted) return;
    for (final message in _provider.messages.where(
      (message) => !message.isUser,
    )) {
      _messageAvatars.putIfAbsent(message.id, () => _currentAvatar);
    }
    setState(() {});
    _jumpToBottom();
  }

  // ===== Initialization =====
  //
  // 상담 엔진을 가장 먼저 올린다. 로그·마이크·스피커는 보조 기능이라, 그중 하나가
  // 실패하거나 응답하지 않아도 대화는 시작될 수 있어야 한다.
  Future<void> _bootstrap() async {
    // 화면 진입부터 대화가 그려질 때까지. Activity cold start 와는 다른 값이다.
    final readyWatch = Stopwatch()..start();

    try {
      await _provider.initialize();
    } catch (e, st) {
      debugPrint('[ChatPage] 상담 엔진 초기화 실패: $e\n$st');
      _appendNotice('상담을 준비하는 중 문제가 발생했습니다.');
      return;
    }

    if (!mounted) return;
    setState(() {});
    _jumpToBottom();

    readyWatch.stop();
    CounselingBenchmark.emit('chat_page_ready', {
      'ms': readyWatch.elapsedMilliseconds,
    });

    Future<void> step(String label, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('[ChatPage] $label 초기화 실패: $e');
      }
    }

    await step('로그', _initJsonLog);
    await step('음성 출력', _speechOutput.initialize);

    // 첫 인사를 읽어준다. 상담 판단이 아니라 표시 계층의 동작이다.
    await step('첫 인사 재생', _speakLatestAssistantMessage);

    await step('음성 입력', _initStt);

    if (kIsWeb) {
      _appendNotice('스피커 또는 마이크 버튼을 눌러 음성을 활성화해 주세요.');
    }
  }

  void _handleSpeakingChanged(bool speaking) {
    _isTtsSpeaking = speaking;
    if (!speaking) _sttGuardUntil = DateTime.now().add(_sttCooldown);
    if (mounted) setState(() {});
  }

  // ===== 로그 =====
  Future<void> _initJsonLog() async {
    if (kIsWeb) return; // 웹은 path_provider 미지원 → 스킵
    try {
      final dir = await getApplicationDocumentsDirectory();
      _transcriptLog = await ChatTranscriptLog.create(Directory('${dir.path}/logs'));
    } catch (e) {
      debugPrint('init json log error: $e');
    }
  }

  void _appendJsonLogMessage({
    required String role,
    required String text,
    Map<String, dynamic>? extra,
  }) {
    _transcriptLog?.append(role: role, text: text, extra: extra);
  }

  // ===== STT / TTS =====
  Future<void> _initStt() async {
    _speechReady = await _speech.initialize(
      onStatus: (s) async {
        debugPrint('STT status: $s');
        // STT는 사용자가 마이크 버튼을 누른 한 번의 세션만 허용한다.
        // 엔진이 조기에 종료되어도 자동으로 다시 켜지 않는다.
        if (s == 'notListening') {
          if (_listening) setState(() => _listening = false);
          if (_autoSend && _recognized.trim().isNotEmpty) {
            _controller.text = _recognized.trim();
            await _send();
          }
        }
      },
      onError: (e) {
        final detail = e.permanent ? ' (permanent)' : '';
        final rawMsg = e.errorMsg.trim();
        final errorText = rawMsg.isEmpty ? '알 수 없는 오류' : rawMsg;
        _appendNotice('STT 오류: $errorText$detail');
      },
      debugLogging: true,
    );
    if (!_speechReady) {
      _appendNotice('마이크 초기화에 실패했습니다. (권한/HTTPS 확인)');
    }
  }

  /// 아직 읽지 않은 마지막 assistant 메시지를 읽는다.
  ///
  /// 음성 출력은 상담 판단과 무관하다. 꺼져 있으면 아무 일도 하지 않는다.
  Future<void> _speakLatestAssistantMessage() async {
    if (!_ttsEnabled || !_speechOutput.isReady) return;
    if (kIsWeb && !_userGestured) {
      _appendNotice('스피커 버튼을 한번 눌러 음성을 활성화해 주세요.');
      return;
    }

    final messages = _provider.messages;
    if (messages.isEmpty) return;

    final latest = messages.last;
    if (latest.isUser) return;
    if (!_spokenMessageIds.add(latest.id)) return;

    // 재생 중 마이크가 열려 있으면 자기 목소리를 받아 적는다.
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) setState(() => _listening = false);
    }

    await _speechOutput.speak(latest.text);
  }

  /// 상단 스피커 버튼의 명시적 사용자 제어.
  /// 끄는 순간 현재 발화도 멈추고, 다시 켜더라도 지난 메시지는 자동 재생하지 않는다.
  Future<void> _toggleTts() async {
    _userGestured = true;
    final enabled = !_ttsEnabled;
    setState(() => _ttsEnabled = enabled);
    if (!enabled) {
      await _speechOutput.stop();
    }
  }

  // ===== STT 토글 =====
  Future<void> _toggleListening() async {
    _userGestured = true;
    await _waitForGuard();

    // 1031 수정 마이크 초기화 안정화 시간 추가
    await Future.delayed(const Duration(milliseconds: 800));

    if (!_speechReady) {
      _appendNotice('STT 준비 안됨');
      return;
    }
    if (!_canStartListening) {
      await _waitForGuard();
      if (!_canStartListening) {
        _appendNotice('지금은 음성을 시작할 수 없어요');
        return;
      }
    }

    if (_listening) {
      try {
        await _speech.cancel(); // 1031 수정 stop() -> cancel()
      } catch (_) {}
      setState(() => _listening = false);
      if (_recognized.trim().isNotEmpty) {
        _controller.text = _recognized.trim();
        await _send();
      }
      return;
    }

    if (!_speech.isAvailable) {
      _appendNotice('마이크 사용이 불가합니다');
      return;
    }

    setState(() {
      _recognized = '';
      _listening = true;
    });

    await _speech.listen(
      localeId: 'ko_KR',
      listenFor: const Duration(seconds: 100), // 1031 수정
      pauseFor: const Duration(seconds: 15), // 1031 수정
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (r) async {
        // 🎤 실시간 인식된 단어를 바로 입력창에 반영
        setState(() {
          _recognized = r.recognizedWords;
          _controller.text = r.recognizedWords;
        });

        // 🎯 최종 결과일 때만 자동 전송
        if (_autoSend && r.finalResult && _recognized.trim().isNotEmpty) {
          await Future.delayed(const Duration(seconds: 2)); // 1031 수정 텀 추가
          try {
            await _speech.stop();
          } catch (_) {}
          setState(() => _listening = false);
          await _send();
          _controller.clear();
        }
      },
    );
  }

  Future<void> _waitForGuard() async {
    final now = DateTime.now();
    final until = _sttGuardUntil ?? now;
    final wait = until.isAfter(now) ? until.difference(now) : Duration.zero;
    if (wait > Duration.zero) await Future.delayed(wait);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildAiProfileFor(String assetPath) {
    return CircleAvatar(
      radius: 32,
      backgroundImage: AssetImage(assetPath),
      backgroundColor: Colors.transparent,
    );
  }

  // ===== 사용자 데이터 열기 =====
  /// 세션 재시작. 대화 상태는 provider 가 갖고 있으므로 여기서는 표시만 되돌린다.
  Future<void> _restartSession() async {
    if (_provider.isGenerating) return;

    await _speechOutput.stop();
    _spokenMessageIds.clear();
    _messageAvatars.clear();
    _notices.clear();
    _closingHintShown = false;

    await _provider.reset();
    if (!mounted) return;

    setState(() {
      _avatarSelector.reset();
      _lastSignal = null;
      _currentAvatar = _avatarSelector.asset;
      _sessionOpen = true;
    });
    _jumpToBottom();
    await _speakLatestAssistantMessage();
  }

  // ===== 감정 선택 규칙 =====
  // ===== 전송 =====
  //
  // 화면이 하는 일은 세 가지다: 입력을 넘기고, 아바타를 고르고, 음성을 재생한다.
  // 무엇을 답할지, 어떤 근거를 쓸지, 다음 단계가 무엇인지는 전부 harness 가 정한다.
  Future<void> _send() async {
    _userGestured = true;
    if (!_sessionOpen) return;

    final text = _controller.text.trim();
    if (text.isEmpty || _provider.isGenerating) return;

    await _speechOutput.stop();

    setState(_controller.clear);
    _appendJsonLogMessage(role: 'user', text: text);
    _applyAvatarFor(text);
    _jumpToBottom();

    await _provider.sendMessage(text);
    if (!mounted) return;

    final latest = _provider.messages.isEmpty ? null : _provider.messages.last;
    if (latest != null && !latest.isUser) {
      _appendJsonLogMessage(role: 'ai', text: latest.text);
    }

    setState(() {});
    _jumpToBottom();

    if (!_closingHintShown && _provider.isSessionFinalized) {
      _closingHintShown = true;
      _appendNotice(
        '오늘 상담은 여기까지예요. 새로운 주제로 다시 이야기하고 싶다면 오른쪽 위 새로고침 버튼을 눌러주세요.',
      );
      if (_llmLedEnabled && _llmLedAlternate) unawaited(_askSessionRating());
    }

    await _speakLatestAssistantMessage();
  }

  /// 이번 턴의 아바타를 고른다.
  ///
  /// 신호는 **사용자가 한 말**에서 읽는다. 상담자 응답으로 표정을 고르면
  /// 상담사가 자기 말에 반응하는 꼴이 된다.
  void _applyAvatarFor(String userMessage) {
    final signal = _detector.detect(
      userMessage: userMessage,
      recentSud: _provider.userContext?.recentSud?.latest,
      previous: _lastSignal,
    );

    final expression = _adapter.adapt(
      signal: signal,
      state: _provider.state,
      safetyLevel: _provider.lastSafetyLevel,
    );

    _lastSignal = signal;
    _currentAvatar = _avatarSelector.update(expression);
  }

  void _appendNotice(String message) {
    if (!mounted) return;
    setState(() => _notices.add(message));
    _jumpToBottom();
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    // 상담 상태의 유일한 출처는 provider 다.
    final loading = _provider.isGenerating || !_provider.isReady;
    final showingGenerationBubble = _provider.isGenerating;
    final messages = _provider.messages;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            splashRadius: 22,
            onPressed:
                () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (_) => false,
                ),
          ),
        ),
        title: const Text('디지털 CBT 상담'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '세션 재시작',
            onPressed: _restartSession,
          ),
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _ttsEnabled ? '음성 출력 끄기' : '음성 출력 켜기',
            onPressed: _toggleTts,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                itemCount:
                    messages.length +
                    (showingGenerationBubble ? 1 : 0) +
                    _notices.length,
                itemBuilder: (context, i) {
                  if (showingGenerationBubble && i == messages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ChatBubble(
                        text: '답변을 생각하고 있어요…',
                        isAi: true,
                        profileWidget: Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 6.0),
                          child: _buildAiProfileFor(_currentAvatar),
                        ),
                      ),
                    );
                  }

                  // 안내 문구는 대화 아래에 모아 보여준다.
                  final noticeStart =
                      messages.length + (showingGenerationBubble ? 1 : 0);
                  if (i >= noticeStart) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: Text(
                        _notices[i - noticeStart],
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  final message = messages[i];
                  final isAi = !message.isUser;
                  // 마지막 상담자 메시지에만 현재 표정을 쓴다.
                  final avatar =
                      isAi
                          ? (_messageAvatars[message.id] ??
                              const AvatarAssetResolver().defaultAsset)
                          : const AvatarAssetResolver().defaultAsset;

                  // harness 가 추천한 활동만 나타난다. UI 가 만들지 않는다.
                  final activity =
                      isAi ? _provider.uiActionForMessage(message.id) : null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChatBubble(
                          text: message.text,
                          isAi: isAi,
                          profileWidget:
                              isAi
                                  ? Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8.0,
                                      right: 6.0,
                                    ),
                                    child: _buildAiProfileFor(avatar),
                                  )
                                  // user_profile.png 자산이 존재하지 않아 아이콘으로 대체한다.
                                  : const Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.0,
                                      right: 6.0,
                                    ),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Color(0xFFD8E5F6),
                                      child: Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Color(0xFF44618A),
                                      ),
                                    ),
                                  ),
                        ),
                        // 추천이지 화면 이동 명령이 아니다. 누르는 대상이 아니며
                        // 사용자가 앱에서 스스로 수행할지 정한다.
                        if (activity != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 76,
                              top: 4,
                              bottom: 4,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF4FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '추천 활동 · ${activity.label}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF315F87),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Colors.redAccent : Colors.grey,
                    ),
                    onPressed: _toggleListening,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: loading ? '응답 생성 중...' : '메시지를 입력하세요',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: loading ? Colors.grey : Colors.blueAccent,
                    onPressed: loading ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // dispose에서는 await할 수 없으므로 먼저 저장을 시작한다. Provider의 저장
    // queue와 서버 upsert가 pause/back/closing 경합을 안전하게 정리한다.
    unawaited(_provider.finalizeIfIncomplete());
    try {
      _speech.stop();
    } catch (_) {}
    _speechOutput.dispose();
    _provider.removeListener(_handleProviderChanged);
    _provider.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
