import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final EduSessionsApi _eduApi = EduSessionsApi(_apiClient);
  late final RelaxationApi _relaxationApi = RelaxationApi(_apiClient);

  DateTime _selectedDate = _startOfDay(DateTime.now());
  DateTime _focusedWeekStart = _startOfWeek(_startOfDay(DateTime.now()));

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _diarySummaries = const [];
  List<Map<String, dynamic>> _eduSessions = const [];
  List<Map<String, dynamic>> _relaxationTasks = const [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) {
    final d = _startOfDay(date);
    final diff = d.weekday % 7; // 일요일 시작
    return d.subtract(Duration(days: diff));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      return parsed?.toLocal();
    }
    return null;
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _diariesApi.listDiarySummaries(),
        _eduApi.listEduSessions(),
        _relaxationApi.listRelaxationTasks(),
      ]);

      if (!mounted) return;
      setState(() {
        _diarySummaries = (results[0] as List).cast<Map<String, dynamic>>();
        _eduSessions = (results[1] as List).cast<Map<String, dynamic>>();
        _relaxationTasks = (results[2] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '리포트 데이터를 불러오지 못했어요.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _diariesFor(DateTime date) {
    return _diarySummaries.where((d) {
      final created = _parseDate(d['created_at']);
      return created != null && _isSameDay(created, date);
    }).toList();
  }

  List<Map<String, dynamic>> _eduForWeek(DateTime date) {
    final weekStart = _startOfWeek(date);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _eduSessions.where((s) {
      final start = _parseDate(s['start_time']) ?? _parseDate(s['created_at']);
      if (start == null) return false;
      final day = _startOfDay(start);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).toList();
  }

  List<Map<String, dynamic>> _relaxFor(DateTime date) {
    return _relaxationTasks.where((r) {
      final start = _parseDate(r['start_time']) ?? _parseDate(r['created_at']);
      return start != null && _isSameDay(start, date);
    }).toList();
  }

  int _completionRateDiary(DateTime date) {
    final diaries = _diariesFor(date);
    if (diaries.isEmpty) return 0;
    return 100;
  }

  int _completionRateEducation(DateTime date) {
    final sessions = _eduForWeek(date);
    if (sessions.isEmpty) return 0;
    final hasCompleted = sessions.any((s) => s['completed'] == true);
    return hasCompleted ? 100 : 0;
  }

  List<String> _educationWeeklyLogs(DateTime date) {
    final sessions = _eduForWeek(date);
    if (sessions.isEmpty) {
      return const ['이번 주 0/1 (미완료)'];
    }

    final completedSessions = sessions.where((s) => s['completed'] == true).toList()
      ..sort((a, b) {
        final aDate = _parseDate(a['start_time']) ?? _parseDate(a['created_at']);
        final bDate = _parseDate(b['start_time']) ?? _parseDate(b['created_at']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    if (completedSessions.isEmpty) {
      return const ['이번 주 0/1 (미완료)'];
    }

    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final completedAt =
        _parseDate(completedSessions.first['start_time']) ??
        _parseDate(completedSessions.first['created_at']);
    final completedDayLabel =
        completedAt == null
            ? '완료일 기록'
            : '${completedAt.month}/${completedAt.day}(${weekdays[completedAt.weekday % 7]}) 완료';
    return ['이번 주 1/1 완료', completedDayLabel];
  }

  int _completionRateRelaxation(DateTime date) {
    final sessions = _relaxFor(date);
    if (sessions.isEmpty) return 0;
    final completed = sessions.where((s) => s['end_time'] != null).length;
    if (completed == 0) return 50;
    return 100;
  }

  List<double> _sudWeeklySeries(DateTime centerDate) {
    final days = List.generate(
      7,
      (i) => _startOfDay(centerDate.subtract(Duration(days: 6 - i))),
    );
    return days.map((day) {
      final entries = _diariesFor(day)
          .map((d) => d['latest_sud'])
          .whereType<num>()
          .map((v) => v.toDouble())
          .toList();
      if (entries.isEmpty) return 0.0;
      final avg = entries.reduce((a, b) => a + b) / entries.length;
      return avg.clamp(0, 10).toDouble();
    }).toList();
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Set<String> _activityDateKeysInWeek(DateTime weekStart) {
    final keys = <String>{};
    final weekEnd = weekStart.add(const Duration(days: 7));

    void addFrom(dynamic raw) {
      final parsed = _parseDate(raw);
      if (parsed == null) return;
      final day = _startOfDay(parsed);
      if (!day.isBefore(weekStart) && day.isBefore(weekEnd)) {
        keys.add(_dateKey(day));
      }
    }

    for (final d in _diarySummaries) {
      addFrom(d['created_at']);
    }
    for (final e in _eduSessions) {
      addFrom(e['start_time'] ?? e['created_at']);
    }
    for (final r in _relaxationTasks) {
      addFrom(r['start_time'] ?? r['created_at']);
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: '리포트',
        showBack: false,
        showHome: true,
        confirmOnBack: false,
        confirmOnHome: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _loadReportData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          children: [
                            _buildCalendarCard(),
                            const SizedBox(height: 10),
                            _buildSelectedDateHeader(),
                            const SizedBox(height: 14),
                            _buildSudCard(),
                            const SizedBox(height: 14),
                            _buildCompletionCard(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final weekStart = _focusedWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${weekStart.month}.${weekStart.day} - ${weekEnd.month}.${weekEnd.day}';
    final weekDates =
        List.generate(7, (i) => _startOfDay(weekStart.add(Duration(days: i))));
    final activeDateKeys = _activityDateKeysInWeek(weekStart);
    const weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return _sectionCard(
      title: '주간 캘린더',
      subtitle: '해당 주의 날짜를 선택하면 일자별 기록이 보여요.',
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedWeekStart = _focusedWeekStart.subtract(
                      const Duration(days: 7),
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  weekLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2F3F),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final today = _startOfDay(DateTime.now());
                  setState(() {
                    _selectedDate = today;
                    _focusedWeekStart = _startOfWeek(today);
                  });
                },
                child: const Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B9FD3),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedWeekStart = _focusedWeekStart.add(
                      const Duration(days: 7),
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekLabels
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7B8A98),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (index) {
              final date = weekDates[index];
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, _startOfDay(DateTime.now()));
              final hasActivity = activeDateKeys.contains(_dateKey(date));

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedDate = date),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFF5B9FD3)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              isToday && !isSelected
                                  ? Border.all(color: const Color(0xFF9EC6E9))
                                  : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : const Color(0xFF263747),
                              ),
                            ),
                            if (hasActivity)
                              Positioned(
                                bottom: 4,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : const Color(0xFF5B9FD3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekdayLabel = weekdays[_selectedDate.weekday % 7];
    final label =
        '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일 ($weekdayLabel)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF97A4B1),
        ),
      ),
    );
  }

  Widget _buildSudCard() {
    final series = _sudWeeklySeries(_selectedDate);
    final labels = List.generate(
      7,
      (i) => '${_selectedDate.subtract(Duration(days: 6 - i)).day}',
    );
    final latest = series.last;

    return _sectionCard(
      title: '나의 불안 변화',
      subtitle: '${_selectedDate.month}월 ${_selectedDate.day}일 기준 최근 7일',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SudMiniBarChart(values: series, labels: labels),
          const SizedBox(height: 10),
          Text(
            latest > 0
                ? '선택하신 날의 불안 점수는 ${latest.toStringAsFixed(1)}점이에요.'
                : '선택하신 날에 불안 점수 기록이 없어요.',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F6B76),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    final diaries = _diariesFor(_selectedDate);
    final relax = _relaxFor(_selectedDate);

    final diaryRate = _completionRateDiary(_selectedDate);
    final eduRate = _completionRateEducation(_selectedDate);
    final relaxRate = _completionRateRelaxation(_selectedDate);

    return _sectionCard(
      title: '수행률',
      subtitle: '교육(주간 1회)/이완/일기 수행률과 상세 로그',
      child: Column(
        children: [
          _CompletionRow(
            label: '교육',
            icon: Icons.menu_book_rounded,
            value: eduRate,
            logs: _educationWeeklyLogs(_selectedDate),
          ),
          const SizedBox(height: 12),
          _CompletionRow(
            label: '이완',
            icon: Icons.self_improvement_rounded,
            value: relaxRate,
            logs: relax
                .map((r) {
                  final task = (r['task_id']?.toString() ?? '이완');
                  final done = r['end_time'] != null ? '완료' : '진행';
                  return '$task $done';
                })
                .toList(),
          ),
          const SizedBox(height: 12),
          _CompletionRow(
            label: '일기',
            icon: Icons.edit_note_rounded,
            value: diaryRate,
            logs: diaries
                .map((d) {
                  final activation = d['activation'];
                  if (activation is Map) {
                    final label = activation['label']?.toString();
                    if (label != null && label.isNotEmpty) return label;
                  }
                  return '일기 기록';
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF8A97A3),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SudMiniBarChart extends StatelessWidget {
  const _SudMiniBarChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final value = values[index];
          final normalized = (value / 10).clamp(0.0, 1.0);
          final height = 24 + (normalized * 92);
          final color = value >= 7
              ? const Color(0xFFE4686C)
              : value >= 4
                  ? const Color(0xFFF4C159)
                  : const Color(0xFF6FB8E6);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value > 0 ? value.toStringAsFixed(1) : '-',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: value > 0 ? color : const Color(0xFFB3BDC7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 20,
                    height: height,
                    decoration: BoxDecoration(
                      color: value > 0 ? color : const Color(0xFFE8EEF3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A97A3),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CompletionRow extends StatelessWidget {
  const _CompletionRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.logs,
  });

  final String label;
  final IconData icon;
  final int value;
  final List<String> logs;

  Color _progressColor(int value) {
    if (value >= 100) return const Color(0xFF60B27E);
    if (value >= 50) return const Color(0xFFF4C159);
    return const Color(0xFFD5DEE7);
  }

  @override
  Widget build(BuildContext context) {
    final color = _progressColor(value);
    final displayLogs = logs.isEmpty ? const ['기록 없음'] : logs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: const Color(0xFF2C4154)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2F3F),
                  ),
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: value / 100,
              backgroundColor: const Color(0xFFF0F4F8),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayLogs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9FC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2EAF1)),
                  ),
                  child: Text(
                    displayLogs[index],
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5F6B76),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
