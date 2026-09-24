import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/firestore_sync_repository.dart';
import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/run_log.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/route_sign_badge.dart';
import '../widgets/stat_tile.dart';

const List<String> _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

/// 過去の走行記録をカレンダー形式で振り返る画面。
/// 日付ごとに、その日走った距離と挑戦していた国道が一覧できる。
/// ランニング計測での記録も、ホーム画面から手動で追加した記録も、
/// どちらも[RunLog]として同じテーブルに保存されているため区別なく表示される。
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final RouteRepository _repo = RouteRepository.instance;

  bool _loading = true;
  List<RunLog> _logs = const [];
  Map<String, NationalRoute> _routesById = const {};

  late DateTime _displayedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    final logs = await _repo.getRunLogs();
    final routes = await _repo.getRoutes();
    logs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _routesById = {for (final r in routes) r.routeId: r};
      _loading = false;
    });
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<RunLog>> get _logsByDay {
    final map = <DateTime, List<RunLog>>{};
    for (final log in _logs) {
      final day = _dateOnly(log.recordedAt);
      map.putIfAbsent(day, () => []).add(log);
    }
    return map;
  }

  List<RunLog> get _logsInDisplayedMonth {
    return _logs
        .where((l) =>
            l.recordedAt.year == _displayedMonth.year && l.recordedAt.month == _displayedMonth.month)
        .toList();
  }

  List<RunLog> get _visibleLogs {
    final selected = _selectedDay;
    if (selected == null) return _logsInDisplayedMonth;
    return _logsInDisplayedMonth.where((l) => _dateOnly(l.recordedAt) == selected).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
      _selectedDay = null;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = _selectedDay == day ? null : day;
    });
  }

  /// 記録カードをタップしたときに編集/削除シートを開く。
  Future<void> _openEditSheet(RunLog log) async {
    final result = await showModalBottomSheet<({bool delete, double distanceKm, int durationSeconds})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusLg)),
      ),
      builder: (sheetContext) => _EditRunLogSheet(log: log, route: _routesById[log.routeId]),
    );
    if (result == null) return;

    if (result.delete) {
      await _repo.deleteRunLog(log);
      // 削除をクラウドにも伝える。待たないのは追加のときと同じ理由。
      unawaited(FirestoreSyncRepository.instance.syncNow());
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を削除しました')),
      );
      return;
    }

    if (result.distanceKm <= 0) return;
    await _repo.updateRunLog(
      oldLog: log,
      distanceKm: result.distanceKm,
      durationSeconds: result.durationSeconds,
      caloriesBurned: log.caloriesBurned ?? 0,
    );
    unawaited(FirestoreSyncRepository.instance.syncNow());
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('記録を更新しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('ラン履歴', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue))
          : SafeArea(
              top: false,
              // カレンダー・サマリー・記録リストをまとめて1つのスクロール領域にする。
              // 以前はリスト部分だけがExpanded+ListViewでスクロールする構成だったため、
              // カレンダー+サマリーの高さだけで画面が埋まる(特にPCのウィンドウが低いとき)と
              // リストへスクロールできなくなる不具合があった。
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _buildCalendarCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: _buildSummaryRow(),
                    ),
                    _buildLogList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCalendarCard() {
    final logsByDay = _logsByDay;
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    // 日曜始まりのグリッドにするための先頭の空白セル数。
    // DateTime.weekday は月=1…日=7 なので、日曜(7)を0扱いにする。
    final leadingBlanks = firstOfMonth.weekday % 7;
    final today = _dateOnly(DateTime.now());

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final hasRun = logsByDay.containsKey(date);
      final isToday = date == today;
      final isSelected = date == _selectedDay;
      cells.add(_buildDayCell(date, day, hasRun: hasRun, isToday: isToday, isSelected: isSelected));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '${_displayedMonth.year}年${_displayedMonth.month}月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Row(
            children: _weekdayLabels
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    int day, {
    required bool hasRun,
    required bool isToday,
    required bool isSelected,
  }) {
    // 走った日は国道標識(おにぎり)の形で示す。選んでいる日はその形を
    // 塗りつぶし、今日には下に点を打つ。走っていない日は形を出さず、
    // 選んでいるときだけ丸く塗る(形の違いで「走った/走っていない」が分かる)。
    final numberColor = isSelected
        ? Colors.white
        : (hasRun ? AppColors.routeSignBlue : AppColors.textPrimary);
    final number = Text(
      '$day',
      style: TextStyle(
        fontSize: 11,
        fontWeight: hasRun ? FontWeight.w900 : FontWeight.w700,
        color: numberColor,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => _selectDay(date),
        // 形の外側をタップしても選べるように、余白でも当たり判定を取る。
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRun)
              RouteSignMark(
                size: _dayMarkSize,
                color: AppColors.routeSignBlue,
                filled: isSelected,
                child: number,
              )
            else
              Container(
                width: _dayMarkSize,
                height: _dayMarkSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.routeSignBlue : Colors.transparent,
                ),
                child: number,
              ),
            const SizedBox(height: 2),
            // 今日の印。日付の位置が揃うよう、今日以外も同じ大きさの
            // 透明な点を置いて高さを合わせる。
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? AppColors.routeSignBlue : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// カレンダーの日付マーク(おにぎり／丸)の大きさ。
  static const double _dayMarkSize = 30;

  Widget _buildSummaryRow() {
    final logs = _visibleLogs;
    final totalKm = logs.fold<double>(0, (sum, l) => sum + l.distanceKm);
    final label = _selectedDay != null
        ? '${_selectedDay!.month}月${_selectedDay!.day}日の記録'
        : '${_displayedMonth.month}月の記録';
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: label,
            value: '${logs.length}回',
            valueFontSize: 17,
            centered: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: '合計走行距離',
            value: formatKm(totalKm, digits: totalKm < 10 ? 2 : 1),
            valueFontSize: 17,
            centered: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          ),
        ),
      ],
    );
  }

  Widget _buildLogList() {
    final logs = _visibleLogs;
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('この期間の記録はまだありません', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      );
    }
    // 画面全体がSingleChildScrollViewで既にスクロールするため、ここはただのColumn
    // (ネストしたスクロール領域を作らない)。
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _RunLogCard(
              log: logs[i],
              route: _routesById[logs[i].routeId],
              onTap: () => _openEditSheet(logs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 1件の走行記録を「日付・距離・所要時間・国道名」の4項目が
/// 一目でわかる形で表示するカード。タップすると編集/削除シートが開く。
class _RunLogCard extends StatelessWidget {
  final RunLog log;
  final NationalRoute? route;
  final VoidCallback? onTap;

  const _RunLogCard({required this.log, required this.route, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = log.recordedAt;
    final digits = log.distanceKm < 1 ? 3 : 2;
    final hasDuration = log.durationSeconds > 0;

    return Material(
      color: AppColors.bgSurfaceRaised,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteSignBadge(routeNumber: route?.routeNumber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          // 挑戦していた国道の名前。
                          child: Text(
                            route?.name ?? '不明な国道',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 記録日。
                            Text(
                              '${date.year}/${date.month}/${date.day}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            ),
                            Text(
                              '${_weekdayLabels[date.weekday % 7]}曜日',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // 走行距離。
                        _field(Icons.straighten, '距離', formatKm(log.distanceKm, digits: digits)),
                        const SizedBox(width: 16),
                        // 所要時間(手動追加の記録は計測していないため「手動記録」と表示)。
                        _field(
                          Icons.timer_outlined,
                          '所要時間',
                          hasDuration ? formatDurationClock(log.durationSeconds) : '手動記録',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          '$label ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// [_RunHistoryScreenState._openEditSheet]から開く、既存の走行記録を
/// 編集・削除するためのボトムシート。入力欄は[_AddDistanceSheet]
/// (home_screen.dart)と同じ構成に、記録日の表示と削除ボタンを加えたもの。
class _EditRunLogSheet extends StatefulWidget {
  final RunLog log;
  final NationalRoute? route;

  const _EditRunLogSheet({required this.log, required this.route});

  @override
  State<_EditRunLogSheet> createState() => _EditRunLogSheetState();
}

class _EditRunLogSheetState extends State<_EditRunLogSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _distanceController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _distanceController = TextEditingController(text: _formatInputDistance(log.distanceKm));
    final minutes = log.durationSeconds ~/ 60;
    final seconds = log.durationSeconds % 60;
    _minutesController = TextEditingController(text: minutes > 0 ? '$minutes' : '');
    _secondsController = TextEditingController(text: seconds > 0 ? '$seconds' : '');
  }

  // 距離の初期値表示用: 末尾の不要な0を削る(例: "5.20" → "5.2", "5.00" → "5")。
  static String _formatInputDistance(double km) {
    var s = km.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final distanceKm = double.parse(_distanceController.text.replaceAll(',', '.'));
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
    final durationSeconds = minutes * 60 + seconds;
    Navigator.of(context).pop((delete: false, distanceKm: distanceKm, durationSeconds: durationSeconds));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この記録を削除しますか？'),
        content: const Text('削除すると元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop((delete: true, distanceKm: 0.0, durationSeconds: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final date = widget.log.recordedAt;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                route != null ? '${route.name}の記録を編集' : '記録を編集',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.year}/${date.month}/${date.day}(${_weekdayLabels[date.weekday % 7]})の記録',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _distanceController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  hintText: '例: 5.2',
                  suffixText: 'km',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return '正しい距離を入力してください';
                  if (parsed > 500) return '一度に追加できる距離が大きすぎます';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '所要時間(任意)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '分',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) return null;
                        final parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 0) return '正しい分数を入力してください';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _secondsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '秒',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) return null;
                        final parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 0 || parsed > 59) return '0〜59の範囲で入力してください';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GradientButton(
                onPressed: _submit,
                height: 50,
                child: const Text(
                  '保存する',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(
                    'この記録を削除する',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
