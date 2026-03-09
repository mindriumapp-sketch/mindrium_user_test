import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/common/constants.dart';

class MindriumPopupDesign extends StatefulWidget {
  final String title;
  final TextEditingController? searchController;
  final MapController? mapController;
  final VoidCallback? onMapReady;
  final LatLng? picked;
  final LatLng? current;
  final List<Marker>? savedMarkers;
  final VoidCallback? onSearch;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final Function(TapPosition, LatLng)? onTap;
  final DateTime? initialTimeDateTime;
  final ValueChanged<DateTime>? onTimeChanged;
  final String? locationText;
  final bool showLocationLabelInput;
  final TextEditingController? locationLabelController;
  final List<String> locationLabelChips;
  final bool isLoadingLocationLabels;
  final ValueChanged<String>? onLocationLabelSelected;
  final Future<void> Function()? onAddLocationLabel;
  final bool showTimePicker;

  const MindriumPopupDesign({
    super.key,
    required this.title,
    this.searchController,
    this.mapController,
    this.onMapReady,
    this.picked,
    this.current,
    this.savedMarkers,
    this.onSearch,
    this.onBack,
    this.onNext,
    this.onTap,
    this.initialTimeDateTime,
    this.onTimeChanged,
    this.locationText,
    this.showLocationLabelInput = false,
    this.locationLabelController,
    this.locationLabelChips = const [],
    this.isLoadingLocationLabels = false,
    this.onLocationLabelSelected,
    this.onAddLocationLabel,
    this.showTimePicker = true,
  });

  @override
  State<MindriumPopupDesign> createState() => _MindriumPopupDesignState();
}

class _MindriumPopupDesignState extends State<MindriumPopupDesign> {
  static const double _sheetMinSize = 0.075;
  static const double _sheetInitialSize = 0.33;
  static const double _sheetMaxSize = 0.6;

  late DateTime _pickerTime;
  bool _showJellyfishMessage = true;

  @override
  void initState() {
    super.initState();
    _pickerTime = widget.initialTimeDateTime ?? DateTime(2000, 1, 1, 9, 0);
  }

  void _toggleJellyfishMessage() {
    setState(() {
      _showJellyfishMessage = !_showJellyfishMessage;
    });
  }

  Widget _buildJellyfishGuide(String guideText) {
    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_showJellyfishMessage)
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(right: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF5DADEC).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    guideText,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF626262),
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -12,
            bottom: 0,
            child: GestureDetector(
              onTap: _toggleJellyfishMessage,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                'assets/image/jellyfish_smart.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool hasLocation, String locationText) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.place_outlined, color: Color(0xFF4A90E2), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '위치 설정',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2233),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: hasLocation ? const Color(0xFF4A4F57) : Colors.grey,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String timeText) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF4A90E2), size: 20),
              const SizedBox(width: 8),
              const Text(
                '시간 설정',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2233),
                ),
              ),
              const Spacer(),
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A4F57),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 156,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _pickerTime,
              onDateTimeChanged: (dt) {
                final next = DateTime(2000, 1, 1, dt.hour, dt.minute);
                setState(() => _pickerTime = next);
                widget.onTimeChanged?.call(next);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationLabelCard() {
    final selectedLabel = widget.locationLabelController?.text.trim() ?? '';
    final chips = widget.locationLabelChips.toSet().toList();

    Widget buildLabelChip({
      required String label,
      required Future<void> Function() onTapAsync,
      bool selected = false,
    }) {
      return InkWell(
        onTap: () async {
          await onTapAsync();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE9F3FF) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF7CB3E8) : const Color(0xFFC7CDD7),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF275E92) : const Color(0xFF2B2F36),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark_border,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '위치 라벨',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2233),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.isLoadingLocationLabels) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...chips.map(
                  (label) => buildLabelChip(
                    label: label,
                    selected: selectedLabel == label,
                    onTapAsync: () async {
                      widget.onLocationLabelSelected?.call(label);
                    },
                  ),
                ),
                buildLabelChip(
                  label: '+ 추가',
                  onTapAsync: () async {
                    await widget.onAddLocationLabel?.call();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeText = TimeOfDay.fromDateTime(_pickerTime).format(context);
    final guideText = widget.showTimePicker
        ? '일기에 작성한 상황이 일어난 위치와 시간을 선택한 뒤 [저장]을 눌러주세요.'
        : '알림을 받을 위치를 선택한 뒤 [저장]을 눌러주세요.';
    final bool hasLocation =
        widget.locationText != null && widget.locationText!.trim().isNotEmpty;
    final String locationText =
        hasLocation ? widget.locationText! : '지도를 탭해 위치를 선택해주세요.';

    return Material(
      color: const Color(0xE0E9F3FF),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.mapController != null)
            FlutterMap(
              mapController: widget.mapController!,
              options: MapOptions(
                initialCenter:
                    widget.picked ?? widget.current ?? const LatLng(37.5665, 126.9780),
                initialZoom: 16,
                onTap: widget.onTap,
                onMapReady: widget.onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.vworld.kr/req/wmts/1.0.0/{key}/Base/{z}/{y}/{x}.png',
                  additionalOptions: {'key': vworldApiKey},
                ),
                if (widget.current != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.current!,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xFF4A90E2),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                if (widget.picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.picked!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFF5B3EFF),
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                if (widget.savedMarkers != null && widget.savedMarkers!.isNotEmpty)
                  MarkerLayer(markers: widget.savedMarkers!),
              ],
            ),

          if (widget.searchController != null)
            Positioned(
              top: 56,
              left: 24,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: widget.searchController,
                  onSubmitted: (_) => widget.onSearch?.call(),
                  decoration: const InputDecoration(
                    hintText: '주소 검색',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF4A90E2)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 24,
            right: 12,
            top: 120,
            child: _buildJellyfishGuide(guideText),
          ),

          Positioned.fill(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: _sheetInitialSize,
                minChildSize: _sheetMinSize,
                maxChildSize: _sheetMaxSize,
                snap: false,
                builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFF).withValues(alpha: 0.97),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      MediaQuery.of(context).padding.bottom + 12,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB9C3D4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.showTimePicker ? '위치/시간 설정' : '위치 설정',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A4760),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLocationCard(hasLocation, locationText),
                      if (widget.showLocationLabelInput &&
                          widget.locationLabelController != null) ...[
                        const SizedBox(height: 10),
                        _buildLocationLabelCard(),
                      ],
                      if (widget.showTimePicker) ...[
                        const SizedBox(height: 10),
                        _buildTimeCard(timeText),
                      ],
                      const SizedBox(height: 12),
                      NavigationButtons(
                        leftLabel: '이전',
                        rightLabel: '저장',
                        onBack: widget.onBack ?? () => Navigator.pop(context),
                        onNext: widget.onNext ?? () {},
                      ),
                    ],
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
