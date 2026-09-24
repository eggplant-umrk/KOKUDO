import 'package:flutter/material.dart';

import '../data/route_catalog.dart';
import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../widgets/route_search_field.dart';
import '../widgets/route_sign_badge.dart';

/// 「挑戦する国道を変更」画面。全国道(459路線)の一覧から、次に
/// 挑戦する路線を選び直せる。数が多いので路線番号・都道府県・地名で絞り込める。
/// 既に進捗がある路線を選んだ場合はその
/// 続きから、初めての路線を選んだ場合は0kmから開始する
/// (RouteRepository.setActiveRoute)。切り替え後も、それまで挑戦していた
/// 路線の進捗は消えずに残るので、あとで選び直せば続きから再開できる。
///
/// 完走済みの路線は一覧には表示するが、タップでは選べないようにしている
/// (再挑戦時にどう扱うかの仕様がまだ決まっていないため、ひとまず選択不可
/// にして「選んだのに何も起きない」という混乱を避けている)。
class ChangeRouteScreen extends StatefulWidget {
  /// 初回起動(まだ挑戦する国道が一度も決まっていない)かどうか。
  ///
  /// trueのときは戻る手段を出さず、切り替えの確認ダイアログも出さない
  /// (切り替え元が無いので聞くことが無い)。選び終えたら [onSelected] を
  /// 呼ぶだけで、この画面自身はpopしない(押し出したのがNavigatorではなく
  /// [RouteSetupGate] のため)。
  final bool firstRun;

  /// [firstRun] のときに、路線を選び終えたことを親へ伝える。
  final VoidCallback? onSelected;

  const ChangeRouteScreen({super.key, this.firstRun = false, this.onSelected});

  @override
  State<ChangeRouteScreen> createState() => _ChangeRouteScreenState();
}

class _ChangeRouteScreenState extends State<ChangeRouteScreen> {
  final RouteRepository _repo = RouteRepository.instance;

  bool _loading = true;
  bool _switching = false;
  List<NationalRoute> _routes = const [];
  Map<String, UserRouteProgress> _progressByRoute = const {};
  String? _activeRouteId;
  String _query = '';
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final routes = await _repo.getRoutes();
    final activeRouteId = await _repo.getActiveRouteId();
    final progressByRoute = await _repo.getProgressByRoute();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _progressByRoute = progressByRoute;
      _activeRouteId = activeRouteId;
      _loading = false;
    });
  }

  RouteStatus _statusOf(NationalRoute route) {
    return RouteRepository.statusOfProgress(_progressByRoute[route.routeId]);
  }

  List<NationalRoute> get _filteredRoutes {
    return _routes.where((r) => routeMatchesQuery(r, _query)).toList();
  }

  Future<void> _handleSelect(NationalRoute route) async {
    if (route.routeId == _activeRouteId || _switching) return;

    // 初回はまだ何にも挑戦していないので、確認を挟まずそのまま始める。
    if (widget.firstRun) {
      setState(() => _switching = true);
      await _repo.setActiveRoute(route.routeId);
      if (!mounted) return;
      widget.onSelected?.call();
      return;
    }

    final currentKm = _progressByRoute[route.routeId]?.currentDistanceKm ?? 0;
    final hasProgress = currentKm > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${route.name}に切り替えますか?'),
        content: Text(
          hasProgress
              ? '現在 ${currentKm.toStringAsFixed(1)}km まで進んでいます。続きから再開します。'
              : '0kmから挑戦を開始します。現在挑戦中の路線の進捗はそのまま保存されるので、あとで選び直せます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('切り替える', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _switching = true);
    await _repo.setActiveRoute(route.routeId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final firstRun = widget.firstRun;
    return PopScope(
      // 初回は国道を選ぶまで先に進めない(戻り先が無いため)。
      canPop: !firstRun,
      child: Scaffold(
        backgroundColor: AppColors.bgSurface,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: !firstRun,
          title: Text(
            firstRun ? '挑戦する国道を選ぶ' : '挑戦する国道を変更',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue))
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (firstRun)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          '走った距離を積み上げる国道を1本選んでください。\n'
                          'あとからいつでも変更できます。まずは短い路線から始めるのがおすすめです。',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: RouteSearchField(
                        controller: _queryController,
                        onChanged: (q) => setState(() => _query = q),
                      ),
                    ),
                    Expanded(child: _buildRouteList(_filteredRoutes)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRouteList(List<NationalRoute> routes) {
    if (routes.isEmpty) {
      return const Center(
        child: Text('該当する路線がありません', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: routes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildRouteTile(routes[index]),
    );
  }

  Widget _buildRouteTile(NationalRoute route) {
    final status = _statusOf(route);
    final isActive = route.routeId == _activeRouteId;
    final isCompleted = status == RouteStatus.completed;
    final progress = _progressByRoute[route.routeId];

    final digits = route.totalDistanceKm < 1 ? 3 : 1;
    var meta = '${regionLabel[route.region]} ・ ${route.totalDistanceKm.toStringAsFixed(digits)}km';
    if (status == RouteStatus.inProgress && progress != null) {
      meta += ' ・ ${progress.currentDistanceKm.toStringAsFixed(1)}km地点';
    }
    // 都道府県(検索で使う情報)を先に、起点→終点はその下に。長い路線は
    // 起点→終点が折り返すので、行数に余裕を持たせている。
    final prefectures = RouteCatalog.prefecturesOf(route.routeId);
    if (prefectures.isNotEmpty) {
      meta += '\n${prefectures.join('・')}';
    }
    final startLabel = route.startPoint.label;
    final endLabel = route.endPoint.label;
    if (startLabel != null && endLabel != null) {
      meta += '\n$startLabel → $endLabel';
    }

    return Opacity(
      opacity: isCompleted ? 0.55 : 1,
      child: Material(
        color: isActive ? const Color(0x1422588E) : AppColors.bgSurfaceRaised,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: InkWell(
          onTap: (isCompleted || _switching) ? null : () => _handleSelect(route),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: isActive ? AppColors.routeSignBlue : AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: Row(
              children: [
                RouteSignBadge(routeNumber: route.routeNumber, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              route.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x2EFFB238),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '完走',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentGoldText),
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x1E22588E),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '挑戦中',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.routeSignBlue),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isActive)
                  const Icon(Icons.check_circle, color: AppColors.routeSignBlue, size: 22)
                else if (!isCompleted)
                  const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
